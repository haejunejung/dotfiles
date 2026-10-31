# Global learnings (promoted)

Rules that apply in every project on every machine. Imported by `~/.claude/CLAUDE.md`.

Conventions:
- One rule per bullet: `- [YYYY-MM-DD] <rule>. Why: <one line>. Evidence: <pointer>. (fact | preference)`
- Never delete a rule you disagree with; append ` (superseded YYYY-MM-DD by: <new rule's first words>)` and add the new one.
- Hard cap: 80 active rules. `/learn review` proposes retirements when the file grows or a rule goes unused.
- Promotion only through `/learn promote` and the user's approval. Agents never edit this file directly.

## Rules

- [2026-10-30] Role handoffs go through files in `.orch/tasks/<id>/`, not chat. Why: files are the record the report is checked against. Evidence: plan doc, section 3. (fact)
- [2026-10-30] Every role ends its turn with Summary / Changes / Open items / Not verified. Why: the orchestrator and the Doc Writer parse these headings. Evidence: plan doc, section 3. (fact)
