# API Reference

Base URL: `https://ms-defence-academy-backend.onrender.com/api` (local default: `http://localhost:4000/api`). Protected endpoints require `Authorization: Bearer <JWT>`. JSON responses use `{ "ok": true, "data": ... }`; errors use `{ "ok": false, "error": { "message": ... } }`.

## Authentication

| Method | Path | Access | Purpose |
|---|---|---|---|
| POST | `/auth/login` | Public | Login with email or student phone and password; returns JWT, user and student profile if applicable |
| GET | `/auth/register/batches` | Public | List active batches available during registration |
| POST | `/auth/register/request-otp` | Public | Send email OTP for a student application; does not create a User account |
| POST | `/auth/register/verify-otp` | Public | Verify OTP and submit a pending application; does not create a User account |
| GET | `/admin/applications` | Admin | List verified applications awaiting review |
| POST | `/admin/applications/:id/review` | Admin | Approve/reject an application; approval provisions the student User and profile |
| DELETE | `/admin/applications/:id` | Admin | Delete a pending application |
| PATCH | `/auth/application/:id/resubmit` | Public | Correct and resubmit a rejected application using its email and password |
| GET | `/auth/me` | Any signed-in user | Current user and profile |
| POST | `/auth/change-password` | Signed-in account requiring rotation | Set a new password after a student's first phone/password login |

Student self-registration stores a verified application only. A student login account and `StudentProfile` are provisioned by the admin approval action; review claims are guarded against concurrent admins and stale interrupted claims are made retryable. The admin application list is read-only with respect to student accounts.

## Students and enrollment

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/students/profile` | Student | Own database-backed profile, assigned batch and fee summary |
| POST | `/students/profile/photo` | Student | Upload/replace own profile photo (multipart field `photo`) |
| GET | `/students/profile/qr` | Student | Own opaque attendance QR token |
| GET | `/students` | Admin | List/search students (`q`, `batchId`) with fee summaries |
| POST | `/students` | Admin | Create login account/profile and optional initial fee payment; multipart with optional `photo` |
| GET/PATCH/DELETE | `/students/:id` | Admin | Read/update or permanently delete a student and associated records |
| PATCH | `/students/:id/password` | Admin | Set a 10–72 character temporary password; student must change it before using the app again |
| POST | `/students/:id/photo` | Admin | Upload/replace a student's photo (multipart field `photo`) |

Enrollment requires `name`, a 10-digit Indian `phone`, and an active `batchId`; email is optional. The phone number is the login ID and initial password. Students must set a different password on first sign-in; the API then blocks other protected endpoints until rotation is complete. Optional admission fields include `studentId` (generated as uppercase `MSDA01`, `MSDA02`, … if blank), `fatherName`, `motherName`, `parentPhone`, `dateOfBirth`, `village`, `post`, `policeStation`, `district`, `state`, `postalCode`, `heightCm`, `weightKg`, `chestCm`, `aadhaarNumber`, `course`, `joiningDate`, `totalFees`, and `paidAmount`. Aadhaar is stored only as AES-256-GCM ciphertext; set a random 32-byte hex `AADHAAR_ENCRYPTION_KEY` on the backend. Aadhaar plaintext is returned only on the student's own profile and the admin's individual student-detail endpoint—not in directory lists or session restoration. `paidAmount` cannot exceed `totalFees`.

`DELETE /students/:id` is permanent: it removes the account/profile, fee/payment ledger, attendance, written-test attempts/results, physical-training results and inbox notifications. The app asks for explicit confirmation before calling it. Student photo assets are also removed from Cloudinary after the database transaction.

Photo uploads accept verified JPG/JPEG, PNG, or WebP up to 12 MB, including JPEG files reported by Android with a generic MIME type. The server uploads photos to Cloudinary and stores the secure URL and asset ID in the student profile. Configure `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` in the backend environment; no Cloudinary secrets belong in the app or repository.

## Batches, attendance and training

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/batches` | Any | List academy batches |
| POST/PATCH | `/batches[/:id]` | Admin | Create/update batch or course details |
| DELETE | `/batches/:id` | Admin | Archive a batch (preserves students and historical schedules); it can be reactivated with `PATCH` and `status: "active"` |
| GET | `/attendance` | Any | Student's own history, or admin history; optional `from`, `to`, `batchId`, `studentId` filters |
| GET | `/attendance/calendar` | Admin | Aggregate marked/present/absent totals for a UTC date range, optionally filtered by `batchId` |
| POST | `/attendance/lookup-qr` | Admin | Resolve `{ "token":"<opaque-token>" }` to the student's photo, name, ID, batch, phone, course, DOB and physical measurements (never Aadhaar or parent details) |
| POST | `/attendance/mark` | Admin | Confirm attendance `{ "token":"...", "status":"present", "trainingSessionId":"..." }` |
| GET | `/training` | Any | Student's batch schedule or admin schedule; optional `batchId`, `from` |
| POST | `/training` | Admin | Schedule a batch session; creates an in-app notification for active students in that batch |
| PATCH | `/training/:id` | Admin | Edit session name, batch, date, times, location or status; scheduled updates notify the target batch |
| DELETE | `/training/:id` | Admin | Cancel and hide a training session while preserving its history |

Attendance duplicates for the same student/session/date are blocked by a MongoDB unique index; duplicate attempts return a conflict response. The QR contains no name, email, phone, or student ID.

