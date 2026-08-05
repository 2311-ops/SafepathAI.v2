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
5. Check Device B — confirm only one emergency session exists (no duplicate from the retry loop).
