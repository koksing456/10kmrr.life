# First Tester Operator Checklist

Use this checklist before inviting the first real alpha tester. The goal is to
collect one clean install and Lock Screen compatibility signal without creating
fake tracker rows or collecting sensitive data.

Do not collect Stripe keys, exact private MRR, raw logs, raw Stripe responses,
customer or payment data, contact data, Stripe object IDs, or unsanitized
screenshots.

## Before Invite

- Run `./script/alpha.sh tracker`.
- Run `./script/alpha.sh first-tester` and read the full flow.
- Assign a stable private tester id such as `tester_001`.
- Keep the real identity and contact mapping outside this repo.
- Confirm non-sensitive setup facts:
  - macOS version, for example `15.5`.
  - CPU: `apple_silicon`, `intel`, or `unknown`.
  - Display setup: `built_in`, `external`, `multiple`, `clamshell`, or `unknown`.
  - Whether they use Stripe subscriptions.
- If the tester came from a public alpha request, map the public display setup
  answer using [alpha-request-template.md](./alpha-request-template.md).
- Preview the invite with `--dry-run`.
- Do not write the invite packet until the tester is real and approved.

## Invite Packet

Preview first:

```sh
./script/alpha.sh invite \
  --tester-id tester_001 \
  --macos-version 15.5 \
  --cpu apple_silicon \
  --display-setup built_in \
  --dry-run
```

Write only after the values are real:

```sh
./script/alpha.sh invite \
  --tester-id tester_001 \
  --macos-version 15.5 \
  --cpu apple_silicon \
  --display-setup built_in
```

The written invite lives under ignored `build/alpha-invites/`.

## Tester Success Criteria

Do not record `success` until all of these are true:

- The tester built or opened the app from the source alpha path.
- The tester configured a restricted read-only Stripe key in the macOS setup
  window, not in chat or a tracker row.
- Mock preview works.
- Real refresh works and the tester reports that MRR appeared.
- The LaunchAgent installed.
- The overlay is visible on the Mac Lock Screen.
- The overlay hides after unlock.
- No secret, raw Stripe response, exact MRR, customer/payment data, raw log, or
  unsanitized screenshot was shared.

When all success criteria are manually confirmed:

```sh
./script/alpha.sh success \
  --tester-id tester_001 \
  --macos-version 15.5 \
  --cpu apple_silicon \
  --display-setup built_in
```

## Partial Evidence

If setup, key, preview, install, and MRR refresh work but Lock Screen visibility
is not confirmed yet, record install evidence only:

```sh
./script/alpha.sh install \
  --tester-id tester_001 \
  --stage saw_mrr \
  --build-verify pass \
  --configured-key yes \
  --previewed yes \
  --installed yes \
  --saw-mrr yes \
  --diagnose-summary "PASS summary only" \
  --next-action lock_screen_check
```

If the Lock Screen check is separate from the success wrapper, record
compatibility directly:

```sh
./script/alpha.sh compatibility \
  --tester-id tester_001 \
  --macos-version 15.5 \
  --cpu apple_silicon \
  --display-setup built_in \
  --build-verify pass \
  --preview-glass private \
  --lock-screen-visible yes \
  --unlock-hides-overlay yes \
  --launchagent-stable yes \
  --result pass \
  --next-action day_7_follow_up
```

## Failure Or Friction

Ask for the sanitized support report only:

```sh
./script/alpha.sh support-report
```

Record the issue with a short non-sensitive summary:

```sh
./script/alpha.sh support \
  --tester-id tester_001 \
  --issue-type lock_screen \
  --result fail \
  --blocker "panel did not appear on Lock Screen" \
  --next-action "repair then retry diagnose"
```

Do not ask for raw logs unless a future support protocol explicitly allows a
sanitized excerpt.

## Day 7

After the tester has kept or removed the app for 7 days:

```sh
./script/alpha.sh day7 \
  --tester-id tester_001 \
  --retained-day-7 yes \
  --overall-pro-signal medium
```

Use `./script/alpha.sh weekly` after at least one real evidence row exists.
