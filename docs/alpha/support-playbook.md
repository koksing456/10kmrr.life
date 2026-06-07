# Safe Support Playbook

Use this playbook for alpha support without collecting secrets or private revenue data.

## Support Boundary

Ask for:

- macOS version.
- Apple Silicon or Intel.
- Display setup category.
- App version and commit from setup or `./script/diagnose.sh`.
- The command that failed.
- Pass/warn/fail summaries from safe scripts.
- Non-sensitive error summaries.

Never ask for:

- Stripe API keys.
- Exact private MRR.
- Raw Stripe API responses.
- Full Stripe dashboard screenshots.
- Customer names, emails, invoices, payments, or subscriptions.
- Unsanitized screenshots with real revenue.
- Raw logs unless reviewed and sanitized first.

## First Triage

If the setup window opens, ask the tester to use the Install & support card:

- Click `Run Diagnose`.
- Share only the PASS/WARN summary, not screenshots with real MRR.
- Use `Generate Report` if a sanitized support report is needed, then review the opened report before sharing.

Ask the tester to run:

```sh
./script/support_report.sh
```

If they cannot generate the support report, ask them to run:

```sh
./script/diagnose.sh
```

The support report redacts local paths, Stripe-key-like strings, Stripe object IDs, email-like contact data, webhook secrets, and obvious money amounts. It includes suggested next steps for setup, repair, and full readiness checks. It does not include log excerpts by default. If `--include-logs` is used, the excerpts are still redacted and must be reviewed before sharing.

If the issue is source/build related, ask for:

```sh
./script/check.sh
```

They should paste only the pass/warn/fail summary and the failing section name.

## Missing Stripe Key

Symptom:

- Diagnose says Stripe key is missing.
- Overlay shows setup or attention copy.

Action:

```sh
./script/build_lock_overlay.sh --setup
```

Ask them to save a restricted read-only key and test Stripe access. Do not ask them to paste the key.

## Stripe Permission Error

Symptom:

- Setup test or overlay says Stripe key cannot read required Billing resources.

Action:

- Confirm they used a restricted key, not `sk_`.
- Confirm the key can read subscriptions and prices.
- Ask them to rotate/delete any key they accidentally shared.

Safe record:

- Permission issue: yes / no
- Resolved by key permission change: yes / no

## LaunchAgent Not Loaded

Symptom:

- Diagnose says LaunchAgent is not loaded.
- Install script warns that the LaunchAgent did not report as loaded.
- Diagnose says the LaunchAgent executable, private glass argument, or log paths drifted.

Action:

```sh
./script/repair_lock_overlay_agent.sh
./script/diagnose.sh
```

The repair script rebuilds the app and reinstalls the LaunchAgent while preserving the Stripe Keychain entry, local cache, and display settings.

If still failing, record:

- macOS version.
- Whether the plist exists.
- Non-sensitive launchctl state line if available.

Do not ask for full raw launchctl output unless sanitized.

## Overlay Not Visible On Lock Screen

Symptom:

- Preview works, install works, but Lock Screen does not show the panel.

Action:

- Confirm they installed with `./script/install_lock_overlay_agent.sh`.
- Confirm `./script/diagnose.sh` reports LaunchAgent loaded.
- Confirm macOS version and display setup.
- Ask whether preview private glass works.

Record this in [compatibility-matrix.md](./compatibility-matrix.md).

## Preview Works But Looks Wrong

Symptom:

- Panel appears but position, size, or contrast is poor.

Action:

- Ask them to adjust position in setup.
- Ask for a sanitized screenshot only if MRR is mock, blurred, or intentionally disclosed.
- Track the issue as visual quality or display placement, not as core MRR failure.

## Stale Cache Or Refresh Failure

Symptom:

- Overlay shows cached/stale state.
- Diagnose says cache exists but refresh is failing.

Action:

- Ask whether internet is available.
- Ask whether setup Stripe test passes.
- Ask for non-sensitive error summary only.

Do not ask for cached MRR value or raw Stripe response.

## Private API Fallback

Symptom:

- Private glass unavailable.
- Overlay uses fallback material.
- Lock Screen placement is inconsistent.

Action:

- Record macOS version and CPU.
- Record whether fallback is visually acceptable.
- Pause wider expansion if this repeats on common macOS versions.

## Uninstall Or Reset

Remove app and LaunchAgent:

```sh
./script/uninstall_lock_overlay_agent.sh
```

Repair app and LaunchAgent while keeping Keychain, cache, and display settings:

```sh
./script/repair_lock_overlay_agent.sh
```

Remove app, LaunchAgent, local cache, and display settings:

```sh
./script/uninstall_lock_overlay_agent.sh --local-data
```

Remove stored Stripe key:

```sh
./script/configure_stripe_key.sh --delete
```

Full local reset, including the stored Stripe key:

```sh
./script/uninstall_lock_overlay_agent.sh --all
```

Only use `--all` when the tester explicitly wants the Keychain key removed.
