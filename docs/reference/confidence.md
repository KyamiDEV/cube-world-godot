# Confidence and uncertainty — recording convention

Brick 029. Refines the baseline in `README.md` §4 (`CLAUDE.md` §4.5), which required
only a `HIGH`/`MEDIUM`/`LOW` tag on every behavioral claim. This file is the full
convention: it does not replace the baseline, it makes it precise enough to apply the
same way across every note and matrix, including the ones already written (021–028)
and every one still to come.

Nothing in `docs/reference/` is ground truth (`README.md` top). This file is about how
we say, in a way a later reader can audit, exactly how much we don't know.

## 1. Two axes, not one

Bricks 021–028 kept running into the same ambiguity: a claim can be confidently
*guessed* from a good name, or it can rest on an actual read of the logic, and those are
different kinds of trust. Keep them as two separate tags. Never fold read depth into the
confidence label by vibes — use the ceiling rule in §3 instead.

### 1a. Claim confidence — `HIGH` / `MEDIUM` / `LOW`

What it means (unchanged from `README.md` §4):

| Level | Means |
|---|---|
| `HIGH` | corroborated by clear, named code paths plus data or naming that agrees; a competent reader would reach the same conclusion |
| `MEDIUM` | one plausible reading of decompiled logic, with no contradicting evidence found |
| `LOW` | inferred, guessed from names or partial control flow, or reconstructed from gameplay memory |

Sharper criteria for applying it:

