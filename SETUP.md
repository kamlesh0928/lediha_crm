# SETUP - everything you have to do

Follow the parts **in order**. Tick each box. Parts 1 to 6 are enough to run and test the app; parts 7 to 11 finish the
production setup.

> Quick health check at any time (Windows PowerShell, project folder):
> `powershell -ExecutionPolicy Bypass -File scripts\check-setup.ps1`
> It tells you which of the first steps is still missing and never prints your keys.

---

## Part 1 - Fix the Gradle error `25.0.3` (do this first)

**Why it happens:** Gradle 8.14 (used by this project) cannot run on JDK 24/25. If your PC's Java is 25, the build stops with
`What went wrong: 25.0.3`. The project must tell Gradle to use JDK 17 (or 21).

- [ ] Check that JDK 17 exists:
  ```powershell
  Test-Path "D:\Program Files\Java\jdk-17\bin\java.exe"
  ```
  - `True` -> nothing else to do; `android\gradle.properties` already points there.
  - `False` -> use one of these:
    - **Android Studio's own Java (easiest):** open `android\gradle.properties` and change the last line to
      `org.gradle.java.home=C:/Program Files/Android/Android Studio/jbr`
      (use forward slashes; check that this folder exists - older versions call it `jre`).
    - **Install JDK 17:** download "Temurin 17 (LTS)" from adoptium.net, install it, then set
      `org.gradle.java.home=C:/Program Files/Eclipse Adoptium/jdk-17.x.x-hotspot` (your exact folder).
- [ ] Stop old Gradle processes and clean:
  ```powershell
  cd android
  .\gradlew --stop
  cd ..
  flutter clean
  flutter pub get
  ```
- [ ] Optional: tell Flutter itself which JDK to use: `flutter config --jdk-dir "D:\Program Files\Java\jdk-17"`

The first build after this downloads Android build tools and can take **5 to 15 minutes**. That is normal.

---

## Part 2 - Tools on your PC

- [ ] Flutter SDK (stable) - `flutter --version` works in PowerShell.
- [ ] Android Studio with **Android SDK**, **Platform-Tools**, **Build-Tools** and a recent **SDK Platform**
      (Android Studio -> Settings -> Languages & Frameworks -> Android SDK).
- [ ] Accept licences: `flutter doctor --android-licenses` (answer `y`).
- [ ] `flutter doctor` shows no red X for **Android toolchain**.
- [ ] Git installed (`git --version`).

---

## Part 3 - Supabase (database), in the browser

Dashboard names change from time to time; look for the closest label.

1. [ ] supabase.com -> sign in -> **New project**. Name it, choose a strong database password (**save it**), pick the nearest
       region (India: Mumbai). Wait 1-2 minutes.
2. [ ] Left sidebar -> **SQL Editor** -> **New query**. Open `supabase\migrations\0001_schema.sql` in Notepad, copy
       everything, paste, click **Run**. Expect **Success**. Run it **only once** (a second run says "already exists").
3. [ ] **Authentication -> Users -> Add user -> Create new user**: the owner's email and password, tick **Auto Confirm User**.
4. [ ] Make that user the admin: SQL Editor -> new query -> paste (use the same email) -> Run:
       ```sql
       insert into public.profiles (id, full_name, email, role)
       select id, 'Owner Name', email, 'admin' from auth.users
       where email = 'owner@example.com';
       ```
5. [ ] Before real employees use the app: **Authentication -> Sign In / Providers** -> turn **OFF**
       "Allow new users to sign up".

---

## Part 4 - Keys (use the PUBLISHABLE key)

The old "anon" key is deprecated. The app uses the **publishable** key.

1. [ ] Supabase -> **Project Settings** (gear) -> **API Keys** -> tab **Publishable and secret API keys**.
       If there is no publishable key, click **Create new API Keys**.
2. [ ] Copy the **Publishable key** (`sb_publishable_...`) and the **Project URL** (`https://xxxx.supabase.co`;
       shown under Project Settings -> Data API, or behind the **Connect** button).
3. Never copy the **secret** key (`sb_secret_...`) into the app. It is only for the backup job (Part 9).

---

## Part 5 - Give the app its settings

The simplest way (no run flags needed):

