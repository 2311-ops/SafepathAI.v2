---
status: deferred
trigger: "Account verification message (sent at signup) arrives empty — no content at all, not even a verification link. User wants to know what channel/provider is used for auth verification and why the body is empty."
created: 2026-08-11
updated: 2026-08-12
---

## Symptoms

- **Expected behavior:** Signup should send a verification email containing a verification link (or code) the user can act on.
- **Actual behavior:** The verification email arrives but its body is completely empty — no link, no code, no text.
- **Channel:** Email.
- **Timeline:** Always been empty — has never worked correctly as far as the user knows (not a regression from a previously-working state).
- **Errors:** None observed yet — user has only looked at the message itself, not backend logs or console output.
- **Reproduction:** Sign up / trigger the account-verification flow in the app; check the received email.

## Current Focus

reasoning_checkpoint:
  hypothesis: "The verification email is NOT empty when it leaves Supabase. GoTrue renders a complete HTML body containing an https verify link. The 'empty' appearance is a client-side (Gmail) rendering artifact whose structural cause is that Supabase custom SMTP is configured to send from the user's OWN personal Gmail account (madhouse2311.2005@gmail.com), producing a stream of self-addressed, identical-subject, byte-identical messages that Gmail threads into one conversation and collapses behind its 'Show trimmed content' (•••) control."
  confirming_evidence:
    - "Direct observation: two live signups against the production project delivered a full HTML body — <h2>Confirm your email address</h2> + instruction paragraph + <a href='https://fezgmdatczhtnxopwpfb.supabase.co/auth/v1/verify?token=...&type=signup&redirect_to=...'>Confirm email address</a>. Raw RFC822 source captured. Body is definitively non-empty."
    - "Direct observation: the two messages are byte-identical after normalizing the token — the precondition for Gmail's repeated-content trimming."
    - "Direct observation of the raw headers: From: \"SafepathAI\" <madhouse2311.2005@gmail.com>, Return-Path: <madhouse2311.2005@gmail.com>, relayed via smtp.gmail.com. That From address is the user's own email address, so any test signup using their own Gmail is a self-addressed message."
    - "Subject is the constant string 'Confirm your email address' on every send — Gmail threads on sender+subject."
  falsification_test: "Have the user open the 'empty' message in Gmail and click the '•••' / 'Show trimmed content' control, OR sign up with a non-Gmail recipient address. If the link is revealed by '•••', or a non-Gmail inbox shows the full body, the hypothesis holds. If the body is still genuinely blank in a fresh non-Gmail inbox, the hypothesis is refuted (but note my own non-Gmail probe inbox already rendered it fully, which is strong prior support)."
  fix_rationale: "There is no code defect to repair — no email-sending code exists in this repository at all. The correct remediation is Supabase Dashboard configuration: stop sending from the user's personal Gmail identity (use a dedicated sender / real SMTP provider), which removes the self-addressed + identical-message conditions that trigger Gmail's collapse. Optionally add the varying {{ .Token }} OTP to the template so no two messages are ever identical."
  blind_spots: "I cannot observe the user's actual Gmail inbox, so the precise client-side mechanism (thread trimming vs. self-send dedup) is inferred from the message's structural properties rather than directly witnessed. Both candidates share the same root condition and the same fix, so the remediation is unaffected, but the exact Gmail code path is unconfirmed. I also could not read the Dashboard's SMTP/template settings directly (no Management API credentials available), so SMTP configuration is inferred from delivery headers."

- **next_action:** None — session closed as **deferred**, not resolved. Root cause is diagnosed and accepted by the user without the '•••'/non-Gmail verification test. Remediation (the two Supabase Dashboard config changes: SMTP sender identity; Redirect URL allow-list + Site URL) is explicitly deferred by the user until they purchase a proper domain, to be applied before production launch. Re-open this session (or re-verify) once the domain is in place and the Dashboard changes are made.

## Evidence

- **timestamp:** 2026-08-11
  **checked:** `mobile/lib/features/auth/data/auth_api.dart` (`SupabaseAuthApi.register`)
  **found:** Registration calls `_client.auth.signUp(email, password, data: {...}, emailRedirectTo: supabaseRedirectUrl)`. No backend endpoint is involved.
  **implication:** The verification email is sent entirely by **Supabase Auth (GoTrue)**, not by the ASP.NET Core backend. Answers the user's "what provider" question.

- **timestamp:** 2026-08-11
  **checked:** Repo-wide grep for `smtp|resend|sendgrid|mailgun|postmark|mailer` across `backend/src`, `mobile/lib`, `docs/`, `.planning/`
  **found:** No email-sending code exists in the application. `01-03-SUMMARY.md:199` states: "No Resend or custom-SMTP code exists anywhere in the codebase — registration/password-reset email is entirely delegated to Supabase Auth's native `signUp`/`resetPasswordForEmail`, with SMTP being a Supabase Dashboard-only setting." The `ResendEmailSender` from `01-04-PLAN.md` was never built.
  **implication:** The bug cannot be in repository source code. It is Supabase Dashboard configuration and/or mail-client rendering.

