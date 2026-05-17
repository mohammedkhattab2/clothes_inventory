# DeltaErp

Flutter desktop inventory/POS/ledger app with SQLite-backed transactional flows.

## Core Invariants

- Stock is derived only from stock movements: `SUM(in) - SUM(out)`.
- Account balances are derived only from ledger transactions.
- Returns are always tied to original invoice lines.
- Cancellation is reversal-based, but cancellation is blocked if the invoice already has returns.

## Cancellation And Return Policy

- Sale/Purchase return:
	- Allowed only for non-cancelled invoices.
	- Quantity must be positive and within remaining returnable quantity.
- Sale/Purchase cancellation:
	- Allowed only when invoice status is not `cancelled`.
	- Blocked when any return exists for that invoice.
	- Blocking message: reverse returns first, then cancel.

This policy prevents ledger/stock drift from mixed return-and-cancel flows.

## Test Coverage Notes

- `test/features/transactions/cancellation_guard_test.dart`
	- Verifies cancellation is rejected when returns exist.
- `test/features/transactions/transaction_invariants_test.dart`
	- Verifies stock and ledger invariants for partial return scenarios and confirms cancellation block behavior.

## Run Checks

```bash
flutter analyze
flutter test
```

## Developer Notes

- Windows debug build failures around `sqlite3.dll` file locks are usually external (running process, antivirus, or file indexing).
- This lock behavior is unrelated to the OCR/Tesseract integration.
