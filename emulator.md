# Running SafePath on the Android Emulator

This project now has an Android emulator (AVD) set up so you can run/test the
Flutter app without plugging in a phone over USB.

- **Emulator name:** `Pixel_6_API_36` (Pixel 6 profile, Android 16 / API 36, Google Play image)
- **AVD storage location:** `D:\dev\android-avd` (redirected off the C: drive via the
  `ANDROID_AVD_HOME` environment variable — this applies to *any* AVD you create
  going forward, not just this one)
- **Android SDK location:** `C:\dev\android-sdk`

## One-time setup (already done)

`ANDROID_AVD_HOME` was set as a persistent user environment variable pointing at
`D:\dev\android-avd`. If you ever open a **new machine/profile** or the variable
gets reset, re-set it with:

```powershell
setx ANDROID_AVD_HOME "D:\dev\android-avd"
```

Then restart VS Code / your terminal so the new value is picked up (env vars set
via `setx` don't affect already-open shells or already-open VS Code windows).

## Option A — VS Code Flutter extension (recommended, no extra tools)

1. Open the project in VS Code.
2. Click the device selector in the bottom-right of the status bar (it normally
   shows something like "No Device" or your last-used device).
3. Pick **Pixel_6_API_36** from the list. VS Code boots the emulator
   automatically if it isn't already running (first boot can take 1-2 minutes;
   subsequent boots are faster).
4. Press **F5** (Run > Start Debugging) or use the Run/Debug panel to launch
   the app on it — this gives you hot reload (`r`) and hot restart (`R`) like
   any other device.

If the emulator doesn't appear in the list, restart VS Code once so it re-reads
`ANDROID_AVD_HOME`.

## Option B — "Android iOS Emulator" VS Code extension

Already installed (`DiemasMichiels.emulate`). It adds a dedicated button/command
to launch AVDs without going through Android Studio.

1. `Ctrl+Shift+P` → **"Emulator: Launch Android Emulator"** (or use its status
   bar icon if enabled).
2. Select **Pixel_6_API_36**.
3. Once it's booted, run the app as normal — VS Code's Flutter device picker or
   the integrated terminal will now see it as a connected device.

## Option C — Terminal only (no VS Code UI)

```powershell
# Boot the emulator (leave this window running)
C:\dev\android-sdk\emulator\emulator.exe -avd Pixel_6_API_36

# In a second terminal, once it's booted:
flutter devices        # confirm it shows up as "sdk_gphone64_x86_64"
flutter run             # launches the app on whichever device you pick
```

To check whether the emulator has finished booting from a script/terminal:

```powershell
C:\dev\android-sdk\platform-tools\adb.exe -s emulator-5554 shell getprop sys.boot_completed
# prints "1" once fully booted
```

## Running The SafePath App On The Emulator

Once the emulator is booted (Option A, B, or C above) and shows up in
`flutter devices` as `emulator-5554`, this is the full flow to run the actual
app against the local backend — equivalent to `start_mobile.md`'s USB-phone
flow, but for the emulator.

### 1. Start the local backend

```powershell
cd D:\Projects\safepathai_V2\backend
dotnet run --launch-profile http --project src\SafePath.Api\SafePath.Api.csproj
```

Keep this terminal open. Confirm it says:

```text
Now listening on: http://localhost:5059
```

### 2. Run the app on the emulator

Unlike the USB-phone flow, **you don't need `adb reverse`**. The Android
emulator has a built-in host alias, `10.0.2.2`, that always means "the
machine running the emulator" — so point the app straight at it:

```powershell
cd D:\Projects\safepathai_V2\mobile
flutter run -d emulator-5554 --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://10.0.2.2:5059
```

(`adb -s emulator-5554 reverse tcp:5059 tcp:5059` plus
`--dart-define=API_BASE_URL=http://127.0.0.1:5059` also works, if you'd
rather mirror the USB-phone flow exactly — `10.0.2.2` is just simpler since
it skips the reverse-forward step.)

### 3. While attached

- `r` — hot reload
- `R` — hot restart
- `q` — quit

### Emulator-specific gotchas

- **Google Sign-In**: the emulator's debug keystore has its own SHA-1,
  separate from the physical phone's. If OAuth fails after picking an
  account, confirm the Google Cloud Android OAuth client for
  `com.safepath.mobile` includes the emulator machine's debug SHA-1 too.
- **Location/GPS testing** (live tracking, geofencing, SOS): use Extended
  Controls → Location (see Notes below) instead of `127.0.0.1`/USB tricks —
  it directly feeds simulated coordinates to the app.

## Notes

- The emulator behaves like any other Flutter device: `flutter run`, hot
  reload, breakpoints, and DevTools all work the same as on a USB-connected
  phone.
- Location/GPS-dependent features (live tracking, geofencing, SOS location)
  can be simulated via the emulator's **Extended Controls → Location** panel
  (three-dot icon on the emulator's toolbar) instead of physically moving a
  real device around.
- You can still use your physical device (`SM A075F`) over USB at any time —
  the emulator doesn't replace it, it just removes the "must have a cable
  plugged in" requirement for routine testing.
- First cold boot of a fresh AVD is the slowest (1-3 min); after that, closing
  and reopening the emulator is much faster because it resumes from a saved
  state (unless launched with `-no-snapshot-save`, which was used for this
  verification boot only).
