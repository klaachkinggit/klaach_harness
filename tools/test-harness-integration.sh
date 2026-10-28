#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"

cleanup() {
  local status=$?
  if [ "$status" -eq 0 ]; then
    rm -rf "$TMP"
  else
    echo "Temp project kept for inspection: $TMP" >&2
  fi
}
trap cleanup EXIT

RAW_BASE="$(python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

print(Path(sys.argv[1]).resolve().as_uri())
PY
)"

mkdir -p "$TMP/home" "$TMP/project"
cd "$TMP/project"
git init -q

cat > AGENTS.md <<'MD'
# Existing Codex Rules

## Project: sentinel-codex
- Keep this Codex project rule.
MD
mkdir -p .codex
mkdir -p .claude/commands .claude/hooks .claude/skills/frontend-design .claude/skills/my-skill prompts .codex/skills/matt-pocock-diagnose .codex/hooks
touch RULES.md sync-rules.sh prompts/old.md .codex/skills/matt-pocock-diagnose/SKILL.md .codex/hooks/project-scope.sh
touch .claude/commands/tdd.md .claude/commands/my-command.md .claude/hooks/project-scope.sh .claude/skills/frontend-design/SKILL.md .claude/skills/my-skill/SKILL.md
cat > CLAUDE.md <<'MD'
# Existing Claude Rules

- sentinel-claude: keep this Claude project rule.
MD
cat > .mcp.json <<'JSON'
{
  "mcpServers": {
    "custom-claude": {"command": "custom-command", "args": ["--custom"]},
    "filesystem": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "."]}
  }
}
JSON
cat > .claude/settings.json <<'JSON'
{
  "customSetting": true,
  "hooks": {
    "PostToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash .claude/hooks/project-scope.sh"}]},
      {"matcher": "Write", "hooks": [{"type": "command", "command": "echo custom-hook"}]}
    ]
  }
}
JSON
cat > .codex/config.toml <<'TOML'
[mcp_servers.custom-codex]
command = "custom-command"
args = ["--custom"]

[mcp_servers.filesystem]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "."]
TOML
cat > .codex/hooks.json <<'JSON'
{
  "customSetting": true
}
JSON

HOME="$TMP/home" HARNESS_RAW_BASE="$RAW_BASE" SKIP_CODEGRAPH=1 bash "$ROOT/apply.sh" >/dev/null

test "$(git config --get core.hooksPath)" = ".githooks"
test -f AGENTS.md
grep -q 'sentinel-codex' AGENTS.md
grep -q 'Foundational Rules (Karpathy)' AGENTS.md
grep -q 'ponytail' AGENTS.md
grep -q '^@AGENTS.md' CLAUDE.md
grep -q 'sentinel-claude' CLAUDE.md
test ! -d prompts
test ! -e RULES.md
python3 - <<'PY'
import json
mcp = json.load(open(".mcp.json"))["mcpServers"]
assert "custom-claude" in mcp and "context7" in mcp and "filesystem" not in mcp, mcp
assert mcp["github"]["env"]["GITHUB_PERSONAL_ACCESS_TOKEN"] == "${GITHUB_TOKEN}"
settings = json.load(open(".claude/settings.json"))
assert settings["customSetting"] is True
commands = [h["command"] for blocks in settings["hooks"].values() for b in blocks for h in b["hooks"]]
assert "echo custom-hook" in commands and not any("project-scope" in c for c in commands), commands
assert any("protect-env.sh" in c for c in commands), commands
PY
test ! -e .claude/commands/tdd.md
test -f .claude/commands/my-command.md
test ! -e .claude/hooks/project-scope.sh
test ! -d .claude/skills/frontend-design
test -f .claude/skills/my-skill/SKILL.md
test -f APPLY.md
test -f HARNESS.md
test -f PROFILES.md
test -f docs/agent-work-environment.md
test -f MEMORY.md
test -f LESSONS.md
test -f docs/adr/0000-template.md
test -f .codex/config.toml
grep -q '^\[mcp_servers.context7\]' .codex/config.toml
grep -q '^\[mcp_servers.custom-codex\]' .codex/config.toml
! grep -q '^\[mcp_servers.filesystem\]' .codex/config.toml
test -x .codex/hooks/protect-env.sh
grep -q 'protect-env.sh' .codex/hooks.json
! grep -q 'project-scope.sh' .codex/hooks.json
for skill in find-skills superpowers grill-me tdd diagnosing-bugs to-issues codebase-design improve-codebase-architecture ponytail; do
  test -f ".codex/skills/${skill}/SKILL.md"
  cmp -s ".codex/skills/${skill}/SKILL.md" ".claude/skills/${skill}/SKILL.md"
