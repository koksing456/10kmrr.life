# 7-Day Follow-Up Template

Use this after an alpha tester has had the overlay installed for about 7 days.

## Follow-Up Questions

1. Is the overlay still installed?
2. Did you notice your MRR more often this week?
3. Did seeing MRR on the Lock Screen feel motivating, distracting, neutral, or unnecessary?
4. Did you trust the local Keychain / restricted Stripe key setup after using it?
5. Did anything break or feel fragile?
6. What would make this worth paying for?
7. Which Pro upgrade would matter most?
8. Would you recommend this to another Stripe founder?
9. Would you rather pay one-time, monthly, annual, or lifetime?

## Outcome Tag

Choose one:

- retained_high_signal
- retained_low_signal
- removed_due_to_trust
- removed_due_to_install_friction
- removed_due_to_low_value
- needs_follow_up

## Safe Recorder

After the follow-up, record only the safe retention and Pro signal summary:

```sh
./script/alpha.sh day7 \
  --tester-id tester_001 \
  --retained-day-7 yes \
  --overall-pro-signal medium \
  --notes "kept it on for day 7"
```

## Notes Boundary

Do not record exact private MRR. If revenue context is useful, record only a broad band, such as under_1k, 1k_to_10k, 10k_to_100k, or 100k_plus, or refer to mock/sanitized display assets.

If the tester gives feedback that may become a public quote, use [testimonial-approval-template.md](./testimonial-approval-template.md). Do not publish informal follow-up replies as testimonials.
