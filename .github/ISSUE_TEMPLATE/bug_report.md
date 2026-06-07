---
name: Bug report
about: Report a non-sensitive local alpha issue
title: "[Bug] "
labels: bug
assignees: ""
---

## Before You Post

Do not paste Stripe keys, exact MRR, email/contact data, raw Stripe responses, raw logs, customer data, payment data, or unsanitized revenue screenshots.

## What Happened

Describe the bug.

## Expected Behavior

What did you expect to happen?

## Safe Diagnostics

Prefer:

```sh
./script/alpha.sh support-report
```

Paste only the sanitized report sections relevant to the issue. Do not use `--include-logs` unless you have reviewed the redacted excerpts for sensitive output.

If you cannot generate a support report, run:

```sh
./script/diagnose.sh
```

Paste only the pass/warn/fail lines. Do not paste secrets or raw logs.

If this is a source/build issue, also run:

```sh
./script/alpha.sh check
```

Paste only the failing section name and non-sensitive summary. The signing preflight may warn that Developer ID signing is not ready; that is expected for source alpha unless the issue is about private beta packaging.

If diagnose reports LaunchAgent executable, private glass argument, or log-path drift, try:

```sh
./script/repair_lock_overlay_agent.sh --dry-run
./script/repair_lock_overlay_agent.sh
./script/diagnose.sh
```

The repair script preserves the Stripe key, local cache, and display settings.

## Environment

- macOS version:
- App commit or build date:
- Installed with `./script/install_lock_overlay_agent.sh`: yes / no
- Repaired with `./script/repair_lock_overlay_agent.sh`: yes / no / not needed
- Preview works with `./script/build_lock_overlay.sh --preview-private-glass`: yes / no / not tested
