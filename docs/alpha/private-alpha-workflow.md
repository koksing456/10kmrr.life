# Private Alpha Workflow

Use this workflow for the gated alpha. Keep the working tracker private.

Do not collect Stripe keys, exact private MRR, raw Stripe API responses, customer/payment data, raw logs, or unsanitized screenshots.

## Tracker Setup

Create a private local tracker workspace first:

```sh
./script/prepare_alpha_tracker.sh
```

This writes starter files under `build/alpha-tracker`, which is ignored by git. Move those files into a private spreadsheet or lightweight CRM if you prefer.

Use these sheets:

- `alpha-users`: one row per approved tester.
- `install-funnel`: one row per setup attempt.
- `pro-interest`: one row per 7-day follow-up.
- `weekly-review`: one row per weekly alpha review.

Starter CSV templates live in [templates](./templates):

- [alpha-users.csv](./templates/alpha-users.csv)
- [install-funnel.csv](./templates/install-funnel.csv)
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

## Public Quotes

Do not publish testimonials by default.

If a tester offers public feedback, use [testimonial-approval-template.md](./testimonial-approval-template.md) and publish only after approval of the exact wording and attribution.
