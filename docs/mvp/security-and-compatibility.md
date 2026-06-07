# Security And Compatibility Notes

## Current Security Model

10kmrr.life is local-first in the current alpha.

The app reads a restricted Stripe API key from macOS Keychain:

- service: `life.10kmrr.StripeMRRScreenSaver`
- account: `stripe_api_key`

The service name is retained for compatibility with the earlier prototype.

## Stripe Key Requirements

Use a restricted read-only Stripe key.

The key should only have the permissions needed to read Billing subscription and price data.

Do not use a full-access secret key for alpha testing.

## Data Storage

Current local storage:

- Stripe key: macOS Keychain.
- Last-good MRR value: local user defaults.
- Last updated timestamp: local user defaults.

Current alpha does not need a backend to store Stripe keys or MRR values.

## Support Boundary

Do not send:

- Stripe API keys.
- Full Stripe dashboard screenshots containing sensitive customer or revenue data.
- Customer emails or payment details.
- Raw logs containing secrets.

When debugging, share only:

- macOS version.
- App version / build date.
- Whether `--verify` passes.
- Non-sensitive error messages.

## Compatibility Caveat

The lock-screen overlay depends on private macOS behavior for lock-screen placement and private glass rendering.

That means:

- Future macOS releases may break the overlay.
- Some machines may behave differently.
- Public distribution will need stronger signing, notarization, diagnostics, and fallback planning.

## Public Messaging Boundary

Do not describe the alpha as a fully stable public Mac app.

Use this framing:

> A personal Mac tool and gated alpha for founders who want Stripe MRR visible on their Lock Screen.
