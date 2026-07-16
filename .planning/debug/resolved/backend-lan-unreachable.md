---
status: resolved
trigger: "App on A30 physical device shows 'Couldn't connect, try again' after rebuild with API_BASE_URL=http://192.168.1.12:5059 (host LAN IP); map marker circles and user data do not load. Fix so the ASP.NET Core backend is reachable from LAN devices during local mobile development without exposing it to the public internet or changing production hosting config, auth, Family Circle logic, or API contracts."
created: 2026-07-14
updated: 2026-07-14
---

# Debug Session: Backend Unreachable From LAN (A30 "Couldn't Connect")

## Symptoms
- expected_behavior: With the backend running and the mobile app built with `API_BASE_URL=http://192.168.1.12:5059` (the host machine's LAN IP), the A30 physical device should be able to reach the backend over Wi-Fi and load family map markers and user/profile data normally.
- actual_behavior: App shows a "Couldn't connect, try again" error; map marker circles and user data fail to load entirely.
- error_messages: "Couldn't connect, try again" (in-app, exact wording per user report). No stack trace yet from device logs.
- timeline: First occurred 2026-07-14 immediately after rebuilding/reinstalling the app with the corrected `--dart-define-from-file=env.json --dart-define=API_BASE_URL=http://192.168.1.12:5059` (previous install lacked these defines entirely, which was a separate already-identified issue). Backend itself has been running continuously and answers on loopback.
- reproduction: With backend running via `dotnet run --project backend/src/SafePath.Api/SafePath.Api.csproj --urls http://localhost:5059`, and app installed on the A30 (same Wi-Fi network as host, IP 192.168.1.12), open the app and observe the connect error on any screen that hits the API (map/profile).

## Current Focus
- hypothesis: CONFIRMED (two-layer root cause). Layer 1 (fixed earlier): Kestrel bound loopback-only. Layer 2 (this session): even with Kestrel on `0.0.0.0:5059`, the A30 cannot reach the host over Wi-Fi because the router enforces client isolation — device-to-device L2/ARP traffic is blocked. The USB tunnel (`adb reverse`) bypasses Wi-Fi entirely and is verified working end-to-end.
- test: DONE — set up `adb reverse tcp:5059 tcp:5059`, then issued a raw HTTP GET from the DEVICE's own loopback (`127.0.0.1:5059`) via toybox `nc`; rebuilt + reinstalled the app with `API_BASE_URL=http://127.0.0.1:5059`.
- expecting: DONE — device-side request through the tunnel returned `HTTP/1.1 200 OK` / `Server: Kestrel` / valid OpenAPI JSON (36407 bytes). App reinstalled on R58M30TGNXV. Tunnel re-confirmed live after install.
- next_action: DONE — human-verify complete. User opened the app on the A30 with the backend running host-side (0.0.0.0:5059) and the USB tunnel armed (`adb reverse tcp:5059 tcp:5059`) and confirmed the app connects successfully: map markers + user/profile data load. Session marked resolved and archived.
- reasoning_checkpoint:
    hypothesis: "Kestrel accepts connections only on loopback because the effective bind URL is `http://localhost:5059` (from the `--urls http://localhost:5059` run flag, mirrored by the launchSettings default profile). In .NET, the `localhost` host binds only the loopback interfaces (127.0.0.1 + [::1]), so the host's LAN interface (192.168.1.12) never accepts TCP connections — the A30 connecting to 192.168.1.12:5059 gets connection-refused/timeout, surfaced in-app as 'Couldn't connect'."
    confirming_evidence:
      - "netstat shows LISTENING only on `127.0.0.1:5059` and `[::1]:5059` (PID 20088), never `0.0.0.0:5059` or `192.168.1.12:5059`."
      - "`curl http://192.168.1.12:5059/` returns HTTP 000 (TCP connect fails) while `curl http://127.0.0.1:5059/` returns HTTP 404 in ~5ms — server is alive and serving, only the LAN interface is unbound."
      - "Program.cs uses `WebApplication.CreateBuilder(args)` with no `UseUrls`/`ConfigureKestrel`/`ListenAnyIP`, and appsettings has no Kestrel endpoint block — so the bind address comes purely from the `localhost` URL config, nothing else."
      - "Windows Firewall already has Allow rules for 5059 (eliminated as blocker); a CORS/HTTPS-redirect cause is ruled out because a native Flutter client doesn't enforce CORS and the failure is at TCP connect, not an HTTP response."
    falsification_test: "After rebinding to `0.0.0.0:5059` and restarting, run `curl http://192.168.1.12:5059/` from the host. If it still returns HTTP 000 while loopback returns 404, the loopback-bind hypothesis is wrong and something else (subnet/AP isolation/interface routing) blocks LAN access."
    fix_rationale: "Binding Kestrel to `0.0.0.0` makes it accept on all IPv4 interfaces, including the LAN IP 192.168.1.12 — directly removing the loopback-only restriction that is the root cause. Delivered as a dedicated Development-only launch profile so the default `http`/`https` profiles and production hosting (which never reads launchSettings.json) stay unchanged; scope stays local-LAN, not public-internet."
    blind_spots: "Cannot test the physical A30 myself (human-verify required). Assumes device and host are on the same /24 with no Wi-Fi AP client-isolation and no VPN/second-NIC routing quirk. The benign `UseHttpsRedirection` 'no https port' warning is expected over plain HTTP but unverified end-to-end from the device."
- tdd_checkpoint:

## Evidence
- timestamp: 2026-07-14
  observation: "`netstat -ano` shows `TCP 127.0.0.1:5059 LISTENING <pid>` and `TCP [::1]:5059 LISTENING <pid>` for the running backend process — never `0.0.0.0:5059` or `192.168.1.12:5059`."
- timestamp: 2026-07-14
  observation: "`curl -s -o /dev/null -w '%{http_code}' http://192.168.1.12:5059/ --max-time 5` from the host machine itself returns HTTP 000 (connection failed) after ~2s, while the identical curl to `http://127.0.0.1:5059/` returns HTTP 404 in ~5ms — proves the process is alive and serving, but not reachable via the LAN-facing interface."
- timestamp: 2026-07-14
  observation: "`backend/src/SafePath.Api/Properties/launchSettings.json` http profile: `applicationUrl: \"http://localhost:5059\"`; https profile: `applicationUrl: \"https://localhost:7216;http://localhost:5059\"`. Both use the `localhost` hostname rather than `0.0.0.0` or `+`."
- timestamp: 2026-07-14
  observation: "A Windows Firewall inbound rule named 'SafePath Backend Dev (5059)' (Action=Allow, Profile=Any) plus two 'SafePath.Api' rules (Allow, Private) already exist for this port, ruling out firewall as the blocker."
- timestamp: 2026-07-14
  checked: "Program.cs and appsettings*.json for any explicit URL/Kestrel binding."
  found: "Program.cs uses `WebApplication.CreateBuilder(args)` with no `UseUrls`/`ConfigureKestrel`/`ListenAnyIP`; appsettings has no `Kestrel:Endpoints` block. Bind address therefore comes purely from URL config (`--urls` arg / launchSettings applicationUrl)."
  implication: "Confirms the loopback bind is caused by the `localhost` URL value, not code — so the fix belongs in the URL/launch config, not Program.cs."
- timestamp: 2026-07-14
  checked: "Applied fix — added Development-only `http-lan` launch profile (`http://0.0.0.0:5059`), killed the old loopback process (PID 5808 tree), restarted with `dotnet run --launch-profile http-lan`."
  found: "`netstat` now shows `TCP 0.0.0.0:5059 LISTENING 28328` (all IPv4 interfaces). Host LAN IPv4 confirmed as 192.168.1.12."
  implication: "Kestrel now binds the LAN interface, not just loopback — the root-cause condition is removed."
- timestamp: 2026-07-14
  checked: "Falsification/verification curl from the host after restart."
  found: "`curl http://192.168.1.12:5059/` -> HTTP 404 in ~5ms (was HTTP 000 before); `curl http://127.0.0.1:5059/` -> HTTP 404; `curl http://192.168.1.12:5059/openapi/v1.json` -> HTTP 200 (real content over LAN)."
  implication: "LAN interface now serves identically to loopback and returns real application content — host-side fix verified. Remaining unknown is the physical A30 (human-verify)."
- timestamp: 2026-07-14
  checked: "Re-confirmed AP client-isolation from the device with a control comparison. `adb shell ip -o -4 addr` -> phone is 192.168.1.3/24 on wlan0. `adb shell ping -c3 192.168.1.12` (host) -> all 3 packets `Destination Host Unreachable` (ARP for the peer host never resolves). `adb shell ping -c3 192.168.1.1` (gateway) -> 100% loss but NO 'Destination Host Unreachable' (ARP to the AP resolves fine; gateway just doesn't answer ICMP)."
  found: "The phone reaches the AP/gateway at L2 but cannot ARP-resolve the peer host on the same /24 — the differential signature of Wi-Fi client isolation at the router, not a Kestrel/firewall/subnet issue."
  implication: "The remaining failure is a router L2 policy blocking device-to-device traffic — not fixable in this codebase. Bypassing Wi-Fi (USB tunnel) is the correct workaround."
- timestamp: 2026-07-14
  checked: "Set up USB tunnel and verified device-side reachability. `adb reverse --list` was empty; ran `adb reverse tcp:5059 tcp:5059` (exit 0); `adb reverse --list` -> `UsbFfs tcp:5059 tcp:5059`. Device has no curl/wget but has toybox `nc`. From the DEVICE loopback: `(printf 'GET /openapi/v1.json HTTP/1.0\\r\\n\\r\\n'; sleep 4) | toybox nc -w 8 127.0.0.1 5059`."
  found: "Device-side response: `HTTP/1.1 200 OK`, `Server: Kestrel`, `Content-Type: application/json`, 36407 bytes of valid OpenAPI JSON. (A naive `printf | nc` without holding stdin open returned 0 bytes — toybox nc EOF-closes the socket before the reply; the `sleep` keeps stdin open so nc waits for the response. TCP connect itself always succeeded, exit 0.)"
  implication: "The `adb reverse` USB tunnel forwards the device's `127.0.0.1:5059` to the host's Kestrel end-to-end at the HTTP layer, bypassing Wi-Fi entirely. Fix empirically confirmed correct, independent of the app."
- timestamp: 2026-07-14
  checked: "Verified the app consumes API_BASE_URL and that cleartext HTTP is not a blocker. `dio_client.dart` uses `String.fromEnvironment('API_BASE_URL')` as the Dio baseUrl when set (else Android default `http://10.0.2.2:5059`). No `usesCleartextTraffic`/`networkSecurityConfig` anywhere; debug manifest only adds INTERNET."
  found: "The app already develops against plain-HTTP local backends (default `http://10.0.2.2:5059`) with zero cleartext config, i.e. Flutter's dart:io HttpClient (via Dio) does not enforce Android's cleartext network-security policy. So `http://127.0.0.1:5059` behaves the same as the existing cleartext URLs — no manifest change needed (kept the fix minimal)."
  implication: "Passing `--dart-define=API_BASE_URL=http://127.0.0.1:5059` is sufficient; the loopback URL is honored and cleartext is permitted for this Flutter app."
- timestamp: 2026-07-14
  checked: "Rebuilt + reinstalled the app on the loopback URL, then re-verified. `flutter build apk --debug --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059` -> built app-debug.apk (Gradle assembleDebug OK). `flutter install -d R58M30TGNXV --debug --use-application-binary=...app-debug.apk` -> installed on SM A305F. Post-install: `adb reverse --list` still `UsbFfs tcp:5059 tcp:5059`; device-side HTTP through tunnel still `HTTP/1.1 200 OK`; host `netstat` still `0.0.0.0:5059 LISTENING 28328` plus a fresh `127.0.0.1:5059 ... TIME_WAIT` proving a connection just traversed the tunnel to host loopback."
  found: "App on the A30 now points at `http://127.0.0.1:5059` (tunnelled to host), the tunnel survived the reinstall, and the full path device->USB->host Kestrel is live."
  implication: "Everything under my control is verified. Only the in-app end-to-end confirmation on the physical A30 remains (human-verify) — I cannot open the app myself."

## Eliminated
- hypothesis: Windows Firewall blocking inbound port 5059
  reason: Confirmed existing Allow rules for port 5059 (Any profile) and SafePath.Api (Private profile); the connection fails before reaching firewall-relevant behavior (Kestrel never listens on the interface firewall would be filtering).

## Resolution
- root_cause: "Two independent layers had to be cleared for the A30 to reach the dev backend. Layer 1 (fixed in the prior session): Kestrel listened only on loopback (127.0.0.1 + [::1]) because the effective bind URL was `http://localhost:5059`, so the host's LAN interface never accepted connections. Layer 2 (this session): even after rebinding Kestrel to `0.0.0.0:5059` (host-side reachable via 192.168.1.12), the A30 still could not connect because the router enforces Wi-Fi client isolation — device-to-device L2/ARP traffic between the phone (192.168.1.3) and host (192.168.1.12) on the same /24 is blocked (`ping host` -> Destination Host Unreachable, while `ping gateway` ARP-resolves). That router policy is not fixable in this codebase. Not firewall, CORS, auth, or app logic."
- fix: "Layer 1 remains: Development-only `http-lan` launch profile binding `http://0.0.0.0:5059` (useful for wireless-only networks WITHOUT AP isolation). Layer 2 workaround (this session): bypass Wi-Fi via a USB tunnel — `adb reverse tcp:5059 tcp:5059` forwards the device's `127.0.0.1:5059` to the host's Kestrel over USB — then rebuilt/reinstalled the app with `API_BASE_URL=http://127.0.0.1:5059`. No app/network-security-config change needed (Flutter dart:io/Dio does not enforce Android cleartext policy; the app already uses plain-HTTP local backends). No production hosting, auth, Family Circle, or API-contract change."
- verification: "Host-side (Layer 1) verified earlier: `0.0.0.0:5059 LISTENING`, LAN curl 404/200. Tunnel (Layer 2) verified this session END-TO-END from the device: `adb reverse --list` -> `UsbFfs tcp:5059 tcp:5059`; a raw HTTP GET from the DEVICE loopback (toybox nc) returned `HTTP/1.1 200 OK` / `Server: Kestrel` / 36407-byte OpenAPI JSON; app rebuilt with the loopback URL and reinstalled on R58M30TGNXV; tunnel + device-side 200 re-confirmed after install. HUMAN-VERIFY COMPLETE (2026-07-14): user opened the app on the A30 through the armed USB tunnel and confirmed it connects successfully — map markers + user/profile data load as expected. Root cause resolved end-to-end."
- files_changed:
    - "backend/src/SafePath.Api/Properties/launchSettings.json (added http-lan Development profile — from prior session)"
    - "docs/DEVELOPMENT.md (prior: LAN-IP/http-lan note; this session: added 'Physical device over USB (adb reverse)' subsection — tunnel command, non-persistence across USB disconnect/reboot, exact re-apply command, and when-to-prefer USB vs LAN-IP)"
    - "mobile app binary: rebuilt app-debug.apk with API_BASE_URL=http://127.0.0.1:5059 and reinstalled on R58M30TGNXV (no source change — build-time dart-define only)"
