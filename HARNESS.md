# HARNESS.md - Codex + Claude Code Capability Map

## Layers

| Layer | Path | Purpose |
| --- | --- | --- |
| Rules | `AGENTS.md`, `CLAUDE.md` | Behavior contract; `CLAUDE.md` imports `AGENTS.md` |
| MCP | `.codex/config.toml`, `.mcp.json` | Local and hosted tool servers |
| Runtime hook | `.codex/hooks.json`, `.claude/settings.json`, `.codex/hooks/protect-env.sh` | Block exact `.env` mutation |
| Skills | `.codex/skills/` (source), `.claude/skills/` (copy) | On-demand workflows and rules |
| Git + CI | `.githooks/`, `.github/workflows/ci.yml` | Tool-independent enforcement |
| Memory | `MEMORY.md`, `LESSONS.md`, `docs/adr/` | Durable project context |
| Agent map | `docs/agent-work-environment.md` | Source ownership, ignored state, verification, finish gate |

## MCP

Generate base config (`codex`, `claude`, or `all`):

```bash
python3 tools/gen-mcp.py all
```

Base servers:

- `github`
- `git`
- `playwright`
- `sequential-thinking`
- `context7`
- `db` when `DATABASE_URL` is set

Optional profiles (Codex config only for now):

- `vercel`
- `supabase`
- `stripe`

Use:

```bash
tools/apply-profile.sh vercel
tools/remove-profile.sh stripe
tools/check-profile.sh all
```

## Runtime Hook

Only `.codex/hooks/protect-env.sh` is installed; Codex and Claude Code both call it. It blocks write/edit/shell mutation of exact `.env` and allows `.env.example`, `.env.sample`, and other non-exact template names.

## Skills

Installed by the base harness:

- `find-skills`
- `superpowers`
- `grill-me`
- `tdd`
- `diagnosing-bugs`
- `to-issues`
- `codebase-design`
- `improve-codebase-architecture`
- `ponytail` from `DietrichGebert/ponytail`

`ponytail` is the shortest-path and LOC-reduction skill. `AGENTS.md` points both runtimes to `.codex/skills/ponytail/SKILL.md`.

## Apply

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/klaachkinggit/klaach_harness/main/apply.sh)
```

This harness installs no portable prompts and no Claude-only rules, hooks, commands, or skills; every Claude file imports, copies, or generates from the shared source.

## Finish Gate

Use `tools/preflight-harness.sh` while work is in progress.

Use `tools/finish-harness.sh` only when work is ready to hand off. It reruns preflight and fails unless `git status --short --untracked-files=all` is clean.
