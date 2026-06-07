# Release Strategy

10kmrr.life is public-alpha source code, not a public binary distribution yet.

## Current Release Boundary

- Public repo: yes.
- Public downloadable installer: no.
- Gated alpha install from source: yes.
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

## Release Checklist

- `./script/build_lock_overlay.sh --verify` passes.
- `./script/install_lock_overlay_agent.sh` works from a clean checkout.
- `./script/diagnose.sh` gives safe, actionable output.
- No Stripe keys, real MRR screenshots, local-only paths, or generated artifacts are committed.
- README and SECURITY docs clearly mention private macOS API risk.
- GitHub issue templates warn against posting sensitive data.
