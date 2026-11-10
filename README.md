# LEDiHA CRM

Offline-first mobile CRM for a TV repair business. One app for **Android and iPhone** with two roles
(**Admin** and **Employee**), built with Flutter on a free-tier Supabase backend.

> **New here?** Follow [SETUP.md](SETUP.md). It lists everything you must do, in order, to run and deploy the app.

---

## Contents
1. [Features](#features)
2. [Technology](#technology)
3. [Architecture](#architecture)
4. [Security model](#security-model)
5. [Data protection and backups](#data-protection-and-backups)
6. [Project structure](#project-structure)
7. [Configuration reference](#configuration-reference)
8. [Quality checks](#quality-checks)
9. [Project status](#project-status)
10. [Cost](#cost)

---

## Features

| Area | What it does |
|---|---|
| **Roles** | Admin sees everything; employees see only their own leads, follow-ups, tasks, attendance and entries. Enforced in the database, not just the screens. |
| **Leads** | Create and edit leads, duplicate-phone warning, assign to staff, status and priority, notes, call and WhatsApp buttons. |
| **Social leads** | Facebook / Instagram lead forms and WhatsApp / Messenger / Instagram messages arrive as leads automatically (Meta webhook). |
| **Follow-up lists** | Due today, Hot leads, Today's pickup, Work pending, Work done, Delivery - with reschedule and "mark done". |
| **Tasks** | Assign, start, complete with a note, reopen with a reason, overdue highlighting. |
| **Attendance** | Check-in / check-out, late flag, admin corrections with a reason, night-shift aware. |
| **Employee location** | Recorded only between check-in and check-out; admin map with the day's route. Needs employee consent. |
| **Messages** | Private chats and a team chat. |
| **Income and expenses** | Daily cash book with categories, payment mode, day and month totals. |
| **Reports and export** | Reports by status, source and employee; CSV export of all data; daily automatic CSV copy on the admin phone. |
| **Permission pop-ups** | Every permission is explained (why, when, what if denied) before the phone's prompt; review under More > App permissions. |
| **CSV import** | Admin imports existing customers with preview, duplicate detection and bulk assignment. |
| **Push notifications** | Alerts for leads, tasks and messages via Firebase (Android; optional). |
| **Audit trail** | Every change to leads, tasks, attendance, finance and profiles is logged. |
| **Works offline** | Everything is saved on the phone first and uploaded automatically when the network returns. |

## Technology

| Layer | Choice | Why |
|---|---|---|
| App | Flutter (Dart), Android + iOS | One codebase |
| Local storage | SQLite (`sqflite`) | Offline use, no data loss |
| Backend | Supabase (PostgreSQL, Auth, Realtime, Edge Functions) | Free tier fits fewer than 50 users |
| Maps | OpenStreetMap via `flutter_map` | Free |
| Backups | GitHub Actions (scheduled) | Free, independent of Supabase |
| CI | GitHub Actions | Analyze, test, build on every push |

## Architecture

```
 Phone (Flutter app)                                   Supabase (cloud)
 +---------------------------------------+            +--------------------------------+
 |  Screens  -->  Store (SQLite cache)   |            |  PostgreSQL + Row Level        |
 |                 +-- outbox (queue)    |  upload    |  Security (who can see what)   |
 |  SyncService  <-----------------------+----------->|  Auth (email + password)       |
 |   - insert new rows / update edits    |  download  |  Realtime (chat, alerts)       |
 |   - pull changes every 60 s           |            |  Edge Functions:               |
 |   - drop rows you may no longer see   |            |    manage-employee (admin)     |
 +---------------------------------------+            |    meta-webhook (Meta leads)   |
                                                      +--------------+-----------------+
 GitHub Actions: nightly CSV backup  <---------------- REST API (secret key, server only)
```

Key ideas:
- **Local first.** Screens read from SQLite, never directly from the network, so the app is fast and works offline.
- **Outbox.** Each save is queued; the newest copy of a record is uploaded, keeping its place in the queue.
- **Insert vs update.** New records are inserted and edits are updated, so the database rules apply exactly as written.
- **Soft deletes.** Records are marked deleted, never removed.

## Security model

- The app contains only the **publishable key**, which is safe to ship. Access is decided by Row Level Security policies in
  `supabase/migrations/0001_schema.sql`.
- Employees cannot change roles, reassign leads, edit customer identity fields, alter other people's records, or read other
  people's private messages; database triggers enforce this even against a modified app.
- The **secret key** is used only by server code (Edge Functions, the backup job) and lives in Supabase / GitHub secrets, never in the app or in Git.
- Accounts are created only by an admin (public sign-up is switched off).
- Employee location is collected only while checked in, after an on-screen consent message.

## Data protection and backups

1. Every record is stored on the phone first. Nothing is lost if the connection drops.
2. A nightly GitHub job downloads every table as CSV and keeps 30 days (free Supabase has no managed backups).
3. The admin can export all data as CSV at any time; a daily copy is also written on the admin phone.
4. The database keeps an audit log of important changes.

## Project structure

```
lib/
  core/          constants, helpers, shared widgets, configuration (env.dart), setup-error screen
  data/          store.dart (local database + outbox), sync_service.dart, app_auth.dart, csv_export.dart
  features/      auth, home, leads, followups, tasks, attendance, location, chat, finance, employees, more
supabase/
  migrations/    0001_schema.sql (tables, security rules, triggers), 0002_push_and_import.sql
  functions/     manage-employee, meta-webhook, send-push
backup/          nightly backup script
scripts/         check-setup.ps1 (Windows setup checker)
assets/config/   env.json (your private settings, git-ignored)
android/ ios/    platform projects
.github/workflows/  ci.yml, nightly-backup.yml, ios-build.yml
```

## Configuration reference

| Setting | Where | Notes |
|---|---|---|
| `SUPABASE_URL` | `assets/config/env.json` or `--dart-define` | Project URL, `https://xxxx.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | same | `sb_publishable_...`. The old `SUPABASE_ANON_KEY` name is still accepted |
| `org.gradle.java.home` | `android/gradle.properties` | JDK 17 (or 21) used by Gradle |
| `META_VERIFY_TOKEN`, `META_APP_SECRET`, `META_PAGE_ACCESS_TOKEN` | Supabase Edge Function secrets | Only for Facebook/Instagram/WhatsApp leads |
| `SUPABASE_URL`, `SUPABASE_SECRET_KEY` | GitHub Actions secrets | Only for the nightly backup |
| Shift time, late grace, location interval | `lib/core/constants.dart` | |

## Quality checks

```powershell
flutter pub get
flutter analyze
flutter test
```
Run the Windows checker any time something does not start: `powershell -ExecutionPolicy Bypass -File scripts\check-setup.ps1`

## Project status

| Item | Status |
|---|---|
| Admin and employee features listed above | Implemented |
| Offline sync, backups, audit log | Implemented |
| Android and iPhone projects | Configured (iPhone builds need a Mac) |
| Automated end-to-end tests | Not yet (unit tests only) - test on real devices before go-live |
| Push notifications (Android) | Implemented, optional (SETUP Part 14). iPhone push needs a Mac and an Apple account |
| CSV import of leads | Implemented |
| Admin-editable shift times | Planned (constants in `lib/core/constants.dart`) |
| Replying to WhatsApp / Instagram from the app | Not planned for release 1 (use the WhatsApp button) |

## Cost

Everything runs on free tiers: Supabase free plan, GitHub free plan, OpenStreetMap. The only unavoidable paid item is the
Apple Developer Program (about USD 99 per year) if employees use iPhones. Android APKs can be shared directly.
