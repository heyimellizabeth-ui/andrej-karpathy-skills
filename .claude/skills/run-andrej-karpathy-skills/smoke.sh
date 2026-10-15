#!/usr/bin/env bash
# Smoke driver for the andrej-karpathy-skills Claude Code plugin.
# Usage (from the repo root):
#   .claude/skills/run-andrej-karpathy-skills/smoke.sh [validate|install|sync|hook|live|all]
# "all" runs everything except "live" (live calls the model and needs Claude auth).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
SKILL=skills/karpathy-guidelines/SKILL.md
CURSOR=.cursor/rules/karpathy-guidelines.mdc
FAIL=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }

validate() {
  echo "== validate: manifests (claude plugin validate)"
  local out; out=$(claude plugin validate . 2>&1); local rc=$?
  echo "$out" | sed 's/^/     /'
  [ $rc -eq 0 ] && pass "claude plugin validate exit 0" || fail "claude plugin validate exit $rc"
}

install() {
  echo "== install: marketplace add + plugin install into a throwaway CLAUDE_CONFIG_DIR"
  local cfg; cfg=$(mktemp -d)
  CLAUDE_CONFIG_DIR="$cfg" claude plugin marketplace add "$ROOT" >/dev/null 2>&1 \
    && pass "marketplace add (karpathy-skills)" || { fail "marketplace add"; rm -rf "$cfg"; return; }
  CLAUDE_CONFIG_DIR="$cfg" claude plugin install andrej-karpathy-skills@karpathy-skills >/dev/null 2>&1 \
    && pass "plugin install andrej-karpathy-skills@karpathy-skills" || { fail "plugin install"; rm -rf "$cfg"; return; }
  local det; det=$(CLAUDE_CONFIG_DIR="$cfg" claude plugin details andrej-karpathy-skills@karpathy-skills 2>&1)
  echo "$det" | grep -E 'Skills|Always-on|karpathy-guidelines  ' | sed 's/^/     /'
  echo "$det" | grep -q 'Skills (1)  karpathy-guidelines' && pass "inventory lists skill karpathy-guidelines" || fail "skill missing from inventory"
  rm -rf "$cfg"
}

sync() {
  echo "== sync: the guideline copies and translations still match"
  for f in "$SKILL" "$CURSOR"; do
    if diff -q <(grep -E '^## ' CLAUDE.md) <(grep -E '^## ' "$f") >/dev/null; then pass "section headings CLAUDE.md == $f"
    else fail "section headings differ: CLAUDE.md vs $f"; diff <(grep -E '^## ' CLAUDE.md) <(grep -E '^## ' "$f") | sed 's/^/     /'; fi
    if diff -q <(sed -n '/^## 1\./,$p' CLAUDE.md) <(sed -n '/^## 1\./,$p' "$f") >/dev/null; then pass "principle text CLAUDE.md == $f"
    else warn "principle text differs: CLAUDE.md vs $f (diff below)"; diff <(sed -n '/^## 1\./,$p' CLAUDE.md) <(sed -n '/^## 1\./,$p' "$f") | sed 's/^/     /'; fi
  done
  head -5 "$SKILL" | grep -q '^name: karpathy-guidelines$' && pass "SKILL.md frontmatter name" || fail "SKILL.md frontmatter name"
  local en zh; en=$(grep -cE '^#{2,3} ' README.md); zh=$(grep -cE '^#{2,3} ' README.zh.md)
  [ "$en" = "$zh" ] && pass "README.md / README.zh.md section count ($en)" || fail "README.md has $en sections, README.zh.md has $zh"
}

hook() {
  echo "== hook: .claude/hooks/session-start.sh"
  local out
  out=$(CLAUDE_CODE_REMOTE=true bash .claude/hooks/session-start.sh 2>&1) && [ -n "$out" ] \
    && pass "remote session: exit 0, prints: $out" || fail "remote session run"
  out=$(CLAUDE_CODE_REMOTE= bash .claude/hooks/session-start.sh 2>&1) && [ -z "$out" ] \
    && pass "local session: exit 0, silent" || fail "local session should be silent"
}

live() {
  echo "== live: headless claude -p with --plugin-dir (uses the model; needs auth)"
  local tmp; tmp=$(mktemp -d)
  local ASK="Without using tools: list the exact names of any skills available to you whose name contains 'karpathy'. Reply with just the names, one per line, or NONE."
  # Control: same question without the plugin must NOT list the skill.
  local base; base=$( (cd "$tmp" && timeout 180 env -u CLAUDECODE claude -p --max-turns 1 "$ASK" < /dev/null) 2>&1)
  echo "     without plugin: $base"
  echo "$base" | grep -q 'andrej-karpathy-skills:karpathy-guidelines' && fail "control run already has the skill (installed globally?)" || pass "control run without --plugin-dir has no karpathy skill"
  local names; names=$( (cd "$tmp" && timeout 180 env -u CLAUDECODE claude -p --plugin-dir "$ROOT" --max-turns 1 \
    "$ASK" < /dev/null) 2>&1)
  echo "$names" | sed 's/^/     /'
  echo "$names" | grep -q 'andrej-karpathy-skills:karpathy-guidelines' && pass "skill is offered to the model" || fail "skill not offered"
  # --allowedTools is variadic and swallows a trailing prompt argument, so the prompt goes in on stdin.
  local used; used=$( (cd "$tmp" && echo "/andrej-karpathy-skills:karpathy-guidelines Then reply with only the exact heading text of principle 3 from the loaded guidelines." \
    | timeout 240 env -u CLAUDECODE claude -p --plugin-dir "$ROOT" --max-turns 3 --allowedTools Skill) 2>&1)
  echo "$used" | sed 's/^/     /'
  echo "$used" | grep -qi 'Surgical Changes' && pass "invoking the skill loads its content" || fail "skill content not loaded"
  rm -rf "$tmp"
}

case "${1:-all}" in
  validate) validate ;; install) install ;; sync) sync ;; hook) hook ;; live) live ;;
  all) validate; install; sync; hook ;;
  *) echo "usage: $0 [validate|install|sync|hook|live|all]"; exit 2 ;;
esac
[ $FAIL -eq 0 ] && echo "RESULT: OK" || echo "RESULT: FAILED"
exit $FAIL
