# Release Notes Template

Use this template for alpha tags or private tester builds.

## Version

- Version:
- Commit:
- Date:
- Distribution: source alpha / private signed build / notarized beta

## Summary

Short description of what changed.

## User-Visible Changes

- Change:
- Change:

## Security And Privacy Notes

- No Stripe keys are included.
- No real MRR screenshots are included unless explicitly sanitized and approved.
- No customer, invoice, payment, subscription, or raw Stripe response data is included.
- The app remains local-first unless explicitly stated otherwise.

## Compatibility Notes

- macOS versions tested:
- Apple Silicon tested: yes / no
- Intel tested: yes / no / build available but Lock Screen behavior unverified
- Binary architecture: Apple Silicon arm64 / universal / other
- External display setups tested:
- Private glass behavior:
- Lock Screen visibility:

## Verification

Required:

```sh
./script/verify_public_repo.sh
```

Optional local install smoke:

```sh
./script/install_lock_overlay_agent.sh
./script/diagnose.sh
./script/uninstall_lock_overlay_agent.sh
```

## Known Issues

- Private macOS behavior may break on future macOS releases.
- This is not a public notarized installer unless the distribution field says so.
