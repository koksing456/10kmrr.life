# Private Beta Packaging Checklist

Use this only after alpha compatibility data is strong enough to justify a private signed build.

Do not publish a public installer until signing, notarization, support, rollback, and compatibility expectations are ready.

## Preconditions

- At least 5 successful installs on supported Macs.
- If Intel is included in the private beta, at least 2 successful Intel installs with Lock Screen visibility verified.
- No repeated private macOS API failure on common supported macOS versions.
- Install failure rate below 30 percent for the same reason.
- `./script/check.sh` passes on a clean checkout.
- `./script/install_lock_overlay_agent.sh`, `./script/repair_lock_overlay_agent.sh`, and `./script/uninstall_lock_overlay_agent.sh --all` pass a local smoke test.
- `./script/support_report.sh` produces a safe report without raw secrets or exact MRR.

Summarize evidence readiness:

```sh
./script/private_beta_readiness.sh
```

Use strict mode before any private package dry run:

```sh
./script/private_beta_readiness.sh --require-ready
```

## Signing Inputs

Record these privately. Do not commit them.

- Apple Developer team ID.
- Developer ID Application certificate availability.
- Notary profile name or keychain profile.
- Bundle identifier: `life.10kmrr.MRRLockScreenOverlay`.
- App version and build commit.

Check local signing readiness:

```sh
./script/signing_preflight.sh
```

Use strict mode before attempting a private signed package:

```sh
./script/signing_preflight.sh --require-ready
```

## Package Shape

Preferred private beta shape:

- Signed `.app`.
- Notarized `.zip` or `.dmg`.
- No bundled Stripe key.
- No installer that writes secrets.
- Clear uninstall path in the release notes.

Source-generated dry run:

```sh
./script/package_private_beta.sh --adhoc
```

This first runs `./script/private_beta_readiness.sh --require-ready`, then writes an explicitly unnotarized private zip under `build/private-beta` for internal testing only. It is not a public installer and should not be distributed broadly.

## Smoke Test

For each private beta package:

- Download package on a clean supported Mac.
- Verify Gatekeeper opens it without scary unsigned warnings.
- Configure a restricted Stripe key locally.
- Run mock preview before real refresh.
- Install LaunchAgent.
- Lock screen and confirm overlay visibility.
- Run `./script/diagnose.sh`.
- Run `./script/repair_lock_overlay_agent.sh` and confirm Keychain, cache, and display settings are preserved.
- Run `./script/support_report.sh`.
- Uninstall with `./script/uninstall_lock_overlay_agent.sh --all`.

## Release Notes Must Say

- Gated private beta, not broad public release.
- Intel support boundary if Intel Lock Screen behavior is still unverified.
- Private macOS API caveat.
- Local-first Stripe key and MRR model.
- No 10kmrr.life server stores Stripe keys or MRR in the current alpha path.
- Do not send Stripe keys, exact private MRR, raw logs, raw Stripe responses, customer data, payment data, or unsanitized screenshots.

## Hold Criteria

Do not ship a private beta package if:

- Notarization fails.
- The app needs elevated permissions not already documented.
- The package changes Keychain behavior unexpectedly.
- The uninstall path leaves the LaunchAgent loaded.
- Compatibility failures are concentrated on a supported macOS version.
- Support reports repeatedly require sensitive data to debug.
