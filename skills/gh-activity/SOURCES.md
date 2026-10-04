# Sources and Decisions

Sources inspected on 2026-10-04; all are local primary evidence with high confidence.

| Source | Contribution |
|--------|--------------|
| User request in this conversation | Organization-filtered weekly meeting highlights, short descriptions or sub-bullets |
| `scripts/gh-activity.sh` | Supported arguments, authenticated-user scope, inclusive UTC dates, labels, partial failures and coverage limits |
| `~/.agents/AGENTS.md` | Minimal changes and copy-ready Markdown conventions |
| `~/.agents/skills/gh-review-requests/SKILL.md` | Neighboring skill frontmatter and GitHub workflow conventions |
| `~/.agents/skills/skill-writer/SKILL.md` and selected workflow references | Inline layout, maintenance contract, provenance, precision and validation |
| `~/.codex/skills/.system/skill-creator/SKILL.md` | Scoped portable instructions and structural validator |

Adopted: one inline runtime file, bundled script, quoted organization glob, seven-date default, thematic grouping, and status fidelity. Added instructions for the requested reporting behavior; kept maintenance material outside runtime. Rejected additional collection scripts, delegation, and provider-specific invocation syntax as unnecessary.

Coverage reviewed: normal collection; missing organization; custom dates; empty and partial reports; draft versus completed work; reviews versus authorship; ambiguous titles; concise output; trigger boundaries. The illustrative output and correction cover normal, partial, and overstated-summary cases.

Retrieval stopped because the user request and local implementation establish the needed behavior. No external API/version assumptions are required. Remaining validation gap: live-account output quality has not been exercised; refine from actual meeting-summary feedback without retaining private activity here.

Updated after the user relocated the executable into the skill: corrected the filename to scripts/gh-activity.sh and replaced the former PATH-based invocation with a skill-relative command. Script contents unchanged.

User clarification: prioritize implemented features and fixes; omit review/comment-only projects by default. Narrowed theme selection, replaced the review-focused example detail, and added the no-implementation fallback. Manually checked mixed-project, draft implementation, and review-only cases against this contract.
