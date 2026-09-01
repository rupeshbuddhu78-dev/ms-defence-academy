require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const mongoSanitize = require('express-mongo-sanitize');
const xss = require('xss-clean');
const hpp = require('hpp');

const connectDB = require('./src/config/database');
const { errorHandler, notFound } = require('./src/middleware/errorMiddleware');
const { globalLimiter } = require('./src/middleware/rateLimiter');

const authRoutes = require('./src/routes/authRoutes');
const studentRoutes = require('./src/routes/studentRoutes');
const adminRoutes = require('./src/routes/adminRoutes');
const attendanceRoutes = require('./src/routes/attendanceRoutes');
const feeRoutes = require('./src/routes/feeRoutes');
const paymentRoutes = require('./src/routes/paymentRoutes');
const noticeRoutes = require('./src/routes/noticeRoutes');
const mediaRoutes = require('./src/routes/mediaRoutes');
const batchRoutes = require('./src/routes/batchRoutes');
const scheduleRoutes = require('./src/routes/scheduleRoutes');
const ptRoutes = require('./src/routes/ptRoutes');
const testRoutes = require('./src/routes/testRoutes');
const publicRoutes = require('./src/routes/publicRoutes');
const pendingStudentRoutes = require('./src/routes/pendingStudentRoutes');
const courseRoutes = require('./src/routes/courseRoutes');
const notificationRoutes = require('./src/routes/notificationRoutes');
const reportRoutes = require('./src/routes/reportRoutes');
const auditRoutes = require('./src/routes/auditRoutes');

const app = express();

// REQUIRED for Render / reverse proxy
app.set('trust proxy', 1);

// Startup checks
if (!process.env.JWT_SECRET) {
  console.error('WARNING: JWT_SECRET is not set in environment variables!');
}
if (!process.env.MONGODB_URI) {
  console.error('WARNING: MONGODB_URI is not set in environment variables!');
}

connectDB();

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: false
}));
app.use(cors({
  origin: true,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(mongoSanitize());
app.use(xss());
app.use(hpp());
app.use(globalLimiter);

// Root + health (so browser / doesn't 404)
app.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'MS Defence Academy API',
    health: '/health',
    version: '1.0.0'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'MS Defence Academy API is running',
    timestamp: new Date().toISOString(),
    hasJwtSecret: !!process.env.JWT_SECRET,
    hasMongo: !!process.env.MONGODB_URI
  });
});

app.use('/api/public', publicRoutes);
app.use('/api/admin/pending-students', pendingStudentRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/student', studentRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/admin/attendance', attendanceRoutes);
app.use('/api/admin/fees', feeRoutes);
app.use('/api/payment', paymentRoutes);
app.use('/api/notices', noticeRoutes);
app.use('/api/media', mediaRoutes);
app.use('/api/admin/batches', batchRoutes);
app.use('/api/schedule', scheduleRoutes);
app.use('/api/physical-training', ptRoutes);
app.use('/api/tests', testRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/audit', auditRoutes);

app.use(notFound);
app.use(errorHandler);

const PORT = process.env.PORT || 5000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`MS Defence Academy Server running on port ${PORT}`);
  console.log(`JWT_SECRET set: ${!!process.env.JWT_SECRET}`);
  console.log(`MONGODB_URI set: ${!!process.env.MONGODB_URI}`);
});

module.exports = app;
