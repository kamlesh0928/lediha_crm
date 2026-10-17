# LEDiHA CRM (Android + iPhone, Flutter + Supabase, free tier)

Offline-first CRM for a TV repair business. One app for Android and iPhone only (no web/desktop),
two roles (Admin, Employee).

Modules: login and roles, leads (manual + Facebook/Instagram/WhatsApp), follow-up lists
(Due today, Hot leads, Today's pickup, Work pending, Work done, Delivery), tasks, attendance,
employee location, direct messages + team chat, daily income/expenses, reports, notifications,
CSV export, audit log.

> First working draft, NOT yet compiled by the author. If `flutter analyze` shows errors,
> send the full text and they will be fixed.

## The whole process in 5 phases (do them in this order)

| Phase | Goal | Needs |
|---|---|---|
| 1 | Create the database in Supabase | Browser |
| 2 | Run the app on your phone, log in as admin | Flutter, phone |
| 3 | Let the admin create employee accounts from the app | Supabase dashboard |
| 4 | Nightly backup + Facebook/Instagram/WhatsApp leads | GitHub, Meta (can wait) |
| 5 | Signed APK for employees | keytool |

Phases 1 and 2 are enough to test almost everything.

---

## Phase 1 - Supabase (all in the browser, no installs)
Dashboard labels change now and then; if a name differs slightly, look for the closest one.

1. supabase.com -> sign in -> **New project**. Choose a name, a strong database password
   (save it), and the nearest region (India: Mumbai). Click Create and wait 1-2 minutes.
2. Left sidebar -> **SQL Editor** -> **New query**. Open `supabase/migrations/0001_schema.sql`
   in Notepad, copy everything, paste, click **Run**. You should see "Success". Any red error:
   copy the message and ask for help.
3. Left sidebar -> **Authentication** -> **Users** -> **Add user** -> **Create new user**.
   Enter the owner's email + password and tick **Auto Confirm User**.
4. Make that user the admin. SQL Editor -> New query -> paste (use the same email) -> Run:
   ```sql
   insert into public.profiles (id, full_name, email, role)
   select id, 'Owner Name', email, 'admin' from auth.users
   where email = 'owner@example.com';
   ```
5. **Project Settings** (gear icon) -> **API Keys**. Copy the **Project URL** (looks like
   `https://abcdxyz.supabase.co`) and the **Publishable key** (starts with `sb_publishable_`).
   If the app later says "invalid API key", use the **anon** key from the "Legacy API keys" tab instead.
   Never put the `secret` / `service_role` key in the app.
6. Before real employees use it: **Authentication** -> **Sign In / Providers** -> turn OFF
   "Allow new users to sign up".

## Phase 2 - Run the app (Windows / PowerShell)
```powershell
cd D:\Flutter_Projects\lediha_crm
Copy-Item env.json.example env.json
notepad env.json            # paste your Project URL and key, save
flutter pub get
flutter analyze             # should show no red errors
flutter run --dart-define-from-file=env.json
```
Do not forget `--dart-define-from-file=env.json`: without it the app has no Supabase address.
- VS Code: press F5 (the included `.vscode/launch.json` passes env.json for you).
- Android Studio: Run -> Edit Configurations -> "Additional run args" -> `--dart-define-from-file=env.json`.

Phone: enable Developer options + USB debugging, connect by USB, accept the prompt, check `flutter devices`.

### Add iPhone support (if your project was created Android-only)
Run once in the project folder (safe: it only adds the missing `ios` folder):
```powershell
flutter create --org com.lediha --platforms=android,ios .
```
New project instead? `flutter create --org com.lediha --platforms=android,ios lediha_crm`.

### iPhone - what you must know
- **You cannot build or run the iPhone app on Windows.** Apple requires a Mac with Xcode.
  Everything else (writing code, Supabase, Android testing) works on Windows.
- To put the app on a real iPhone: Mac + Xcode, then `flutter run --dart-define-from-file=env.json`
  with the phone connected. A free Apple ID lets you test on your own iPhone, but the app expires after 7 days.
- To give it to employees' iPhones (TestFlight or App Store) you need the **Apple Developer Program,
  about USD 99 per year** - the only unavoidable paid item for iPhone. (Check the current price on developer.apple.com.)
- No Mac? Options: borrow/rent one, or use a cloud Mac build service. GitHub Actions has a manual
  `ios-build` workflow that only checks the code compiles for iPhone.
- Add the keys from `ios_patch/Info.plist.snippet.xml` to `ios/Runner/Info.plist`. The
  `UIBackgroundModes` key is REQUIRED or the app crashes when location tracking starts.
- In Xcode: open `ios/Runner.xcworkspace` -> Runner -> Signing & Capabilities -> choose your Team,
  and set a unique Bundle Identifier (for example `com.lediha.crm`).
- iPhone location: updates continue in the background while the app has been opened and the employee
  stays checked in, with a blue indicator in the status bar. If the employee force-closes the app,
  tracking stops. iPhones may send fewer points when the phone is not moving.

Android manifest: open `android/app/src/main/AndroidManifest.xml` and add the lines from
`android_patch/AndroidManifest.snippet.xml` (permissions + queries). Without them location,
Call and WhatsApp buttons will not work.

## Phase 3 - Let the admin create employees (Edge Function, no CLI needed)
The app cannot create logins by itself (that needs a secret key), so a small server function does it.
1. Supabase -> **Edge Functions** -> **Deploy a new function** -> **Via Editor**.
2. Name: `manage-employee`. Delete the sample code, paste all of
   `supabase/functions/manage-employee/index.ts`, click **Deploy**.
3. Open the function -> **Details** and switch **Verify JWT** OFF (the function checks the
   caller is an admin itself).
   Until this is done, create employees manually: Authentication -> Users -> Add user, then run in SQL Editor:
```sql
insert into public.profiles (id, full_name, email, phone, role)
select id, 'Employee Name', email, '9876543210', 'employee' from auth.users where email = 'emp@example.com';
```

Optional CLI route (only if you prefer): you need either Node.js (`npx supabase login`) or Scoop
(`scoop bucket add supabase https://github.com/supabase/scoop-bucket.git` then `scoop install supabase`).
`npm install -g supabase` does NOT work.
Then: `npx supabase login`, `npx supabase link --project-ref YOUR_REF`,
`npx supabase functions deploy manage-employee --no-verify-jwt`.

## Phase 4 - Backup and Meta leads (can wait until the app works)
### Nightly backup
1. Create a PRIVATE GitHub repository and push this project (env.json is ignored, see below).
2. GitHub repo -> Settings -> Secrets and variables -> Actions -> New secret:
   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (Supabase -> API Keys -> secret/service_role key).
3. Actions tab -> "nightly-backup" -> Run workflow once to test. CSVs appear as a downloadable
   artifact (kept 30 days).

### Facebook / Instagram / WhatsApp leads
1. Deploy `supabase/functions/meta-webhook/index.ts` the same way as Phase 3 (name `meta-webhook`),
   but Verify JWT must be OFF (Meta cannot send a Supabase login).
2. Edge Functions -> **Secrets** (or Project Settings -> Edge Functions): add
   `META_VERIFY_TOKEN` (any long random text you invent), `META_APP_SECRET`, `META_PAGE_ACCESS_TOKEN`.
3. In developers.facebook.com create an app, add Webhooks, callback URL
   `https://YOUR_REF.supabase.co/functions/v1/meta-webhook`, verify token = your `META_VERIFY_TOKEN`.
   Subscribe the Page to `leadgen` (lead forms), WhatsApp to `messages`.
4. Meta app review / business verification can take days to weeks. Use Meta test mode meanwhile.
5. Check results in the app: More -> "Facebook / Instagram / WhatsApp log".

## Phase 5 - Signed APK for employees
You only need this when you hand the app to employees. For your own testing skip it.
1. Make a folder OUTSIDE the project and create the key (type `yes` when asked "is ... correct?"):
   ```powershell
   mkdir D:\Flutter_Projects\keys
   keytool -genkey -v -keystore D:\Flutter_Projects\keys\lediha-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lediha
   ```
   Back up that .jks file and its passwords somewhere safe. Lose them = you can never update the installed app.
2. Create `android/key.properties` (this file is git-ignored):
   ```
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=lediha
   storeFile=D:/Flutter_Projects/keys/lediha-release.jks
   ```
3. Edit `android/app/build.gradle.kts`:
    - at the very top add
      ```kotlin
      import java.util.Properties
      import java.io.FileInputStream
 
      val keystoreProperties = Properties()
      val keystorePropertiesFile = rootProject.file("key.properties")
      if (keystorePropertiesFile.exists()) {
          keystoreProperties.load(FileInputStream(keystorePropertiesFile))
      }
      ```
    - inside `android { ... }` add
      ```kotlin
      signingConfigs {
          create("release") {
              keyAlias = keystoreProperties["keyAlias"] as String
              keyPassword = keystoreProperties["keyPassword"] as String
              storeFile = keystoreProperties["storeFile"]?.let { file(it) }
              storePassword = keystoreProperties["storePassword"] as String
          }
      }
      ```
    - inside `buildTypes { release { ... } }` change `signingConfig` to
      `signingConfig = signingConfigs.getByName("release")`
4. Build: `flutter build apk --release --dart-define-from-file=env.json`
   The file is `build\app\outputs\flutter-apk\app-release.apk`. Send it to employees (WhatsApp/Drive);
   they must allow "install unknown apps".

### iPhone release (on a Mac)
```bash
flutter build ipa --dart-define-from-file=env.json
```
Then upload with Xcode (Product -> Archive -> Distribute) or the Transporter app, and invite employees
through TestFlight in App Store Connect. Needs the paid Apple Developer account.

---

## Keeping env.json out of Git
`.gitignore` already lists `env.json`. If Git still shows it:
```powershell
git check-ignore -v env.json     # prints the rule if it is ignored; prints nothing if not
git ls-files env.json            # prints env.json if Git is ALREADY tracking it
```
- If it prints `env.json` -> Git tracks it, and ignore rules do not apply to tracked files. Fix:
  `git rm --cached env.json` then `git commit -m "stop tracking env.json"`.
- If `.gitignore` is missing the line: `Add-Content .gitignore "`nenv.json"`.
- `.gitignore` must be saved as UTF-8 and sit in the project root (next to pubspec.yaml). PowerShell 5's
  `echo ... > .gitignore` writes UTF-16, which Git ignores completely; use `Add-Content` or Notepad (UTF-8).
- If env.json was ever pushed to GitHub: it only holds the public key, so risk is low, but never commit
  the secret/service_role key; if that happened, rotate it in Supabase.

## How "no data loss" works
1. Every save goes to the phone's local database first (works with no internet).
2. A sync service uploads waiting changes and downloads new data every 60 s, when the network
   returns, when the app opens, and after each save.
3. Rows are never hard-deleted and every change is written to `audit_logs`.
4. Nightly GitHub backup (Phase 4) is your real safety net: the free Supabase plan has no managed backups.
5. Admin phone: More -> "Export ALL data (CSV)", plus an automatic daily copy when the admin opens the app.

## Employee location - read before you ship
- Saved only between check-in and check-out, about every 5 minutes.
- Employee sees a consent message; Android shows a permanent notification and iPhone shows a blue status-bar indicator while tracking.
- Get written consent; India's DPDP Act applies to personal data. The PRD said "no GPS", so the owner must approve this.
- Ask employees to allow notifications and set battery to "Unrestricted" for the app.

## Folder map
```
lib/core/        constants (statuses, follow-up lists, shift time), helpers, shared widgets
lib/data/        store.dart (local db + outbox), sync_service.dart, app_auth.dart, csv_export.dart
lib/features/    auth, home, leads, followups, tasks, attendance, location, chat, finance, employees, more
supabase/        migrations (tables + security rules), functions (meta-webhook, manage-employee)
backup/          nightly CSV backup script      .github/workflows/  CI + nightly backup
ios_patch/       Info.plist keys for iPhone      android_patch/   manifest lines for Android
.vscode/         launch.json (passes env.json when you press F5)
```

## Known gaps
Last-save-wins edits, no push notifications yet (in-app alerts only), shift time is a constant in
`lib/core/constants.dart`, no CSV lead import yet, no automated tests.
