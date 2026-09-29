# Settlement visibility: digest + receipt

Date: 2026-09-29. Surface: broadsheet newspaper (`/` on the dashboard),
fed by `automation/scripts/newspaper-compose.py`.

## Problem

When the operator settled a decision card (park with a required note,
acknowledge, dismiss), the card vanished from the next edition and
nothing on the page recorded that the decision happened or where it
was durably held. The park of 2026-09-29T13:56:25Z (item faa648fe)
showed the gap: the note went into the report-queue ledger and
`automation/agent-handoffs.md`, but no surface answered "what happened
to the card I parked?".

## Change

- `newspaper-compose.py`: `settled_article()` reads the operator
  handoff ledger (`HNGH_HANDOFFS` override, else
  `automation/agent-handoffs.md`), parses
  `operator-<verb> | <ts> | automation|<id> | <why>` rows, sorts
  newest-first, caps at 8, and emits an `Operator settlements: how
  decisions landed` digest article (ts of newest row, 0.9 salience,
  agent-handoffs doc link). Fail-open: unreadable or empty ledger
  means no article, never a broken feed.
- `broadsheet-view.js`: after a successful decision POST the client
  shows a receipt chip (`#settle-receipt`, 15 s): park receipts name
  the report-queue row (`operator-item:<id>:parked`) and the
  dismissed-side ledger plus the operator's note; acknowledge receipts
  name the approved-side ledger. Card filtering still happens at feed
  rebuild — the receipt tells the operator where the decision went,
  the digest keeps it visible in later editions.
- `broadsheet.css`: `#settle-receipt` styled from the existing paper
  palette (`--paper`/`--rule`/`--ink`), opacity-gated `.on`.

## Verification

- `automation/tests/test-newspaper-compose.py`: digest presence, ts =
  newest handoff row, 10-row ledger capped to 8 newest-first,
  fail-open on absent/empty ledger. Suite: 31 tests OK.
- `automation/tests/test-broadsheet-view.py`: receipt text pinned for
  park/acknowledge/dismiss, wiring pin
  `settleReceipt(act.endpoint, payload)` in the choice click handler,
  `#settle-receipt.on` style pin. Suite: 48 tests OK.
- Full `make test` gate green; live beat regeneration produced the
  digest with the faa648fe park row on top; browser proof (fetch
  stubbed, no server mutation) showed the `.on` receipt with the full
  park text and zero JS errors.
