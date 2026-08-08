# Run SafePath AI On A USB Android Phone

These steps run the Flutter mobile app on a physical Android phone over USB and let the phone reach the local backend through the USB cable.

## 1. Connect The Phone

1. Enable Developer options on the phone.
2. Enable USB debugging.
3. Connect the phone by USB.
4. Accept the RSA debugging prompt on the phone.
5. From the repo root, verify the device is visible:

```powershell
cd D:\Projects\safepathai_V2\mobile
flutter devices
adb devices -l
```

For the current A30, the device id is:

```text
R58M30TGNXV
```

## 2. Start The Local Backend

Run the API on port `5059`:

```powershell
cd D:\Projects\safepathai_V2\backend
dotnet run --launch-profile http --project src\SafePath.Api\SafePath.Api.csproj
```

Keep this terminal open. Confirm it says:

```text
Now listening on: http://localhost:5059
```

## 3. Forward The Backend Port Over USB

In a second terminal:

```powershell
R9KL2033NWD
cd D:\Projects\safepathai_V2\mobile
adb -s R58M30TGNXV reverse tcp:5059 tcp:5059
```
This lets the phone call the PC backend at `http://127.0.0.1:5059`.

## 4. Run The App On The Phone

```powershell
cd D:\Projects\safepathai_V2\mobile
flutter run -d R58M30TGNXV --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

Use hot restart while Flutter is attached:

```text
R
```

Use hot reload:

```text
r
```

Quit the attached Flutter session:

```text
q
```

## Quick Restart Without Staying Attached

```powershell
cd D:\Projects\safepathai_V2\mobile
adb -s R58M30TGNXV reverse tcp:5059 tcp:5059
adb -s R58M30TGNXV shell am force-stop com.safepath.mobile
flutter run -d R58M30TGNXV --no-resident --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
adb -s R58M30TGNXV shell monkey -p com.safepath.mobile -c android.intent.category.LAUNCHER 1
```

## Troubleshooting

- If `flutter devices` does not show the phone, reconnect USB, unlock the phone, and accept the USB debugging prompt.
- If profile or circle data does not load, make sure the backend terminal is still running and repeat `adb reverse tcp:5059 tcp:5059`.
- If the app can sign in but cannot load `/me` or `/families/mine`, confirm the run command includes `--dart-define=API_BASE_URL=http://127.0.0.1:5059`.
- If Google shows the account chooser but fails after selecting an account, confirm Google Cloud has an Android OAuth client for package `com.safepath.mobile` with this machine's debug SHA-1.
- If you use Wi-Fi instead of USB forwarding, replace the API URL with your PC LAN IP, for example `--dart-define=API_BASE_URL=http://192.168.1.20:5059`.

## 5. Two-Device SOS Verification (03-06 Push + 03-07 Offline Queue)

Needs a second Android phone. The stray line `R9KL2033NWD` sitting above section 3 looks like an orphaned note — possibly this second device's id. Confirm it with `flutter devices` / `adb devices -l` before trusting it; the steps below call it `<DEVICE_B>` until you have.

### 5.1 Connect Both Phones

```powershell
cd D:\Projects\safepathai_V2\mobile
flutter devices
adb devices -l
```

Device A (sender, already documented above): `R58M30TGNXV`
Device B (Guardian): `<DEVICE_B>` — verify against the list above, do not assume it is `R9KL2033NWD` without checking.

### 5.2 Start The Backend And Forward Both Devices

```powershell
cd D:\Projects\safepathai_V2\backend
dotnet run --launch-profile http --project src\SafePath.Api\SafePath.Api.csproj
```

In a second terminal, reverse-forward port `5059` on **both** phones — each USB connection gets its own forward, so this is safe to run for two devices against the same backend:

```powershell
cd D:\Projects\safepathai_V2\mobile
adb -s R58M30TGNXV reverse tcp:5059 tcp:5059
adb -s <DEVICE_B> reverse tcp:5059 tcp:5059
```

### 5.3 Run The App On Both Phones

In two separate terminals:

```powershell
flutter run -d R58M30TGNXV --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

```powershell
flutter run -d <DEVICE_B> --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

### 5.4 Sign In

- Device A: sign in as a regular family member (the one who will trigger SOS).
- Device B: sign in as a **Guardian** in the same family circle (the one who will receive the alert).

### 5.5 Test 1 — FCM Push (closes 03-06 for Android)

1. Background Device B (press Home — do not just switch screens).
2. On Device A, press and hold the SOS button for 3 seconds.
3. Confirm Device B gets a heads-up push notification naming the sender.
4. Tap the notification — confirm it opens directly on the Responder Alert screen for that session.
5. Confirm Device A's delivery chip for Device B flips Queued → Delivered.
6. Repeat steps 1–5 with Device B fully **terminated** (swipe the app away, not just backgrounded) to exercise the cold-start path.

### 5.6 Test 2 — Offline Queue/Retry (closes 03-07's last open item)

