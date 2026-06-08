# Alpha Ops Checklist

Use this checklist before inviting each alpha tester.

For the full private tracker workflow, use [private-alpha-workflow.md](./private-alpha-workflow.md).

## Before Invite

- Run `./script/alpha.sh tracker` and keep the generated tracker private.
- Use `./script/alpha.sh tracker --readme-only` for tracker instruction refreshes after rows exist.
- Run `./script/alpha.sh next` first when deciding what to do next.
- Run `./script/alpha.sh check` before repo changes or releases.
- Run `./script/alpha.sh report` when you need a private readiness report under `build/`.
- Run `./script/alpha.sh audit` if tracker rows were edited manually.
- Confirm they use Stripe subscriptions.
- Confirm they use a Mac daily.
- Confirm they understand this is source alpha, not a notarized public installer.
- Confirm they are comfortable creating a restricted read-only Stripe key.
- Send SECURITY.md before any setup conversation.
- Preview the invite packet with `./script/alpha.sh invite --tester-id tester_XXX --macos-version 15.x --cpu apple_silicon --display-setup built_in --dry-run` before writing any tracker rows.
- Prepare the tester invite packet only after you have a real tester assigned to that stable id: replace `tester_XXX` and `15.x`, then remove `--dry-run`.
- Send the generated invite body from ignored `build/alpha-invites/<tester-id>.md`.
- Send [alpha-invite-template.md](./alpha-invite-template.md) after approval only if you need to edit the template manually.

## During Setup

- Ask for macOS version.
- Ask whether Apple Silicon or Intel.
- Ask them to run `./script/alpha.sh start --tester-id tester_XXX` when the tester id is already assigned privately.
- Use `./script/alpha.sh start` without a tester id only when the tester will report evidence later through another private channel.
- Use [install-smoke-checklist.md](./install-smoke-checklist.md) only when you need to isolate a specific failed stage.
- If they install, see MRR, see the Lock Screen overlay, and confirm it hides after unlock, run the success packet command printed by `start_alpha.sh`.
- If they are blocked or hit a warning, record the common support issue with `./script/alpha.sh support --tester-id tester_XXX --issue-type lock_screen --result fail` after replacing `tester_XXX`.
- Use `./script/alpha.sh install` and `./script/alpha.sh compatibility` separately when a stage is partial, warns, or fails.
- If anything fails, ask for `./script/alpha.sh support-report`, not raw logs.

## Before Private Beta Packaging

- Preview the local smoke sequence with `./script/alpha.sh smoke`.
- On a clean smoke machine, run and record with `./script/alpha.sh smoke --apply --full-reset --confirm-full-reset --record`.
- Re-run `./script/alpha.sh beta-ready`.
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
./script/alpha.sh success \
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

Record the outcome in the private `pro-interest` and `alpha-users` trackers:

```sh
./script/alpha.sh day7 \
  --tester-id tester_001 \
  --retained-day-7 yes \
  --overall-pro-signal medium \
  --notes "kept it on for day 7"
```

Keep Pro pull separate from general feedback.

## Weekly Review

Run the safe aggregate summary before writing the weekly review row:

```sh
./script/alpha.sh weekly
```

Run the private tracker audit before widening alpha:

```sh
./script/alpha.sh audit
```

Use the suggested `./script/alpha.sh review` command only after checking that the aggregate counts match the private tracker.

## Kill Criteria

Pause alpha expansion if:

- More than 30 percent of testers fail setup for the same reason.
- Testers repeatedly try to send secrets.
- Private macOS API behavior fails on common supported macOS versions.
- Most demand shifts toward full analytics rather than Lock Screen signal.
