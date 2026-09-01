# Architecture decision records

An ADR records a decision that is **expensive to reverse** and whose reasoning would
otherwise be lost: engine and module choices, authority model, coordinate system,
persistence format, protocol shape, threading model.

`CLAUDE.md` is policy — what must be true. An ADR is history — what was decided, when,
against which alternatives, and at what cost.

## When to write one

Write an ADR when a choice:

- constrains more than one subsystem, or
- would be costly to undo once content or saves exist, or
- rejects an obvious alternative for a non-obvious reason.

Do **not** write one for a routine implementation choice inside a single file, or for
anything a backlog brick already fully specifies.

## Format

File: `docs/adr/NNNN-short-kebab-title.md`, numbered sequentially from `0001`, never
renumbered.

```markdown
# NNNN — Title

| Field | Value |
|---|---|
| Status | Proposed / Accepted / Superseded by NNNN / Deprecated |
| Date | YYYY-MM-DD |
| Backlog bricks | IDs |
| Supersedes | NNNN or — |

## Context
## Decision
## Alternatives considered
## Consequences
## Revisit if
```

`Revisit if` is required: it names the measurement or event that would justify
reopening the decision, so a future session can tell a settled question from a stale
one.

## Changing a decision

Never edit the Decision section of an accepted ADR. Write a new ADR, set the old one to
`Superseded by NNNN`, and state in the new one what changed and why. The old reasoning
stays readable — that is the point of the record.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-baseline-technical-stack.md) | Baseline technical stack and architecture | Accepted |
| [0002](0002-mesh-block-size.md) | Initial mesh block size | Accepted |