done
test ! -d .codex/skills/frontend-design

HOME="$TMP/home" tools/check-agent-context.sh >/dev/null
HOME="$TMP/home" tools/check-profile.sh >/dev/null
HOME="$TMP/home" tools/preflight-harness.sh >/dev/null

printf 'SECRET=1\n' > .env
set +e
printf '{"tool_input":{"file_path":".env"}}' | .codex/hooks/protect-env.sh >/dev/null 2>&1
edit_env_status=$?
printf '{"tool_input":{"file_path":".env.example"}}' | .codex/hooks/protect-env.sh >/dev/null 2>&1
example_status=$?
printf '{"tool_input":{"command":"printf FOO=bar > .env"}}' | .codex/hooks/protect-env.sh >/dev/null 2>&1
bash_env_status=$?
printf '{"tool_input":{"command":"printf FOO=bar > .env.example"}}' | .codex/hooks/protect-env.sh >/dev/null 2>&1
bash_example_status=$?
set -e
test "$edit_env_status" -eq 2
test "$example_status" -eq 0
test "$bash_env_status" -eq 2
test "$bash_example_status" -eq 0

# Claude Code hook input shape (tool_name + tool_input), run through the command in .claude/settings.json.
claude_hook() { CLAUDE_PROJECT_DIR="$PWD" bash -c "$(python3 -c 'import json; print(json.load(open(".claude/settings.json"))["hooks"]["PreToolUse"][0]["hooks"][0]["command"])')"; }
set +e
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.env","content":"X=1"}}' "$PWD" | claude_hook >/dev/null 2>&1
claude_write_status=$?
printf '{"tool_name":"Bash","tool_input":{"command":"echo X=1 >> .env"}}' | claude_hook >/dev/null 2>&1
claude_bash_status=$?
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.env.example","content":"X="}}' "$PWD" | claude_hook >/dev/null 2>&1
claude_example_status=$?
set -e
test "$claude_write_status" -eq 2
test "$claude_bash_status" -eq 2
test "$claude_example_status" -eq 0

HOME="$TMP/home" STRIPE_SECRET_KEY=sk_test_placeholder tools/apply-profile.sh all >/dev/null
HOME="$TMP/home" STRIPE_SECRET_KEY=sk_test_placeholder tools/check-profile.sh all >/dev/null
grep -q '^\[mcp_servers.vercel\]' .codex/config.toml
grep -q '^\[mcp_servers.supabase\]' .codex/config.toml
grep -q '^\[mcp_servers.stripe\]' .codex/config.toml
HOME="$TMP/home" tools/audit-capabilities.sh --expect-profile all >/dev/null

before="$(cksum .codex/config.toml)"
HOME="$TMP/home" tools/apply-profile.sh supabase --dry-run >/dev/null
after="$(cksum .codex/config.toml)"
test "$before" = "$after"
HOME="$TMP/home" tools/remove-profile.sh stripe >/dev/null
! grep -q '^\[mcp_servers.stripe\]' .codex/config.toml
grep -q '^\[mcp_servers.custom-codex\]' .codex/config.toml
HOME="$TMP/home" tools/remove-profile.sh all >/dev/null
! grep -Eq '^\[mcp_servers\.(vercel|supabase|stripe)\]' .codex/config.toml
grep -q '^\[mcp_servers.custom-codex\]' .codex/config.toml

mkdir -p "$TMP/no-curl-project"
cd "$TMP/no-curl-project"
git init -q
HOME="$TMP/home" HARNESS_RAW_BASE="$RAW_BASE" SKIP_CODEGRAPH=1 bash "$ROOT/apply.sh" >/dev/null
test -f AGENTS.md
grep -q '^@AGENTS.md' CLAUDE.md
test -f .mcp.json
test -f .claude/settings.json
test -f .claude/skills/ponytail/SKILL.md
test -x tools/preflight-harness.sh
test -x tools/finish-harness.sh
test ! -d klaach_harness
test ! -d .harness-archive
HOME="$TMP/home" tools/check-agent-context.sh >/dev/null

echo "Temp-project harness integration passed."
