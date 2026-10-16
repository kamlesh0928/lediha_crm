# LEDiHA CRM (Android, Flutter + Supabase, all free-tier)

Offline-first CRM for a TV repair business. One app, two roles (Admin, Employee).

**Modules:** login and roles · leads (manual + Facebook/Instagram/WhatsApp) · follow-up lists
(Due today, Hot leads, Today's pickup, Work pending, Work done, Delivery) · tasks · attendance ·
employee location · direct messages + team chat · daily income/expenses · reports · notifications ·
CSV export · audit log.

> **Status: first working draft. It has NOT been compiled or run yet** (it was written without a
> Flutter SDK). Expect to fix a few small compile errors on the first `flutter run`. Test every
> screen on a real phone before giving it to employees.

## How "no data loss" works
1. Every save goes to the phone's local database first (works with no internet).
2. A sync service uploads the waiting changes (the "outbox") and downloads new data, every 60 s,
   when the network returns, when the app opens, and after each save.
3. Rows are never hard-deleted (soft delete only) and every change is written to `audit_logs`.
4. **Nightly server backup:** `.github/workflows/nightly-backup.yml` downloads every table as CSV
   into a GitHub artifact (kept 30 days). This is your real safety net - the free Supabase plan
   has no managed backups.
5. **CSV on the admin phone:** More -> "Export ALL data (CSV)", plus an automatic copy once a day
   whenever the admin opens the app.

## 1. Supabase (free)
1. supabase.com -> New project (pick the Mumbai/Singapore region).
2. SQL Editor -> paste `supabase/migrations/0001_schema.sql` -> Run.
3. Authentication -> Users -> Add user (tick *Auto Confirm*) for the owner. Then run the
   `insert into public.profiles ...` snippet at the bottom of the SQL file to make that user admin.
4. Authentication -> Providers -> Email: turn **off** "Allow new users to sign up" (only admins create accounts).
5. Project Settings -> API: copy the project URL and the anon/publishable key into `env.json`
   (copy `env.json.example`). Never put the service_role key in the app.
6. Install the Supabase CLI, then:
   ```bash
   supabase login
   supabase link --project-ref YOUR_REF
   supabase functions deploy manage-employee
   supabase functions deploy meta-webhook --no-verify-jwt
   supabase secrets set META_VERIFY_TOKEN=choose-a-long-random-string META_APP_SECRET=... META_PAGE_ACCESS_TOKEN=...
   ```
Free projects pause after about a week with no activity; daily use and the nightly backup job prevent that.

## 2. Flutter app
```bash
flutter create --org com.lediha --platforms=android lediha_crm
# copy this repo's lib/, pubspec.yaml, analysis_options.yaml, supabase/, backup/, .github/, README.md,
# env.json.example and .gitignore over the new folder (overwrite when asked)
cd lediha_crm
cp env.json.example env.json        # then fill in your values
flutter pub get
```
Edit `android/app/src/main/AndroidManifest.xml` as shown in `android_patch/AndroidManifest.snippet.xml`.
If `flutter pub get` reports a version conflict, run `flutter pub upgrade --major-versions`.

Run on a phone: `flutter run --dart-define-from-file=env.json`

Release APK (share it directly with employees, no Play Store needed):
```bash
keytool -genkey -v -keystore ~/lediha-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lediha
# create android/key.properties and wire signing in android/app/build.gradle (Flutter docs: "Build and release an Android app")
flutter build apk --release --dart-define-from-file=env.json
```
**Back up the .jks file and its passwords.** Without them you cannot update the installed app.

## 3. Facebook / Instagram / WhatsApp leads
Webhook URL: `https://YOUR_REF.functions.supabase.co/meta-webhook`; verify token = `META_VERIFY_TOKEN`.
1. developers.facebook.com -> create an app (Business type); add **Webhooks**. Set `META_APP_SECRET` from App settings -> Basic.
2. Facebook/Instagram Lead Ads: subscribe the **Page** object to `leadgen`; generate a long-lived Page access token
   (`META_PAGE_ACCESS_TOKEN`). Needs the `leads_retrieval` and `pages_manage_metadata` permissions.
   Name custom form questions `tv_brand`, `tv_model`, `tv_issue` so they map to lead fields.
3. WhatsApp: use the Cloud API test number first; subscribe `messages`. A real number needs Meta Business verification.
4. Instagram/Messenger DMs: subscribe `messages` on the Instagram / Page object (needs app review for live use).
5. Check results in the app: More -> "Facebook / Instagram / WhatsApp log".
Replying to customers from inside the app is not built; staff use the WhatsApp button (click-to-chat).
App review and business verification by Meta can take days to weeks; until then use test mode or CSV import of leads.

## 4. Employee location - read before you ship
- Location is saved only between check-in and check-out, about every 5 minutes (`locationIntervalMinutes`).
- The employee sees a consent message on first check-in, and Android shows a permanent notification while tracking.
- Get written consent from employees and tell them what is recorded (India's DPDP Act applies to personal data).
- The earlier PRD said "no GPS"; this feature is a scope change the owner must approve.
- Map uses OpenStreetMap tiles (free, fine for a small team). If usage grows, switch to a tile provider with a free plan.
- Ask employees to allow notifications and set battery to "Unrestricted" for the app, or Android may stop tracking.
- Phones can fake GPS; treat the data as indicative, not proof.

## 5. Folder map
```
lib/core/        theme helpers, constants (statuses, follow-up lists, shift time), widgets
lib/data/        store.dart (local db + outbox), sync_service.dart, auth_state.dart, csv_export.dart
lib/features/    auth, home(dashboard), leads, followups, tasks, attendance, location, chat,
                 finance, employees, more (reports, notifications, logs, settings)
supabase/        migrations (tables + security rules), functions (meta-webhook, manage-employee)
backup/          nightly CSV backup script      .github/workflows/  CI + nightly backup
```

## 6. Known gaps (planned next)
- Edits are "last save wins"; no merge screen.
- Overdue alerts are shown inside the app only (no push notifications yet; add Firebase Cloud Messaging later - free).
- Settings (shift time, late grace) are constants in `lib/core/constants.dart`.
- CSV import of leads, Excel export, and a lead-source report by campaign are not built yet.
- Password reset is done by the admin (More -> Employees).
- No automated tests yet.
