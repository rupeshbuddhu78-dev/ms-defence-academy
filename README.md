# MS Defence Academy

A Flutter Android client and Node.js/Express/MongoDB API for a defence and physical-training academy. The application supports student and admin/teacher roles in the same app and follows the supplied mobile reference image's green-and-white visual direction.

## Reference-image analysis

- **Branding:** forest-green academy header, circular MS emblem with gold detail, discipline-focused tagline, dark athletic imagery and clear academy identity.
- **Visual language:** white/light neutral page backgrounds, dark-green app bars, rounded information cards, compact icon-led shortcuts, restrained orange accent, legible text hierarchy and consistent spacing.
- **Student screens shown:** academy landing/dashboard, student QR, attendance scanner, monthly attendance calendar, student profile and a multi-item bottom navigation.
- **Admin screen shown:** compact four-stat dashboard, quick-access cards for attendance, students, batches, reports, fees, notices, training and tests.
- **Interaction patterns:** bottom navigation for frequent destinations; card-based shortcuts for less-frequent tasks; QR scan followed by a student confirmation card and a prominent PRESENT action.
- **Implementation choice:** preserve the recognizable layout and green professional tone, but use original widgets and an original SVG emblem rather than copying the screenshot or its imagery.

## Screens and navigation

### Student

- Login (shared with admin; server assigns role)
- Home dashboard: profile photo, identity/batch, attendance summary, upcoming training/tests and notices; refreshes the profile when returning to the Home tab
- My QR Code: secure opaque student token only
- Physical Training Results: private history for running time, beam/pull-ups, long/high jump, push-ups, sit-ups and shuttle run
- Training schedule
- Attendance calendar and monthly summary
- Written preparation/test list and timed MCQ attempt
- Test result confirmation after backend scoring
- Profile, notices and fee ledger

**Navigation:** Home → quick actions → QR / attendance / tests / training / notices / fees; bottom bar → Home, Training, Attendance, Profile.

### Admin / teacher

- Admin dashboard with live totals and quick actions
- Student enrollment and searchable directory with a full admission form: phone-based login, parent details, date of birth, village/post/police station/district/state/PIN, Aadhaar, height, weight, chest, batch, joining date, optional photo and initial fee/payment
- Full student detail view with administrator edit controls for all admission fields, Cloudinary photo, fee ledger summary, admin-set temporary password reset (forced student rotation) and confirmed permanent deletion; student thumbnails appear in directory and attendance lists
- Batch and course management with batch assignment on enrollment
- Camera-based attendance scanner → student photo and basic-detail preview → PRESENT confirmation
- Monthly attendance calendar with marked-day indicators; tapping a student opens their full attendance history and summary
- Batch-specific test scheduling/editing with the closing time calculated from selected start + duration, bulk MCQ entry (10 by default, up to 100 per save), timed autosave and automatic submission; only the first official result is saved, then 24-hour-delayed unlimited practice runs without storing practice answers/results
- Batch physical marks sheets for Army, BHG/Home Guard, Bihar Police, BSF, CISF, CRPF, ITBP, Police SI, SSB and SSC-GD; admins toggle optional events, record running distance in KM and its time, then enter one overall total mark per student (not marks for every event). Students see the complete sheet for their own batch with their row highlighted, alongside their individual assessment history.
- Batch-filtered student directory, fee ledgers, attendance calendars and admin exam results; students receive sequential `MSDA01`, `MSDA02`, … IDs automatically
- Batch-specific training schedules
- All-academy or batch-targeted notices and persisted in-app notifications
- Fee ledgers with batch-first student search, enrollment payments, remaining balance, payment records, admin edit and delete
- Exam results for admins (filterable by batch with student profile details) and students (own profile and score history)
- New students sign in using their phone as the temporary password and must set a new password before using the app
- Student profile and photo retrieval from MongoDB; photo uploads show byte-based progress and are stored in Cloudinary; Aadhaar is encrypted at rest with AES-256-GCM
- Admins can permanently delete a test and dependent results, or permanently delete a student's account, including associated physical assessment records, after a confirmation dialog

**Navigation:** Dashboard → scanner / test authoring / training / notices / fees; bottom bar → Dashboard, Students, Attendance, More.

## Architecture plan and implementation

