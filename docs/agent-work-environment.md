# AI Agent Work Environment

This repo is a harness for Codex and Claude Code. Treat it as an agent runtime contract, not a normal app.

## Start Here

Read in this order:

1. `AGENTS.md` for behavior rules and finish requirements.
2. `README.md` for the current harness surface.
3. `HARNESS.md` for ownership by layer.
4. `APPLY.md` when changing adoption behavior.
5. `PROFILES.md` when changing optional MCP profiles.
6. `MEMORY.md` and `LESSONS.md` when present for local decisions and repeated failure modes.

If `.codegraph/` exists, use CodeGraph before broad file search. This source checkout currently does not require a CodeGraph index.

## Ownership Map

| Area | Source owner | Generated or installed output | Verification |
| --- | --- | --- | --- |
| Rules | `AGENTS.md`, `CLAUDE.md` (import only) | Target project `AGENTS.md`/`CLAUDE.md` with project-specific tail preserved | `tools/check-agent-context.sh` |
| MCP config | `tools/gen-mcp.py`, `tools/profile.py` | `.codex/config.toml`, `.mcp.json` | `tools/audit-capabilities.sh`, `tools/check-profile.sh` |
| Runtime hook | `.codex/hooks/protect-env.sh`, wired by `.codex/hooks.json` and `.claude/settings.json` | Same paths in target projects | `tools/test-harness-integration.sh` |
| Skills | `.codex/skills/*/SKILL.md` (`.claude/skills` is a symlink here) | `.codex/skills/` and copies in `.claude/skills/` | `tools/check-agent-context.sh` |
| Installer | `apply.sh` | Harness files copied into target projects | `tools/test-harness-integration.sh` |
| Docs | `README.md`, `HARNESS.md`, `APPLY.md`, `PROFILES.md`, this file | Same docs in target projects | `tools/preflight-harness.sh` |
| Git and CI | `.githooks/`, `.github/workflows/ci.yml` | Same paths in target projects | hooks, CI, `tools/preflight-harness.sh` |

## Current Friction Points

- Ignored local files such as `MEMORY.md` and `tools/__pycache__/` can look like project truth even though Git will not carry them.
- Installer behavior, installed-project behavior, and source-repo maintenance checks are easy to mix up.
- Generated MCP config is versioned as harness surface, but its source is still `tools/gen-mcp.py` and `tools/profile.py`.
- Preflight is the shared gate, so conditional skips or masked command failures make future agent work riskier.
- A clean `tools/preflight-harness.sh` run is not the same as a clean handoff; the worktree can still contain uncommitted work.

## Recovery Plan

1. Keep this ownership map current when harness surfaces move.
2. Harden `tools/preflight-harness.sh` before adding new checks elsewhere.
3. Keep adoption behavior covered by `tools/test-harness-integration.sh`.
4. Keep generated or installed surfaces documented in `README.md`, `HARNESS.md`, and `APPLY.md`.
5. Use `tools/finish-harness.sh` as the final handoff gate after verified work is committed.

## Edit Rules

- Edit source files, not generated output, unless the generated file is the versioned harness surface.
- Keep source-repo checks separate from installed-project checks.
- Keep one source per surface: Claude files import, copy, or generate from the Codex sources. Do not add Claude-only rules, hooks, commands, skills, portable prompt packs, or broad optional profile support.
- Do not delete compatibility cleanup in `apply.sh` unless the integration test proves adopted projects no longer need it.
- Keep `tools/preflight-harness.sh` as the normal verification entrypoint.

## Local State

Tracked Git state is the finish signal. Ignored local files can still distract agents:

- `MEMORY.md` may exist locally and is intentionally ignored by this checkout.
- `__pycache__/`, `.codegraph/`, `.codex/sessions/`, `*.bak`, and build outputs are disposable.
- `.env` and `.env.*` are blocked except `.env.example`.

Before finishing, inspect:

```bash
git status --short --untracked-files=all
git status --ignored --short
```

Do not treat ignored reports, caches, or backups as current source of truth.

## Verification

Use the smallest relevant check while editing:

```bash
bash -n tools/preflight-harness.sh tools/finish-harness.sh
tools/check-agent-context.sh
tools/check-profile.sh
tools/audit-capabilities.sh
tools/test-harness-integration.sh
```

Run the full source-repo gate before pushing:

```bash
tools/preflight-harness.sh
```

After the work is committed and the tree should be clean, run:

```bash
tools/finish-harness.sh
```

`tools/finish-harness.sh` reruns preflight and fails if Git reports tracked or untracked changes.
