#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

INPUT_JSON="$INPUT" python3 - <<'PY'
import json
import os
import shlex
import sys
from pathlib import Path


def is_exact_env(raw):
    path = Path(raw).expanduser()
    values = {str(path), path.name}
    try:
        values.add(str(path.resolve(strict=False)))
    except Exception:
        pass
    return ".env" in values or path.name == ".env"


def block(raw):
    if is_exact_env(raw):
        print("BLOCKED: .env is protected. Use .env.example for templates.", file=sys.stderr)
        sys.exit(2)


def bash_writes_env(command):
    try:
        tokens = shlex.split(command)
    except ValueError:
        tokens = command.split()
    write_ops = {"rm", "mv", "cp", "touch", "truncate", "tee", "sed", "perl", "python", "python3", "node"}
    if any(op in tokens for op in {">", ">>"}):
        return any(is_exact_env(token) for token in tokens)
    return bool(tokens and Path(tokens[0]).name in write_ops and any(is_exact_env(token) for token in tokens[1:]))


try:
    payload = json.loads(os.environ.get("INPUT_JSON", "{}") or "{}")
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input", {}) or {}
for key in ("file_path", "filepath", "filePath", "path", "notebook_path"):
    value = tool_input.get(key)
    if isinstance(value, str) and value:
        block(value)
for key in ("paths", "files"):
    value = tool_input.get(key)
    if isinstance(value, list):
        for item in value:
            if isinstance(item, str) and item:
                block(item)
for key in ("command", "cmd"):
    value = tool_input.get(key)
    if isinstance(value, str) and bash_writes_env(value):
        print("BLOCKED: .env is protected. Use .env.example for templates.", file=sys.stderr)
        sys.exit(2)
PY
