# Student Approval Flow Fix

## What was wrong

- `GET /admin/applications` had a cleanup loop that deleted student-role `User` records without a `StudentProfile`. Because this ran during normal list refreshes, it could delete an account created moments earlier by an approval request before its profile was saved, leaving the approval flow inconsistent.
- Registration also silently deleted those orphan `User` records. Registration should only submit an application; creating or deleting login accounts there was unsafe.
- The admin Students tab is kept mounted inside a Flutter `IndexedStack`, so it could keep showing its cached API response after an approval completed elsewhere in the dashboard.
- Two administrators could try to approve the same application concurrently.

## Changes

- Application listing is now read-only with respect to student accounts; registration does not create or delete `User` records.
- Approval now atomically claims a pending application using the `approving` status. A competing review cannot claim it at the same time. Failed attempts return it to `pending`; interrupted claims older than two minutes are recoverable on the next admin list request. Profile/user creation remains idempotent for retries.
- The Flutter approvals page broadcasts a profile-change event after approval; the already-mounted Students tab reloads from the server.
- API documentation and regression tests were updated.

## Validation

- Backend JavaScript syntax checks: passed.
- Backend test suite: **23 passed, 0 failed** (`npm test`).
- Flutter analyzer/build and live MongoDB integration were not run because Flutter/Dart and a configured database connection are unavailable in this workspace.

## Deploy

Deploy the updated `backend/` source to the backend service and rebuild/release the Flutter app from the updated `flutter/` source. This package does not deploy to a live server or change production data by itself. Existing pending applications remain available for admin approval.

## Branding and test schedule fix (v1.1.5)

- Logo and background uploads now validate actual JPEG/JPG, PNG, and WebP file signatures instead of relying on inconsistent Android MIME labels. Branding uploads are capped at 12 MB.
- Login and dashboard branding images now fall back to bundled artwork if a remote image cannot be decoded or fetched; the dashboard hero overlay was reduced so the uploaded background is visible.
- Admins can reschedule a published test before any student attempt exists, including moving an overdue schedule into the future. Tests with attempts and explicitly closed tests remain protected. The student API recalculates availability from the new start time, so future tests stay locked until then.
- The test date picker now accepts older existing dates without an out-of-range assertion.
- Validation: backend suite **37 passed, 0 failed**; Flutter analyzer **no issues found**. Release APK version **1.1.5 (versionCode 7)** built and signature-verified. Universal APK is **74,998,826 bytes (about 71.5 MiB)** and contains `armeabi-v7a`, `arm64-v8a`, and `x86_64`; separate ABI-specific APKs were also verified. This is signed with the repository's debug key for direct testing, not a Play Store signing key.

## Physical-results calendar and editing (v1.1.6)

- Admin individual physical results now have a month calendar with markers on recorded days, previous/next month navigation, and a selected-day filter. The add flow uses the selected calendar date.
- Existing result cards now expose an Edit action for the date, measurements/reps and coach notes. Student and batch association remain fixed while editing.
- The API supports validated inclusive-start/exclusive-end date filters and an admin-only `PATCH /physical-training-results/:id` endpoint.
- Batch physical marks sheets remain unchanged; OTP-related code and setup files were not changed.
- Validation: backend suite **39 passed, 0 failed**; Flutter analyzer **no issues found**. Release APK build is verified separately below.
