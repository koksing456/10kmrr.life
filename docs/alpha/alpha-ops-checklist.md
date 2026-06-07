# Alpha Ops Checklist

Use this checklist before inviting each alpha tester.

For the full private tracker workflow, use [private-alpha-workflow.md](./private-alpha-workflow.md).

## Before Invite

- Confirm they use Stripe subscriptions.
- Confirm they use a Mac daily.
- Confirm they understand this is source alpha, not a notarized public installer.
- Confirm they are comfortable creating a restricted read-only Stripe key.
- Send SECURITY.md before any setup conversation.

## During Setup

- Ask for macOS version.
- Ask whether Apple Silicon or Intel.
- Ask them to run `./script/build_lock_overlay.sh --verify`.
- Ask them to configure through `./script/build_lock_overlay.sh --setup`.
- Ask them to run `./script/build_lock_overlay.sh --preview-private-glass`.
- Ask them to install only after preview/setup are understood.

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
