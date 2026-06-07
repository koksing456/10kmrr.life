# Install Smoke Checklist

Use this checklist for each approved alpha tester or local release smoke. It verifies the app path without collecting Stripe keys, exact MRR, raw logs, or unsanitized screenshots.

## Ground Rules

- Use a restricted read-only Stripe key only.
- Do not paste the key into notes, issues, screenshots, or chat.
- Do not record exact MRR unless the tester intentionally shares a sanitized value.
- Record pass/warn/fail summaries, not raw logs.
- Run install steps only on a machine where the tester accepts the private macOS API caveat.

## Preflight

- [ ] Tester uses Stripe subscriptions.
- [ ] Tester uses macOS 14 or newer.
- [ ] Tester confirms Apple Silicon or Intel.
- [ ] Tester understands this is source alpha, not a notarized public installer.
- [ ] Tester has read [SECURITY.md](../../SECURITY.md).

Record:

- macOS version:
- CPU: Apple Silicon / Intel
- External displays: none / one / multiple
- Private glass accepted: yes / no

## Build

Run:

```sh
./script/build_lock_overlay.sh --verify
```

Record:

- Build result: pass / warn / fail
- Build version/commit:
- Non-sensitive failure summary:

## Setup

Run:

```sh
./script/build_lock_overlay.sh --setup
```

In the setup window:

- [ ] Use Preview Mock before adding a real Stripe key.
- [ ] Save restricted Stripe key.
- [ ] Test Stripe access.
- [ ] Save refresh and position settings.

Record:

- Mock preview from setup: pass / warn / fail
- Key setup result: pass / warn / fail
- Stripe test result: pass / warn / fail
- Do not record the key or exact MRR.

## Preview

Run:

```sh
./script/build_lock_overlay.sh --preview-private-glass
```

Record:

- Preview visible: yes / no
- Private glass visible: yes / no / fallback
- Panel legible: yes / no
- Position acceptable: yes / no

Stop preview:

```sh
pkill -f "MRRLockScreenOverlay .*--preview"
```

## Install

Run:

```sh
./script/install_lock_overlay_agent.sh
```

Record:

- App installed: yes / no
- LaunchAgent loaded: yes / no
- Setup opened automatically: yes / no / not needed

## Diagnose

Run:

```sh
./script/diagnose.sh
```

Record only pass/warn/fail lines and non-sensitive summaries:

- Build artifact:
- Installed app:
- LaunchAgent plist:
- LaunchAgent loaded:
- Keychain presence:
- Cache presence:
- Settings:

## Lock Screen Check

Lock the Mac and verify:

- [ ] Overlay appears on the Lock Screen.
- [ ] MRR value appears or cached/stale state is clear.
- [ ] Panel does not block the password/avatar area.
- [ ] Unlock hides the overlay.

Record:

- Lock Screen visible: yes / no
- Display where visible:
- Non-sensitive issue summary:

## Uninstall

Run:

```sh
./script/uninstall_lock_overlay_agent.sh
```

Then run:

```sh
./script/diagnose.sh
```

Record:

- App removed: yes / no
- LaunchAgent removed: yes / no
- Process stopped: yes / no

Optional local data reset:

```sh
./script/uninstall_lock_overlay_agent.sh --local-data
```

Optional full reset, including the stored Stripe key:

```sh
./script/uninstall_lock_overlay_agent.sh --all
```

Record:

- Local cache/settings removed: yes / no / not requested
- Keychain key removed: yes / no / not requested

## Reinstall

Run:

```sh
./script/repair_lock_overlay_agent.sh
./script/diagnose.sh
```

Record:

- Reinstall result: pass / warn / fail
- LaunchAgent loaded after reinstall: yes / no
- Stripe key still present in Keychain: yes / no
- Cache still present: yes / no
- Display settings still present: yes / no

## Outcome

Choose one:

- pass_ready_for_day_7
- pass_with_minor_friction
- blocked_install
- blocked_key_setup
- blocked_private_api
- blocked_visual_quality
- blocked_security_concern

Next action:
