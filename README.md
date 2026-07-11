# SafePath AI

SafePath AI is a software-only family safety platform built as a monorepo:

- `mobile/` - Flutter mobile app for Android/iOS.
- `backend/` - ASP.NET Core Web API using Clean Architecture.
- `.planning/` - GSD planning state, roadmap, phase plans, summaries, debug sessions, and project context.

The product goal is family safety with secure auth, family circles, live location, history, privacy controls, geofencing, an always-fast SOS path, explainable AI analytics, and optional health/wellness features.

## Current Project State

Last checked with GSD on 2026-07-11.

| Area | State |
| --- | --- |
| Project | SafePath AI |
| Repository branch | `master` |
| Remote | `origin` -> `https://github.com/2311-ops/SafepathAI.v2.git` |
| Overall phase progress | About 94% by plan/summary count |
| Phase 1 | Backend & Auth Foundation has 14/14 plans executed, but canonical verification is missing |
| Phase 01.1 | Animated Logo Splash Screen has 1/2 formal plans summarized; implementation fixes are in progress |
| Next planned phase | Phase 2: Real-Time Location, History & Privacy |

Recent working fixes include:

- Android/native launch splash no longer shows a plain white screen.
- Flutter startup splash is visible on slower physical Android startup.
- Android routing now respects the intended splash route instead of skipping to `/`.
- USB mobile API configuration supports physical-device local backend calls.
- Google sign-in now passes both the Google ID token and access token to Supabase.
- Mobile tests pass locally (`105` Flutter tests at the last verification).

Known project-state caveat:

- GSD still reports Phase 1 verification as missing. Before advancing deeply into Phase 2, run verification or execution routing for Phase 1/01.1 so GSD state catches up with the implemented code.

## Local Setup

### Backend

```powershell
cd D:\Projects\safepathai_V2\backend
dotnet restore
dotnet build SafePath.sln
dotnet run --launch-profile http --project src\SafePath.Api\SafePath.Api.csproj
```

The local API should listen on:

```text
http://localhost:5059
```

### Mobile

```powershell
cd D:\Projects\safepathai_V2\mobile
flutter pub get
flutter analyze
flutter test
```

To run on a USB Android phone, use [start_mobile.md](start_mobile.md). The short version is:

```powershell
cd D:\Projects\safepathai_V2\mobile
adb reverse tcp:5059 tcp:5059
flutter run -d <DEVICE_ID> --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

Do not commit `mobile/env.json`, backend `.env`, client secret JSON files, logs, or screenshots.

## GSD Command Map

GSD is the project workflow system under `.planning/`.

Depending on the agent surface, commands may appear as slash commands (`/gsd-progress`) or skill names (`$gsd-progress`). Use the spelling your current tool supports; the workflow intent is the same.

Common commands:

| Command | Use |
| --- | --- |
| `/gsd-progress` | Show project state and next recommended action |
| `/gsd-progress --next` | Let GSD route to the next logical workflow |
| `/gsd-discuss-phase <N>` | Gather context and clarify a phase before planning |
| `/gsd-ui-phase <N>` | Generate a UI design contract for UI-heavy phases |
| `/gsd-plan-phase <N>` | Produce executable phase plans |
| `/gsd-execute-phase <N>` | Execute existing plans for a phase |
| `/gsd-verify-work <N>` | Run user acceptance / verification checks |
| `/gsd-debug <issue>` | Start a persistent debug session |
| `/gsd-docs-update` | Generate or verify docs against the codebase |
| `/gsd-complete-milestone` | Archive a completed milestone and prepare the next one |

## Recommended Next GSD Steps

Run these from the repo root.

1. Check current state:

   ```text
   /gsd-progress
   ```

2. Reconcile Phase 1 verification debt:

   ```text
   /gsd-execute-phase 01
   ```

3. Finish the inserted splash phase:

   ```text
   /gsd-execute-phase 01.1
   /gsd-verify-work 01.1
   ```

4. Start Phase 2 when Phase 1 and 01.1 are verified:

   ```text
   /gsd-discuss-phase 2
   /gsd-ui-phase 2
   /gsd-plan-phase 2
   /gsd-execute-phase 2
   /gsd-verify-work 2
   ```

5. Continue through the roadmap:

   ```text
   /gsd-progress --next
   ```

## Branch Per Phase Workflow

Use one Git branch per phase. Keep `master` as the integration branch.

### 1. Start From A Clean Master

```powershell
git checkout master
git pull origin master
git status
```

If `git status` is not clean, commit or stash unrelated local work before starting a new phase branch.

### 2. Create A Phase Branch

Use a readable branch name:

```powershell
git checkout -b phase/02-real-time-location-history-privacy
```

Suggested branch names:

- `phase/01-backend-auth-foundation`
- `phase/01-1-animated-logo-splash-screen`
- `phase/02-real-time-location-history-privacy`
- `phase/03-sos-fast-path`
- `phase/04-geofencing`
- `phase/05-ai-analytics-dashboard`
- `phase/06-signature-safety-features`
- `phase/07-health-wellness`

### 3. Run GSD On That Branch

For a new phase:

```text
/gsd-discuss-phase 2
/gsd-ui-phase 2
/gsd-plan-phase 2
/gsd-execute-phase 2
/gsd-verify-work 2
```

For an existing phase with plans already written:

```text
/gsd-execute-phase <phase-number>
/gsd-verify-work <phase-number>
```

For a bug discovered during the phase:

```text
/gsd-debug Describe the bug and expected behavior
```

### 4. Commit The Phase Work

```powershell
git status
git add <changed-files>
git commit -m "phase 02: implement real-time location foundation"
```

Keep generated logs, screenshots, local secrets, and build outputs out of the commit.

### 5. Push The Phase Branch

```powershell
git push -u origin phase/02-real-time-location-history-privacy
```

Open a pull request or merge locally after review:

```powershell
git checkout master
git pull origin master
git merge --no-ff phase/02-real-time-location-history-privacy
git push origin master
```

### 6. Move To The Next Phase

After merge, ask GSD for the next route:

```text
/gsd-progress --next
```

Then create the next phase branch and repeat the same cycle.

## Verification Commands

Mobile:

```powershell
cd D:\Projects\safepathai_V2\mobile
flutter analyze
flutter test
```

Backend:

```powershell
cd D:\Projects\safepathai_V2\backend
dotnet test SafePath.sln
```

GSD project state:

```text
/gsd-progress --forensic
```

Docs check:

```text
/gsd-docs-update --verify-only
```

## Safety Notes

- Never commit Supabase service-role keys, Google OAuth client secrets, local `.env` files, screenshots containing personal data, or generated logs.
- Keep API secrets in `mobile/env.json` or backend `.env` locally only.
- Treat `.planning/PROJECT.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` as the source of truth for project state.
- Use GSD verification before marking a phase complete; executed plans are not the same thing as a verified phase.
