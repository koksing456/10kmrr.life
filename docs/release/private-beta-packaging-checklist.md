# Private Beta Packaging Checklist

Use this only after alpha compatibility data is strong enough to justify a private signed build.

Do not publish a public installer until signing, notarization, support, rollback, and compatibility expectations are ready.

## Preconditions

- At least 5 successful installs on supported Macs.
- If Intel is included in the private beta, at least 2 successful Intel installs with Lock Screen visibility verified.
- If Intel is not included, run readiness and packaging with `--exclude-intel` and make the Intel exclusion explicit in release notes.
- No repeated private macOS API failure on common supported macOS versions.
- Install failure rate below 30 percent for the same reason.
- `./script/check.sh` passes on a clean checkout.
- `./script/install_lock_overlay_agent.sh`, `./script/repair_lock_overlay_agent.sh`, and `./script/uninstall_lock_overlay_agent.sh --all` pass a local smoke test.
- The local smoke result is recorded with `./script/run_local_smoke.sh --apply --full-reset --record`.
- `./script/support_report.sh` produces a safe report without raw secrets or exact MRR.

Summarize evidence readiness:

```sh
./script/private_beta_readiness.sh
```

Use strict mode before any private package dry run:

```sh
./script/private_beta_readiness.sh --require-ready
```

For an Apple Silicon-only private beta gate, exclude Intel explicitly:

```sh
./script/private_beta_readiness.sh --exclude-intel --require-ready
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

For strict private beta readiness, store notary credentials privately and set the profile name only in your shell environment:

```sh
xcrun notarytool store-credentials "your-private-profile-name"
export TENKMRR_NOTARY_PROFILE="your-private-profile-name"
./script/signing_preflight.sh --require-ready
```

Do not commit the profile name if it identifies a private Apple account or team.

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

For an Apple Silicon-only private beta package, run:

```sh
./script/package_private_beta.sh --adhoc --exclude-intel
```

The generated manifest must say Intel Lock Screen behavior is excluded/unverified.

## Smoke Test

Preview the local source smoke plan first:

```sh
./script/run_local_smoke.sh
```

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

For the source-based local smoke gate, run and record only on a clean smoke machine:

```sh
./script/run_local_smoke.sh --apply --full-reset --record
```

`--full-reset` removes local cache, display settings, and the stored Stripe key at the end of the smoke.
The runner records `pass` only when the commands succeed and the diagnostic/support output has no `WARN` or `FAIL` lines.

## Release Notes Must Say

- Gated private beta, not broad public release.
- Intel support boundary if Intel Lock Screen behavior is still unverified or explicitly excluded.
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
