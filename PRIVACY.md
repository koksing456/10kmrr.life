# Privacy

10kmrr.life is local-first in the current alpha.

## What The App Reads

The app reads Stripe Billing subscription data directly from Stripe on your Mac using the restricted Stripe API key you configure.

Use a restricted read-only Stripe key. Do not use a full-access Stripe secret key.

## What Stays Local

Current alpha storage:

- Stripe API key: macOS Keychain.
- Last-good MRR value: local user defaults.
- Last updated timestamp: local user defaults.
- Display settings: local user defaults.
- Source checkout path for support commands: local app support file.

The current alpha does not upload your Stripe key, MRR, customer data, payment data, or Stripe API responses to a 10kmrr.life server.

## What Public Issues Must Not Include

Do not include:

- Stripe API keys.
- Exact private MRR.
- Raw Stripe API responses.
- Raw logs that may contain secrets.
- Customer names, emails, invoices, payments, or subscriptions.
- Unsanitized screenshots with real revenue.

## Safe Alpha Feedback

Safe to share:

- macOS version.
- Apple Silicon or Intel.
- Display setup category.
- App version and commit.
- Pass/warn/fail summaries from `./script/diagnose.sh`.
- Non-sensitive error summaries.

## Compatibility Caveat

The Lock Screen overlay depends on private macOS behavior for placement and private glass rendering. Future macOS releases may break the overlay or require fixes.

This is not a notarized public Mac app yet.
