---
name: Alpha feedback
about: Share non-sensitive feedback from trying the 10kmrr.life alpha
title: "[Alpha] "
labels: alpha-feedback
assignees: ""
---

## Before You Post

Do not include Stripe keys, Stripe object IDs, exact MRR, email/contact data, customer data, payment data, raw Stripe responses, raw logs, or unsanitized revenue screenshots.

## Environment

- macOS version:
- Apple Silicon or Intel:
- Display setup: built_in / external / multiple / clamshell / unknown
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

If a local script failed, run `./script/alpha.sh support-report` and paste only the sanitized sections relevant to the issue. Do not use `--include-logs` unless the redacted excerpts have been reviewed and sanitized.

If a build or source verification failed, run `./script/alpha.sh check` and paste only the failing section name plus a non-sensitive summary.
