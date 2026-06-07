# Improvement Backlog

This backlog captures the next meaningful improvements after public-alpha readiness. It is ordered by impact on alpha learning, user trust, and product quality.

## P0: Alpha Must-Haves

These should happen before inviting more than a handful of testers.

- Add focused MRR calculation tests with sanitized Stripe fixtures. Done: covered by `./script/test_mrr_calculator.sh`.
- Add a clean install smoke checklist that covers build, setup, preview, install, diagnose, uninstall, and reinstall. Done: see [install-smoke-checklist.md](./install-smoke-checklist.md).
- Add a compatibility matrix for macOS version, Apple Silicon vs Intel, external displays, and whether private glass works. Done: see [compatibility-matrix.md](./compatibility-matrix.md).
- Split the 1200+ line Swift app into smaller files: model, Stripe client, MRR calculator, setup UI, overlay UI, SkyLight integration, and app delegate. Done: the largest Swift file is now under 200 lines.
- Add a safe support playbook for common failures: missing key, Stripe permission error, LaunchAgent not loaded, no lock-screen visibility, stale cache, and private API fallback. Done: see [support-playbook.md](./support-playbook.md).
- Replace mailto-only alpha intake with a simple gated form or private issue flow that explicitly blocks secrets and raw revenue data. Done: public GitHub issue form at `.github/ISSUE_TEMPLATE/alpha_request.yml`.

## P1: Product Experience

These make the app feel more like something founders will keep installed.

- Add a menu bar control for setup, preview, refresh now, diagnose, restart overlay, and uninstall guidance. Done: the running app exposes these actions from a menu bar item.
- Add manual refresh and visible "last refreshed" confidence inside setup. Done: setup can refresh MRR, update the local last-good cache, and show cache freshness without printing private values.
- Add size and horizontal position controls, not only vertical position. Done: setup exposes small/default/large panel sizes and left/center/right horizontal placement.
- Add multi-display preference: main display, cursor display, or all displays. Done: setup can target main display, cursor display, or every connected display.
- Add visual style presets: compact pill, full MRR panel, goal panel, focus panel, and ultra-minimal number-only style. Done: setup exposes full, compact, number-only, goal, and focus styles.
- Add MRR goal or milestone display as a Pro-signal experiment. Done: setup stores a local goal currency and amount for the goal panel.
- Add stale/error state copy that is useful on the lock screen without becoming noisy. Done: overlay shows setup/key/refresh/cached states without raw Stripe details.
- Add a first-run path that previews with mock MRR before asking for a real Stripe key. Done: setup and `./script/build_lock_overlay.sh --preview-mock` can launch a mock overlay before any Stripe key is configured.

## P1: Distribution And Trust

These reduce friction and make the source alpha easier to trust.

- Build a universal binary or document Apple Silicon-only support clearly. Done: current public docs state the source alpha build is Apple Silicon arm64 only.
- Add signed and notarized private beta packaging after compatibility data is stronger.
- Add an uninstall option that can optionally remove local cache and settings, not only the app and LaunchAgent. Done: `./script/uninstall_lock_overlay_agent.sh --local-data` and `--all`.
- Migrate the old Keychain service name to a cleaner `life.10kmrr.MRRLockScreenOverlay` service while preserving compatibility. Done: app and scripts prefer the current service and keep legacy fallback/delete coverage.
- Add release versioning and a visible app version/build commit in setup and diagnostics. Done: setup and `./script/diagnose.sh` show version and commit.
- Add a public privacy page that mirrors README and SECURITY in plain product language. Done: see [PRIVACY.md](../../PRIVACY.md).

## P1: Engineering Quality

These reduce maintenance risk.

- Convert Stripe pagination from recursion to an iterative loop with an explicit page cap. Done: `StripeMRRClient` caps each subscription status at 100 pages.
- Add timeout, retry, and backoff policy for Stripe requests. Done: Stripe requests have request/resource timeouts plus capped retries for transient network errors, 429, and 5xx responses.
- Add tests for annual, weekly, daily, quantity, discount, free, metered, multi-currency, active, and past-due MRR cases. Done: sanitized fixture now covers 8 focused calculator cases.
- Add a fixture format for sanitized Stripe subscription responses. Done: `tests/fixtures/mrr_calculator_cases.json` drives the focused calculator harness.
- Add CI checks for shell syntax, app build, public repo scan, and MRR calculator tests. Done: `.github/workflows/public-repo-check.yml` runs `./script/verify_public_repo.sh` on macOS.
- Add structured log events with no secrets and no MRR values by default. Done: local app logs event names and safe counters only.
- Add a debug mode that explains which private API path failed without dumping sensitive runtime data. Done: `--debug` / `--preview-debug` exposes safe private API failure labels.
- Add a sanitized support report for alpha testers. Done: `./script/support_report.sh` writes a redacted local report and keeps raw logs out by default.

## P2: Alpha Ops

These make learning from testers less manual.

- Turn the alpha user tracker into a small private spreadsheet or lightweight CRM workflow. Done: see [private-alpha-workflow.md](./private-alpha-workflow.md) and CSV templates under [templates](./templates).
- Add a 7-day follow-up cadence with retained/not-retained tags. Done: private alpha workflow defines Day 0/1/3/7 cadence and retention tagging.
- Track install funnel stages: requested, approved, built, configured key, previewed, installed, saw MRR, retained day 7. Done: workflow defines exact stage values and `install-funnel.csv`.
- Track Pro pull separately from general feedback. Done: `pro-interest.csv` and scorecard keep Pro signal separate.
- Add a rule that screenshots must use mock, blurred, or intentionally disclosed MRR. Done: screenshot rule is in private alpha workflow and demo checklist.
- Add a weekly alpha review checklist: support load, retention, setup failure rate, Pro signal, compatibility failures. Done: `weekly-review.csv` and workflow define the weekly review.

## P2: Landing And Demo

These improve conversion without changing the app.

- Add a short demo video using mock MRR only. Done: `./script/capture_demo_video.sh` writes `docs/demo/assets/demo-loop.mp4` and `demo-poster.png`.
- Add social-sized sanitized assets: square, wide, vertical, and GitHub social preview. Done: `./script/capture_demo_assets.sh` writes all four mock-only social assets.
- Make the landing page CTA point to the real gated intake once it exists. Done: the static page points to the public GitHub alpha request issue form.
- Add a concise "why I built this" section to the landing page, not only the README. Done.
- Add a stronger before/after demo: Stripe Dashboard requires checking; lock screen makes MRR ambient. Done: the static landing page includes a mock before/after section without real Stripe dashboard data.
- Add testimonials only after alpha users explicitly approve public quotes.

## P2: Repo And Community

These help if the repo becomes public-facing.

- Add `CONTRIBUTING.md` with security boundaries and no-secret contribution rules. Done.
- Add `CODE_OF_CONDUCT.md` only if community contribution becomes real.
- Add a `CHANGELOG.md` once alpha versions are tagged. Done: initialized for alpha source changes.
- Add GitHub labels for install, compatibility, security, MRR semantics, visual design, and alpha feedback. Done: see `.github/labels.yml`.
- Add release notes template that repeats private API and no-public-installer caveats. Done: see [docs/release/release-notes-template.md](../release/release-notes-template.md).

## Keep Avoiding

These are tempting but should stay out until alpha evidence demands them.

- Hosted Stripe key storage.
- Full analytics dashboard scope.
- Customer, invoice, or payment data collection.
- Public installer before signing, notarization, support, and rollback expectations are ready.
- Real MRR screenshots in public assets unless intentionally sanitized and approved.
