# Release Strategy

10kmrr.life is public-alpha source code, not a public binary distribution yet.

## Current Release Boundary

- Public repo: yes.
- Public downloadable installer: no.
- Gated alpha install from source: yes.
- Current source build architecture: universal arm64 and x86_64.
- Notarized distribution: not yet.
- Auto-update: not yet.

## Why No Public Installer Yet

The app depends on private macOS behavior for Lock Screen placement and private glass rendering. A public installer would imply a level of compatibility and support that the alpha has not earned yet.

The alpha should first prove:

- Founders want the Lock Screen MRR signal after 7 days.
- Restricted-key setup is acceptable.
- The private macOS overlay behavior is stable enough across tester machines.
- Safe support workflows can debug issues without collecting secrets.

## Candidate Release Path

1. Gated source alpha.
2. Signed local build instructions.
3. Small private signed build for trusted testers.
4. Notarized beta installer if compatibility is stable.
5. Public installer only after support, security, and rollback expectations are documented.

Use [private-beta-packaging-checklist.md](./private-beta-packaging-checklist.md) before creating any private signed package.

Summarize the private beta evidence gate with:

```sh
./script/alpha.sh beta-ready
```

Use strict mode before any private package dry run:

```sh
./script/alpha.sh beta-ready --require-ready
```

## Release Checklist

- `./script/alpha.sh check` passes.
- `./script/build_lock_overlay.sh --verify` passes.
- `./script/test_mrr_calculator.sh` passes.
- `./script/install_lock_overlay_agent.sh` works from a clean checkout.
- `./script/diagnose.sh` gives safe, actionable output.
- `./script/alpha.sh support-report` gives a sanitized report without raw secrets, Stripe object IDs, raw Stripe fields, local paths, or exact MRR.
- No Stripe keys, real MRR screenshots, local-only paths, or generated artifacts are committed.
- README and SECURITY docs clearly mention private macOS API risk.
- Release notes state whether the build is Apple Silicon-only or universal.
- GitHub issue templates warn against posting sensitive data.
- GitHub issue labels are synced from `.github/labels.yml` or verified with `./script/alpha.sh labels --verify`.

## Public Repo Gate

Run this before pushing release-readiness changes:

```sh
./script/alpha.sh check
```

The gate checks shell syntax, focused MRR calculator/cache/settings tests, Stripe client tests, local app build/signing, required sanitized demo assets, obvious Stripe secret patterns, local-only paths, retired wallpaper artifacts, ignored private folders, required public docs, and signing readiness preflight.

For a quick non-build status summary during alpha operations:

```sh
./script/alpha.sh status
```

This summarizes source state, private tracker presence, signing readiness, latest GitHub Actions status when available, and safe next actions. It is not a replacement for `./script/alpha.sh check` before release or repo changes.
If your private tracker lives outside the default ignored `build/alpha-tracker` path, pass it explicitly with `./script/alpha.sh status --tracker-dir /path/to/private-tracker`.

It also validates the GitHub label manifest and label sync parser. To verify or apply labels after reviewing the plan:

```sh
./script/alpha.sh labels --verify
./script/alpha.sh labels --dry-run
./script/alpha.sh labels --apply
```

It does not install the LaunchAgent. Install/reinstall remains a separate local smoke test because it mutates the user's machine state. Preview that sequence with:

```sh
./script/alpha.sh smoke
```

Record full local smoke only on a clean smoke machine:

```sh
./script/alpha.sh smoke --apply --full-reset --confirm-full-reset --record
```

For a private signed/notarized package after evidence and signing are ready:

```sh
./script/alpha.sh package --signed
```

This creates a private signed/notarized zip under `build/private-beta`. It is still not a public installer.

For an explicit internal unnotarized package dry run only:

```sh
./script/alpha.sh package --adhoc
```

This creates an unnotarized private zip under `build/private-beta`. It is not a public installer and should not be used as the default private beta package once Developer ID signing is ready.
The packaging script refuses to continue unless the private beta readiness gate passes first.

For Developer ID readiness:

```sh
./script/alpha.sh signing
```

This checks whether Developer ID signing and a notary keychain profile appear available without printing notary credentials. Set `TENKMRR_NOTARY_PROFILE` only in your private shell when you want strict notarization readiness checked.
