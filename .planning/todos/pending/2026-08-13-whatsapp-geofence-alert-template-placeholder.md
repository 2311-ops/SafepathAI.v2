---
created: 2026-08-12T21:58:40.078Z
updated: 2026-08-12T21:58:40.078Z
title: Reserve WhatsApp Utility template for future geofence alerts
area: backend/geofencing
files:
  - docs/EXTERNAL-SETUP.md
  - backend/src/SafePath.Infrastructure/Sms/WhatsAppOptions.cs
  - backend/src/SafePath.Infrastructure/Sms/WhatsAppSmsGateway.cs
  - .planning/phases/04-geofencing/04-04-PLAN.md
status: pending
---

## Problem

SafePath has moved the emergency fallback messaging path from TextBee to the WhatsApp Business
Cloud API. Future geofencing alert work will need a WhatsApp template name, but that name should
not be guessed later or accidentally share the SOS template/configuration.

User-provided placeholder: `geofence_alert`.

User-provided placeholder shape:

- `{{1}}` = member name
- `{{2}}` = entered / exited
- `{{3}}` = zone name
- `{{4}}` = time

## Solution

When geofence alert messaging is implemented, create or reference a separate Utility-category
WhatsApp template named `geofence_alert`.

Do not reuse the existing SOS `sos_alert` template. Do not use the Authentication-category
`otp_verification` template. Do not overload the existing `WhatsApp__TemplateName` key unless the
future implementation deliberately supports only one active template; if SOS and geofence sends
coexist, add a separate geofence-specific option so routine geofence alerts stay out of the SOS
fallback channel.

## Acceptance Notes

- Meta template name for routine geofence alerts is `geofence_alert`.
- Template body placeholders are ordered as member name, entered/exited, zone name, and time.
- SOS messaging continues to use its own `sos_alert` template and remains isolated from routine
  geofence notifications.
- The future implementation tests the configured template name and parameter ordering instead of
  assuming free-text WhatsApp sends.
