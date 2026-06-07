# Private Alpha Workflow

Use this workflow for the gated alpha. Keep the working tracker private.

Do not collect Stripe keys, exact private MRR, raw Stripe API responses, customer/payment data, raw logs, or unsanitized screenshots.

## Tracker Setup

Create a private local tracker workspace first:

```sh
./script/prepare_alpha_tracker.sh
```

This writes starter files under `build/alpha-tracker`, which is ignored by git. Move those files into a private spreadsheet or lightweight CRM if you prefer.
If only the generated tracker README is stale, refresh it with `./script/prepare_alpha_tracker.sh --readme-only` so existing CSV rows are preserved. `--force` refuses to overwrite tracker CSVs that already contain private rows.

Use these sheets:

- `alpha-users`: one row per approved tester.
- `install-funnel`: one row per setup attempt.
- `compatibility`: one row per Lock Screen compatibility check.
- `local-smoke`: one row per private beta local smoke run.
- `pro-interest`: one row per 7-day follow-up.
- `weekly-review`: one row per weekly alpha review.

Keep identity and contact mapping outside this repo. The tracker should use a stable `tester_id`, not names, email addresses, or handles.

Starter CSV templates live in [templates](./templates):

- [alpha-users.csv](./templates/alpha-users.csv)
- [install-funnel.csv](./templates/install-funnel.csv)
- [compatibility.csv](./templates/compatibility.csv)
- [local-smoke.csv](./templates/local-smoke.csv)
- [pro-interest.csv](./templates/pro-interest.csv)
- [weekly-review.csv](./templates/weekly-review.csv)

## Funnel Stages

Use one of these exact stage values:

- `requested`
- `approved`
- `built`
- `configured_key`
- `previewed`
- `installed`
- `saw_mrr`
- `retained_day_7`
- `closed_lost`

Only advance a tester when the previous stage is confirmed by their non-sensitive report or a safe diagnostic summary.

Record approved testers with the safe append script:

```sh
./script/record_alpha_user.sh \
  --tester-id tester_001 \
  --uses-stripe-subscriptions yes \
  --macos-version 15.5 \
  --cpu apple_silicon \
  --display-setup built_in \
  --approved yes \
  --current-stage approved \
  --next-action "send invite"
```

Record install attempts with the safe append script:

```sh
./script/record_alpha_install.sh \
  --tester-id tester_001 \
  --stage installed \
  --build-verify pass \
  --configured-key yes \
  --previewed yes \
  --installed yes \
  --saw-mrr yes \
  --diagnose-summary "PASS summary only" \
  --next-action "day 7 follow-up"
```

The recorder rejects Stripe-key-like strings and obvious money amounts. Do not paste raw logs, exact MRR, raw Stripe responses, customer/payment data, or unsanitized screenshots into tracker fields.

## Compatibility Evidence

Use [compatibility-matrix.md](./compatibility-matrix.md) for the field definitions and threshold rules.

Record Lock Screen compatibility with:

```sh
./script/record_alpha_compatibility.sh \
  --tester-id tester_001 \
  --macos-version 15.5 \
  --cpu apple_silicon \
  --display-setup built_in \
  --build-verify pass \
  --preview-glass private \
  --lock-screen-visible yes \
  --unlock-hides-overlay yes \
  --launchagent-stable yes \
  --result pass \
  --next-action "day 7 follow-up"
```

Record only the pass/warn/fail outcome and non-sensitive blocker summaries. Keep screenshots mock, blurred, or explicitly sanitized.

## Local Beta Smoke

Before any private beta package dry run, preview the local smoke sequence:

```sh
./script/run_local_smoke.sh
```

Run and record the full local smoke only on a clean smoke machine:

```sh
./script/run_local_smoke.sh --apply --full-reset --record
```

This records only pass/warn/fail evidence. `--full-reset` removes local cache, display settings, and the stored Stripe key at the end of the smoke, so do not run it on a machine where you want to preserve the alpha setup.

## 7-Day Cadence

Run this cadence for every approved tester:

- Day 0: approve tester, send source alpha boundary, security rules, and setup path.
- Day 1: check build/setup/install friction if no successful install is reported.
- Day 3: ask whether the overlay is still visible and trusted.
- Day 7: send [seven-day-follow-up-template.md](./seven-day-follow-up-template.md), tag retention and Pro interest.

## Pro Pull

Track Pro interest separately from general feedback.

Use [pro-interest-scorecard.md](./pro-interest-scorecard.md) and record only:

- Feature scores from 0-3.
- Preferred pricing model.
- Overall Pro signal.
- Short non-sensitive notes.

Record Day 7 / Pro signal with:

```sh
./script/record_alpha_pro_followup.sh \
  --tester-id tester_001 \
  --retained-day-7 yes \
  --signed-notarized-installer 3 \
  --compatibility-updates 2 \
  --overall-pro-signal medium \
  --notes "kept it on for day 7"
```

Do not convert requests for full analytics into automatic product scope. Treat them as positioning data.

## Screenshot Rule

Screenshots are allowed only when one of these is true:

- MRR is mock.
- MRR is blurred.
- Tester explicitly says the visible MRR is sanitized and approved for sharing.

Reject screenshots that show Stripe keys, raw Stripe dashboards, customer names, emails, invoices, payments, subscriptions, or exact private MRR.

## Weekly Review

Once per week, fill `weekly-review`.

Review:

- Support load.
- Setup failure rate.
- Retention.
- Pro signal.
- Compatibility failures.
- Repeated secret-sharing risk.
- Scope pull toward full analytics.

Pause wider alpha expansion if install failure rate exceeds 30 percent for the same reason, if testers repeatedly try to send secrets, or if private macOS API behavior fails on common supported macOS versions.

Record the aggregate weekly review with:

```sh
./script/record_alpha_weekly_review.sh \
  --week-start 2026-06-08 \
  --support-load low \
  --setup-failure-rate low \
  --retention-count 2 \
  --pro-signal-count 1 \
  --compatibility-failures 0 \
  --decision continue \
  --next-action "invite next tester"
```

## Public Quotes

Do not publish testimonials by default.

If a tester offers public feedback, use [testimonial-approval-template.md](./testimonial-approval-template.md) and publish only after approval of the exact wording and attribution.
