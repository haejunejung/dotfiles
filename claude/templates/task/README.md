---
task_id: {{TASK_ID}}
slug: {{SLUG}}
created: {{DATE}}
base_ref: {{BASE_REF}}
max_review_rounds: 3
report_audience: technical
status: drafting
---

# Task {{TASK_ID}}

Files in this folder are the only handoff between roles. Roles never paste these into chat.

| File | Written by | Gate |
|---|---|---|
| 01-spec.md | Main | - |
| 02-plan.md | Main | - |
| 03-pm-review.md | PM | G0 |
| 04-architecture.md | Architect | G1 (user approves) |
| plan.lock.md | `orch-task.sh lock` | G1 snapshot, never edited |
| 05-impl-notes.md | Developer | G2 |
| 06-design-notes.md | Designer via orchestrator | - |
| 07-review-a/b/c.md | Reviewers via orchestrator | G3 |
| 08-qa.md | QA via orchestrator | G4 |
| 00-evidence/ | `orch-evidence.sh` | - |
| 09-report.md | Doc Writer | G5 |
| 00-log.md | Orchestrator | gate decisions |
| scope-changes.md | Orchestrator | only when the locked plan had to change |
