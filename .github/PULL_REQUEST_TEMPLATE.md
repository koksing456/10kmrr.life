## Summary

What changed?

## Verification

- [ ] I ran `./script/alpha.sh check`.
- [ ] If this touches install behavior, I reviewed `docs/alpha/install-smoke-checklist.md`.
- [ ] If this touches packaging or release docs, I reviewed `docs/release/private-beta-packaging-checklist.md`.

## Security Boundary

- [ ] I did not commit Stripe keys, Stripe object IDs, exact private MRR, raw Stripe responses, raw logs, customer/payment data, or unsanitized revenue screenshots.
- [ ] Any screenshots or demo assets use mock, blurred, or explicitly sanitized MRR.
- [ ] Any support or diagnostic output is sanitized.

## Scope Boundary

- [ ] This keeps 10kmrr.life focused on Stripe MRR on the Mac Lock Screen.
- [ ] This does not add hosted Stripe key storage or full analytics dashboard scope.
