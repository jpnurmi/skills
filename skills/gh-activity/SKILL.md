---
name: gh-activity
description: Generates concise GitHub activity highlights for technical team meetings, standups, or personal work recaps, plus compact keyword summaries for personal time tracking or customer invoicing. Supports daily, weekly, monthly, or custom periods, optionally limited to a GitHub organization. Use when asked to summarize the user's GitHub work, prepare meeting bullets, or describe activity for Clockify time entries or invoices with gh-activity. Requires scope, format/purpose, and timeframe; asks interactively for missing inputs without defaults.
---

# GitHub Activity Highlights

Turn the authenticated user's GitHub activity into high-level meeting bullets or compact time-tracking or invoicing keywords.

Read the input contract before announcing any reporting scope, format, or timeframe. This skill has no defaults; do not promise a default or recent period on a bare invocation.

## Resolve inputs

| Input | Choices |
|-------|---------|
| Scope | All activity or activity limited to a specific GitHub organization |
| Format/purpose | Meeting bullets for technical colleagues, personal time-tracking keywords, or customer invoicing keywords |
| Timeframe | A specific day, week, month, or inclusive date range |

- Preserve explicitly supplied values, including answers already given while clarifying this request. Do not infer scope from the current repository or unrelated earlier requests, or apply format or date defaults.
- If any input is missing, call `request_user_input_async` when available, or an equivalent interactive question tool permitted in the current mode. Submit all missing questions in one call; do not end the turn with a Markdown question list or a skill-policy explanation instead of using the tool.
- For an asynchronous question tool, keep the request pending until the user submits answers. The tool returning, preselected options, or elapsed time do not supply answers. Run the collector only after all three inputs are resolved.
- If no interactive question tool is available in the current mode, ask one concise direct question in chat covering the missing inputs and wait for the reply.
- Treat meeting updates as meeting bullets, hour tracking or Clockify descriptions as personal time-tracking keywords, and invoices as customer invoicing keywords. If the user asks only for “keywords,” ask whether they are for personal tracking or customer invoicing. Keep scope, format/purpose, and timeframe independent: any purpose can summarize any period. If only “daily,” “weekly,” or “monthly” is specified, clarify which day, week, or month.

When `request_user_input_async` is available, use the following input for a bare `gh-activity` invocation. Omit questions already resolved by the request. Allow an organization slug or custom timeframe as free text; if an organization choice lacks its slug, ask for it before collecting.

```json
{
  "questions": [
    {
      "title": "Should I summarize all your GitHub activity or a specific organization? Enter its slug to limit the scope.",
      "options": ["All activity"]
    },
    {
      "title": "What is the summary for?",
      "options": ["Meeting bullets for technical colleagues", "Personal time-tracking keywords", "Customer invoicing keywords"]
    },
    {
      "title": "What timeframe should I summarize? You can also enter a specific week, month, or date range.",
      "options": ["Today", "Yesterday", "Last week", "This month"]
    }
  ]
}
```

## Gather activity

- Run the bundled `scripts/gh-activity.sh` from this skill directory (resolve the path relative to this SKILL.md, not the project working directory). It requires authenticated `gh`, `jq`, and GNU `date` (`gdate` on macOS).
- For a specific organization, filter with `--repo "${org}/*"`, where `org` is its slug. Keep the wildcard quoted. For all activity, omit `--repo`. Both scopes report the authenticated user's activity, not the whole team's activity.
- Resolve the requested timeframe as inclusive UTC dates. For the past seven dates, including today, use `"6 days ago" today`. For an explicit “last week,” use `last week` (previous ISO calendar week, Monday–Sunday). Honor other requested periods and show the resolved dates from the report header.
- If the user requests separate daily entries for a range, collect and summarize each date separately. Otherwise, summarize the requested period together.
- Include `MENTIONED IN` entries for issues and PRs using their mention-event dates. Mentions stay under the repository containing the issue or PR.

Example for a specific organization over seven dates:

```bash
bash scripts/gh-activity.sh --repo "${org}/*" "6 days ago" today
```

Example for all activity in the requested month:

```bash
bash scripts/gh-activity.sh this month
```

Supported period examples (replace the final date arguments above):

| Request | Arguments |
|---------|-----------|
| Last calendar week | `last week` |
| Specific ISO week | `2026-W40` |
| This month | `this month` |
| Explicit inclusive range | `2026-09-28 2026-10-02` |
| Daily entry for today | `today` |
| Daily entry for yesterday | `yesterday` |

