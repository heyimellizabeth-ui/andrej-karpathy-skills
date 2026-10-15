---
name: run-andrej-karpathy-skills
description: Run, install, validate, test and smoke-check the andrej-karpathy-skills Claude Code plugin. Use when asked to run this plugin, check that the karpathy-guidelines skill loads, test a change to SKILL.md / CLAUDE.md / the Cursor rule / the READMEs, or verify the marketplace install works.
---

# Run andrej-karpathy-skills

This repo is a Claude Code plugin with no build step. It ships one skill (`skills/karpathy-guidelines/SKILL.md`) through `.claude-plugin/marketplace.json`, and keeps the same guidelines in `CLAUDE.md`, `.cursor/rules/karpathy-guidelines.mdc` and two READMEs (English and Chinese). "Running" it means installing the plugin into Claude Code and seeing the model load the skill. The driver is `smoke.sh`, next to this file. All paths below are relative to the repo root.

## Prerequisites

The `claude` CLI on `PATH` (this was verified with 2.1.300) and bash. No other packages. The `live` check also needs a logged-in Claude.

## Run (agent path)

```bash
.claude/skills/run-andrej-karpathy-skills/smoke.sh all    # offline: validate, install, sync, hook (~10 s)
.claude/skills/run-andrej-karpathy-skills/smoke.sh live   # calls the model 3 times (~20 s)
```

Each prints `PASS` / `WARN` / `FAIL` lines, ends with `RESULT: OK` or `RESULT: FAILED`, and exits non-zero on failure. Run one check at a time with `validate`, `install`, `sync`, `hook` or `live`:

| Check | What it does |
|---|---|
| `validate` | `claude plugin validate .` on the marketplace and plugin manifests. |
| `install` | Adds this checkout as a marketplace and installs `andrej-karpathy-skills@karpathy-skills` into a throwaway `CLAUDE_CONFIG_DIR`. Then checks that `claude plugin details` lists `Skills (1) karpathy-guidelines`. Your real `~/.claude` is never touched. |
| `sync` | Checks that the `## ` headings and principle text in `CLAUDE.md`, `SKILL.md` and the Cursor rule match, that the SKILL.md frontmatter name is right, and that `README.md` and `README.zh.md` have the same number of sections. Changes to these files are most of this repo's PRs, so run this after touching any of them. |
| `hook` | Runs `.claude/hooks/session-start.sh`. It must print one line when `CLAUDE_CODE_REMOTE=true` and stay silent otherwise. |
| `live` | Headless `claude -p --plugin-dir .` from a temp directory. First a control run without the plugin must answer NONE. Then the run with the plugin must list `andrej-karpathy-skills:karpathy-guidelines`. Finally it invokes `/andrej-karpathy-skills:karpathy-guidelines` and must reply with principle 3's heading, "Surgical Changes". |

The same flow by hand, to poke at it:

```bash
cfg=$(mktemp -d)
CLAUDE_CONFIG_DIR=$cfg claude plugin marketplace add "$PWD"
CLAUDE_CONFIG_DIR=$cfg claude plugin install andrej-karpathy-skills@karpathy-skills
CLAUDE_CONFIG_DIR=$cfg claude plugin details andrej-karpathy-skills@karpathy-skills
rm -rf "$cfg"
```

## Run (human path)

Follow the Install section of `README.md` (the `/plugin` commands, run inside an interactive Claude Code session). That installs from GitHub rather than your local checkout, and it wasn't run for this skill because it needs an interactive session. Use the agent path to test local changes.

## Gotchas

- **`validate` passes with two warnings, both expected.** `marketplace.json` has an `id` field that Claude Code ignores. `CLAUDE.md` at the plugin root is **not** loaded for people who install the plugin: only the skill ships. An edit to `CLAUDE.md` alone never reaches plugin users.
- **Known drift: `sync` reports one WARN.** `SKILL.md` lacks the closing "These guidelines are working if…" paragraph that `CLAUDE.md` and the Cursor rule have. It's a WARN, not a FAIL. A heading mismatch is a FAIL; this was confirmed by renaming principle 3 in the Cursor rule.
- **Run `live` from outside the repo.** Run inside the checkout, Claude also reads the repo's `CLAUDE.md`, which contains the same headings, so the content check would pass even with a broken skill. The driver runs from `mktemp -d` for this reason.
- **When loaded with `--plugin-dir`, the skill is namespaced** `andrej-karpathy-skills:karpathy-guidelines`, not just `karpathy-guidelines`. Invoke it with that full name.
- **`claude -p ... --allowedTools Skill "prompt"` fails** with `Input must be provided either through stdin or as a prompt argument`. `--allowedTools` takes several values and swallows the prompt. Pipe the prompt on stdin instead.
- **`claude -p "prompt"` with no stdin waits 3 s** and prints `Warning: no stdin data received in 3s`. Add `< /dev/null`.
- **`claude plugin install` writes to your user config.** Always set `CLAUDE_CONFIG_DIR=$(mktemp -d)` when testing, or you'll install the local checkout over a real install.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Error: Input must be provided either through stdin or as a prompt argument when using --print` | The prompt came after `--allowedTools`. Pipe it on stdin (see Gotchas). |
| `live` content check passes but you changed the skill's headings | You ran from the repo root, so `CLAUDE.md` answered. Use `smoke.sh live`, which runs from a temp directory. |
| `FAIL control run already has the skill` | The plugin is installed in your real config. The `live` result means nothing until you remove it, or run with an empty `CLAUDE_CONFIG_DIR`. |