1. **UI:** central Poppins typography and green design tokens; reusable cards, navigation, loading/error/empty states; responsive scrollable layouts.
2. **Identity:** email-or-phone JWT login endpoint, bcrypt password hashes, forced first-login password rotation for newly enrolled students, Android Keystore-backed persisted Flutter session, and database-backed role checks on every protected API.
3. **Data:** MongoDB references connect users to student profiles/batches; attendance, training, physical results, tests, questions, attempts, notices, fees and notifications are stored separately with timestamps/indexes. Enrollment creates the login, profile and initial fee ledger together.
4. **Attendance:** QR payload is a random opaque token; only admins can resolve it; server looks up the student; admin confirms; MongoDB unique index prevents repeat present marks for one student/session/day.
5. **Exams:** admins schedule exams for a batch; closing time is computed as start + duration. Up to 100 questions can be added in one bulk request. Only the first timed official attempt/result is persisted and shown to admins. After 24 hours, students get unlimited timed practice sessions whose scores are returned transiently and never stored. Answers autosave and expired official attempts are scored automatically. Answer keys are excluded from student queries.
6. **API:** modular route groups; role middleware; JSON errors; rate-limited login; request body size cap; health endpoint.
7. **Media and mobile:** app shell and screens are separated from the API client/session provider/theme; Android camera permission is configured for QR scanning; student photos upload through authenticated multipart routes to Cloudinary.

## Project structure

```text
backend/
  src/{config,controllers,middleware,models,routes,services}/
  src/app.js  src/server.js  src/seed.js
flutter/
  android/                     # Android manifest, Kotlin activity and Gradle wrapper/config
  assets/academy_emblem.svg    # original vector emblem
  assets/academy_app_icon.png # supplied academy logo for login and launcher icon
  lib/core/{constants,theme}/
  lib/providers/  lib/services/  lib/screens/{auth,student,admin,shared}/  lib/widgets/
docs/API.md
```

## Setup

### 1. MongoDB and backend

Use a local MongoDB server or a MongoDB Atlas URI. From `backend/`:

```bash
cp .env.example .env
# Edit .env: set MONGODB_URI and a random JWT_SECRET (32+ characters).
# For Aadhaar entry, also set AADHAAR_ENCRYPTION_KEY to 64 random hex characters.
npm install
npm run seed       # optional demo accounts and sample batch
npm run dev         # API at http://localhost:4000
```

The API health check is `GET http://localhost:4000/health`. To enable profile photos locally, set `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` in `backend/.env`; these belong only in a server-side secret store. Never commit a real `.env` file or encryption key.

**Seeded local-only accounts** (only after `npm run seed`):

- Admin: `admin@msda.local` / `Admin@12345`
- Student: `student@msda.local` / `Student@12345`

These are development credentials. Change/remove them before a shared or production deployment. The seed script never overwrites existing accounts.

### 2. Flutter Android app

Install Flutter 3.35+ (Dart 3.11+), Android SDK and Java 17. The photo-picker dependency requires Android 7.0/API 24 or newer. From `flutter/`:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
flutter build apk --release --target-platform android-arm64
```

The app defaults to the deployed API at `https://ms-defence-academy-backend.onrender.com/api`. For local development, override it with the Android emulator's host-machine alias `http://10.0.2.2:4000/api`. For a physical phone using a local server, set `API_BASE_URL` to the development computer's reachable LAN address (for example, `http://192.168.1.20:4000/api`) and allow the API port through the local firewall.

Build a smaller ARM64 test APK (targets most current Android phones):

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64
```

This starter config signs release-mode **test** APKs with the local debug key so they can be installed directly. Do not use that key for a Play Store or production release. Debug-mode APKs are substantially larger; use release mode for the smaller test build. The supplied logo is used for both the Android launcher icon and login header.

Replace academy identity/contact via `backend/.env` (`ACADEMY_NAME`, `ACADEMY_LOCATION`, `ACADEMY_PHONE`). The optional Render startup seed is disabled by default; only enable `SEED_DEMO_ON_START=true` for a deliberate one-time setup, then turn it off again. The seed script creates missing demo accounts and does not overwrite existing accounts.

## API and database details

See [API reference](docs/API.md) for endpoints, permissions and payload examples. MongoDB model references are documented there as well.

## Validation status and limitations

- Backend JavaScript syntax checks and all 30 automated API/security tests pass (`npm test`), including physical-result access controls, practice scoring without database persistence, authentication guards and encrypted Aadhaar.
- Flutter analyzer reports no issues and the release APK builds successfully (74.6 MB universal APK). It is signed with the local debug key for direct testing; use an organization-owned release/upload key before Play Store or production distribution. The app has not been tested on a physical device.
- API screens require MongoDB to be reachable. The Android manifest allows cleartext HTTP for local development; use HTTPS and disable cleartext traffic for production.
- Fees are ledger-only (no payment gateway). Notices and schedules are persisted in-app notifications (inbox refresh/pull-to-refresh; no Firebase push/SMS configured). Tests remain visible as locked/closed according to their schedule; Android does not allow the app to launch itself from the background. Admins must securely share each student's phone-based temporary login details. Configure backups and institute-specific retention/access policies before launch; Aadhaar should be collected only where necessary.
