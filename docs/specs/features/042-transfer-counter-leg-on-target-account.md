# A transfer names its target account and books the counter-leg there

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | 032 |
| **Status** | Done |

## Description
A transfer is marked per booking today: the leg on the account being looked at is flagged, and the report leaves it out.
What is missing is the other side. Money that leaves the Giro account arrives on the Tagesgeld account, and the app cannot
say so — the receiving balance only learns about it when that account's own statement is imported, which may be weeks
later or never for an account that is not imported at all.

Wanted: when marking a booking as a transfer, name the account on the other side, and let the app book the counter-leg
there — same amount with the opposite sign, same date.

## Why this is more than a second save
Ticket 032 deliberately left the two legs unlinked. Writing the mirror booking creates the problem it avoided: the same
movement can now enter the database twice — once because this feature wrote it, once because the other account's statement
gets imported later. The dedupe check keys on amount, booking day and normalized counterparty; the imported leg will carry
the bank's own counterparty text, which almost certainly differs from whatever the mirror booking wrote. So the guard that
normally catches a double booking is exactly the one that will not fire here.

That collision is the ticket. The picker for the target account is the easy half.

## Resolved during refinement
- **Scope** → the import collision moved to its own ticket **048**. It needs both accounts to be importable, which today is
  exactly the pair ING Girokonto ↔ TR Cashkonto; the common case Giro → Tagesgeld never sees a second import because ING
  Extrakonten get no statements (`decisions.md`, 2026-08-24). The pair mechanics are useful for every account and have to
  land first anyway, since 048 needs the link to reconcile against
