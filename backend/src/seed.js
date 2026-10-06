require('dotenv').config();
const mongoose = require('mongoose');
const { connectDatabase } = require('./config/db');
const User = require('./models/User');
const Batch = require('./models/Batch');
const StudentProfile = require('./models/StudentProfile');

async function seedDemoData() {
  let batch = await Batch.findOne({ name: 'Army GD (Morning)' });
  if (!batch) {
    batch = await Batch.create({
      name: 'Army GD (Morning)',
      course: 'Army GD',
      trainer: 'Instructor Sharma',
      startTime: '06:00',
      endTime: '08:00',
      location: process.env.ACADEMY_LOCATION || 'Academy Ground'
    });
  }

  const ensureUser = async ({ name, email, phone, password, role }) => {
    const existing = await User.findOne({ email });
    if (existing) return { user: existing, created: false };
    const user = await User.create({
      name,
      email,
      phone,
      role,
      passwordHash: await User.hashPassword(password)
    });
    return { user, created: true };
  };

  const admin = await ensureUser({
    name: 'Academy Admin',
    email: 'admin@msda.local',
    phone: process.env.ACADEMY_PHONE || '8228949212',
    password: 'Admin@12345',
    role: 'admin'
  });
  const student = await ensureUser({
    name: 'Ravi Kumar',
    email: 'student@msda.local',
    phone: '9000000000',
    password: 'Student@12345',
    role: 'student'
  });

  if (!await StudentProfile.findOne({ userId: student.user._id })) {
    await StudentProfile.create({
      userId: student.user._id,
      studentId: 'MSDA1256',
      batchId: batch._id,
      course: 'Army GD',
      address: 'Shahpur Patori, Samastipur'
    });
  }

  return {
    adminCreated: admin.created,
    studentCreated: student.created
  };
}

async function runSeed() {
  await connectDatabase();
  try {
    const result = await seedDemoData();
    console.log(`Seed complete (admin ${result.adminCreated ? 'created' : 'already present'}, student ${result.studentCreated ? 'created' : 'already present'}).`);
  } finally {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  runSeed().catch(error => {
    console.error('Seed failed:', error.message);
    process.exitCode = 1;
  });
}

module.exports = { seedDemoData };
