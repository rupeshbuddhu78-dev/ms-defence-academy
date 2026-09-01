# Security Policy — MS Defence Academy Backend

## Authentication & Authorization

- JWT access tokens (short-lived recommended).
- Role-based access: STUDENT | ADMIN.
- Backend always verifies role from JWT — never trusts client-sent role.
- Student can only access own data (derived from JWT user id).
- Admin APIs return 403 for non-admin users.

## Passwords

- Hashed with bcrypt (cost 12).
- Never stored or logged in plaintext.
- Never returned in API responses.
- Login rate limiting + temporary lock after 5 failed attempts.

## MongoDB

- Android never connects to MongoDB.
- Connection string only in server `.env`.
- Use dedicated least-privilege database user.
- Schema validation via Mongoose.
- express-mongo-sanitize against NoSQL injection.
- Unique indexes on studentId, mobile, QR identifier, payment ids.

## Cloudinary

- API secret only on server.
- Signed/server-side uploads.
- MIME and size validation.
- Delete from Cloudinary before removing DB record.

## Payments (Razorpay)

- Key secret only on server.
- Order created on server.
- Signature verified on server before marking PAID.
- Never trust client `paymentSuccess=true`.

## QR Attendance

- QR contains secure random identifier only.
- No password, mobile, address, or fee data in QR.
- QR can be regenerated (old becomes invalid).
- Entry/Exit rules enforced on server with unique indexes.
- Server time used for date/time.

## Rate Limiting

- Global, auth, attendance, and payment limiters enabled.

## Headers & Input

- Helmet, CORS, HPP, XSS clean.
- Input validation on all sensitive endpoints.

## Audit Logs

- Important admin actions recorded (no secrets/passwords).

## Production Checklist

- [ ] HTTPS only
- [ ] Strong JWT_SECRET
- [ ] MongoDB TLS + IP restriction
- [ ] No secrets in code or logs
- [ ] NODE_ENV=production
- [ ] Regular backups
