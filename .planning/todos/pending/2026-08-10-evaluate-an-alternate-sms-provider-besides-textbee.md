---
created: 2026-08-10T22:00:35.276Z
title: Evaluate an alternate SMS provider besides TextBee
area: backend
files:
  - backend/src/SafePath.Infrastructure/Sms/TextBeeSmsGateway.cs
  - backend/src/SafePath.Infrastructure/Sms/TextBeeOptions.cs
  - backend/src/SafePath.Infrastructure/Sms/TextBeeWebhookSignatureValidator.cs
  - docs/EXTERNAL-SETUP.md
---

## Problem

The SOS emergency-contact SMS fallback channel was just migrated from Twilio to TextBee
(quick task 260810-vcf, commits 2bc4367/b3f5ebe/047b1b1/8144421 on `phase/04-geofencing`),
switched to a free, self-hosted-Android-gateway model to avoid Twilio's cost and Egypt-specific
A2P filtering/pricing (Twilio charges ~$0.40/segment to Egypt without a registered Alpha Sender
ID, vs. ~$0.01 domestic-registered — see conversation 2026-08-10).

The user tested TextBee themselves and, independent of that result, flagged wanting to evaluate
a different SMS provider for the future. The known reliability gap driving this: TextBee routes
SMS through one physical Android phone running the TextBee app — if that phone loses power,
network, or the app stops running, SOS SMS sends silently fail to reach anyone. TextBee also has
no delivery-status webhook, so `TextBeeWebhookSignatureValidator.IsValid` is a permanent
unconditional `false` and every send is recorded as `Queued` (sent, unconfirmed) forever, never
`Delivered` — a real observability regression versus Twilio's webhook-confirmed `Delivered`
status, for the one channel (SOS) where "did it actually arrive" matters most.

Brevo was raised as a middle-ground candidate during the same conversation (carrier-routed,
pay-as-you-go like Twilio, no single-phone dependency) but its SMS-specific delivery-webhook
support was never confirmed (its docs page 403'd during research) before the user pivoted straight
to TextBee.

## Solution

TBD — no direction locked yet. Candidates surfaced in prior research to start from:
- Brevo transactional SMS (carrier-routed, pay-as-you-go; confirm delivery-webhook support before
  committing — see `help.brevo.com` SMS docs, blocked by a 403 during automated fetch on
  2026-08-10, needs a logged-in or manual check).
- Twilio with a registered Egypt Alphanumeric Sender ID (keeps the already-built webhook-confirmed
  `Delivered` status; the earlier cost objection was specifically *unregistered* Egypt traffic,
  which registration fixes — see `support.twilio.com` Egypt Alpha Sender ID registration docs).
- Any other carrier-routed provider with a genuine delivery-status callback, evaluated primarily
  against: (1) does it have a delivery-status webhook (TextBee's key gap), (2) Egypt/target-market
  pricing and A2P filtering behavior, (3) whether it fits behind the existing unchanged
  `ISmsGateway`/`ISmsWebhookSignatureValidator` seam with no interface changes, same pattern as
  the Twilio->TextBee migration.