Read both the report and any warnings. If execution fails, report the concrete blocker. If a lookup fails but a partial report is returned, summarize it with a brief coverage note. If no matching activity is returned, say so without inventing highlights. Older periods can omit comments and updates because the script relies on recent events; contribution lookup is limited to one year.

## Write meeting highlights

- Prioritize projects where the user implemented features or fixes during the requested period, supported by authored PRs or commits. Inspect mention context for other substantive work, such as release coordination; a mention alone does not establish work performed. Omit projects with only reviews or comments unless the user explicitly asks to include them. Issue creation or discussion alone does not establish implementation.
- Group related work into themes or outcomes, even across repositories. Lead with the most substantial work; avoid a chronological log or one bullet per PR. Include reviews or comments only as brief supporting context for the user's substantive work. If no substantive work is found, say so rather than filling the summary with review-only projects.
- Select details that help technical colleagues understand changed behavior, affected components, significant implementation choices, integration risks, or follow-up coordination. Name relevant components and mechanisms. Include tradeoffs, blockers, or next steps only when the evidence establishes them; omit routine test additions, minor cleanup, and mechanical changes unless they explain a substantial theme.
- Give each theme a clear, concise area title on its own line, in bold and without a bullet marker. After a blank line, add a flat bullet list: first a one-line summary of the work, then one to three short bullets elaborating on concrete changes, tests, or other distinct details without repeating the summary. Separate topics with a blank line. Usually three to six themes suffice; use fewer themes or details when evidence is sparse.
- Preserve status: distinguish merged work, open or draft work, investigation, and reviews. A merge does not establish deployment; a review does not establish authorship. Do not infer impact, completion, blockers, or next steps from titles alone.
- Use the report as evidence. If a title is too vague for a meaningful summary, read the relevant PR or issue through `gh` using its returned URL. Fetch only the context needed for the highlight.
- Omit routine churn and raw activity counts unless they explain a meaningful result. Avoid inflated impact claims and generic labels such as “miscellaneous improvements.”
- Keep area titles and descriptions free of embedded Markdown links. When sources are useful, append plain URLs to summary or detail bullets or at the end of the report, or place them in source bullets after the related theme's details. Use only URLs returned by the script or subsequent lookup; keep sources brief and avoid duplicate links.
- Present a short scope/date line (organization or “all activity”) followed by copy-ready Markdown topic titles and bullet lists in a fenced block, unless the user requests another format. Put any collection caveat outside the block.

Example style (illustrative, not evidence; `PR_URL` stands for a returned source URL):

**Release reliability**

- Merged fixes for retry handling and clearer failure messages.
- Corrected retry handling after transient failures.
- Clarified failure messages when retries are exhausted. PR_URL

**Authentication**

- Opened a draft for token refresh.
- Added session-expiry tests to the draft.
- Source: PR_URL

Prefer “Opened a draft for token refresh” over “Shipped seamless authentication” when the evidence is only a draft PR. A separate project with only review or comment activity should be omitted, even if it has more events than the implementation projects.

## Write time-tracking or invoicing keywords

- For personal time tracking, select concrete tasks that help the user remember work performed: implementation, fixes, debugging, testing, investigation, maintenance, and substantive reviews or discussions. Include meaningful small tasks and unfinished work even when they do not merit a meeting highlight. Retain useful component or issue terminology and group repeated work on the same task.
- For customer invoicing, group the requested period's work by the supplied customer/project context and recognizable technical project or component names. Describe the work performed on each area, such as implementation, fixes, investigation, testing, or review. Collapse individual commits and repeated daily tasks into concise service descriptions; omit internal identifiers and mechanical churn that do not help the customer identify the work. Preserve investigation, review, and unfinished status instead of implying delivery.
- Review-only work can be included in either keyword purpose. Do not rank tasks by event counts or infer effort from merge status. Omit generic filler.
- Use concrete keywords or short noun phrases, usually three to five, with fewer when evidence is sparse. Do not write full sentences or copy PR titles wholesale.
- Base keywords on report evidence. For vague titles, fetch only the needed PR or issue context through `gh` using returned URLs. Add qualifiers such as “review,” “investigation,” or “draft” when needed to preserve status and avoid implying authorship or completion.
- Return one line of keywords separated by a comma and a space in a fenced `text` block per requested period or daily entry. Keep bullets, links, dates, durations, and trailing sentence punctuation out of the description. Put the scope/date line and any collection caveat outside the block. Do not infer hours worked from GitHub activity.

Example style (illustrative, not evidence):

Personal time tracking:

```text
token refresh, session-expiry tests, retry handling review
```

Customer invoicing, grouping the same activity by technical area:

```text
authentication development and testing, retry handling review
```