- **timestamp:** 2026-08-11
  **checked:** Live probe `GET https://fezgmdatczhtnxopwpfb.supabase.co/auth/v1/settings`
  **found:** `{"external":{...,"email":true,"google":true},"disable_signup":false,"mailer_autoconfirm":false,"phone_autoconfirm":false,"sms_provider":"twilio"}`
  **implication:** `mailer_autoconfirm: false` confirms the project genuinely issues confirmation emails on signup.

- **timestamp:** 2026-08-11
  **checked:** EXPERIMENT 1 — live `POST /auth/v1/signup` against the production project using a disposable inbox (mail.gw) I could read programmatically; retrieved the full RFC822 source.
  **found:** Signup returned 200 with `confirmation_sent_at` set. Message arrived within ~3s. Headers: `From: "SafepathAI" <madhouse2311.2005@gmail.com>`, `Return-Path: <madhouse2311.2005@gmail.com>`, `Received: from fezgmdatczhtnxopwpfb.supabase.co ... by smtp.gmail.com`, `Subject: Confirm your email address`, `Content-Type: text/html; charset=UTF-8`, `Content-Transfer-Encoding: quoted-printable`. Body:
  `<h2>Confirm your email address</h2>\r\n\r\n<p>Follow the link below to confirm this email address and finish signing up.</p>\r\n<p><a href="https://fezgmdatczhtnxopwpfb.supabase.co/auth/v1/verify?token=43036429218566de84ee51a3fb6bf35b18e3ee471dcfadf87c8f9199&amp;type=signup&amp;redirect_to=http://localhost:3000">Confirm email address</a></p>`
  **implication:** **THE EMAIL BODY IS NOT EMPTY.** GoTrue renders a complete, well-formed HTML body with a working https verify link, and it survives SMTP transit intact. The reported symptom cannot originate in Supabase's send path. Also reveals **custom SMTP is configured, relaying through Gmail with the user's own personal address as the sender identity** — a fact not documented anywhere in the repo.

- **timestamp:** 2026-08-11
  **checked:** EXPERIMENT 2 — repeated the live signup, this time passing `redirect_to=safepathai%3A%2F%2Freset-password` exactly as `SupabaseAuthApi.register` does via `emailRedirectTo: supabaseRedirectUrl`.
  **found:** The emailed link came back as `...&type=signup&redirect_to=http://localhost:3000` — the requested `safepathai://reset-password` was **silently discarded**. Body otherwise byte-identical to Experiment 1 apart from the token (`da46969254ae68cc...` vs `43036429218566de...`).
  **implication:** Two independent conclusions. (1) `safepathai://reset-password` is **NOT in the project's allowed Redirect URLs**, so GoTrue falls back to Site URL, which is still the unconfigured default `http://localhost:3000` — a **separate, real, flow-breaking bug**: clicking the link on a phone verifies the token but then 302s to a dead localhost page, so `supabase_flutter` never receives the session. (2) Consecutive confirmation emails are byte-identical except the token — the exact precondition for Gmail's repeated-content trimming.

- **timestamp:** 2026-08-11
  **checked:** `mobile/lib/core/config/supabase_config.dart`, `mobile/lib/core/deep_link/deep_link_service.dart`, `AndroidManifest.xml`, `ios/Runner/Info.plist`
  **found:** The `safepathai://` scheme IS correctly registered on both Android and iOS. `DeepLinkService._handle` routes `safepathai://invite` and the expired-`reset-password` case; the session-bearing link is handled by `supabase_flutter` itself. `supabaseRedirectUrl` defaults to `safepathai://reset-password` and `SUPABASE_REDIRECT_URL` is not set in `mobile/env.json`.
  **implication:** The client side of the deep-link contract is correctly built. The only missing piece is the Dashboard allow-list entry. Note also that the signup-confirmation flow reuses the `reset-password` host, which is semantically wrong for a signup even once allow-listed.

- **timestamp:** 2026-08-11
  **checked:** Email template wording vs. Supabase defaults
  **found:** Default GoTrue text is "Confirm your signup" / "Follow this link to confirm your user". This project sends "Confirm your email address" / "Follow the link below to confirm this email address and finish signing up."
  **implication:** The "Confirm signup" template HAS been customized on the Dashboard, and it renders correctly. Rules out a blank/corrupt template.

## Eliminated

- **hypothesis:** The empty email is produced by application code (ASP.NET Core `IEmailSender` / Resend integration).
  **evidence:** No email-sending code exists in `backend/src` or `mobile/lib`; `01-03-SUMMARY.md:199` documents that the Resend integration was never built.
  **timestamp:** 2026-08-11

- **hypothesis:** Signup is auto-confirming, so the "verification" message is a different, contentless notification.
  **evidence:** `GET /auth/v1/settings` returns `mailer_autoconfirm: false`.
  **timestamp:** 2026-08-11

