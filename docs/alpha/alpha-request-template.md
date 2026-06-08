# Alpha Request Template

Use this template for gated alpha requests. It is intentionally designed to avoid collecting sensitive Stripe or revenue data.

The public GitHub issue form lives at [.github/ISSUE_TEMPLATE/alpha_request.yml](../../.github/ISSUE_TEMPLATE/alpha_request.yml). Public requests must not include email, exact MRR, Stripe keys, Stripe object IDs, customer data, payment data, raw logs, raw Stripe responses, or unsanitized revenue screenshots.

## Request Fields

- Stable tester id, if already assigned privately:
- macOS version:
- Apple Silicon or Intel:
- Display setup:
- Uses Stripe subscriptions: yes / no
- Comfortable creating a restricted read-only Stripe key: yes / no / unsure
- Why do you want MRR on your Mac Lock Screen?
- What would make you uninstall it after a week?
- Interested in Pro convenience features: yes / no / maybe

Keep name, handle, email, and preferred contact mapping outside this repo and outside public GitHub issues.

Map public display setup answers into tracker values:

- Built-in display only: `built_in`
- One external display: `external`
- Multiple displays: `multiple`
- Clamshell: `clamshell`
- Not sure: `unknown`

## Never Collect

- Stripe API keys.
- Stripe object IDs.
- Exact MRR.
- Names, handles, emails, or preferred contact in public issues or repo-tracked files.
- Raw Stripe API responses.
- Stripe dashboard screenshots.
- Customer names, emails, payments, subscriptions, or invoices.
- Unsanitized screenshots with real MRR.

## Approval Notes

Good alpha candidates:

- Use Stripe subscriptions today.
- Use a Mac daily.
- Understand that this is a source alpha, not a notarized public installer.
- Are willing to run a local script and report safe diagnostics.

Lower-priority candidates:

- Do not use Stripe subscriptions.
- Need a polished signed installer immediately.
- Need a full analytics dashboard.
- Are not comfortable with the private macOS API compatibility caveat.
