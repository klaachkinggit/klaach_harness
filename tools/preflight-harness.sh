#!/usr/bin/env bash
set -u

failures=0

run() {
  local label="$1"
  shift
  printf '\n== %s ==\n' "$label"
  if "$@"; then
    printf 'PASS %s\n' "$label"
  else
    printf 'FAIL %s\n' "$label"
    failures=$((failures + 1))
  fi
}

run_shell_syntax() {
  local scripts=()
  while IFS= read -r file; do scripts+=("$file"); done < <(find . -path './.git' -prune -o -type f \( -name '*.sh' -o -path './.githooks/*' \) -print)
  local status=0
  for script in "${scripts[@]}"; do
    bash -n "$script" || status=1
  done
  return "$status"
}

run_json_syntax() {
  local file
  for file in .codex/hooks.json .claude/settings.json .mcp.json; do
    python3 -m json.tool "$file" >/dev/null || return 1
  done
}

run_python_compile() {
  local status=0
  for file in tools/*.py; do
    [ -e "$file" ] || continue
    python3 -m py_compile "$file" || status=1
  done
  return "$status"
}

run_profile_dry_runs() {
  local status=0
  tools/apply-profile.sh all --dry-run >/dev/null || status=1
  tools/remove-profile.sh all --dry-run >/dev/null || status=1
  return "$status"
}

run_secret_scan() {
  if grep -rInE "(password|secret|token|api_key|apikey|aws_secret)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{8,}" \
      --include='*.js' --include='*.ts' --include='*.py' --include='*.go' --include='*.rs' --include='*.sh' \
      --exclude-dir=.git --exclude-dir=node_modules .; then
    return 1
  fi
  return 0
}

run "shell syntax" run_shell_syntax
run "JSON syntax" run_json_syntax
run "Python compile" run_python_compile
run "capability audit" tools/audit-capabilities.sh
run "agent context check" tools/check-agent-context.sh
run "profile health check" tools/check-profile.sh
run "profile dry runs" run_profile_dry_runs
run "secret scan" run_secret_scan

if [ -f apply.sh ]; then
  if [ -x tools/test-harness-integration.sh ]; then
    run "temp-project integration" tools/test-harness-integration.sh
  else
    run "temp-project integration available" false
  fi
fi

printf '\n'
if [ "$failures" -gt 0 ]; then
  printf 'Harness preflight failed: %s failure(s)\n' "$failures"
  exit 1
fi

printf 'Harness preflight passed.\n'
