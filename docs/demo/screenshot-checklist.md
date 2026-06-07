# Screenshot And Demo Checklist

Use only mock or sanitized MRR values in public demo assets.

## Required Checks

- [ ] No real Stripe API keys visible.
- [ ] No Stripe dashboard visible.
- [ ] No customer names, emails, payments, or subscriptions visible.
- [ ] MRR value is mock or explicitly sanitized.
- [ ] Menu bar or desktop does not reveal private information.
- [ ] Lock Screen panel is legible at common social preview sizes.
- [ ] Private macOS API caveat is not contradicted by the surrounding copy.
- [ ] Demo does not imply this is a fully public notarized release.

## Generate Sanitized Landing Assets

Run:

```sh
./script/capture_demo_assets.sh
```

This captures the static landing page with mock MRR only:

- `docs/demo/assets/landing-hero.png`
- `docs/demo/assets/landing-desktop.png`
- `docs/demo/assets/landing-mobile.png`

The script checks for horizontal overflow on mobile and verifies the mock demo label is present.

## Recommended Mock Values

Use values that are clearly illustrative:

- `US$351.93`
- `US$1,024.00`
- `US$10,000.00`

Do not use a real current MRR unless it has been intentionally sanitized and approved for public display.

## Demo Variants

- Lock Screen close-up.
- Full desktop / Lock Screen context.
- Before: Stripe Dashboard hidden behind clicks.
- After: MRR visible on Lock Screen.

## Caption Boundary

Allowed:

- "Your Stripe MRR, on your Mac Lock Screen."
- "Local-first alpha for Mac-first Stripe founders."
- "Gated alpha. No public installer yet."

Avoid:

- "Works on every Mac."
- "Fully stable public release."
- "Replaces your analytics dashboard."
