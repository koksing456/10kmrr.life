# Open Source Readiness

## Recommended Model

Open-source trust surface + gated alpha install.

Open source is used to reduce Stripe key and local-data trust concerns. It should not mean immediately publishing a public installer or exposing every experimental artifact.

## What Can Be Opened

Good candidates:

- `MRRLockScreenOverlay/`
- `script/build_lock_overlay.sh`
- `script/install_lock_overlay_agent.sh`
- `script/uninstall_lock_overlay_agent.sh`
- `ThirdParty/SkyLightWindow/LICENSE`
- `README.md`
- `docs/mvp/`
- `opc-doc/` only if strategic docs are intended to be public

## What Needs Review Before Opening

Review carefully:

- `Atoll/` cloned reference repo.
- `build/` artifacts and logs.
- Local paths in docs and scripts.
- Any screenshots or generated images with real MRR.
- Any logs that may include usernames, system paths, or sensitive runtime details.
- Keychain service names and install instructions for clarity.

## What Should Not Be Public

Do not publish:

- Stripe API keys.
- Real customer or payment data.
- Real revenue screenshots unless sanitized.
- Personal private notes not intended for users.
- Build logs containing sensitive data.
- A public installer before signing / notarization / support expectations are clear.

## Suggested Repo Cleanup Before Public GitHub

- Remove `build/` from public repo and ensure `.gitignore` covers it.
- Keep `Atoll/` out of the public repo. Prefer referencing Atoll as inspiration / dependency research rather than vendoring the clone.
- Keep docs focused on user-facing alpha, security, compatibility, install, and uninstall.
- Add a clear license.
- Add security disclosure / support instructions.
- Add a compatibility caveat for private macOS APIs.

## Open Core / Paid Convenience Boundary

Open-source core:

- Local MRR calculation.
- Keychain storage.
- Lock-screen overlay source.
- Install / verify scripts.
- Security model.

Paid convenience:

- Signed / notarized installer.
- Auto-update.
- Premium visual designs.
- Compatibility maintenance.
- Priority support.
- Future packaged signals.

## Public README Requirements

The public README should answer:

- What does this app do?
- Who is it for?
- Is it a full analytics dashboard?
- Where does the Stripe key live?
- Does it upload revenue data?
- What macOS versions are supported?
- Why is installation gated during alpha?
- How do I request alpha access?

## Go / No-Go Checklist

- [ ] No secrets in repo.
- [ ] No real MRR screenshots.
- [ ] `build/` ignored and not published.
- [ ] Atoll clone removed or clearly excluded.
- [ ] License chosen.
- [ ] Security notes visible.
- [ ] Compatibility caveat visible.
- [ ] Alpha install is gated.
- [ ] Public download is not linked until distribution is ready.
