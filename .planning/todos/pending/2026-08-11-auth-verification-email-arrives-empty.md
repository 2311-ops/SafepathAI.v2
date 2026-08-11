---
created: 2026-08-11T20:10:00.000Z
title: Account verification email arrives with empty body (no link, no content)
area: backend/auth
files:
  - .planning/debug/verification-email-empty.md
---

## Problem

The signup/account-verification email the user receives is completely empty — no verification link,
no code, no text at all. This has always been broken (not a regression from previously-working
behavior), and it's unrelated to the SOS SMS/WhatsApp work tracked separately. It isn't yet known
which mechanism actually sends this email (Supabase Auth's built-in email templates vs. a custom
ASP.NET Core email service), so the first investigation step is identifying the channel/provider
before diagnosing why the body renders empty.

A live `/gsd-debug` session is investigating this in parallel — see
`.planning/debug/verification-email-empty.md` for the current hypothesis/evidence/next-action state.
This todo exists as a durable pointer in case that session is abandoned or paused before resolution;
if the debug session resolves (status: resolved, moved to `.planning/debug/resolved/`), this todo can
be closed out too.

## Solution

TBD — pending the debug session's root-cause finding. Likely candidates: (1) Supabase Auth email
template misconfigured/left blank in the Supabase dashboard, (2) a custom email-sending service
whose template rendering silently fails or was never wired up, (3) SMTP/provider config present but
the template payload itself is empty.