- [ ] Create the file `assets\config\env.json` (copy `env.json.example` and edit):
  ```powershell
  Copy-Item env.json.example assets\config\env.json
  notepad assets\config\env.json
  ```
  ```json
  {
    "SUPABASE_URL": "https://xxxx.supabase.co",
    "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxxxxxxx"
  }
  ```
  Already have a working `env.json` in the project root? Just copy it: `Copy-Item env.json assets\config\env.json`.
- [ ] Check it is private: `git status` must **not** list `env.json`. (It is git-ignored.)
- [ ] **Stop** the app and press **Run** again whenever you change this file (hot reload does not reload assets).

(Alternative for release builds / CI: `--dart-define-from-file=env.json`; both ways are supported.)

---

## Part 6 - Run the app

### Option A - Android emulator
- [ ] Android Studio -> **Device Manager** -> **Create device** -> Pixel (any) -> system image **API 34 or 35 with Google Play**
      (download it) -> Finish -> press the green play button.
      If it will not start, enable virtualisation in BIOS and "Windows Hypervisor Platform" in Windows Features.
- [ ] Choose the emulator in the device list at the top of Android Studio, select `main.dart`, press **Run**.
- [ ] To test location: emulator side bar `...` -> **Location** -> set a point -> **Send**.

### Option B - Your phone (your device shows as CPH2531, an Oppo/Realme phone)
- [ ] Settings -> About phone -> tap **Build number** 7 times (turns on Developer options).
- [ ] Settings -> Additional settings -> **Developer options**: turn on **USB debugging**.
      On Oppo/Realme (ColorOS) also turn on **Install via USB** (and **USB debugging (Security settings)** if shown).
- [ ] Use a data cable, set USB mode to **File transfer**, tap **Allow** on the "Allow USB debugging?" prompt.
- [ ] `flutter devices` must list your phone. Select it at the top of Android Studio, press **Run**.
- [ ] If the install is blocked ("INSTALL_FAILED_USER_RESTRICTED"), allow the install in the pop-up on the phone, or switch on
      "Install via USB" as above.

### What you should see
- [ ] The **login screen** (teal TV icon). If you see **"setup needed"** instead, Part 5 is not finished.
- [ ] Sign in with the admin email and password from Part 3.

---

## Part 7 - First test (10 minutes)

- [ ] Add a lead (Leads -> Add lead). Add a second lead with the same phone number: you should get a duplicate warning.
- [ ] Open the lead -> Schedule follow-up -> type **Delivery** -> see it under Follow-ups -> Delivery.
- [ ] More -> Income & expenses -> add one income and one expense.
- [ ] **Offline test:** turn on airplane mode, add a lead (the cloud icon shows a number), turn airplane mode off: the number goes to 0.
- [ ] More -> Export ALL data (CSV): a share sheet opens.

---

## Part 8 - Employees

Create the server function once so the admin can add employees inside the app:

1. [ ] Supabase -> **Edge Functions** -> **Deploy a new function** -> **Via Editor**. Name: `manage-employee`.
       Delete the sample code, paste all of `supabase\functions\manage-employee\index.ts`, **Deploy**.
2. [ ] Open the function -> **Details** -> switch **Verify JWT** **OFF** (required with the new keys; the function checks the
       caller is an admin itself).
3. [ ] In the app: More -> Employees -> Add employee. Test by signing in as that employee on a second phone or emulator.

Without the function you can still create an employee by hand: Authentication -> Users -> Add user, then in SQL Editor:
```sql
insert into public.profiles (id, full_name, email, phone, role)
select id, 'Employee Name', email, '9876543210', 'employee' from auth.users where email = 'emp@example.com';
```

---

## Part 9 - Nightly backup (GitHub)

1. [ ] Create a **private** GitHub repository and push the project (`git status` must not show `env.json`).
2. [ ] Supabase -> Project Settings -> API Keys -> create a **Secret key** named `backup` and copy it.
3. [ ] GitHub repo -> Settings -> Secrets and variables -> Actions -> **New repository secret**:
       `SUPABASE_URL` = your project URL, `SUPABASE_SECRET_KEY` = the `sb_secret_...` key (no quotes, no spaces).
4. [ ] Actions tab -> **nightly-backup** -> **Run workflow**. When it turns green, open the run and download the artifact
       (one CSV per table). It then runs every night at 02:00 India time and keeps 30 days.

---

## Part 10 - Facebook / Instagram / WhatsApp leads (optional, can wait)

