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
./script/private_beta_readiness.sh
```

Use strict mode before any private package dry run:

```sh
./script/private_beta_readiness.sh --require-ready
```

## Release Checklist

- `./script/check.sh` passes.
- `./script/build_lock_overlay.sh --verify` passes.
- `./script/test_mrr_calculator.sh` passes.
- `./script/install_lock_overlay_agent.sh` works from a clean checkout.
- `./script/diagnose.sh` gives safe, actionable output.
- `./script/support_report.sh` gives a sanitized report without raw secrets or exact MRR.
- No Stripe keys, real MRR screenshots, local-only paths, or generated artifacts are committed.
- README and SECURITY docs clearly mention private macOS API risk.
- Release notes state whether the build is Apple Silicon-only or universal.
- GitHub issue templates warn against posting sensitive data.
- GitHub issue labels are synced from `.github/labels.yml` or at least dry-run with `./script/sync_github_labels.sh --dry-run`.

## Public Repo Gate

Run this before pushing release-readiness changes:

```sh
./script/check.sh
```

The gate checks shell syntax, focused MRR calculator/cache/settings tests, Stripe client tests, local app build/signing, required sanitized demo assets, obvious Stripe secret patterns, local-only paths, retired wallpaper artifacts, ignored private folders, required public docs, and signing readiness preflight.

For a quick non-build status summary during alpha operations:

```sh
./script/alpha_status.sh
```

This summarizes source state, private tracker presence, signing readiness, latest GitHub Actions status when available, and safe next actions. It is not a replacement for `./script/check.sh` before release or repo changes.

It also validates the GitHub label manifest and label sync parser. To apply labels after reviewing the plan:

```sh
./script/sync_github_labels.sh --dry-run
./script/sync_github_labels.sh --apply
```

It does not install the LaunchAgent. Install/reinstall remains a separate local manual test because it mutates the user's machine state.

For an internal package dry run only:

```sh
./script/package_private_beta.sh --adhoc
```

This creates an unnotarized private zip under `build/private-beta`. It is not a public installer.
The packaging script refuses to continue unless `./script/private_beta_readiness.sh --require-ready` passes first.

For Developer ID readiness:

```sh
./script/signing_preflight.sh
```

This checks whether Developer ID signing appears available without printing notary credentials.