## Physical training results

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/physical-training-results` | Student / Admin | Students receive only their own records; admins may filter by `batchId` or `studentId` |
| POST | `/physical-training-results` | Admin | Record one student's physical assessment within a selected batch |

The admin payload includes `batchId`, `studentId`, `testDate`, optional `runTimeSeconds`, `beamReps`, `longJumpCm`, `highJumpCm`, `pushUps`, `sitUps`, `shuttleRunSeconds` and `remarks`. The server verifies that the student belongs to the selected active batch and prevents students from writing or querying another student's records.

## Tests and results

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/tests` | Any | Admin list, or the student's batch's published tests including upcoming, open and closed schedules |
| POST | `/tests` | Admin | Create a draft with batch, duration and start time; close time is calculated as start + duration |
| PATCH | `/tests/:id` | Admin | Edit draft/published test title, description, batch, duration and start time (not after attempts exist); close time is recalculated |
| GET | `/tests/:id` | Any | Test details; students may fetch questions only during the scheduled test window |
| POST | `/tests/:id/questions` | Admin | Add another four-option MCQ with server-held `correctAnswer` index 0–3 and marks; no fixed question-count cap is imposed by the app |
| PATCH | `/tests/:id/questions/bulk` | Admin | Add 1–100 validated four-option MCQs in a single request |
| PATCH | `/tests/:id/publish` | Admin | Publish after at least one question exists; sends an in-app notice to the target batch |
| DELETE | `/tests/:id` | Admin | Permanently delete the test, questions, attempts/results and associated test notifications |
| POST | `/tests/:id/start` | Student | Start/resume attempt; returns safe questions only |
| PATCH | `/tests/:id/answers` | Student | Save the current answer draft for a resumable attempt; server enforces the attempt deadline |
| POST | `/tests/:id/submit` | Student | Submit `{"answers":[{"questionId":"...","selected":0}]}`; server calculates result |
| POST | `/tests/:id/practice/start` | Student | After the first official result is at least 24 hours old, start a stateless practice session with a signed timer token |
| POST | `/tests/:id/practice/submit` | Student | Score practice answers and return the score without storing the session, answers or result |
| GET | `/tests/results` | Any | Student's own results, or admin results (optional `studentId`, `testId`, or `batchId`) with profile summary and score |

Question answer keys are stored in `Question.correctAnswer` with `select:false`; student-facing projections only select question text/options/marks/order. The first real attempt is the only attempt stored in `TestAttempt` and the only result shown in admin reports. Its deadline is the earlier of its duration or scheduled close time; a server sweep automatically submits it even if the student closes the app. After that result is 24 hours old, a student can use unlimited stateless practice sessions with a fresh duration each time. Practice answers and scores are computed in memory and returned to the student only; they are not stored in MongoDB or admin results. Students see upcoming tests as locked; the list refreshes periodically. Android does not permit the app to launch itself from the background at a scheduled time. Publishing, training schedules, and notices create persisted in-app notifications (not device push notifications).

## Notices, notifications and fee ledger

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET/POST | `/notices` | Any / Admin | Read or publish an all-academy or batch-targeted notice; publishing creates per-student in-app notifications |
| GET | `/notifications` | Any | Current user's notification inbox |
| PATCH | `/notifications/:id/read` | Any | Mark own notification as read |
| GET | `/fees` | Any | Student's own ledger or admin's ledger (`studentId` and `batchId` filters) |
| POST | `/fees` | Admin | Create a fee ledger for a student in the selected active batch `{ "batchId":"...", "studentId":"...", "totalFees":10000, "paidAmount":1000 }` |
| PATCH | `/fees/:id` | Admin | Correct ledger total/paid amount with an audit entry; existing payment history is retained |
| DELETE | `/fees/:id` | Admin | Permanently delete the selected fee ledger/payment record |
| POST | `/fees/:id/payments` | Admin | Record cash or online payment with `{ "amount":1000, "paymentMethod":"cash", "paymentDate":"2026-10-06T17:25:00.000Z", "note":"Cash receipt 123" }`; online payments require `transactionId`. Every payment is retained in the fee ledger and shown in student history |

No money is charged by this app; payments are manual ledger records only.

## MongoDB relationships

- `User` holds authentication, hashed credential, mandatory-password-rotation flag, role and active status.
- `StudentProfile.userId` references `User`; `StudentProfile.batchId` references `Batch`; photo URL/public asset ID and admission details are stored here; Aadhaar is AES-256-GCM encrypted; `qrToken` is random and excluded by default.
- `Attendance.studentId` references `StudentProfile`; `batchId` and optional `trainingSessionId` reference academy records; `markedBy` references `User`.
- `TrainingSession.batchId` references `Batch`; `createdBy` references `User`.
- `PhysicalTrainingResult` references one `StudentProfile`, its `Batch`, and the admin `User` who recorded it.
- `Test.batchId` references `Batch`; `Question.testId` references `Test`; `TestAttempt` references `Test`, `StudentProfile` and `Question` and stores the one official timed attempt; practice sessions are stateless and never create `TestAttempt` documents.
- `Notice.batchId` optionally targets a batch; `Notification.userId` references the recipient `User`.
- `Fee.studentId` references `StudentProfile`; each payment and fee correction records its admin user, and corrections retain the prior ledger values.
