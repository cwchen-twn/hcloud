---
name: commit-style
description: Generates commit messages for the hisag project using conventional format inferred from repo history. Use when committing changes, writing commit messages, staging and committing, or when the user asks for a commit message or commit style.
---

# Commit message style (hisag)

When committing in this repo, use the format below. Do not use scopes (e.g. `feat(scheduler):`).

## Format

```
<type>: <subject>

[optional body]
```

- **Subject**: One line, imperative, sentence case. Start with a verb (Added, Fixed, Corrected, Updated). No period at the end.
- **Body**: Optional. Blank line after subject. Use bullet list or numbered list (1. 2. 3.) for non-trivial changes.

## Types

| Type       | Use for |
|-----------|---------|
| `feat`    | New feature or user-facing capability |
| `fix`     | Bug fix or correction of incorrect behavior |
| `chore`   | Maintenance: logging, config, deps, refactors that aren’t a feature or fix |
| `refactor`| Code restructure without changing behavior |
| `wip`     | Work in progress (sparingly) |

Use exactly one type. Do **not** use `fixx`, `add`, `adjust`, `bug`; use `fix` or `feat`.

## Examples

**Single-line:**
- `feat: Added Vigilancia Report and Scheduler Helm Chart`
- `fix: Corrected the locale.setlocale error`
- `chore: Added more logging messages for vigi_arbovirus_rept_v2 job`
- `refactor: Rename tipo_documento to tipo_history in paciente history DAO`

**With body (bullets):**
```
fix: Synology client retry and graceful degradation for scheduler

- Add tenacity retry with exponential backoff on upload/list_folder
- Reset shared requests.Session before each drive op to avoid stale connections
- Make to_synology() failure non-fatal so email still sends with note when NAS unreachable
```

**With body (numbered):**
```
feat: Added Vigilancia Report and Scheduler Helm Chart

1. Implemented Vigilancia Report requested via Tony, King, and Candela
2. Added helm chart for scheduler
3. Added report_email_receivers schemas
```

## Do not

- Use scope in subject (no `feat(scheduler):`).
- Change merge commit messages from GitLab.
- Use subject like "Fixes X" or "Fixing X"; use "Fixed X" or imperative "Fix X" / "Add X".
