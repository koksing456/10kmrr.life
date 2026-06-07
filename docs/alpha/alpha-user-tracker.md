# Alpha User Tracker

Use this tracker for approved gated alpha testers only.

Do not record Stripe API keys, raw revenue logs, customer/payment data, email/contact data, names, handles, or unsanitized screenshots.
Keep identity and contact mapping outside this repo. Use stable tester ids such as `tester_001`.

| Tester ID | Uses Stripe subscriptions | Primary Mac version | Approved | Install status | Key setup status | First MRR seen | Day 7 retained | Pro interest | Blocker | Next action |
|---|---|---|---|---|---|---|---|---|---|---|
| tester_001 | yes/no/unknown | macOS version | yes/no | not sent/sent/installed/failed | not started/success/failed | yes/no | yes/no/unknown | none/low/medium/high | short note | short note |

## Approval Criteria

- Uses Stripe subscriptions or is close to using Stripe subscriptions.
- Works primarily on a Mac.
- Understands this is a gated alpha.
- Accepts the private macOS API compatibility caveat.
- Will use a restricted read-only Stripe key.

## Rejection / Hold Reasons

- Wants full analytics instead of a daily MRR signal.
- Does not use Mac.
- Does not use Stripe subscriptions.
- Is not comfortable with local alpha software.
- Requires public notarized installer before trying.
