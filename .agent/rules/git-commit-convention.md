---
trigger: always_on
---

---
alwaysApply: true
---
# Cursor Rules: Git Commit Convention (Conventional Commits)

## 1) Commit message must follow this structure
<type>(<optional-scope>)<optional-!>: <description>

<blank line>

<body - optional, wrap at 72 chars>

<footer - optional (BREAKING CHANGE / issue links)>

Rules:
- Header/subject line should be <= 50 characters (try hard).
- Do NOT end the subject line with a period.
- Use imperative, present tense in the subject (e.g., "add", "fix", "update").
- Always put ONE blank line between header and body (if body exists).
- Wrap body text at 72 characters per line.
- Prefer lowercase for description unless proper nouns/acronyms are required.

## 2) Allowed commit types (required)
Use exactly one of:
- feat:     new user-facing feature (not build-only)
- fix:      user-facing bug fix (not build-only)
- docs:     documentation only
- style:    formatting only (whitespace, semicolons) no logic change
- refactor: code change that is neither fix nor feature
- perf:     performance improvement
- test:     add/fix tests
- build:    build system / external dependencies
- ci:       CI config/scripts
- chore:    maintenance tasks not modifying src/test (e.g., deps bumps)
- revert:   revert a previous commit

## 3) Scope (optional but recommended for non-trivial changes)
- Format: (scope) where scope is a short noun.
- Use lowercase, kebab-case if needed (e.g., auth, api, parser, web-socket).
Examples:
- feat(auth): add google login integration
- fix(api): handle empty payload in create endpoint
- chore(deps): bump fastapi to 0.115.x

## 4) Breaking changes
Indicate breaking changes in ONE of the following ways:
- Add ! after type/scope: feat(api)!: remove legacy endpoint
- Or add footer: BREAKING CHANGE: <explain what changed and migration path>

If breaking change exists, prefer both:
- Header with !
- Footer with BREAKING CHANGE:

## 5) Body guidelines (when to include)
Include a body when:
- The change is not obvious from the subject line
- There are multiple changes in one commit
- There are behavioral changes, risks, or rationale to capture

Body should explain:
- What changed, why, and any notable constraints/side-effects.
- Avoid implementation noise unless it matters for future readers.

## 6) Footer guidelines (issues, tracking, references)
Use footers for linking issues/tickets:
- Closes #123
- Fixes #45
- Refs #67

If using Jira-like keys, keep them in footer:
- Refs PROJ-1024
- Closes PROJ-2048

## 7) Anti-patterns (avoid)
- "update", "fix stuff", "WIP", "temp"
- Mixing unrelated changes in one commit
- Overly long headers (> 72 chars is a hard no; aim <= 50)
- Past tense in subject ("added", "fixed") -> use "add", "fix"

## 8) Quick templates
Template (simple):
<type>(<scope>): <description>

Template (with body + footer):
<type>(<scope>)!: <description>

<why/what changed, wrapped at 72>

BREAKING CHANGE: <what breaks and how to migrate>
Closes #123
