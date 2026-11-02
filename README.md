# LEDiHA CRM (Android + iPhone, Flutter + Supabase, free tier)

Offline-first CRM for a TV repair business. One app for Android and iPhone, two roles (Admin, Employee).

Modules: login and roles, leads (manual + Facebook/Instagram/WhatsApp), follow-up lists (Due today, Hot leads,
Today's pickup, Work pending, Work done, Delivery), tasks, attendance, employee location, direct messages +
team chat, daily income/expenses, reports, notifications, CSV export, audit log.

> The code has been reviewed but never run end-to-end by its author. Test every screen on a real phone
> before giving it to employees, and send any error text for fixing.

## Quick checklist (what you must configure)

| # | What | Where | Done when |
|---|---|---|---|
| 1 | Supabase project + database tables | Supabase website, SQL Editor | "Success" after running `0001_schema.sql` |
| 2 | First admin login | Supabase: Authentication > Users + one SQL line | You can sign in to the app |
| 3 | `env.json` with URL + **publishable** key | project root | App shows the login screen (not the "setup needed" screen) |
| 4 | Android permissions + Info.plist | already in this project | (nothing to do) |
| 5 | Employee-creation function | Supabase: Edge Functions | Admin can add employees in the app |
| 6 | Nightly backup | GitHub secrets + Actions | Backup artifact appears |
| 7 | Meta leads (Facebook/Instagram/WhatsApp) | Meta developer site + Supabase secrets | Test lead appears in the app |
| 8 | Release signing / iPhone signing | keytool, Xcode | APK / TestFlight build |

Do 1 to 3 first. Everything else can wait until the basics work.

---

## 1. Supabase project (browser only, no installs)
Dashboard labels change now and then; look for the closest name if one differs.

1. supabase.com -> sign in -> **New project**. Pick a name, a strong database password (save it) and the nearest
   region (India: Mumbai). Wait 1-2 minutes.
2. Left sidebar -> **SQL Editor** -> **New query**. Open `supabase/migrations/0001_schema.sql` in Notepad, copy
   everything, paste, click **Run**. Expect "Success". Run it only ONCE (running twice gives "already exists").
   Any red error: copy the message and ask for help.

## 2. First admin login
1. **Authentication** -> **Users** -> **Add user** -> **Create new user**. Enter the owner's email and password and
   tick **Auto Confirm User**.
2. SQL Editor -> New query -> paste (use the same email) -> Run:
   ```sql
   insert into public.profiles (id, full_name, email, role)
   select id, 'Owner Name', email, 'admin' from auth.users
   where email = 'owner@example.com';
   ```
3. Before real employees use the app: **Authentication** -> **Sign In / Providers** -> turn OFF
   "Allow new users to sign up" (only admins create accounts).

## 3. Keys: use the PUBLISHABLE key (the old "anon" key is deprecated)
1. Supabase -> **Project Settings** (gear icon) -> **API Keys** -> tab **Publishable and secret API keys**.
   If you see no publishable key, click **Create new API Keys**.
2. Copy the **Publishable key** (starts with `sb_publishable_`) and the **Project URL**
   (`https://xxxx.supabase.co`, shown under Project Settings > Data API or the Connect button).
3. In the project folder:
   ```powershell
   Copy-Item env.json.example env.json
   notepad env.json
   ```
   ```json
   {
     "SUPABASE_URL": "https://xxxx.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxxxxxxx"
   }
   ```
   (An old `SUPABASE_ANON_KEY` entry still works, but rename it.)
4. Never put the **secret key** (`sb_secret_...`) or the old `service_role` key in the app or in Git.
   The secret key is only for server things: the GitHub backup (section 6) and Supabase itself.

## 4. Run the app
Install: Flutter (stable), Android Studio with the Android SDK, a phone with USB debugging on (or an emulator).
```powershell
cd D:\Flutter_Projects\lediha_crm
flutter doctor              # fix anything marked with a red X for Android
flutter pub get
flutter analyze
flutter test
flutter devices             # your phone must be listed
flutter run --dart-define-from-file=env.json
```
The flag `--dart-define-from-file=env.json` is mandatory. If you forget it the app shows "setup needed".
- **Android Studio:** Run > Edit Configurations > main.dart > **Additional run args** =
  `--dart-define-from-file=env.json` (this zip includes `.idea/runConfigurations/main_dart.xml` with it already set).
- **VS Code:** press F5 (`.vscode/launch.json` already has it).

First test: sign in with the admin email, add a lead, add an employee, check Follow-ups, Tasks, Finance, Chat.
Turn on airplane mode, add a lead (the cloud icon shows a number), turn it off: the number goes to 0.

## 5. Let the admin create employees (Edge Function)
The app cannot create logins by itself (that needs a secret key), so a small server function does it.
1. Supabase -> **Edge Functions** -> **Deploy a new function** -> **Via Editor**. Name: `manage-employee`.
   Delete the sample code, paste all of `supabase/functions/manage-employee/index.ts`, **Deploy**.
2. Open the function -> **Details** -> switch **Verify JWT** OFF. (Required with the new API keys; the function
   checks that the caller is an admin by itself.)
3. In the app: More > Employees > Add employee.

No function yet? Create employees by hand: Authentication > Users > Add user, then in SQL Editor
```sql
insert into public.profiles (id, full_name, email, phone, role)
select id, 'Employee Name', email, '9876543210', 'employee' from auth.users where email = 'emp@example.com';
```
Optional CLI route: needs Node.js (`npx supabase login`) or Scoop; `npm install -g supabase` does not work.

## 6. Nightly backup (GitHub, free)
1. Push the project to a PRIVATE GitHub repository (env.json is git-ignored; check with `git status`).
2. Supabase -> Project Settings -> API Keys -> create a **Secret key** (name it `backup`) and copy it.
3. GitHub repo -> Settings -> Secrets and variables -> Actions -> New repository secret:
   `SUPABASE_URL` = your project URL, `SUPABASE_SECRET_KEY` = the `sb_secret_...` key.
4. Actions tab -> **nightly-backup** -> Run workflow. When it is green, open the run and download the artifact:
   one CSV per table. It then runs every night (02:00 India time) and keeps 30 days.
   (The free Supabase plan has no managed backups, so this job is your safety net.)

## 7. Facebook / Instagram / WhatsApp leads (can wait)
1. Deploy `supabase/functions/meta-webhook/index.ts` like step 5 (name `meta-webhook`). Verify JWT must be OFF.
2. Edge Functions -> **Secrets**: add `META_VERIFY_TOKEN` (any long random text you invent), `META_APP_SECRET`,
   `META_PAGE_ACCESS_TOKEN`. (Names must not start with `SUPABASE_`.)
3. developers.facebook.com -> create an app (Business) -> add **Webhooks**. Callback URL:
   `https://YOUR_REF.supabase.co/functions/v1/meta-webhook`, verify token = your `META_VERIFY_TOKEN`.
   Subscribe the Page to `leadgen`; WhatsApp to `messages`; Instagram/Messenger to `messages`.
4. Name form questions `tv_brand`, `tv_model`, `tv_issue` so they fill those lead fields.
5. Meta app review and business verification can take days to weeks; use Meta's test mode first.
6. See what arrived: More > "Facebook / Instagram / WhatsApp log".

## 8. Release builds
### Android (APK for employees)
1. Create the key OUTSIDE the project (type `yes` when asked "is ... correct?"):
   ```powershell
   mkdir D:\Flutter_Projects\keys
   keytool -genkey -v -keystore D:\Flutter_Projects\keys\lediha-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lediha
   ```
   Back up that file and its passwords. Lose them and you can never update the installed app.
2. Create `android/key.properties` (git-ignored):
   ```
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=lediha
   storeFile=D:/Flutter_Projects/keys/lediha-release.jks
   ```
   `android/app/build.gradle.kts` already uses it when the file exists.
3. `flutter build apk --release --dart-define-from-file=env.json`
   -> `build\app\outputs\flutter-apk\app-release.apk`. Share it by WhatsApp/Drive; employees allow "install unknown apps".

### iPhone
- You cannot build iPhone apps on Windows: it needs a Mac with Xcode.
- Real iPhones (TestFlight/App Store) need the Apple Developer Program, about USD 99 per year (check Apple's site).
  A free Apple ID only runs the app on your own iPhone for 7 days.
- On the Mac: open `ios/Runner.xcworkspace` in Xcode -> Runner -> Signing & Capabilities -> choose your Team,
  then `flutter build ipa --dart-define-from-file=env.json` and upload with Xcode/Transporter; invite staff via TestFlight.
- `Info.plist` already has the location texts, background location and file-sharing keys.

---

## How "no data loss" works
1. Every save goes to the phone's database first (works offline) and waits in an outbox.
2. The sync service uploads the outbox, then downloads changes: every 60 s, when the network returns, when the app
   opens, and after each save. New records use INSERT, edits use UPDATE (so Supabase security rules are respected).
3. If an edit is rejected by the server it stays on the phone and shows under More > "Some changes could not sync".
4. Rows are never hard-deleted; every change is logged in `audit_logs`.
5. Nightly GitHub backup (step 6) + admin CSV: More > "Export ALL data (CSV)" (also saved once a day when the admin opens the app).
6. Do not log out with unsynced changes if you can avoid it (the app warns you). Logging in as a different person on
   the same phone clears the phone's local copy.

## Employee location - read before you ship
- Saved only between check-in and check-out, about every 5 minutes. Admin: More > Team location.
- The employee sees a consent message; Android shows a notification, iPhone a blue status-bar indicator.
- Get written consent (India's DPDP Act). The original PRD said "no GPS", so the owner must approve this.
- Ask employees to allow notifications and set battery to "Unrestricted" for the app. On iPhone, force-closing the
  app stops tracking. GPS can be faked; treat it as indicative.
- Night shifts: a check-out after midnight is matched to the previous day's check-in (up to 16 hours).

## Changing things
- Shift start / late grace / location interval: `lib/core/constants.dart`.
- Follow-up list names: `followupKindLabels` in the same file (database values must stay as they are).

## Troubleshooting
| Symptom | Fix |
|---|---|
| Red screen "setup needed" | Start with `--dart-define-from-file=env.json` (see section 4) |
| "Invalid API key" at login | Use the publishable key (`sb_publishable_...`) and the exact Project URL |
| Hundreds of "Target of URI doesn't exist" errors | `pubspec.yaml` lacks the dependencies: restore this project's file, `flutter pub get` |
| `git` still shows env.json | `git rm --cached env.json`, commit; check `.gitignore` is UTF-8 in the project root |
| Employee changes never arrive | More > "Some changes could not sync" shows the reason; usually a lead was reassigned |
| Build fails with a Java/JDK error | Use JDK 17. Put `org.gradle.java.home=D:/Program Files/Java/jdk-17` (your path) in `C:\Users\<you>\.gradle\gradle.properties`, NOT in the project |
| Backup job: 401/403 | The GitHub secret must be a Supabase **secret** key; no spaces or quotes |

## Folder map
```
lib/core/        constants, helpers, shared widgets, env + setup screen
lib/data/        store.dart (local db + outbox), sync_service.dart, app_auth.dart, csv_export.dart
lib/features/    auth, home, leads, followups, tasks, attendance, location, chat, finance, employees, more
supabase/        migrations (tables + security rules), functions (meta-webhook, manage-employee)
backup/          nightly CSV backup script       .github/workflows/  CI, nightly backup, manual iOS check
```

## Known gaps
Last-save-wins edits, no push notifications (in-app alerts only), no CSV lead import, no replies to WhatsApp/Instagram
from inside the app (use the WhatsApp button), no automated end-to-end tests.
