---
name: commit
description: Use for every request to commit changes or draft a commit message. Creates Sentry-style conventional commits with issue references.
---

# Sentry Commit Messages

## Before Committing

Commit to the current branch unless the user explicitly mentioned a specific
branch or requested a feature branch. If the user mentioned or requested a
specific branch, either checkout that branch if it already exists, or create it
if it does not, and then commit to that branch.

Commit one coherent, independently reviewable change at a time.

## Message Rules

Use:

```text
<type>(<scope>): <subject>

<optional body>

<optional footer>
```

- Scope is optional. Add `!` before `:` for a breaking change.
- Write the subject in imperative, present tense; capitalize it, omit the
  trailing period, and keep it at 72 characters or fewer. State what changed.
- Keep every line under 100 characters.
- Use the body only when useful. Explain what changed, and especially why the
  change was needed, including previous behavior or motivation when it helps.
  Wrap body lines at 72 characters.
- In the body, wrap keywords, type names, function names, and other identifiers in single backticks (e.g., `MyType`, `myFunction`, `keyword`).
- Put code snippets in fenced code blocks with triple backticks and a language
  identifier.
- Never include customer or organization names, user emails, support ticket
  contents, secrets, or PII. Describe the technical symptom instead.

Allowed types: `feat`, `fix`, `ref`, `perf`, `docs`, `test`, `build`,
`ci`, `chore`, `style`, `meta`, `license`, and `revert`.

Use `ref` for refactoring without behavior changes, `style` for formatting
without logic changes, and `meta` for repository metadata.

## Footers

- `Fixes: <#NNNN>` for bug fixes.
- `Close: <#NNNN>` for tasks and feature requests.
- `Ref: <#NNNN>` for non-closing reference links.
- For breaking changes, add `BREAKING CHANGE: <impact>`.

## Creating the Commit

Use separate `-m` arguments for paragraphs and footers. Never put literal
`\n` sequences in a commit message or open an interactive editor.

```bash
git commit -m "fix(api): Handle null response in user endpoint" \
  -m "Return `404` when `GET /api/user` finds a deleted account." \
  -m "Fix: #5678"
```