1. [ ] Deploy `supabase\functions\meta-webhook\index.ts` like Part 8 (name `meta-webhook`). **Verify JWT must be OFF.**
2. [ ] Edge Functions -> **Secrets** -> add `META_VERIFY_TOKEN` (any long random text you invent), `META_APP_SECRET`,
       `META_PAGE_ACCESS_TOKEN`.
3. [ ] developers.facebook.com -> create an app (type Business) -> add **Webhooks**. Callback URL:
       `https://YOUR_REF.supabase.co/functions/v1/meta-webhook`, verify token = your `META_VERIFY_TOKEN`.
       Subscribe the Page to `leadgen`; WhatsApp to `messages`; Instagram / Messenger to `messages`.
4. [ ] In your lead forms name the custom questions `tv_brand`, `tv_model`, `tv_issue` so they fill those fields.
5. [ ] Meta's app review and business verification can take days to weeks. Use Meta's test mode meanwhile.
6. [ ] See what arrived in the app: More -> "Facebook / Instagram / WhatsApp log".

---

## Part 11 - Release builds

### Android APK for employees
1. [ ] Create a signing key **outside** the project (type `yes` when asked "Is CN=... correct?"):
       ```powershell
       mkdir D:\Flutter_Projects\keys
       keytool -genkey -v -keystore D:\Flutter_Projects\keys\lediha-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lediha
       ```
       **Back up that file and its passwords.** If you lose them you can never update the installed app.
2. [ ] Create `android\key.properties` (git-ignored):
       ```
       storePassword=YOUR_PASSWORD
       keyPassword=YOUR_PASSWORD
       keyAlias=lediha
       storeFile=D:/Flutter_Projects/keys/lediha-release.jks
       ```
3. [ ] `flutter build apk --release`  ->  `build\app\outputs\flutter-apk\app-release.apk`
       (your `assets\config\env.json` is bundled automatically). Share the APK by WhatsApp or Drive; employees must allow
       "Install unknown apps".

