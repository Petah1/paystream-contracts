# Stream Receipts (PROD-01)

## Feasibility

Soroban has no native NFT primitive, and there is no ratified SEP for
non-fungible tokens on Stellar yet. A separate NFT contract would add a
cross-contract call to every `withdraw` and tie PayStream to a draft interface.

**Decision:** implement receipts natively inside the stream contract. Each
stream has exactly one receipt, keyed by stream ID (`DataKey::ReceiptOwner`).
The interface (`receipt_owner`, `transfer_receipt`) mirrors `owner_of` /
`transfer` so it can be wrapped by a standard NFT contract later without
changing stream storage.

## Design

| Action | Behaviour |
|---|---|
| `create_stream`, `create_streams_batch` | Mint the receipt to `employee` |
| `receipt_owner(stream_id)` | Current holder; falls back to `stream.employee` for streams created before receipts existed |
| `transfer_receipt(from, to, stream_id)` | Holder moves the receipt; `to` is added to the employee index; emits `receipt` event |
| `withdraw` | Only the receipt holder may withdraw (E016 otherwise) |
| `withdraw_all` | Skips streams whose receipt the caller no longer holds |

Unchanged: `stream.employee` keeps the original employee for audit and events;
employer controls (pause, resume, cancel, top-up, rate updates) are unaffected.
On `cancel_stream` / `cancel_streams_batch`, accrued earnings are paid to the
receipt holder and the unearned remainder is refunded to the employer.

Receipts carry no metadata on-chain; indexers derive it from `get_stream`.

## Legal and compliance considerations

- **Wage assignment law:** many jurisdictions restrict or prohibit assigning
  future wages (e.g. US state wage-assignment statutes, EU member-state labour
  codes). Integrators must confirm transfers are lawful for their employees
  and may need to disable transfers in the UI.
- **Securities classification:** a transferable claim on future income could be
  treated as a security or financial instrument (Howey test, MiCA). Secondary
  markets built on receipts need their own legal review.
- **KYC/AML:** transferring a receipt moves value to an unverified address;
  regulated employers should restrict transfers to verified accounts off-chain.
- **Tax and payroll reporting:** the employer's payroll obligations attach to
  the employee, not the receipt holder. Withdrawals by a third party do not
  change the employer's reporting duties.
- **Employer risk:** the employer can still cancel a stream; buyers of a
  receipt bear that counterparty risk and should be informed.

PayStream provides the mechanism only and does not endorse any secondary
market. This section is informational, not legal advice.
