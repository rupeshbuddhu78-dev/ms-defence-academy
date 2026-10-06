const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const { rateLimit } = require('express-rate-limit');
const apiRoutes = require('./routes');
const { notFound, errorHandler } = require('./middleware/errors');

const app = express();
// Render terminates the public connection at one reverse-proxy hop.
app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN === '*' ? true : (process.env.CORS_ORIGIN || '').split(',').map(s => s.trim()), credentials: false }));
app.use(express.json({ limit: '1mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, limit: 60, standardHeaders: 'draft-7', legacyHeaders: false }));

app.get('/', (_req, res) => res.json({
  ok: true,
  service: 'MS Defence Academy API',
  health: '/health',
  api: '/api'
}));
app.get('/api', (_req, res) => res.json({
  ok: true,
  service: 'MS Defence Academy API',
  endpoints: {
    login: 'POST /api/auth/login',
    currentUser: 'GET /api/auth/me',
    health: 'GET /health'
  }
}));
app.get('/health', (_req, res) => res.json({ ok: true, service: 'ms-defence-academy-api', timestamp: new Date().toISOString() }));
app.use('/api', apiRoutes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;