### iPhone
- [ ] You need a **Mac with Xcode** (iPhone apps cannot be built on Windows).
- [ ] TestFlight / App Store needs the **Apple Developer Program, about USD 99 per year** (check Apple's site). A free Apple ID only
      runs the app on your own iPhone for 7 days.
- [ ] On the Mac: copy `assets/config/env.json`, open `ios/Runner.xcworkspace` in Xcode -> Runner -> Signing & Capabilities ->
      select your Team -> `flutter build ipa` -> upload with Xcode / Transporter -> invite employees in TestFlight.

---

## Part 12 - Permission pop-ups (nothing to configure)

The app never shows a system permission prompt without explaining it first.

- [ ] After the first sign-in you see "Permissions this app uses", then a short explanation (why, when, what happens if you say no) before each phone prompt.
- [ ] Employees can review and change permissions any time: **More -> App permissions**.
- [ ] To see the first-run pop-up again: phone Settings -> Apps -> LEDiHA CRM -> Storage -> Clear data.

---

## Part 13 - Import existing customers from a CSV file (admin)

- [ ] Run `supabase\migrations\0002_push_and_import.sql` once in the Supabase SQL Editor (after 0001). It also stops the server from sending one alert per imported lead.
- [ ] In the app: **More -> Import leads (CSV) -> Get sample file** to see the format. Required columns: `name`, `phone`.
- [ ] In Excel save as **CSV UTF-8**, and format the phone column as **Text** (otherwise Excel writes 9.87E+09).
- [ ] Choose the file, check the preview (new / duplicate / problems), choose who to assign them to, tap **Import**.

---

## Part 14 - Push notifications (Android; optional)

Alerts for new leads, tasks and chat messages even when the app is closed. Skip this part if you do not need it yet; the app works without it.

1. [ ] Firebase console (console.firebase.google.com, free) -> Add project -> Add app -> **Android**, package name **`com.lediha.lediha_crm`** (must equal `applicationId` in `android\app\build.gradle.kts`).
2. [ ] Download `google-services.json` into `android\app\` (it is git-ignored).
3. [ ] Firebase -> Project settings -> **Service accounts** -> **Generate new private key**. Keep the JSON file private.
4. [ ] Firebase -> Project settings -> Cloud Messaging: "Firebase Cloud Messaging API (V1)" must say **Enabled**.
5. [ ] Supabase -> Edge Functions -> **Secrets**: `PUSH_WEBHOOK_SECRET` = a long random text you invent; `FCM_SERVICE_ACCOUNT` = the whole content of the JSON file.
6. [ ] Edge Functions -> Deploy a new function -> Via Editor -> name `send-push` -> paste `supabase\functions\send-push\index.ts` -> Deploy -> Details -> **Verify JWT OFF**.
7. [ ] SQL Editor (once, with your values; the secret must equal `PUSH_WEBHOOK_SECRET`):
   ```sql
   insert into private.push_settings (id, function_url, secret)
   values (1, 'https://YOUR_REF.supabase.co/functions/v1/send-push', 'THE_SAME_RANDOM_TEXT')
   on conflict (id) do update set function_url = excluded.function_url, secret = excluded.secret;
   ```
8. [ ] Stop the app and Run again on a real phone (hot reload is not enough). Sign in as an employee, allow notifications, close the app.
9. [ ] Test: as admin assign a lead to that employee, or run
   ```sql
   insert into public.notifications (user_id, title, body)
   select id, 'Test alert', 'Push works' from public.profiles where email = 'emp@example.com';
   ```
   Nothing arrives? Run `select * from net._http_response order by created desc limit 5;` and read Edge Functions -> send-push -> Logs. 403 = the two secrets differ; 500 = `FCM_SERVICE_ACCOUNT` is wrong.

iPhone push needs an Apple Developer account, `GoogleService-Info.plist`, and permission flags in `ios/Podfile` (`PERMISSION_NOTIFICATIONS=1`, `PERMISSION_LOCATION=1`). Do it later on a Mac.

---

## Before going live - checklist

- [ ] Public sign-up is OFF (Part 3, step 5).
- [ ] Each employee has their own login; the admin account has a strong password.
- [ ] Employees were told about location recording and agreed (written consent).
- [ ] The nightly backup ran at least once and you opened a CSV from it.
- [ ] The signing key and its passwords are saved in two places.
- [ ] `git status` shows no `env.json`, `key.properties` or `.jks` files.
- [ ] Employees saw the permission pop-ups and chose their answers (More -> App permissions).
- [ ] Employees allowed notifications and set battery to "Unrestricted" for the app (keeps location running).

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `What went wrong: 25.0.3` | Gradle is running on JDK 25. Do Part 1. |
| `Value ... given for org.gradle.java.home is invalid` | The JDK path does not exist. Fix the path in `android\gradle.properties` (Part 1). |
| App shows "setup needed" | `assets\config\env.json` missing or wrong. Part 5; stop and Run again. |
| Login: "Invalid API key" / "Invalid login credentials" | Use the publishable key and the exact Project URL; check the email and password; the user must be Auto Confirmed and have a row in `profiles` (Part 3). |
| Login works but screens are empty | Normal for a new database. Add a lead. Check the cloud icon in the top bar. |
| `SDK location not found` | Open the `android` folder once in Android Studio, or run `flutter doctor`; `android\local.properties` is created automatically. |
| `Failed to find Platform SDK ... / compileSdk` | Android Studio -> SDK Manager -> install the latest **Android SDK Platform**; then Run again. |
| `No matching client found for package name` | The package name in `google-services.json` must equal `applicationId` (Part 14). |
| `minSdkVersion ... cannot be smaller` | `android\app\build.gradle.kts` must contain `maxOf(flutter.minSdkVersion, 23)`. |
| `Execution failed ... License for package ... not accepted` | `flutter doctor --android-licenses` and answer `y`. |
| `flutter devices` does not list the phone | Different cable, USB mode **File transfer**, accept the debugging prompt, enable "Install via USB" on Oppo/Realme. |
| `INSTALL_FAILED_USER_RESTRICTED` | Allow the install on the phone or enable "Install via USB". |
| Hundreds of "Target of URI doesn't exist" errors | Run `flutter pub get`; check `pubspec.yaml` is the project's. |
| `git status` shows `env.json` | `git rm --cached env.json`, commit; the `.gitignore` must be saved as UTF-8 in the project root. |
| Employee changes do not arrive | More -> "Some changes could not sync" shows the reason (usually a lead was reassigned). |
| Backup job fails (401/403) | The GitHub secret must be a Supabase **secret** key (`sb_secret_...`), no quotes or spaces. |
| Location not recorded | Allow location (and notifications) for the app, switch GPS on, set battery to "Unrestricted". |
| Supabase project paused | Free projects pause after about a week of no use: open the dashboard and click Restore. Daily use prevents it. |

Still stuck? Copy the **full red error text** (not a screenshot) and share it.
