# Signing And Notarization Setup

Use this only for private beta packaging after alpha evidence is strong enough.
It does not replace [private-beta-packaging-checklist.md](./private-beta-packaging-checklist.md).

Do not publish a public installer from these steps.

## Current Gate

Check the machine:

```sh
./script/alpha.sh signing
```

Strict readiness must pass before a signed private beta package:

```sh
./script/alpha.sh signing --require-ready
```

The command must not print notary credentials, private profile names, Stripe
keys, exact MRR, customer data, payment data, or raw Stripe responses.

## Required Local Inputs

Keep these private. Do not commit them.

- Apple Developer account with a Developer ID Application certificate.
- Developer ID Application certificate installed in this Mac Keychain.
- Notary credentials stored in the local Keychain through `notarytool`.
- Private shell variable `TENKMRR_NOTARY_PROFILE` set only for signing runs.

Confirm Developer ID appears locally:

```sh
security find-identity -v -p codesigning
```

Apple Development identities are not enough for Developer ID notarized
distribution.

## Store Notary Credentials

Store credentials privately with Apple tooling:

```sh
xcrun notarytool store-credentials "<private-profile-name>"
```

Then set the profile name only in your shell:

```sh
export TENKMRR_NOTARY_PROFILE="<private-profile-name>"
```

Do not commit the profile name if it identifies a private Apple account or team.
Do not paste notary credentials into docs, issues, support reports, screenshots,
or alpha tracker rows.

## Package After Evidence Is Ready

First confirm alpha/private beta evidence:

```sh
./script/alpha.sh beta-ready --require-ready
```

Then create the private signed package:

```sh
./script/alpha.sh package --signed
```

The package script re-signs the app with Developer ID, submits a zip to
notarytool, staples the app, validates the notarization ticket, and writes a
private beta zip under `build/private-beta`.

## If Signing Still Fails

Use this order:

1. Run `./script/alpha.sh signing`.
2. Install or create the Developer ID Application certificate if missing.
3. Store notary credentials with `xcrun notarytool store-credentials`.
4. Export `TENKMRR_NOTARY_PROFILE` in the current shell only.
5. Re-run `./script/alpha.sh signing --require-ready`.
6. Run `./script/alpha.sh beta-ready --require-ready`.
7. Run `./script/alpha.sh package --signed`.

Do not bypass a failing strict readiness check with `--adhoc` for a tester
package. `--adhoc` is only for explicit internal dry runs and remains
unnotarized.
