require('dotenv').config();
const app = require('./app');
const { connectDatabase } = require('./config/db');

async function start() {
  if ((process.env.JWT_SECRET || '').length < 32) throw new Error('JWT_SECRET must be at least 32 characters');
  await connectDatabase();
  const port = Number(process.env.PORT || 4000);
  const server = app.listen(port, '0.0.0.0', () => console.log(`MS Defence Academy API listening on ${port}`));
  const shutdown = async signal => {
    console.log(`${signal}: shutting down`);
    server.close(async () => { await require('mongoose').disconnect(); process.exit(0); });
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}
if (require.main === module) start().catch(err => { console.error('Startup failed:', err.message); process.exit(1); });
module.exports = start;
