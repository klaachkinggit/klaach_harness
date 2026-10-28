#!/usr/bin/env python3
"""Generate MCP server config for Codex (.codex/config.toml) and Claude Code (.mcp.json).

Usage:
    python3 tools/gen-mcp.py codex|claude|all
"""
import json
import os
import re
import sys


SERVERS = [
    {"name": "github", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"], "env": "GITHUB_TOKEN", "env_key": "GITHUB_PERSONAL_ACCESS_TOKEN"},
    {"name": "git", "command": "uvx", "args": ["mcp-server-git", "--repository", "."], "env": None},
    {"name": "playwright", "command": "npx", "args": ["-y", "@playwright/mcp"], "env": None},
    {"name": "sequential-thinking", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"], "env": None},
    {"name": "context7", "command": "npx", "args": ["-y", "@upstash/context7-mcp"], "env": None},
]

if os.environ.get("DATABASE_URL"):
    SERVERS.append({
        "name": "db",
        "command": "npx",
        "args": ["-y", "@bytebase/dbhub", "--dsn", os.environ["DATABASE_URL"]],
        "env": None,
    })


def emit_codex():
    lines = []
    for server in SERVERS:
        lines.append("[mcp_servers.%s]" % server["name"])
        lines.append("command = %s" % json.dumps(server["command"]))
        lines.append("args = %s" % json.dumps(server["args"]))
        if server["env"] and server["env_key"] == server["env"]:
            lines.append("env_vars = %s" % json.dumps([server["env"]]))
        elif server["env"]:
            lines.append("")
            lines.append("[mcp_servers.%s.env]" % server["name"])
            lines.append("%s = %s" % (server["env_key"], json.dumps("$%s" % server["env"])))
        lines.append("")

    os.makedirs(".codex", exist_ok=True)
    path = ".codex/config.toml"
    existing = ""
    if os.path.exists(path):
        with open(path) as handle:
            existing = _without_managed_codex_servers(handle.read())
    body = "\n".join(lines).rstrip()
    with open(path, "w") as handle:
        handle.write((existing.rstrip() + "\n\n" if existing.strip() else "") + body + "\n")
    print("  wrote %s" % path)


MANAGED = {server["name"] for server in SERVERS} | {"filesystem"}


def emit_claude():
    path = ".mcp.json"
    existing = {}
    if os.path.exists(path):
        with open(path) as handle:
            text = handle.read()
        existing = json.loads(text) if text.strip() else {}
    servers = {name: cfg for name, cfg in existing.get("mcpServers", {}).items() if name not in MANAGED}
    dsn = os.environ.get("DATABASE_URL")
    for server in SERVERS:
        # .mcp.json is usually committed: reference secrets as ${VAR}, never inline them.
        entry = {"command": server["command"], "args": ["${DATABASE_URL}" if dsn and arg == dsn else arg for arg in server["args"]]}
        if server["env"]:
            entry["env"] = {server["env_key"]: "${%s}" % server["env"]}
        servers[server["name"]] = entry
    existing["mcpServers"] = servers
    with open(path, "w") as handle:
        handle.write(json.dumps(existing, indent=2) + "\n")
    print("  wrote %s" % path)


def _without_managed_codex_servers(text):
    kept = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        match = re.match(r"\[mcp_servers\.([^\].]+)(?:\.[^\]]+)?\]", lines[i])
        if match and match.group(1) in MANAGED:
            i += 1
            while i < len(lines) and not lines[i].startswith("["):
                i += 1
            continue
        kept.append(lines[i])
        i += 1
    return "\n".join(kept)


if __name__ == "__main__":
    tool = (sys.argv[1] if len(sys.argv) > 1 else "").lower()
    if tool not in ("codex", "claude", "all"):
        print("Usage: gen-mcp.py <codex|claude|all>", file=sys.stderr)
        sys.exit(1)
    if not os.environ.get("GITHUB_TOKEN"):
        print("  note: GITHUB_TOKEN not set - github MCP will fail until you set it in .env", file=sys.stderr)
    if tool in ("codex", "all"):
        emit_codex()
    if tool in ("claude", "all"):
        emit_claude()
