# ADR-0001 — Support Codex and Claude Code from one source

- **Status:** Accepted
- **Date:** 2026-10-28
- **Deciders:** @klaachkinggit

## Context
Commit 8fe75f0 made the harness Codex-only and `apply.sh` deleted `.claude/`, `CLAUDE.md` and `.mcp.json` in target projects. The owner uses both Codex and Claude Code and asked for the harness to serve both.

## Decision
Claude Code is a second runtime over the existing Codex sources; nothing Claude-specific is maintained by hand.

- Rules: `CLAUDE.md` imports `AGENTS.md` with `@AGENTS.md`.
- MCP: `tools/gen-mcp.py claude|all` writes `.mcp.json` from the same server list, preserving unmanaged servers.
- Hook: `.claude/settings.json` runs `.codex/hooks/protect-env.sh`, which already parses Claude Code's `tool_input`.
- Skills: `.codex/skills/` is the only source; `apply.sh` copies it to `.claude/skills/` (a symlink in this repo).

## Alternatives Considered
- **Restore the old Claude surface (commands, extra hooks, design skills) —** rejected: that bloat is why it was removed.
- **Separate Claude copies of rules/skills/hook —** rejected: two copies drift.
- **Symlink `.claude/skills` in target projects —** rejected: it would clobber project-local Claude skills already in that folder.

## Consequences
- ✅ One edit updates both runtimes.
- ✅ Checks and the integration test cover both surfaces.
- ⚠️ Target projects hold copied skills; re-run `apply.sh` / `tools/update-harness.sh` to refresh them.
- ⚠️ Optional MCP profiles still write `.codex/config.toml` only.
- 🔁 Reversibility: easy.

## Links
- Related commit: 8fe75f0 (Codex-only)
