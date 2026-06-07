# Alpha Ops Checklist

Use this checklist before inviting each alpha tester.

For the full private tracker workflow, use [private-alpha-workflow.md](./private-alpha-workflow.md).

## Before Invite

- Run `./script/prepare_alpha_tracker.sh` and keep the generated tracker private.
- Use `./script/prepare_alpha_tracker.sh --readme-only` for tracker instruction refreshes after rows exist.
- Confirm they use Stripe subscriptions.
- Confirm they use a Mac daily.
- Confirm they understand this is source alpha, not a notarized public installer.
- Confirm they are comfortable creating a restricted read-only Stripe key.
- Send SECURITY.md before any setup conversation.
- Send [alpha-invite-template.md](./alpha-invite-template.md) after approval.

## During Setup

- Ask for macOS version.
- Ask whether Apple Silicon or Intel.
- Ask them to run `./script/start_alpha.sh --tester-id tester_XXX` when the tester id is already assigned privately.
- Use `./script/start_alpha.sh` without a tester id only when the tester will report evidence later through another private channel.
- Use [install-smoke-checklist.md](./install-smoke-checklist.md) only when you need to isolate a specific failed stage.
- If they install, see MRR, see the Lock Screen overlay, and confirm it hides after unlock, run the success packet command printed by `start_alpha.sh`.
- Use `./script/record_alpha_install.sh` and `./script/record_alpha_compatibility.sh` separately when a stage is partial, warns, or fails.
- If anything fails, ask for `./script/support_report.sh`, not raw logs.

## Before Private Beta Packaging

- Preview the local smoke sequence with `./script/run_local_smoke.sh`.
- On a clean smoke machine, run and record with `./script/run_local_smoke.sh --apply --full-reset --confirm-full-reset --record`.
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

Successful Apple Silicon example:

```sh
./script/record_alpha_success.sh \
  --tester-id tester_001 \
  --macos-version 15.5 \
  --cpu apple_silicon \
  --display-setup built_in
```

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
