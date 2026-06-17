#!/bin/bash
# SessionStart hook for Claude Code on the web.
# This is a documentation/skills repository with no dependencies, build, or
# tests, so there is nothing to install. The hook is kept for consistency
# across the repo fleet and as a place to add setup later if needed.
set -euo pipefail

# Only run in remote (Claude Code on the web) sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "[session-start] No dependencies to install (markdown skills repository)."
