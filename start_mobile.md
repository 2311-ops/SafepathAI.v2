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
