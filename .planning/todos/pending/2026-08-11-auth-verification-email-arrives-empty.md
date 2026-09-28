---
created: 2026-08-11T20:10:00.000Z
updated: 2026-08-12T00:00:00.000Z
title: Fix Supabase verification email SMTP sender + redirect allow-list (blocked on domain purchase)
area: backend/auth
files:
  - .planning/debug/verification-email-empty.md
  - mobile/lib/features/auth/data/auth_api.dart
---

## Problem

**Root cause found (2026-08-11 debug session, `.planning/debug/verification-email-empty.md`) — not a
code bug.** The signup verification email is not actually empty: Supabase Auth (GoTrue) is the sole
sender (no email-sending code exists anywhere in this repo — confirmed by grep and `01-03-SUMMARY.md`)
and live test signups showed it renders a complete HTML body with a working verify link every time.

The "empty" appearance is a Gmail rendering artifact: custom SMTP is configured to relay through the
user's own personal Gmail address (`madhouse2311.2005@gmail.com`) as sender, producing self-addressed,
same-subject, near-identical-body messages that Gmail threads and collapses behind "Show trimmed
content" (•••).

A second, separate bug was found in the same investigation: the app's redirect URL
(`safepathai://reset-password`, passed via `emailRedirectTo` in `SupabaseAuthApi.register`,
`mobile/lib/features/auth/data/auth_api.dart`) is not in Supabase's Redirect URL allow-list, so GoTrue
silently falls back to the default Site URL (`http://localhost:3000`) — meaning even a correctly-found
link currently dead-ends instead of reopening the app. This is likely why old test accounts are stuck
at "Email not confirmed."

**User decision (2026-08-11):** defer both fixes until a proper domain is purchased (needed for a
non-personal SMTP sender identity) and set up in Supabase — to be done before production launch, not
urgently now. The debugger's third suggestion (fixing that signup confirmations semantically reuse the
"reset-password" redirect host) was explicitly declined — out of scope, dashboard fixes only.

## Solution

Once a domain is purchased and added to Supabase, two Supabase **Dashboard** changes (no code):
1. **Auth → Emails → SMTP Settings** — change sender off the personal Gmail address to a dedicated
   transactional address on the new domain (e.g. `noreply@yourdomain.com`). Optionally add
   `{{ .Token }}` to the "Confirm signup" template so no two messages are ever byte-identical.
2. **Auth → URL Configuration** — add `safepathai://reset-password` (or `safepathai://**`) to Redirect
   URLs, and change Site URL off `http://localhost:3000`.

No repository code changes needed for either fix.
