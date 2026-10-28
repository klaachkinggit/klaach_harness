#!/usr/bin/env bash
set -u

failures=0
warnings=0

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

check_file() {
  if [ -f "$1" ]; then pass "$1 exists"; else fail "$1 missing"; fi
}

check_dir() {
  if [ -d "$1" ]; then pass "$1 exists"; else fail "$1 missing"; fi
}

check_text() {
  local file="$1" pattern="$2" label="$3"
  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

for path in prompts RULES.md sync-rules.sh; do
  if [ -e "$path" ]; then
    fail "$path should not exist in the harness"
  else
    pass "$path absent"
  fi
done

check_file AGENTS.md
check_file .codex/config.toml
check_file .codex/hooks.json
check_file .codex/hooks/protect-env.sh
check_dir .codex/skills
check_file CLAUDE.md
check_file .mcp.json
check_file .claude/settings.json
check_dir .claude/skills
check_file APPLY.md
check_file HARNESS.md
check_file PROFILES.md
check_file docs/agent-work-environment.md
check_file tools/finish-harness.sh

check_text AGENTS.md "Foundational Rules (Karpathy)" "AGENTS.md keeps Karpathy rules"
check_text AGENTS.md "ponytail" "AGENTS.md references Ponytail"
check_text AGENTS.md "sequential-thinking" "AGENTS.md references sequential-thinking"
check_text AGENTS.md "context7" "AGENTS.md references context7"
check_text CLAUDE.md "^@AGENTS.md" "CLAUDE.md imports AGENTS.md"

python3 - <<'PY'
import json
import re
import sys
from pathlib import Path

failures = []
expected_skills = {
    "find-skills",
    "superpowers",
    "grill-me",
    "tdd",
    "diagnosing-bugs",
    "to-issues",
    "codebase-design",
    "improve-codebase-architecture",
    "ponytail",
}
base_mcp = {"github", "git", "playwright", "sequential-thinking", "context7"}

got = {item.name for item in Path(".codex/skills").iterdir() if item.is_dir()} if Path(".codex/skills").exists() else set()
if got != expected_skills:
    failures.append(".codex/skills expected %s, got %s" % (", ".join(sorted(expected_skills)), ", ".join(sorted(got))))

hooks = json.loads(Path(".codex/hooks.json").read_text())
commands = [
    hook.get("command", "")
    for blocks in hooks.get("hooks", {}).values()
    for block in blocks
    for hook in block.get("hooks", [])
]
if commands != ['bash "$(git rev-parse --show-toplevel)/.codex/hooks/protect-env.sh"']:
    failures.append(".codex/hooks.json should only run protect-env.sh")

text = Path(".codex/config.toml").read_text() if Path(".codex/config.toml").exists() else ""
servers = set(re.findall(r"^\[mcp_servers\.([^\].]+)\]", text, re.M))
missing = sorted(base_mcp - servers)
if missing:
    failures.append("Codex MCP missing: %s" % ", ".join(missing))
forbidden = sorted({"filesystem"} & servers)
if forbidden:
    failures.append("Codex MCP must not include: %s" % ", ".join(forbidden))
for skill in sorted(expected_skills):
    path = Path(".codex/skills") / skill / "SKILL.md"
    if not path.exists():
        failures.append("%s missing" % path)
        continue
    content = path.read_text()
    if not content.startswith("---\n") or "\nname:" not in content or "\ndescription:" not in content:
        failures.append("%s missing skill frontmatter" % path)

claude_skills = {item.name for item in Path(".claude/skills").iterdir() if item.is_dir()} if Path(".claude/skills").exists() else set()
missing_claude = sorted(expected_skills - claude_skills)
if missing_claude:
    failures.append(".claude/skills missing: %s" % ", ".join(missing_claude))
for skill in sorted(expected_skills & claude_skills):
    if (Path(".claude/skills") / skill / "SKILL.md").read_text() != (Path(".codex/skills") / skill / "SKILL.md").read_text():
        failures.append(".claude/skills/%s/SKILL.md differs from .codex/skills source" % skill)

settings = json.loads(Path(".claude/settings.json").read_text())
claude_commands = [
    hook.get("command", "")
    for block in settings.get("hooks", {}).get("PreToolUse", [])
    for hook in block.get("hooks", [])
]
if 'bash "$CLAUDE_PROJECT_DIR/.codex/hooks/protect-env.sh"' not in claude_commands:
    failures.append(".claude/settings.json should run the shared protect-env.sh")

mcp = json.loads(Path(".mcp.json").read_text()).get("mcpServers", {})
missing_mcp = sorted(base_mcp - set(mcp))
if missing_mcp:
    failures.append("Claude MCP missing: %s" % ", ".join(missing_mcp))
if "filesystem" in mcp:
    failures.append("Claude MCP must not include: filesystem")
if mcp.get("github", {}).get("env", {}).get("GITHUB_PERSONAL_ACCESS_TOKEN") != "${GITHUB_TOKEN}":
    failures.append("Claude github MCP should map ${GITHUB_TOKEN}")

for failure in failures:
    print("FAIL " + failure)
sys.exit(1 if failures else 0)
PY
status=$?
if [ "$status" -eq 0 ]; then
  pass "Codex and Claude Code skill, hook, and MCP surfaces present"
else
  failures=$((failures + 1))
fi

printf '\n'
if [ "$failures" -gt 0 ]; then
  printf 'Agent context check failed: %s failure(s), %s warning(s)\n' "$failures" "$warnings"
  exit 1
fi

printf 'Agent context check passed: %s warning(s)\n' "$warnings"