1. Put Device A in airplane mode.
2. Hold the SOS button — confirm the session shows "Not sent yet, retrying…" immediately, with the call-contact and copy-location fallback actions visible.
3. Kill Device A's app entirely and reopen it — confirm it resumes the *same* queued session (same session id), not a new one.
4. Turn networking back on — confirm the queued SOS submits automatically with no user action.
5. Check Device B — confirm only one emergency session exists (no duplicate from the retry loop). This step is already single-device-friendly: see 5.7's `GET /sos/{sosSessionId}` command below to check server-side instead of using a second phone.

### 5.7 Single-Device Variant Of Test 1 (No Second Phone Needed)

Test 1 needs two roles — a trigger and a receiver — not two phones. The receiving side genuinely needs one real device (Guardian, backgrounded/terminated). The triggering side can be a direct API call instead of a second phone running the app.

1. Sign in as the Guardian on your one phone (Device B from 5.4) and background or terminate it as in 5.5.
2. Get an access token for the second family-member account via Supabase's password grant, using the `SUPABASE_URL` and `SUPABASE_ANON_KEY` already in `mobile/env.json`:

```bash
curl -X POST "<SUPABASE_URL>/auth/v1/token?grant_type=password" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"email":"<second-account-email>","password":"<second-account-password>"}'
```

Copy `access_token` from the response.

3. Trigger SOS directly against the local backend with that token:

```bash
curl -X POST "http://127.0.0.1:5059/sos/trigger" \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "sosSessionId": "<new-guid>",
    "familyId": "<family-id>",
    "latitude": 30.0444,
    "longitude": 31.2357,
    "accuracyMeters": 10,
    "triggeredAtUtc": "2026-08-05T00:00:00Z"
  }'
```

4. Confirm the push, deep-link, and delivery-status steps from 5.5 (steps 3–5) still hold.
5. To check for a duplicate session instead of using a second phone (5.6 step 5), query it directly:

```bash
curl "http://127.0.0.1:5059/sos/<sosSessionId>" -H "Authorization: Bearer <access_token>"
```

This variant does not re-test the physical press-and-hold gesture — that is already covered by 03-02's own tests — but it exercises everything this verification actually cares about: server-side fan-out, FCM delivery, deep-link tap, and the delivery-status flip.

## 6. Remote Contributor Testing Over An ngrok Tunnel

Use this section when the contributor is on a **different network entirely** — not plugged into this PC by USB, and not on the same Wi-Fi. Neither `adb reverse` (section 3) nor the PC LAN IP fallback (last bullet of Troubleshooting above) can reach the backend across two unrelated networks. An ngrok tunnel gives the local backend on port `5059` a public HTTPS URL any network can call. If the device is on your desk or your Wi-Fi, keep using sections 1-4 instead — they are faster and involve no third-party service.

### 6.1 Install ngrok (One Time, On Your PC)

ngrok is already installed on this machine. For a fresh setup, install it with:

```powershell
winget install ngrok.ngrok
```

Then create a free ngrok account and copy the authtoken from the ngrok dashboard. Register it once with:

```powershell
ngrok config add-authtoken <your-authtoken>
```

The authtoken is stored in ngrok's own config and is registered once per machine, not per session.

### 6.2 Start The Local Backend

Do not start a second backend. Follow section 2 above and leave that terminal open — the tunnel forwards to that same already-running process on port `5059`.

### 6.3 Open The Tunnel

In a second terminal, alongside the section 2 backend terminal:

```powershell
ngrok http 5059
```

ngrok prints a Forwarding line:

```text
Forwarding    https://<subdomain>.ngrok-free.app -> http://localhost:5059
```

Copy the `https://` URL. Keep this terminal open for the whole session — closing it tears down the tunnel.

### 6.4 What To Send The Contributor

All of the items below travel over a private channel (direct message, encrypted file, password-manager share) and never through git — every item is on the do-not-commit list in `docs/CONFIGURATION.md`.

- The current ngrok https URL from 6.3.
- The values from `mobile/env.json` — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_SERVER_CLIENT_ID` — so the contributor can write their own `mobile/env.json`. That file is gitignored and is not present in a fresh clone.
- `mobile/android/app/google-services.json`, only if the contributor needs to test FCM push (section 5.5). It is also gitignored and absent from a fresh clone, so skip it when push is not being tested.

### 6.5 The Contributor's Run Command

The contributor clones the repo, writes their own `mobile/env.json` from the values in 6.4, then runs from their `mobile` directory:

```powershell
flutter run --dart-define-from-file=env.json --dart-define=API_BASE_URL=https://<subdomain>.ngrok-free.app
```

They need no `adb reverse` and no `-d <device-id>` from this repo's device list — their phone or emulator is attached to their own machine, and the API URL is public rather than loopback.

### 6.6 Free-Tier URLs Change Every Session

On the free tier, ngrok assigns a new random subdomain every time the tunnel restarts, so the previously-sent URL goes dead. Each restart means: copy the new https URL from the Forwarding line, re-send it, and have the contributor re-run with the new `--dart-define=API_BASE_URL`. A paid ngrok plan's reserved domain stays stable instead, so the contributor can save the run command once.
