---
name: Bug report
about: Report a non-sensitive local alpha issue
title: "[Bug] "
labels: bug
assignees: ""
---

## Before You Post

Do not paste Stripe keys, raw Stripe responses, raw logs, customer data, payment data, or unsanitized screenshots with real MRR.

## What Happened

Describe the bug.

## Expected Behavior

What did you expect to happen?

## Safe Diagnostics

Run:

```sh
./script/diagnose.sh
```

Paste only the pass/warn/fail lines. Do not paste secrets or raw logs.

If this is a source/build issue, also run:

```sh
./script/verify_public_repo.sh
```

Paste only the failing section name and non-sensitive summary.

## Environment

- macOS version:
- App commit or build date:
- Installed with `./script/install_lock_overlay_agent.sh`: yes / no
- Preview works with `./script/build_lock_overlay.sh --preview-private-glass`: yes / no / not tested
