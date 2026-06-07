# Alpha Invite Template

Use this for approved gated alpha testers. Keep it short and do not ask for sensitive data.

Generate the current invite for an approved tester with:

```sh
./script/alpha.sh invite --tester-id tester_001 --macos-version 15.5 --cpu apple_silicon --display-setup built_in --dry-run
```

## Message

Thanks for trying 10kmrr.life.

This is a source alpha, not a notarized public Mac app yet. It depends on private macOS behavior for Lock Screen placement, so compatibility is part of what we are testing.

Before setup:

- Read `SECURITY.md`.
- Use a restricted read-only Stripe key, not a full-access secret key.
- Do not send Stripe keys, exact MRR, raw Stripe responses, raw logs, customer/payment data, or unsanitized screenshots.

Setup path:

```sh
./script/alpha.sh start --tester-id tester_001
```

Replace `tester_001` with the private stable tester id assigned outside this public repo. This opens the setup window and mock preview before installing. Enter the restricted key only in the macOS setup window, never in Terminal or support messages.

If something fails:

```sh
./script/alpha.sh support-report
```

Share only the sanitized support report summary or the failing section name. Use `--include-logs` only after checking the redacted excerpts do not contain sensitive output.

After setup works, send back only this safe reply format:

- MRR visible in the setup window: yes/no
- Lock Screen panel appears: yes/no
- Overlay hides after unlock: yes/no
- Display setup: built_in/external/multiple/clamshell
- macOS version: 15.x or unknown
- Blocker, if any: key/setup/refresh/lock_screen/unlock/launchagent/other/none
- Pro interest after first use: low/medium/high/unknown

Do not include exact MRR, Stripe keys, raw Stripe responses, raw logs, customer/payment data, contact data, or unsanitized screenshots.

Day 7 question:

Would you keep MRR on your Lock Screen after the novelty wears off?
