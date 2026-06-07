# Contributing

10kmrr.life is currently a gated public-alpha source repo. Contributions are welcome only when they preserve the local-first security model and narrow product scope.

## Security Rules

Do not commit, paste, or attach:

- Stripe API keys.
- Exact private MRR.
- Raw Stripe API responses.
- Customer names, emails, invoices, payments, or subscriptions.
- Raw logs that may contain secrets.
- Unsanitized screenshots with real revenue.

Use mock or sanitized data for tests, screenshots, fixtures, and docs.

## Product Scope

The core product promise is:

> Your Stripe MRR, on your Mac Lock Screen.

Keep changes aligned with that promise. Avoid expanding into a full analytics dashboard, hosted Stripe data warehouse, customer/payment data viewer, or finance reporting platform.

## Before Opening A PR

Run:

```sh
./script/verify_public_repo.sh
```

This checks shell syntax, MRR calculator fixtures, app build/signing, sanitized demo assets, obvious Stripe secret patterns, local-only paths, ignored private folders, and required public docs.

## Useful Local Commands

Build and verify the app:

```sh
./script/build_lock_overlay.sh --verify
```

Run focused MRR tests:

```sh
./script/test_mrr_calculator.sh
```

Run safe diagnostics:

```sh
./script/diagnose.sh
```

## Private macOS API Caveat

The Lock Screen overlay depends on private macOS behavior. Changes touching SkyLight, private glass, window levels, LaunchAgents, or lock-screen behavior should be tested carefully and documented in alpha compatibility notes.
