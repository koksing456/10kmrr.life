# Improvement Backlog

This backlog captures the next meaningful improvements after public-alpha readiness. It is ordered by impact on alpha learning, user trust, and product quality.

## P0: Alpha Must-Haves

These should happen before inviting more than a handful of testers.

- Add focused MRR calculation tests with sanitized Stripe fixtures.
- Add a clean install smoke checklist that covers build, setup, preview, install, diagnose, uninstall, and reinstall.
- Add a compatibility matrix for macOS version, Apple Silicon vs Intel, external displays, and whether private glass works.
- Split the 1200+ line Swift app into smaller files: model, Stripe client, MRR calculator, setup UI, overlay UI, SkyLight integration, and app delegate.
- Add a safe support playbook for common failures: missing key, Stripe permission error, LaunchAgent not loaded, no lock-screen visibility, stale cache, and private API fallback.
- Replace mailto-only alpha intake with a simple gated form or private issue flow that explicitly blocks secrets and raw revenue data.

## P1: Product Experience

These make the app feel more like something founders will keep installed.

- Add a menu bar control for setup, preview, refresh now, diagnose, restart overlay, and uninstall guidance.
- Add manual refresh and visible "last refreshed" confidence inside setup.
- Add size and horizontal position controls, not only vertical position.
- Add multi-display preference: main display, cursor display, or all displays.
- Add visual style presets: compact pill, full MRR panel, goal panel, and ultra-minimal number-only style.
- Add MRR goal or milestone display as a Pro-signal experiment.
- Add stale/error state copy that is useful on the lock screen without becoming noisy.
- Add a first-run path that previews with mock MRR before asking for a real Stripe key.

## P1: Distribution And Trust

These reduce friction and make the source alpha easier to trust.

- Build a universal binary or document Apple Silicon-only support clearly.
- Add signed and notarized private beta packaging after compatibility data is stronger.
- Add an uninstall option that can optionally remove local cache and settings, not only the app and LaunchAgent.
- Migrate the old Keychain service name to a cleaner `life.10kmrr.MRRLockScreenOverlay` service while preserving compatibility.
- Add release versioning and a visible app version/build commit in setup and diagnostics.
- Add a public privacy page that mirrors README and SECURITY in plain product language.

## P1: Engineering Quality

These reduce maintenance risk.

- Convert Stripe pagination from recursion to an iterative loop with an explicit page cap.
- Add timeout, retry, and backoff policy for Stripe requests.
- Add tests for annual, weekly, daily, quantity, discount, free, metered, multi-currency, active, and past-due MRR cases.
- Add a fixture format for sanitized Stripe subscription responses.
- Add CI checks for shell syntax, app build, public repo scan, and MRR calculator tests.
- Add structured log events with no secrets and no MRR values by default.
- Add a debug mode that explains which private API path failed without dumping sensitive runtime data.

## P2: Alpha Ops

These make learning from testers less manual.

- Turn the alpha user tracker into a small private spreadsheet or lightweight CRM workflow.
- Add a 7-day follow-up cadence with retained/not-retained tags.
- Track install funnel stages: requested, approved, built, configured key, previewed, installed, saw MRR, retained day 7.
- Track Pro pull separately from general feedback.
- Add a rule that screenshots must use mock, blurred, or intentionally disclosed MRR.
- Add a weekly alpha review checklist: support load, retention, setup failure rate, Pro signal, compatibility failures.

## P2: Landing And Demo

These improve conversion without changing the app.

- Add a short demo video using mock MRR only.
- Add social-sized sanitized assets: square, wide, vertical, and GitHub social preview.
- Make the landing page CTA point to the real gated intake once it exists.
- Add a concise "why I built this" section to the landing page, not only the README.
- Add a stronger before/after demo: Stripe Dashboard requires checking; lock screen makes MRR ambient.
- Add testimonials only after alpha users explicitly approve public quotes.

## P2: Repo And Community

These help if the repo becomes public-facing.

- Add `CONTRIBUTING.md` with security boundaries and no-secret contribution rules.
- Add `CODE_OF_CONDUCT.md` only if community contribution becomes real.
- Add a `CHANGELOG.md` once alpha versions are tagged.
- Add GitHub labels for install, compatibility, security, MRR semantics, visual design, and alpha feedback.
- Add release notes template that repeats private API and no-public-installer caveats.

## Keep Avoiding

These are tempting but should stay out until alpha evidence demands them.

- Hosted Stripe key storage.
- Full analytics dashboard scope.
- Customer, invoice, or payment data collection.
- Public installer before signing, notarization, support, and rollback expectations are ready.
- Real MRR screenshots in public assets unless intentionally sanitized and approved.
