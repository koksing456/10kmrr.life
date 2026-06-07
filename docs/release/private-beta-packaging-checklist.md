# Private Beta Packaging Checklist

Use this only after alpha compatibility data is strong enough to justify a private signed build.

Do not publish a public installer until signing, notarization, support, rollback, and compatibility expectations are ready.

## Preconditions

- At least 5 successful installs on supported Apple Silicon Macs.
- No repeated private macOS API failure on common supported macOS versions.
- Install failure rate below 30 percent for the same reason.
- `./script/verify_public_repo.sh` passes on a clean checkout.
- `./script/install_lock_overlay_agent.sh` and `./script/uninstall_lock_overlay_agent.sh --all` pass a local smoke test.
- `./script/support_report.sh` produces a safe report without raw secrets or exact MRR.

## Signing Inputs

Record these privately. Do not commit them.

- Apple Developer team ID.
- Developer ID Application certificate availability.
- Notary profile name or keychain profile.
- Bundle identifier: `life.10kmrr.MRRLockScreenOverlay`.
- App version and build commit.

## Package Shape

Preferred private beta shape:

- Signed `.app`.
- Notarized `.zip` or `.dmg`.
- No bundled Stripe key.
- No installer that writes secrets.
- Clear uninstall path in the release notes.

## Smoke Test

For each private beta package:

- Download package on a clean supported Mac.
- Verify Gatekeeper opens it without scary unsigned warnings.
- Configure a restricted Stripe key locally.
- Run mock preview before real refresh.
- Install LaunchAgent.
- Lock screen and confirm overlay visibility.
- Run `./script/diagnose.sh`.
- Run `./script/support_report.sh`.
- Uninstall with `./script/uninstall_lock_overlay_agent.sh --all`.

## Release Notes Must Say

- Gated private beta, not broad public release.
- Apple Silicon support boundary if Intel is still unbuilt.
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
