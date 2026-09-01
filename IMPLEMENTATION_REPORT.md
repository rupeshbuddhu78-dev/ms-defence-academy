# MS Defence Academy — Implementation Report

## Already Present (Phase 1–2 preserved)
- Roles: USER, STUDENT, ADMIN
- Public register/login, public home
- Admin public users list
- Student pending → approve / reject
- Forgot password OTP (hashed, expiry, attempts)
- JWT auth, QR attendance entry/exit, anti-duplicate
- Fees, media, notices, batch, schedule, PT, tests (backend)

## Added / Extended
### Backend
- Course model + CRUD routes
- Notification model + list/read APIs
- Report routes (students, fees, low-attendance, attendance)
- Audit list API
- Pending student approve/reject + in-app notification on approve
- OTP model + NodeMailer mailer
- Notice audience role filtering
- Student REJECTED status + rejection fields
- Public USER registration (not auto-student)

### Android
- 3-tab login (USER / STUDENT / ADMIN)
- UserMainActivity (public home)
- AdminPendingStudentsActivity (approve/reject)
- AdminPublicUsersActivity
- AdminStudentsActivity + AdminStudentDetailActivity
- AdminCurrentlyInsideActivity
- AdminReportsActivity, AdminAuditActivity, AdminMoreActivity
- ForgotPasswordActivity (3-step)
- StudentAttendanceActivity, StudentProfileActivity
- StudentScheduleActivity, StudentFeesActivity, StudentVideosActivity, StudentNoticesActivity
- NotificationsActivity
- NotificationHelper (system bar)

## APIs (key)
POST /api/public/auth/register
POST /api/public/auth/login
GET  /api/public/home
GET  /api/public/admin/users
GET  /api/admin/pending-students
POST /api/admin/pending-students/:id/approve
POST /api/admin/pending-students/:id/reject
POST /api/auth/forgot-password
POST /api/auth/verify-otp
POST /api/auth/reset-password
GET  /api/notifications
GET  /api/courses
GET  /api/reports/students
GET  /api/reports/fees
GET  /api/audit
...existing auth, student, admin, attendance, media, notices, fees, tests, PT

## Env Variables
MONGODB_URI, JWT_SECRET, JWT_EXPIRES_IN, NODE_ENV, PORT
CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET
RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (optional)
SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM

## Deploy
Start Command: node server.js
Build: npm install
Optional seed: node scripts/seed.js

## Limitations (honest)
- Full month calendar grid UI: list-based history used instead
- Admin video upload UI: API ready, full multipart admin form partial
- FCM push: in-app notifications work; live push needs Firebase project keys
- ViewModel/Repository architecture: Activities still call Retrofit directly
- CSV file download: report JSON API present, client export not packaged
- Premium motion/charts: basic Material UI, not full Lottie suite
- Admin create-student form UI: backend createStudent exists; dedicated form screen partial
