# Alpha Install Guide

This guide is for gated private alpha testers.

## Configure Stripe Key

Preferred guided path:

```sh
./script/start_alpha.sh
```

The guided flow builds the app, opens setup, launches a mock preview, waits for you to save a restricted key in the macOS setup window, confirms a Keychain key and last-good MRR cache exist without printing either value, then installs the LaunchAgent and runs diagnose. If setup is not ready yet, it pauses before LaunchAgent changes.

Manual setup path:

```sh
./script/build_lock_overlay.sh --setup
```

The setup window stores a restricted read-only Stripe key in macOS Keychain and can test Stripe access without printing the key.

The same setup window keeps first-run setup focused and places advanced controls behind a disclosure:

- Refresh interval.
- Vertical overlay position.
- Horizontal overlay position.
- Panel size, display targeting, visual style, and optional local MRR goal.

Settings are stored locally and apply the next time the overlay starts.

Compatibility alias:

```sh
./script/open_setup.sh
```

Terminal setup path:

```sh
./script/configure_stripe_key.sh
```

## Before You Start

You need:

- A Mac running macOS 14 or newer.
- A Stripe account with subscriptions.
- A restricted read-only Stripe API key that can read subscriptions and prices.

Do not share your secret key in chat, email, screenshots, or support messages.

## What The Alpha Does

10kmrr.life reads Stripe subscription data locally and displays MRR on your Mac Lock Screen.

It stores:

- Stripe API key in macOS Keychain.
- Last-good MRR cache in local user defaults.

It does not store your Stripe API key in this repo, in shell scripts, or in public files.

## Install

From the project folder:

```sh
./script/install_lock_overlay_agent.sh
```

Use this direct install command after setup is ready. If no Stripe key is configured yet, the installer opens the setup window automatically.

This builds the app, installs it into:

```text
~/Library/Application Support/10kmrr.life/MRRLockScreenOverlay.app
```

and loads this LaunchAgent:

```text
~/Library/LaunchAgents/life.10kmrr.mrr-lock-overlay.plist
```

## Preview

To preview without locking your Mac:

```sh
./script/build_lock_overlay.sh --preview-private-glass
```

## Verify

```sh
./script/build_lock_overlay.sh --verify
```

## Logs

```sh
./script/build_lock_overlay.sh --logs
```

## Uninstall

```sh
./script/uninstall_lock_overlay_agent.sh
```

## Alpha Feedback Questions

After setup:

- Did you successfully see your MRR?
- Did the Stripe key setup feel acceptable?
- Would you keep this on for 7 days?
- What would make this worth paying for?
- Did the private macOS API caveat change your willingness to use it?
