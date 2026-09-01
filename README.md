# MS Defence Academy - Backend Server

Professional Node.js + Express + MongoDB backend for MS Defence Academy Management System.

**Location:** Shahpur Patori, Samastipur, Bihar  
**Phone:** 8228949212 | 9117841390

## Tech Stack

- Node.js (>= 18)
- Express.js
- MongoDB + Mongoose
- JWT Authentication
- bcryptjs
- Cloudinary (media)
- Razorpay (payments)
- Helmet, CORS, Rate Limiting, Input Sanitization

## Setup

### 1. Install dependencies

```bash
cd MS_Defence_Academy_Server
npm install
```

### 2. Environment

```bash
cp .env.example .env
```

Edit `.env` with your values:

- `MONGODB_URI` — MongoDB Atlas connection string
- `JWT_SECRET` — strong random secret (min 32 chars)
- `CLOUDINARY_*` — from Cloudinary dashboard
- `RAZORPAY_*` — from Razorpay dashboard (optional for offline-only)

### 3. Seed demo data

```bash
npm run seed
```

**Demo Admin:**  
Email: `admin@msdefenceacademy.com`  
Password: `ChangeMe@123` (must change on first login)

**Demo Students:**  
Mobile: `9876543211`, `9876543212`, `9876543213`  
Password: `Student@123`

### 4. Run

```bash
# Development
npm run dev

# Production
npm start
```

Server runs on `http://localhost:5000` by default.

## API Overview

Base URL: `http://localhost:5000/api`

Auth, Student, Admin, Attendance, Fees, Payment, Notices, Media, Batches, Schedule, PT, Tests — all implemented with role-based access.

## Security

See SECURITY.md

## License

Proprietary — MS Defence Academy
