# Landing Skeleton

This was the planning structure for the public alpha page. The current static page lives in [site](../../site).

Run it locally:

```sh
./script/serve_site.sh
```

The page must continue to use mock or sanitized MRR only.

## Hero

Headline:

Your Stripe MRR, on your Mac Lock Screen.

Subhead:

A local Mac-first revenue signal for solo SaaS founders who want their MRR visible every day.

Primary CTA:

Request alpha access.

Secondary CTA:

Join Pro interest list.

## What It Does

- Reads Stripe subscriptions locally.
- Computes Stripe-like MRR.
- Displays MRR as a Lock Screen overlay.
- Keeps Stripe key in macOS Keychain.

## What It Is Not

- Not a full analytics dashboard.
- Not a finance reporting platform.
- Not a replacement for Stripe Dashboard.
- Not a public notarized installer yet.

## Local And Private

- Restricted read-only Stripe key.
- Key stored in macOS Keychain.
- Last-good MRR cached locally.
- No alpha backend storage for Stripe keys or MRR values.

## Compatibility

This alpha depends on private macOS behavior for Lock Screen placement and glass rendering. Future macOS releases may require fixes.

## Alpha Request

Collect:

- Name / handle.
- Email or contact.
- Uses Stripe subscriptions: yes/no.
- Main macOS version.
- Why they want MRR on Lock Screen.
- Comfort with restricted read-only Stripe key.

Do not collect:

- Stripe API key.
- Exact MRR.
- Customer or payment data.

## Pro Interest

Ask which upgrades matter:

- Custom design.
- Position / size controls.
- Refresh / cache controls.
- Multi-currency polish.
- MRR goal / delta / milestone.
- Signed / notarized installer.
- Compatibility updates.
