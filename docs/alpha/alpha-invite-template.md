# Alpha Invite Template

Use this for approved gated alpha testers. Keep it short and do not ask for sensitive data.

## Message

Thanks for trying 10kmrr.life.

This is a source alpha, not a notarized public Mac app yet. It depends on private macOS behavior for Lock Screen placement, so compatibility is part of what we are testing.

Before setup:

- Read `SECURITY.md`.
- Use a restricted read-only Stripe key, not a full-access secret key.
- Do not send Stripe keys, exact MRR, raw Stripe responses, raw logs, customer/payment data, or unsanitized screenshots.

Setup path:

```sh
./script/build_lock_overlay.sh --verify
./script/build_lock_overlay.sh --setup
./script/build_lock_overlay.sh --preview-mock
./script/build_lock_overlay.sh --preview-private-glass
./script/install_lock_overlay_agent.sh
```

If something fails:

```sh
./script/support_report.sh
```

Share only the sanitized support report summary or the failing section name. Use `--include-logs` only after checking the logs do not contain sensitive output.

Day 7 question:

Would you keep MRR on your Lock Screen after the novelty wears off?