- **hypothesis:** The Supabase "Confirm signup" email template was saved blank or contains only unrenderable variables.
  **evidence:** Experiments 1 and 2 both captured a fully-populated HTML body with heading, instruction paragraph and a token-bearing anchor. The template is customized and renders correctly.
  **timestamp:** 2026-08-11

- **hypothesis:** A broken SMTP integration strips the message body in transit.
  **evidence:** The raw RFC822 source captured at the receiving MTA contains the complete quoted-printable HTML body. Transit is intact.
  **timestamp:** 2026-08-11

- **hypothesis:** Gmail strips the anchor because `emailRedirectTo` is the custom scheme `safepathai://`, leaving a blank body.
  **evidence:** The anchor `href` is always an **https** Supabase `/auth/v1/verify` URL; the custom scheme only ever appears as a `redirect_to` query parameter (and in practice is discarded entirely — see Experiment 2). No non-http(s) href is ever present for a sanitizer to strip.
  **timestamp:** 2026-08-11

## Resolution

root_cause: |
  Two distinct issues, neither of them a code defect in this repository.

  (1) THE REPORTED SYMPTOM — "empty" verification email. The email is not empty. Supabase Auth
  (GoTrue) renders and delivers a complete HTML body containing an https verify link; this was
  confirmed twice by capturing the raw RFC822 source of live signups. The emptiness is a
  client-side rendering artifact in Gmail. Its structural cause is that Supabase custom SMTP is
  configured to relay through Gmail using the user's OWN personal address
  (madhouse2311.2005@gmail.com) as the sender identity. Every confirmation therefore arrives
  with a constant sender, a constant subject ("Confirm your email address") and a body that is
  byte-identical to the previous one except for the token — and, when testing with the user's own
  Gmail address, is additionally self-addressed (From == To). Gmail threads these into a single
  conversation and collapses the repeated body behind its "Show trimmed content" (•••) control,
  so the message opens looking completely blank.

  (2) A SEPARATE, INDEPENDENT BUG found during investigation. The app passes
  emailRedirectTo: 'safepathai://reset-password', but that URL is not in the project's allowed
  Redirect URLs, so GoTrue silently discards it and falls back to Site URL — still the
  unconfigured default http://localhost:3000. Even once the user finds the verification link,
  clicking it on a phone verifies the token and then redirects to a dead localhost page, so
  supabase_flutter never receives the session. This is almost certainly why phase 01's
  .continue-here.md recorded two test accounts stuck at "Email not confirmed".

fix: |
  DEFERRED — not yet applied. No repository code changes are involved (or possible); both
  remediations are Supabase Dashboard configuration, which only the project owner can apply. The
  user has explicitly chosen to defer applying these until they purchase a proper domain, which
  they plan to do before production launch. Scope is intentionally limited to the two Dashboard
  fixes below only — no further scope (e.g. renaming the signup redirect off the shared
  `reset-password` host) was requested.

  A. Auth -> Emails -> SMTP Settings: replace the personal Gmail sender with a dedicated sender
     identity (a real transactional provider such as Resend/SendGrid on a verified domain, or at
     minimum a sender address that is not the account used to receive test signups). This removes
     the self-addressed + identical-message conditions behind Gmail's collapse.
     Optional hardening: add the varying {{ .Token }} OTP to the "Confirm signup" template so no
     two messages are ever identical and Gmail can never treat one as quoted repeat content.

  B. Auth -> URL Configuration: add `safepathai://reset-password` (and preferably a
     `safepathai://**` wildcard) to Redirect URLs, and change Site URL off `http://localhost:3000`
     to a URL that is meaningful for a mobile client. Re-run Experiment 2 afterwards to confirm the
     emailed link carries `redirect_to=safepathai://...` instead of localhost.

verification: |
  Self-verified so far (automated, against the live project):
  - Live signup delivers a non-empty, well-formed HTML confirmation email containing the verify
    link — captured raw twice, from two independent disposable inboxes.
  - Both messages are byte-identical after token normalization.
  - Sender identity confirmed from raw headers as the user's own Gmail via smtp.gmail.com.
  - redirect_to confirmed to fall back to http://localhost:3000 even when the app's exact
    emailRedirectTo value is supplied.

  NOT independently verified by the human, and not required to be right now: the user has
  accepted this diagnosis as sufficient explanation without opening the "empty" message's
  "•••" / "Show trimmed content" control or retesting with a non-Gmail address.

  Human decision (2026-08-12): "i will buy a domain later them put it to supabase just mark it
  as pending also as we will do it before production." Both Dashboard remediations (SMTP sender
  identity; Redirect URL allow-list + Site URL) are deferred until a production domain is
  purchased, to be completed before production launch — not resolved now. On the redirect-host
  naming follow-up (reusing "reset-password" as the signup redirect), the user's decision was
  "Just the two Dashboard fixes for now" — that additional scope is explicitly not being pursued.

status_detail: deferred — blocked on user purchasing a domain; both Dashboard fixes to be applied
  before production launch. Root cause stands as diagnosed and accepted; no fix has been applied
  or verified yet.

files_changed: []
