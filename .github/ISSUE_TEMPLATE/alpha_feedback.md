---
name: Alpha feedback
about: Share non-sensitive feedback from trying the 10kmrr.life alpha
title: "[Alpha] "
labels: alpha-feedback
assignees: ""
---

## Before You Post

Do not include Stripe keys, real customer data, payment data, raw Stripe logs, or unsanitized screenshots with real MRR.

## Environment

- macOS version:
- Apple Silicon or Intel:
- Install status: not started / built / installed / uninstalled
- Key setup status: not configured / configured / unsure
- Repair tried if install drifted: yes / no / not needed

## Result

- Did the overlay appear on the Lock Screen?
- Did the first MRR value appear?
- Did it still feel useful after using it?
- If you ran `./script/repair_lock_overlay_agent.sh`, did it preserve the key/cache/settings?

## Feedback

What felt good, confusing, or unnecessary?

## Blocker

If blocked, what was the first step that failed?

If a local script failed, run `./script/support_report.sh` and paste only the sanitized sections relevant to the issue. Do not use `--include-logs` unless they have been reviewed and sanitized.

If a build or source verification failed, run `./script/check.sh` and paste only the failing section name plus a non-sensitive summary.
