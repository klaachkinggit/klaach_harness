# PROFILES.md - Optional MCP Profiles

The base harness keeps optional stack integrations project-local. Profiles currently write `.codex/config.toml` only; add the same server to `.mcp.json` by hand for Claude Code.

## Profiles

| Profile | MCP | Auth |
| --- | --- | --- |
| Vercel | `https://mcp.vercel.com` | Hosted OAuth in the client |
| Supabase | `https://mcp.supabase.com/mcp?read_only=true` | Hosted OAuth; set `SUPABASE_PROJECT_REF` to pin a project |
| Stripe | `npx -y @stripe/mcp@latest` | `STRIPE_SECRET_KEY` forwarded from the environment |

## Commands

```bash
tools/apply-profile.sh vercel
tools/apply-profile.sh supabase
tools/apply-profile.sh stripe
tools/apply-profile.sh all --dry-run

tools/remove-profile.sh stripe
tools/check-profile.sh all
tools/audit-capabilities.sh --expect-profile all
```

## Skill Policy

Base skills have one source, `.codex/skills/`, which `apply.sh` copies to `.claude/skills/`:

- `find-skills`
- `superpowers`
- Matt Pocock workflow skills
- `ponytail`

Single-source rule: edit a skill only under `.codex/skills/`; never maintain a separate Claude copy. Do not add Claude-only skills, portable prompts, broad UI-design bundles, or extra stack skills to the base harness. Use `find-skills` for project-specific additions.
