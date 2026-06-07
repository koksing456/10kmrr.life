# Compatibility Matrix

Use this matrix to track private macOS API behavior across alpha machines. Do not include Stripe keys, exact MRR, raw logs, or unsanitized screenshots.

## Matrix

| Tester | macOS version | CPU | Display setup | Build verify | Preview glass | Lock Screen visible | Unlock hides overlay | LaunchAgent stable | Result | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| Example | 15.x | Apple Silicon / Intel | built-in / external / multi | pass/fail | private/fallback/fail | yes/no | yes/no | yes/no | pass/warn/fail | non-sensitive summary |

## Fields

- macOS version: exact version if the tester is comfortable sharing it.
- CPU: Apple Silicon or Intel.
- Display setup: built-in only, clamshell, one external, multiple external, or unknown.
- Build verify: result of `./script/build_lock_overlay.sh --verify`.
- Preview glass: whether `./script/build_lock_overlay.sh --preview-private-glass` shows private glass, fallback material, or fails.
- Lock Screen visible: whether the installed overlay appears after locking.
- Unlock hides overlay: whether the overlay disappears after unlock.
- LaunchAgent stable: whether `./script/diagnose.sh` reports the LaunchAgent loaded after install/restart.
- Result: pass, warn, or fail.

## Compatibility Thresholds

Pause wider alpha expansion if:

- The overlay fails on a common current macOS version.
- Private glass fails repeatedly and fallback does not look acceptable.
- External display setups cause repeated bad placement.
- Unlock does not reliably hide the overlay.
- LaunchAgent stability fails for more than 30 percent of testers.

## Safe Evidence

Safe to request:

- macOS version.
- CPU type.
- Display setup category.
- Pass/warn/fail output from `./script/diagnose.sh`.
- Sanitized screenshot with mock, blurred, or intentionally disclosed MRR.

Do not request:

- Stripe keys.
- Exact private MRR.
- Raw Stripe responses.
- Customer, invoice, payment, or subscription data.
- Raw logs unless they have been reviewed and sanitized first.
