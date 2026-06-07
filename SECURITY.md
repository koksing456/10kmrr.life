# Security Policy

10kmrr.life is a local-first macOS alpha. The current alpha does not require a backend to store your Stripe API key or revenue data.

## Stripe Key Guidance

Use a restricted read-only Stripe API key. Do not use a full-access secret key.

The key should only have the permissions needed to read Billing subscriptions and prices.

Never send your Stripe key in chat, email, screenshots, support tickets, logs, or pull requests.

The helper script stores the key without printing it:

```sh
./script/configure_stripe_key.sh
```

If you accidentally stored the wrong key, remove it with:

```sh
./script/configure_stripe_key.sh --delete
```

## Local Storage

Current alpha storage:

- Stripe API key: macOS Keychain.
- Last-good MRR value: local user defaults.
- Last updated timestamp: local user defaults.

Current Keychain lookup:

- service: `life.10kmrr.StripeMRRScreenSaver`
- account: `stripe_api_key`

The service name is retained for compatibility with an earlier prototype.

## Safe Debugging Information

Safe to share:

- macOS version.
- App build date or commit.
- Whether `./script/build_lock_overlay.sh --verify` passes.
- Whether `./script/diagnose.sh` reports pass, warn, or fail for each check.
- Non-sensitive error messages.
- Whether the generated LaunchAgent exists.

Do not share:

- Stripe API keys.
- Full Stripe dashboard screenshots.
- Customer names, emails, payments, or subscriptions.
- Raw logs that may contain secrets or private revenue data.
- Unsanitized screenshots with real MRR unless you explicitly intend to disclose it.

## Compatibility Caveat

The Lock Screen overlay depends on private macOS behavior for placement and private glass rendering. Future macOS releases may break the overlay or require changes.

The alpha is a personal Mac tool first. It is not yet a notarized public release.

## Reporting Issues

For alpha testing, report only non-sensitive details. If a report would require sensitive Stripe or revenue information, describe the issue at a high level first and wait for a safe debugging path.

Do not include secrets in GitHub issues or pull requests.