- **`HIGH`** requires at least one of: (a) the same behavior independently visible in
  both binaries, (b) a `VERIFIED` struct/offset from `cube_types.h` backing it (e.g.
  `matrix-combat.md`'s `cube_Creature_offsets`), or (c) a full read of the decompiled
  body with unambiguous control flow. Function *naming* confidence from
  `GAP_ANALYSIS.md` is not by itself grounds for `HIGH` — see §3.
- **`MEDIUM`** is the default for "read the code, it plausibly means this" with no
  corroboration and no contradiction. Most matrix rows should land here.
- **`LOW`** covers guesses from a function name alone, a single ambiguous branch, or
  anything reconstructed from memory of playing the original game rather than from the
  reference tree. A `LOW` claim is still implementable (`README.md` §4) — mark it, and
  make the resulting Godot code cheap to revise (small function, isolated, documented).

### 1b. Read depth — `FULL` / `PARTIAL` / `GAP-ONLY` / `UNREAD`

Independent of how confident the claim is: how much of the actual reference source
backs it. This has been tracked informally since brick 023 ("not read in full", "GAP
one-liner only") without a shared vocabulary — this is that vocabulary.

| Depth | Means |
|---|---|
| `FULL` | the relevant `.cpp` body (or the specific methods that matter) was read directly |
| `PARTIAL` | some of the body was read — enough to extract the claim, not the whole function/class |
| `GAP-ONLY` | the claim rests on a `GAP_ANALYSIS.md` one-line summary, the body itself was never opened |
| `UNREAD` | the class/function is known to exist (from `attribution.tsv`) but nothing about it was read; the row exists only so the gap is visible |

Record read depth in the same place the reading budget already lives (`_template.md`
§2, `_matrix_template.md` §5) — a "not read in full" note there **is** a `GAP-ONLY` or
`PARTIAL` tag; this section just names the levels so every note uses the same four
words instead of ad hoc phrasing.

## 2. Recording it

- **Matrix rows** (`_matrix_template.md` §1, §2): the existing `Confidence` column is
  claim confidence (§1a). Where read depth is anything other than `FULL`, say so in the
  row's `Note` cell or, if it matters enough to gate a brick, promote it to an open
  question (§4 template) rather than leaving it buried in prose. Do not add a new table
  column to the template for this — the existing matrices (021–028) are not retrofitted
  by this brick, and a column absent from eight already-committed files would be worse
  than a documented convention for prose.
- **Per-subsystem notes** (`_template.md` §3, §6): tag every claim and invariant
  `HIGH`/`MEDIUM`/`LOW` as already required. State read depth in §2 (Sources examined)
  — that section already asks "what was read", so "GAP summary only" or "3 methods,
  rest unread" answers it directly.
- **Overall confidence** (`_template.md` header field, `_matrix_template.md` §1): the
  **minimum**, not the average or the maximum, of the confidence levels of the claims
  that the Godot contract (§8) actually depends on. A note that is mostly `HIGH` with
  one load-bearing `LOW` claim is an overall `LOW` note — the weak link decides.
  Claims the contract doesn't depend on (curiosities, discarded alternatives) don't
  count toward this.

## 3. The GAP-only ceiling

`GAP_ANALYSIS.md` carries its own `high`/`med`/`low` confidence per function — that is
the *decompiler's* confidence that it named and summarized the function correctly. It
is not our confidence in the behavioral claim, and the two must never be conflated by
copying GAP's tag straight into a matrix row.

Rule: a claim whose read depth is `GAP-ONLY` cannot be recorded as claim-confidence
`HIGH`, regardless of what `GAP_ANALYSIS.md` says about the naming, unless it is
independently corroborated (§1a's condition (a) or (b)). Two examples already in the
matrices show both sides of this:

- `matrix-client-server.md`'s dirty-bit receive row is `GAP-ONLY` for all four
  functions, but is correctly rated `MEDIUM` (not `HIGH`) precisely because the only
  corroboration is "four independent rows with the same shape" — real corroboration,
  capped below `HIGH` because none of the four bodies was actually read.
- `matrix-ai.md`'s ability-timing row rates the *naming* `HIGH` ("per-function, from
  GAP") while explicitly placing the behavior `NONE`/"not ours to place" — i.e. it
  never asserts a `HIGH` behavioral claim from GAP-only evidence, it defers the claim
  entirely to `matrix-combat.md`. That is the correct move when the ceiling would
  otherwise be violated: defer rather than inflate.

If a future row is tempted to write `GAP-ONLY` + `HIGH` for an actual behavioral claim,
that combination is a mistake — either the read depth needs to become `FULL`/`PARTIAL`
(go read the body) or the confidence needs to drop to `MEDIUM`.

## 4. Confidence never launders upward

Already stated in `README.md` §4: never restate a `LOW` claim in a later document as if
it were `HIGH`. Extending it:

- Confidence **may drop** when new evidence contradicts an earlier claim. When it does,
  say what changed and where — don't just edit the tag silently. `matrix-combat.md`
  Q1's resolution (§5 below) is an example of new evidence *removing* an uncertainty
  rather than changing a confidence tag, which is the more common case in practice.
- Restating a claim in a new note/matrix is not corroboration. Corroboration is a
  *second, independent* code path or data source agreeing with the first (§1a).
- When a `LOW` or `MEDIUM` claim is later upgraded, the note must say what new evidence
  justified it (a second binary's code path found, a `VERIFIED` offset located, a body
  finally read). An upgrade with no cited cause is itself a `LOW`-confidence edit.

## 5. Open-question lifecycle

Matrix `§4 Open questions` rows (`_matrix_template.md` §4) and note `§7 Uncertainties`
rows (`_template.md` §7) follow one lifecycle, already used informally in
`matrix-combat.md`, `matrix-items.md`, `matrix-ui.md` when brick 028 closed three of
their questions. Formalized:

1. A question starts as an open row: `Q<n> | question | blocks | resolved by` (matrix)
   or `U<n> | unknown | how to resolve | impact if wrong` (note). "Resolved by" is a
   plan (a brick, a dedicated read, a design decision), not yet an answer.
2. When evidence resolves it, **prefix the question text** with
   `(RESOLVED — brick <NNN>)` and rewrite the "Resolved by" cell to state the actual
   answer plus where the supporting evidence lives (a matrix section, a note, a cited
   line range). Do not just change "TODO" to "done" — the answer itself must be
   readable from the row without opening another file.
3. When a decision (not new reference evidence) resolves it — e.g. "we choose our own
   slot count, the reference is contradictory" — that is still a resolution. Tag it
   `(RESOLVED — brick <NNN>)` and record the decision and its rationale in the
   "Resolved by" cell, same as an evidence-based resolution. Clean-room decisions are
   first-class resolutions, not lesser ones (`README.md` §5).
4. **Never delete a resolved row.** It is the audit trail for why the project's
   behavior diverges (or doesn't) from a `LOW`/`MEDIUM` guess made under uncertainty.
   `matrix-index.md` §6 (traceability, brick 030) reads these rows; deleting one breaks
   that index silently.
5. A question that gates specific bricks must appear in `nextsteps.md`'s "Next N
   actions" list until resolved (already the working pattern since brick 021 — this
   just makes it a rule instead of a habit). Once resolved, drop it from that list; the
   matrix/note row remains the permanent record.

## 6. Why this is a separate file, not a longer README §4

`README.md` §4 stays as the one-paragraph baseline every note author needs to start
writing (`_template.md` copies straight from it). This file is the fuller rulebook for
the cases that only come up once a note author hits an actual ambiguity — GAP-only
evidence, conflicting formulas, a question that needs closing. Keeping the baseline
short means a first-time note doesn't need to read six sections before writing `HIGH` on
a line; keeping the rulebook separate means the edge cases have one canonical place
instead of being re-litigated per matrix.

## 7. Backlog bricks

Referenced by: every reference note and matrix brick (021–028 retroactively, all of
029+ going forward), and `030` (traceability index, which reads the resolved/open
question rows this file's §5 governs).
