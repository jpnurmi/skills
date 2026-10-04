---
name: gh-activity
description: Generates concise GitHub activity highlights for weekly team meetings, standups, or personal work recaps, filtered by organization and time period. Use when asked to summarize the user's GitHub work or prepare meeting bullets with gh-activity.
---

# GitHub Activity Highlights

Turn the authenticated user's GitHub activity into high-level meeting bullets.

## Gather activity

- Resolve the GitHub organization from the request or established conversation context. Ask if it is missing; do not assume an organization from the current repository.
- Run the bundled `scripts/gh-activity.sh` from this skill directory (resolve the path relative to this SKILL.md, not the project working directory). It requires authenticated `gh`, `jq`, and GNU `date` (`gdate` on macOS).
- Filter the organization with `--repo "${org}/*"`, where `org` is the resolved organization slug. Keep the wildcard quoted. The script reports the authenticated user's activity within that organization, not the whole team's activity.
- Default to the past seven UTC dates, including today. The script includes both endpoints, so use `"6 days ago" today`. For an explicit “last week,” use `last week` (previous ISO calendar week, Monday–Sunday). Honor other requested periods and show the resolved dates from the report header.

```bash
bash scripts/gh-activity.sh --repo "${org}/*" "6 days ago" today
```

Supported period examples (replace the final date arguments above):

| Request | Arguments |
|---------|-----------|
| Last calendar week | `last week` |
| Specific ISO week | `2026-W40` |
| This month | `this month` |
| Explicit inclusive range | `2026-09-28 2026-10-02` |

Read both the report and any warnings. If execution fails, report the concrete blocker. If a lookup fails but a partial report is returned, summarize it with a brief coverage note. If no matching activity is returned, say so without inventing highlights. Older periods can omit comments and updates because the script relies on recent events; contribution lookup is limited to one year.

## Write meeting highlights

- Prioritize projects where the user implemented features or fixes during the requested period, supported by authored PRs or commits. Omit projects with only reviews or comments unless the user explicitly asks to include them. Issue creation or discussion alone does not establish implementation.
- Group related implementation work into themes or outcomes, even across repositories. Lead with the most substantial work; avoid a chronological log or one bullet per PR. Include reviews or comments only as brief supporting context for the user's implementation work. If no implementation activity is found, say so rather than filling the summary with review-only projects.
- Give each high-level bullet a short, concrete label and a few words explaining what changed. Use one to three short sub-bullets when a theme needs distinct details. Usually three to six themes suffice; use fewer when evidence is sparse.
- Preserve status: distinguish merged work, open or draft work, investigation, and reviews. A merge does not establish deployment; a review does not establish authorship. Do not infer impact, completion, blockers, or next steps from titles alone.
- Use the report as evidence. If a title is too vague for a meaningful summary, read the relevant PR or issue through `gh` using its returned URL. Fetch only the context needed for the highlight.
- Omit routine churn and raw activity counts unless they explain a meaningful result. Avoid inflated impact claims and generic labels such as “miscellaneous improvements.”
- Include a compact source link on a relevant phrase when useful, using URLs returned by the script or subsequent lookup. Do not turn the summary into a link inventory.
- Present a short organization/date line followed by copy-ready Markdown bullets in a fenced block, unless the user requests another format. Put any collection caveat outside the block.

Example style (illustrative, not evidence):

- **Release reliability** — merged fixes for retry handling and clearer failure messages.
- **Authentication work**
  - Opened a draft for token refresh.
  - Added session-expiry tests to the draft.

Prefer “Opened a draft for token refresh” over “Shipped seamless authentication” when the evidence is only a draft PR. A separate project with only review or comment activity should be omitted, even if it has more events than the implementation projects.
