# Install Friction Tracker

Track installation friction without collecting secrets or sensitive revenue data.

| Tester | macOS version | Build verify result | Install result | LaunchAgent generated | Preview works | Lock Screen visible | Keychain setup result | Error summary | Resolution | Follow-up needed |
|---|---|---|---|---|---|---|---|---|---|---|
| Example Founder | 15.x | pass/fail | pass/fail | yes/no | yes/no | yes/no | success/failed/not attempted | non-sensitive note | fixed/open | yes/no |

## Non-sensitive Evidence To Request

- Output of `./script/build_lock_overlay.sh --verify` with secrets removed.
- Whether `~/Library/LaunchAgents/life.10kmrr.mrr-lock-overlay.plist` exists.
- macOS version.
- A screenshot with mock or blurred MRR only.

## Do Not Request

- Stripe API keys.
- Full Stripe dashboard screenshots.
- Raw logs containing secrets.
- Customer/payment data.
- Real MRR screenshots unless explicitly sanitized by the tester.
