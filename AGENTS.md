# Dev Harness - Agent Behavioral Rules

## Foundational Rules (Karpathy)

1. **No silent assumptions.** Task ambiguous -> ask one focused question before proceeding. Never assume scope and run with it.
2. **No over-abstraction.** Simplest code that solves the problem. Three similar lines > premature abstraction. No hypothetical future requirements.
3. **No silent mutations.** Never remove or change code you do not understand without flagging it first.

## Communication

- Terse by default. No pleasantries, hedging, filler, or trailing summaries.
- Reference code as `file:line`. Fragments OK.
- Full sentences only for security warnings and destructive operation confirmations.

## Code

- No comments unless the reason is non-obvious.
- No error handling for impossible internal scenarios. Trust framework and internal guarantees.
- No features beyond task scope. No half-finished implementations.
- Validate only at system boundaries: user input, external APIs, files, network, and persistence.
- No security vulnerabilities: SQL injection, XSS, command injection, hardcoded secrets, or credential leaks.

## Workflow

- Stay inside the project root for file and shell access unless the user explicitly names an external path.
- Before non-trivial work, assess whether an existing skill or MCP server helps. Use `find-skills` for discovery.
- Use `sequential-thinking` for complex planning/debugging, multi-step refactors, ambiguous failures, or architecture choices.
- Use `context7` before relying on memory for version-sensitive library, framework, SDK, CLI, or cloud-service behavior.
- Use `superpowers` for small to medium implementation workflows that need brainstorm -> plan -> execute structure.
- Use the Matt Pocock skills for requirements grilling, TDD, bug diagnosis, issue slicing, codebase design, and architecture improvement.
- Use `ponytail` for shortest-path implementation and LOC reduction. Follow `.codex/skills/ponytail/SKILL.md`, sourced from `DietrichGebert/ponytail`: YAGNI first, reuse existing code, stdlib/native features before custom code, one line before fifty, and never cut validation, security, accessibility, or required checks.
- Failing test before implementation on any non-trivial behavior change.
- Before finishing, run the narrow relevant checks, then `tools/preflight-harness.sh`. After committing verified work, run `tools/finish-harness.sh`; do not call the task finished while it reports a dirty worktree.

## Memory, Decisions & Learning

- Read `MEMORY.md` and `LESSONS.md` at session start if present.
- Hard-to-reverse choices need an ADR in `docs/adr/`.
- Append non-obvious persistent decisions to `MEMORY.md`.
- Append reusable "next time" heuristics to `LESSONS.md`.

## Risk & Review

- Auth, data persistence, secrets, payment, and infra changes require explicit risk review before shipping.
- Never hardcode secrets or read/write `.env` through agent tooling. Use `.env.example` for templates.
- Destructive actions require explicit confirmation. Never skip hooks. Never force-push `main`.

## Token Economy

- If `.codegraph/` exists, use CodeGraph before broad file reads.
- Read semantically with scoped lookups instead of whole-repo sweeps.
- Route cheap search/summaries to cheaper models when available; reserve stronger models for design, architecture, and review.
- Keep the cache warm: stable rules live here, heavy procedures live in Codex skills.

## Harness Scope

- This harness supports Codex and Claude Code from one set of sources.
- Codex reads `AGENTS.md`, `.codex/config.toml`, `.codex/hooks.json`, `.codex/hooks/`, and `.codex/skills/`.
- Claude Code reads `CLAUDE.md` (imports `AGENTS.md`), `.mcp.json`, `.claude/settings.json`, and `.claude/skills/`.
- Single source: edit `AGENTS.md`, `.codex/skills/`, `.codex/hooks/protect-env.sh`, and `tools/gen-mcp.py`; Claude files import, copy, or generate from them. No Claude-only rules, hooks, commands, skills, or portable prompt packs.
- Optional MCP profiles are Vercel, Supabase, and Stripe only.

---
<!-- Add project-specific rules below this line -->
