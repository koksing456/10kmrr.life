# Alpha Ops Checklist

Use this checklist before inviting each alpha tester.

For the full private tracker workflow, use [private-alpha-workflow.md](./private-alpha-workflow.md).

## Before Invite

- Run `./script/prepare_alpha_tracker.sh` and keep the generated tracker private.
- Confirm they use Stripe subscriptions.
- Confirm they use a Mac daily.
- Confirm they understand this is source alpha, not a notarized public installer.
- Confirm they are comfortable creating a restricted read-only Stripe key.
- Send SECURITY.md before any setup conversation.
- Send [alpha-invite-template.md](./alpha-invite-template.md) after approval.

## During Setup

- Ask for macOS version.
- Ask whether Apple Silicon or Intel.
- Ask them to run `./script/start_alpha.sh`.
- Use [install-smoke-checklist.md](./install-smoke-checklist.md) only when you need to isolate a specific failed stage.
- Record compatibility with `./script/record_alpha_compatibility.sh` after preview/install/Lock Screen visibility are checked.
- If anything fails, ask for `./script/support_report.sh`, not raw logs.

## Before Private Beta Packaging

- Run the local smoke steps in [../release/private-beta-packaging-checklist.md](../release/private-beta-packaging-checklist.md).
- Record the result with `./script/record_alpha_local_smoke.sh`.
- Re-run `./script/private_beta_readiness.sh`.
- Do not continue to package dry runs until local smoke has a pass row and the remaining blocker is only signing/notarization.

## Never Collect

- Stripe API keys.
- Exact MRR.
- Raw Stripe API responses.
- Customer names, emails, invoices, or payments.
- Unsanitized screenshots with real revenue.
- Raw logs unless reviewed and sanitized first.

## First Success

Track only:

- Install status.
- Key setup status.
- First MRR seen: yes / no.
- Preview works: yes / no.
- Lock Screen visible: yes / no.
- Blocker summary.
- Next action.

## Day 7

Ask:

- Did you keep it on?
- Did seeing MRR on Lock Screen change behavior?
- Did it become noise?
- What would make it worth paying for?
- What would make you uninstall it?

Record the outcome in the private `pro-interest` and `alpha-users` trackers. Keep Pro pull separate from general feedback.

## Kill Criteria

Pause alpha expansion if:

- More than 30 percent of testers fail setup for the same reason.
- Testers repeatedly try to send secrets.
- Private macOS API behavior fails on common supported macOS versions.
- Most demand shifts toward full analytics rather than Lock Screen signal.