- **Recognising the pair** → a stored link, `Transaction.counterpartUuid` (nullable). Read-time matching on amount, day and
  the two account uuids is the heuristic this project already rejected (`decisions.md`, 2026-08-21: "Paarung erfindet
  Verknüpfungen — zwei zufällig gleiche Beträge am selben Tag sind keine Umbuchung"). A link written when the user creates
  the pair is a fact, not a guess. The field is additive, so no bump of `kDbSchemaVersion` — same as `Transaction.kind` in 032
- **Lifecycle of a pair** → amount and date are mirrored to the other leg on edit (same amount, opposite sign, same date);
  category, description and counterparty stay independent per leg; deleting either leg soft-deletes **both**, after a
  confirmation naming the other account. Refusing the edit while linked would be worse, since correcting a wrong amount is
  the normal case, and half a transfer is wrong in both balances. Deliberately deviates from the non-cascade of line items
  (`decisions.md`, 2026-08-13): a line item is only reachable through its booking, while both legs here are reachable through
  their own account, so a leftover leg stays visible and wrong.
  Note for 048: once one leg can come from an import, the cascade deletes a row the bank confirmed — that case is 048's to
  answer, not this ticket's.
  **Clarified while refining 048 (2026-08-25): the mirroring of amount and date is a rule for form edits only.** When an import
  replaces a mirror leg with the bank's own figures, nothing propagates to the other leg — money leaves on one day and arrives on
  another, and a fee can make the amounts differ legitimately

- **Choosable accounts** → every other **non-archived** own account. Archived ones stay out: the category picker sets that
  precedent, and archiving means "no longer in use", so writing a fresh booking into one contradicts it
- **Target account is optional** → `Umbuchung` on without a target stays legal and writes no counter-leg. Money moving to a
  broker outside the app is a real transfer: it rightly falls out of the report, and there is nothing to mirror
- **Text on the counter-leg** → description `Umbuchung von <Kontoname>` / `Umbuchung nach <Kontoname>` by direction,
  `counterparty` = the other account's name, no category. Not an invention but the one fact that row carries — it exists
  because something happened on the other account — and editable like any booking. Rejected copying the source
  description: `Miete` on the other side of a Tagesgeld transfer does not describe what happened there. Nothing leaks into
  tagging, since the learn hook skips transfers
- **Changing the target later** → the existing counter-leg is **moved** (`accountUuid` updated, uuid stable), not deleted and
  rewritten: one `update` in the change queue instead of `delete` + `create`, and anything the user already edited on that
  row survives. Its description is regenerated only while it still equals the generated text. Clearing the target
  soft-deletes the counter-leg and drops the link on the source — the delete rule, triggered from the other side

## Acceptance Criteria
- [x] With `Umbuchung` on, the booking form offers a target-account picker listing every other non-archived account
- [x] Leaving the target empty is allowed, saves, and writes no counter-leg — the 032 case stays intact
- [x] Choosing a target writes the counter-leg on that account: same amount with the opposite sign, same date,
      `kind = transfer`, `counterparty` = the source account's name, description `Umbuchung von <Kontoname>`
- [x] Both legs carry `Transaction.counterpartUuid` pointing at each other; the field is additive and `kDbSchemaVersion` is
      **not** bumped
- [x] Editing amount or date on either leg mirrors onto the other; category, description and counterparty stay per leg
- [x] Deleting either leg soft-deletes both, after a confirmation that names the other account
- [x] Changing the target account moves the counter-leg without changing its uuid, and regenerates its description only if
      the user never edited it
- [x] Clearing the target account soft-deletes the counter-leg and clears the link on the source booking
- [x] Both account balances reflect the movement at once — transfers stay in the balance (`decisions.md`, 2026-08-21)
- [x] Neither leg appears in the monthly report
- [x] Nothing is paired automatically: a transfer whose target was never chosen stays unpaired forever
- [x] `make check` green

## Out of Scope (proposed, to confirm)
- Multi-currency transfers
- Transfers between accounts of different users

## Affected Tests
- `TransactionRepository`: writing the pair, mirroring an amount or date edit, the cascading soft-delete, moving the
  counter-leg, clearing the target
- The balance suite: both accounts move at once, and the existing transfer-stays-in-the-balance case keeps holding
- The report suite: both legs excluded (already true for transfers, so this is a regression guard)
- Form widget test: the picker appears only with `Umbuchung` on, lists no archived account, and an empty target saves
- Dedupe suites are **not** affected — nothing here changes the hash. The import side is ticket 048

## Fixtures Needed
No. Two accounts and one booking, built inline — same call as 041, 025 and 026. The repository side runs against real Isar
in a temp directory, the form side against fakes.

### Refinement Tokens (estimate)
- Input: ~15k tokens
- Output: ~2.5k tokens

### Implementation Tokens (estimate)
- Input: ~150k tokens
- Output: ~18k tokens
- Delegated: ~125k tokens across two Sonnet sub-agents (the repository suite, then
  the balance/report/form suites)

## How it was built
Built in three gates rather than one, because the new field needs `make gen`
before anything can compile, and that step is the user's.

**The pair lives in `TransferPairService` (`domain/`), not in
`TransactionRepository.save`.** Both legs are Transactions, so unlike the
line-item reconcile and the tagging learn hook (`decisions.md`, 2026-08-13) no
dependency edge would have been inverted by putting it in the repository. Two
other reasons decided it anyway:

- Mirroring has to stay a form-edit rule. 048 replaces a mirror leg with the
  bank's own figures and must not propagate them — money can leave on one day and
  arrive on another, and a fee can make the amounts differ. An unconditional
  `save` invariant would have walled that ticket off.
- The cascading delete needs a confirmation naming the other account, and a
  repository cannot show a dialog. A silent cascade underneath a UI that is still
  asking is two answers to one question.

The accepted risk is a write path forgetting the service. Answered as in
2026-08-13: a guard plus a test, not a compiler — a widget test pins that the
booking list's swipe-delete reaches `deletePair` and that
`TransactionRepository.softDelete` is never called directly.

Details worth keeping:

- The counter-leg is **moved** on a target change: `accountUuid` is updated and
  the uuid stays, so the change queue sees one `update` instead of a `delete`
  plus a `create`, and anything the user edited on that row survives.
- Its description is regenerated only while it still equals either generated
  wording, which is what makes a sign flip rewrite `Umbuchung von X` to
  `Umbuchung nach X` while leaving the user's own text alone.
- `counterparty` on the counter-leg is written once and then belongs to that leg,
  like its category.
- The target picker drops its choice when the source account is changed to the
  same account: a pair inside one account would cancel out on that balance.

Two findings from the gates, neither in the feature itself:

- `softDelete` sets a flag and keeps the row, and `findByUuid` does **not** filter
  deleted rows while `findByAccount` does. Three tests asserted `findByUuid`
  returns null after a delete. They now assert `deleted` **and** that the account
  no longer lists the row, which is the half the user sees.
- Reading `transferPairServiceProvider` in the form pulls `AccountRepository` and
  therefore `isarProvider` into every form widget test that drives a save to
  completion. `manual_entry_suggest_test.dart` needed a fake; the other two
  manual-entry suites never finish a save, so they were left alone.
- Noted in passing, not acted on: `Transaction` has no `operator ==`, so
  comparing booking lists directly is an identity comparison against freshly
  queried rows. Compare uuids.
