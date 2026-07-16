---
phase: 02
slug: real-time-location-history-privacy
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-07-16
---

# Phase 02 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Mobile app ↔ Backend API/SignalR hub | Flutter client to ASP.NET Core `/hubs/location`, `/families/*`, `/me/*`, `/privacy/*` endpoints | JWT bearer/query-string tokens, live location pings, profile data, sharing preferences |
| Backend ↔ Supabase Postgres | EF Core over Npgsql direct connection | LocationPing, SharingPreference, Users (DisplayName/ProfileImagePath) rows |
| Backend ↔ Supabase Storage | Signed-URL upload/read/delete of avatar objects | Profile image binary content, signed URLs (1h TTL) |
| Mobile app ↔ OSM tile server (tile.openstreetmap.org) | flutter_map TileLayer HTTPS requests | Map viewport tile coordinates (no location/PII in tile request itself, but request pattern implies rough position) |
| Family member ↔ Family member (via backend) | Live location, history, presence, avatar broadcast scoped by family membership + SharingPreference | Location coordinates, accuracy, battery, presence, avatar/display name |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| 02-01:T-02-SC | Tampering | signalr_netcore pub.dev install | high | mitigate | Blocking legitimacy checkpoint before pubspec add | closed |
| 02-01:T-02-03 | Information Disclosure | LocationHub group broadcast | high | mitigate | RequireMembership before group join; group-scoped broadcast | closed |
| 02-01:T-02-04 | Spoofing | LocationHub connection identity | high | mitigate | userId from Context.UserIdentifier (validated JWT) | closed |
| 02-01:T-02-01 | Tampering | familyId query-string param | high | mitigate | Server re-checks familyId against caller's active membership | closed |
| 02-01:T-02-06 | Information Disclosure | access_token in query string / access logs | medium | accept | TLS/WSS in transit; prod log suppression deferred to deploy | closed |
| 02-01:T-02-07 | Session | JWT not revalidated mid-connection | low | accept | Documented SignalR behavior, acceptable for this threat model | closed |
| 02-02:T-02-01 | Tampering/Info Disclosure | GET live-locations IDOR | high | mitigate | RequireMembership before read; caller id from ICurrentUserService | closed |
| 02-02:T-02-04 | Spoofing/Tampering | ReportLocation payload spoofed UserId/coords | high | mitigate | UserId server-derived; bounds + not-future timestamp validated | closed |
| 02-02:T-02-08 | Tampering | Out-of-range coordinate/battery injection | medium | mitigate | Bounds check in handler before persistence | closed |
| 02-02:T-02-03 | Information Disclosure | Broadcast fan-out to wrong recipients | high | mitigate | Broadcast scoped to caller's family group; per-recipient gate in 02-03 | closed |
| 02-03:T-02-02 | Information Disclosure | Privacy toggle enforced only client-side | high | mitigate | Gate lives server-side in ISharingAuthorizationService | closed |
| 02-03:T-02-01 | Tampering | Setting sharing prefs for another user | high | mitigate | OwnerUserId forced to CallerUserId in command handler | closed |
| 02-03:T-02-05 | Information Disclosure | Race: disable toggle while broadcast in flight | medium | mitigate | Recipients evaluated at broadcast time, not cached at group-join | closed |
| 02-03:T-02-09 | Tampering | Expired temporary share still leaking data | medium | mitigate | Read/broadcast gate excludes expired rows + sweep service disables them | closed |
| 02-03:T-02-01b | Information Disclosure | GetSharingMatrix exposing another user's matrix | high | mitigate | Query scoped to CallerUserId after RequireMembership | closed |
| 02-04:T-02-01 | Tampering/Info Disclosure | History/stats read IDOR | high | mitigate | RequireMembership + target-in-family + CanView(History) | closed |
| 02-04:T-02-02 | Information Disclosure | History exposed despite History-sharing disabled | high | mitigate | Independent SharedDataType.History gate server-side | closed |
| 02-04:T-02-10 | Denial of Service | Unbounded date-range read | medium | mitigate | Query restricted to bounded [from,to] on composite index | closed |
| 02-05:T-02-01 | Tampering/Info Disclosure | Export/delete IDOR | high | mitigate | Scoped to CallerUserId from ICurrentUserService | closed |
| 02-05:T-02-11 | Denial of Service | Battery-alert spam flooding family | medium | mitigate | Falling-edge hysteresis (alert 20/clear 25) | closed |
| 02-05:T-02-02 | Information Disclosure | Battery alert leaking non-sharing member presence | medium | mitigate | Alert broadcast reuses LiveLocation sharing recipient filter | closed |
| 02-05:T-02-12 | Repudiation | Irreversible delete with no confirmation | low | accept | Confirmation friction lives in mobile UI (delivered 02-09) | closed |
| 02-06:T-02-13 | Information Disclosure | Over-broad location permission requested prematurely | medium | mitigate | Foreground-only manifests; no background/Always permission strings | closed |
| 02-06:T-02-14 | Repudiation/UX-harm | OS prompt fired before user understands why | medium | mitigate | requestPermission() gated behind priming-screen CTA | closed |
| 02-06:T-02-04 | Spoofing | Client-reported position trusted as identity | high | transfer | Identity server-derived at hub (Context.UserIdentifier) | closed |
| 02-06:T-02-15 | Tampering | Maps API key exposure in app bundle | low | accept | Superseded — Google Maps/API key removed entirely in 02-12 | closed |
| 02-07:T-02-03 | Information Disclosure | Rendering unauthorized member | high | mitigate | Client only renders server-pushed data; backend double-gate | closed |
| 02-07:T-02-16 | UX/correctness | Presence lying (online while stale) | low | mitigate | Two independent signals surfaced distinctly | closed |
| 02-07:T-02-11 | Denial of Service | Battery-banner spam | low | accept | Suppression enforced server-side (02-05); client displays deduped event | closed |
| 02-08:T-02-02 | Information Disclosure | Viewing history despite History-sharing disabled | high | mitigate | Server-side enforcement; client shows friendly denied state | closed |
| 02-08:T-02-01 | Information Disclosure | Requesting arbitrary targetUserId's history | high | mitigate | Server re-checks membership+target-in-family+History share | closed |
| 02-09:T-02-02 | Information Disclosure | Toggle appearing to work but not enforced | high | mitigate | Toggle PATCHes server (sole enforcement point); reverts on failure | closed |
| 02-09:T-02-01 | Information Disclosure | Export/delete touching another user's data | high | mitigate | Server scopes both to authenticated caller | closed |
| 02-09:T-02-12 | Repudiation | Accidental irreversible delete | low | mitigate | Confirmation dialog with explicit "can't be undone" copy | closed |
| 02-09:T-02-17 | Information Disclosure | Exported JSON leaking on-device | low | accept | Export uses OS share sheet; delegated to user's chosen target | closed |
| 02-10:T-02-10-01 | Information Disclosure | LocationController/positionStreamProvider | high | mitigate | Controller-level guard blocks connect/fetch/stream until permission granted | closed |
| 02-10:T-02-10-02 | Tampering | /home route bypassing priming | medium | mitigate | /home wrapped in LocationPermissionGate | closed |
| 02-10:T-02-10-03 | Repudiation | OS permission prompt without user intent | medium | mitigate | requestPermission() only from priming CTA | closed |
| 02-10:T-02-10-04 | Denial of Service | Permission check/router redirect loops | low | mitigate | Neutral loading scaffold; excludes /permission-priming from loop | closed |
| 02-11:T-02-11-01 | Information Disclosure | Temporary sharing recipient selection | high | mitigate | Controls bound to explicit recipient rows | closed |
| 02-11:T-02-11-02 | Tampering | Custom duration input | medium | mitigate | Dialog validates empty/non-numeric/zero/negative | closed |
| 02-11:T-02-11-03 | Repudiation | User cannot tell who is temporarily receiving location | medium | mitigate | Recipient-scoped controls + remaining-time context | closed |
| 02-11:T-02-11-04 | Denial of Service | Excessively large custom duration | low | mitigate | Custom input validation caps duration at 7 days | closed |
| 02-12:T-02-M1 | Information Disclosure | TileLayer requests to tile.openstreetmap.org | medium | accept (dev) / mitigate (prod) | Accepted at dev/graduation scale; USER-SETUP documents prod tile-provider migration | closed |
| 02-12:T-02-M2 | Tampering | OSM tile fetch over network | low | mitigate | HTTPS tile URL only, never HTTP | closed |
| 02-12:T-02-SC | Tampering | flutter_map/latlong2 install (supply chain) | low | mitigate | CLAUDE.md-sanctioned OSM stack; pinned versions | closed |
| 02-13:T-02-03 | Tampering | Avatar upload polyglot file | high | mitigate | Full Image.Load + JpegEncoder re-encode discards embedded non-image bytes | closed |
| 02-13:T-02-04 | Denial of Service | Avatar upload pixel-flood/decompression bomb | high | mitigate | Image.Identify metadata-only read rejects >4000x4000 before decode | closed |
| 02-13:T-02-05 | Denial of Service | Avatar upload oversized payload | high | mitigate | 5 MB MaxUploadBytes check before decode | closed |
| 02-13:T-02-07 | Tampering/EoP | Storage object key path traversal | high | mitigate | Key built only from server Guid; no client string interpolated | closed |
| 02-13:T-02-01 | Information Disclosure | Unsigned/guessable object URL | medium | mitigate | Private bucket, no RLS; only backend-issued signed URL can read | closed |
| 02-13:T-02-SC | Tampering | SixLabors.ImageSharp 4.0.0 NuGet install | low | accept | Verified official org, 281.9M downloads | closed |
| 02-14:T-02-02 | Tampering/EoP | /me/profile-image + /me/display-name IDOR | high | mitigate | No userId in route/body; CallerUserId from ICurrentUserService | closed |
| 02-14:T-02-01 | Information Disclosure | live-locations avatar exposure across families | high | mitigate | ProfileImageUrl signed only when sharing gate passes | closed |
| 02-14:T-02-05 | Denial of Service | Oversized upload body | high | mitigate | [RequestSizeLimit(6_000_000)] refuses bodies before buffering | closed |
| 02-14:T-02-06 | Information Disclosure | signed-URL leakage/replay | medium | accept | 1-hour TTL bounds exposure; prod logging must not log signed URLs | closed |
| 02-14:T-02-SC | Tampering | package installs | low | accept | No new packages added | closed |
| 02-15:T-02-13 | Tampering | Client-side validation trusted as boundary | high | mitigate | Backend re-validates/re-encodes every upload; no direct Storage calls from client | closed |
| 02-15:T-02-06 | Information Disclosure | Signed avatar URL persistence in cache | low | accept | cached_network_image keys on non-secret cacheKey; URL decays at 1h TTL | closed |
| 02-15:T-02-SC | Tampering | image_picker/cached_network_image installs | low | accept | Verified publishers, high adoption | closed |
| 02-16:T-02-01 | Information Disclosure | Cross-family avatar/name render | high | mitigate | Map renders only gated query results; broadcast scoped to family group | closed |
| 02-16:T-02-06 | Information Disclosure | Signed avatar URL in image cache | low | accept | cached_network_image keys on userId+profileUpdatedAt, not URL | closed |
| 02-16:T-02-SC | Tampering | package installs | low | accept | No new packages added | closed |
| 02-17:T-02-17-01 | Information Disclosure | Live Map header MemberMapPin | low | accept | Header reads state?.selfPosition only; null → neutral initials | closed |
| 02-17:T-02-17-02 | Tampering | avatar URL rendering | low | accept | Same server-issued signed URL as LiveMemberMarker; errorWidget falls back to initials | closed |
| 02-17:T-02-17-SC | Tampering | package installs | n/a | accept | No dependency added/removed/upgraded | closed |
| 02-18:T-02-18-01 | Information Disclosure | ProfileUpdatedAt projection | low | mitigate | Gated behind existing canViewLocation sharing check | closed |
| 02-18:T-02-18-02 | Tampering | profileUpdatedAt / client cache key | low | accept | Server-sourced, read-only on client | closed |
| 02-18:T-02-18-SC | Tampering | package installs | n/a | accept | No new dependencies added | closed |
| 02-19:T-02-19-01 | Information Disclosure | IsOnline calculation via latestPing | high | mitigate | Gated behind canViewLocation; regression test for denied sharing | closed |
| 02-19:T-02-19-02 | Tampering | Test setup for sharing denial | medium | mitigate | Regression tests seed explicit disabled SharingPreference row | closed |
| 02-19:T-02-19-03 | Information Disclosure | Independent connection presence | low | accept | _presence.IsOnline preserved as separate signal; preservation test added | closed |
| 02-19:T-02-19-04 | Repudiation | Future regression of privacy gate | medium | mitigate | Named regression tests added to GetLiveLocationsQueryTests.cs | closed |
| 02-19:T-02-19-SC | Tampering | package installs | n/a | accept | No installs planned | closed |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|--------------|------|
| AR-01 | 02-01:T-02-06 | access_token appears in SignalR query string; TLS/WSS protects it in transit, production log suppression deferred to deploy config | Phase 02 plan | 2026-07-16 |
| AR-02 | 02-01:T-02-07 | JWT not revalidated mid-connection is standard SignalR behavior, acceptable for this threat model | Phase 02 plan | 2026-07-16 |
| AR-03 | 02-05:T-02-12 | Irreversible delete confirmation friction lives in mobile UI, not the endpoint (delivered 02-09) | Phase 02 plan | 2026-07-16 |
| AR-04 | 02-06:T-02-15 | Maps API key client exposure — moot, Google Maps/key removed entirely in 02-12 OSM migration | Phase 02 plan | 2026-07-16 |
| AR-05 | 02-07:T-02-11 | Battery-banner spam suppression enforced server-side (02-05); client just displays deduped event | Phase 02 plan | 2026-07-16 |
| AR-06 | 02-09:T-02-17 | Exported JSON handling on-device delegated to the user's chosen OS share-sheet target | Phase 02 plan | 2026-07-16 |
| AR-07 | 02-12:T-02-M1 | OSM tile requests to tile.openstreetmap.org accepted at dev/graduation scale; USER-SETUP documents pre-production tile-provider migration | Phase 02 plan | 2026-07-16 |
| AR-08 | 02-13:T-02-SC | SixLabors.ImageSharp 4.0.0 — verified official org, 281.9M downloads | Phase 02 plan | 2026-07-16 |
| AR-09 | 02-14:T-02-06 | Signed avatar URL leakage/replay bounded by 1h TTL; production logging must avoid logging signed-URL query strings | Phase 02 plan | 2026-07-16 |
| AR-10 | 02-14:T-02-SC, 02-16:T-02-SC, 02-17:T-02-17-SC, 02-18:T-02-18-SC, 02-19:T-02-19-SC | No new dependencies added in these plans | Phase 02 plan | 2026-07-16 |
| AR-11 | 02-15:T-02-06, 02-16:T-02-06 | Signed avatar URL cached client-side keyed on userId+profileUpdatedAt (not the URL itself); URL decays at 1h TTL | Phase 02 plan | 2026-07-16 |
| AR-12 | 02-15:T-02-SC | image_picker/cached_network_image — verified publishers, high adoption | Phase 02 plan | 2026-07-16 |
| AR-13 | 02-17:T-02-17-01, 02-17:T-02-17-02 | Live Map header avatar reads only the caller's own selfPosition/signed URL; same trust boundary as existing family marker rendering | Phase 02 plan | 2026-07-16 |
| AR-14 | 02-18:T-02-18-02 | profileUpdatedAt is server-sourced and read-only on the client — no new trust boundary | Phase 02 plan | 2026-07-16 |
| AR-15 | 02-19:T-02-19-03 | Connection-derived presence (_presence.IsOnline) intentionally kept as an independent signal from location-derived recency (D-03) | Phase 02 plan | 2026-07-16 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-16 | 74 | 74 | 0 | gsd-secure-phase (register built from 19 PLAN.md threat models + 9 SUMMARY.md threat-flag sections; L1/ASVS-1 short-circuit — no auditor spawn needed, threats_open: 0 and register_authored_at_plan_time: true) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-16
