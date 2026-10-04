# gh-activity Specification

Create concise personal work highlights for team meetings from organization-filtered GitHub activity. Class: workflow-process. Shape: inline-guidance; the bundled executable handles collection, so no additional collection logic or provider-specific mechanics are needed.

Scope: organization and period resolution, read-only collection, evidence-based grouping, and copy-ready bullets. Excludes whole-team reporting, publishing, and changes to GitHub artifacts.

Runtime contract: require an organization, default to seven inclusive UTC dates, preserve activity status and collection caveats, and prefer short themes with brief details about implemented features and fixes. Omit review/comment-only projects by default; reviews may support an implementation theme but must not be presented as authored work. Read SKILL.md and execute scripts/gh-activity.sh at runtime; SOURCES.md records maintenance provenance.

Validation: check skill frontmatter and examples against the executable's argument parser; review sparse, partial, draft-only, mixed implementation/review, and review-only activity cases. Trigger examples: “Summarize my work in getsentry for last week”; “Prepare GitHub highlights for our weekly meeting”; “Use gh-activity for 2026-W40.” Non-triggers: “Review this PR”; “Fix gh-activity completion”; “Show the whole team's velocity.”

Limitations: authenticated-user scope, inclusive UTC dates, recent-event availability, and contribution lookup limits. No live account query is required to validate skill creation. Revisit the skill when the executable's interface or reporting semantics change. Do not store raw private activity or credentials in skill files.
