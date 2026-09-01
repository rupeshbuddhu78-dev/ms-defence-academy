require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../src/models/User');
const Admin = require('../src/models/Admin');
const Student = require('../src/models/Student');
const Batch = require('../src/models/Batch');
const Notice = require('../src/models/Notice');
const Schedule = require('../src/models/Schedule');
const Test = require('../src/models/Test');
const Question = require('../src/models/Question');
const Attendance = require('../src/models/Attendance');
const Fee = require('../src/models/Fee');
const Payment = require('../src/models/Payment');
const Media = require('../src/models/Media');
const Course = require('../src/models/Course');

const seed = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    let adminUser = await User.findOne({ email: 'admin@msdefenceacademy.com' });
    if (!adminUser) {
      adminUser = await User.create({
        role: 'ADMIN',
        email: 'admin@msdefenceacademy.com',
        mobile: '8228949212',
        password: 'ChangeMe@123',
        isActive: true,
        mustChangePassword: true
      });
      await Admin.create({
        user: adminUser._id,
        adminId: 'ADMIN001',
        fullName: 'MS Defence Admin',
        email: 'admin@msdefenceacademy.com',
        mobile: '8228949212',
        designation: 'Administrator'
      });
      console.log('Admin created: admin@msdefenceacademy.com / ChangeMe@123');
    } else {
      console.log('Admin already exists');
    }

    let batch = await Batch.findOne({ name: 'NDA Foundation 2026' });
    if (!batch) {
      batch = await Batch.create({
        name: 'NDA Foundation 2026',
        course: 'NDA',
        instructor: 'Capt. Sharma',
        startDate: new Date('2026-01-15'),
        endDate: new Date('2026-12-15'),
        days: ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'],
        startTime: '05:30',
        endTime: '12:00',
        maximumStudents: 50,
        status: 'ACTIVE',
        description: 'Morning batch - Physical + Written'
      });
      console.log('Batch created');
    }

    const studentSpecs = [
      { mobile: '9876543211', name: 'Rahul Kumar', paid: 25000, qualification: '12th Pass' },
      { mobile: '9876543212', name: 'Amit Singh', paid: 0, qualification: 'Graduate' },
      { mobile: '9876543213', name: 'Vikash Yadav', paid: 50000, qualification: '12th Pass' }
    ];

    const createdStudents = [];
    for (const spec of studentSpecs) {
      let existing = await User.findOne({ mobile: spec.mobile });
      let student;
      if (!existing) {
        const user = await User.create({
          role: 'STUDENT',
          mobile: spec.mobile,
          password: 'Student@123',
          isActive: true
        });
        const studentId = await Student.generateStudentId();
        student = await Student.create({
          user: user._id,
          studentId,
          fullName: spec.name,
          fatherName: 'Father of ' + spec.name.split(' ')[0],
          motherName: 'Mother',
          mobile: spec.mobile,
          gender: 'MALE',
          address: 'Shahpur Patori, Near Main Road',
          district: 'Samastipur',
          state: 'Bihar',
          course: 'NDA',
          qualification: spec.qualification,
          batch: batch._id,
          qrIdentifier: Student.generateQrIdentifier(),
          status: 'ACTIVE',
          totalFee: 50000,
          paidFee: spec.paid
        });
        await Fee.create({
          student: student._id,
          studentId: student.studentId,
          totalFee: 50000,
          paidAmount: spec.paid,
          pendingAmount: 50000 - spec.paid,
          status: spec.paid >= 50000 ? 'PAID' : (spec.paid > 0 ? 'PARTIAL' : 'PENDING'),
          course: 'NDA'
        });
        if (spec.paid > 0) {
          await Payment.create({
            student: student._id,
            studentId: student.studentId,
            amount: spec.paid,
            mode: 'CASH',
            status: 'PAID',
            receiptNumber: 'RCP' + Date.now() + Math.floor(Math.random() * 100),
            remarks: 'Seed payment',
            recordedBy: adminUser._id,
            paymentDate: new Date()
          });
        }
        console.log(`Student created: ${studentId} / Student@123`);
      } else {
        student = await Student.findOne({ user: existing._id });
        console.log(`Student exists: ${student?.studentId}`);
      }
      if (student) createdStudents.push(student);
    }

    // Attendance for last 14 days
    for (const student of createdStudents) {
      for (let d = 1; d <= 14; d++) {
        const dateObj = new Date();
        dateObj.setDate(dateObj.getDate() - d);
        // IST date string
        const ist = new Date(dateObj.getTime() + 5.5 * 60 * 60 * 1000);
        const dateStr = ist.toISOString().slice(0, 10);
        const exists = await Attendance.findOne({ student: student._id, date: dateStr });
        if (exists) continue;
        // Skip some days as absent (every 5th day)
        if (d % 5 === 0) continue;
        const entry = new Date(dateObj);
        entry.setHours(5, 30 + (d % 10), 0, 0);
        const exit = new Date(dateObj);
        exit.setHours(11, 45 + (d % 15), 0, 0);
        await Attendance.create({
          student: student._id,
          studentId: student.studentId,
          batch: batch._id,
          date: dateStr,
          entryTime: entry,
          exitTime: exit,
          entryMarkedBy: adminUser._id,
          exitMarkedBy: adminUser._id,
          status: 'PRESENT'
        });
      }
      console.log(`Attendance seeded for ${student.studentId}`);
    }

    const noticeCount = await Notice.countDocuments();
    if (noticeCount === 0) {
      await Notice.create([
        {
          title: 'Welcome to MS Defence Academy',
          description: 'Welcome all students. Training starts at 5:30 AM sharp. Be punctual.',
          priority: 'IMPORTANT',
          isPublished: true,
          publishedAt: new Date(),
          createdBy: adminUser._id
        },
        {
          title: 'Physical Training Schedule',
          description: 'Morning PT: Running, Push-ups, Sit-ups. Bring proper sports kit.',
          priority: 'NORMAL',
          isPublished: true,
          publishedAt: new Date(),
          createdBy: adminUser._id
        },
        {
          title: 'URGENT: Fee Submission Deadline',
          description: 'Last date for fee submission is 15th of this month. Contact office for details.',
          priority: 'URGENT',
          isPublished: true,
          publishedAt: new Date(),
          createdBy: adminUser._id
        }
      ]);
      console.log('Notices created');
    }

    const schedCount = await Schedule.countDocuments();
    if (schedCount === 0) {
      const days = [
        { day: 'MONDAY', subject: 'Physical Training', startTime: '05:30', endTime: '07:00' },
        { day: 'TUESDAY', subject: 'Mathematics', startTime: '07:00', endTime: '09:00' },
        { day: 'WEDNESDAY', subject: 'English', startTime: '07:00', endTime: '09:00' },
        { day: 'THURSDAY', subject: 'General Knowledge', startTime: '07:00', endTime: '09:00' },
        { day: 'FRIDAY', subject: 'Physics', startTime: '07:00', endTime: '09:00' },
        { day: 'SATURDAY', subject: 'Parade Training', startTime: '05:30', endTime: '08:00' }
      ];
      for (const d of days) {
        await Schedule.create({ ...d, batch: batch._id, isActive: true, instructor: 'Capt. Sharma' });
      }
      console.log('Schedule created');
    }

    let test = await Test.findOne({ title: 'NDA Sample Mock Test 1' });
    if (!test) {
      test = await Test.create({
        title: 'NDA Sample Mock Test 1',
        subject: 'Mathematics',
        duration: 30,
        totalMarks: 10,
        negativeMarking: true,
        negativeMarks: 0.25,
        isPublished: true,
        instructions: 'Choose the correct option. Negative marking applies.',
        createdBy: adminUser._id
      });
      await Question.create([
        { test: test._id, questionText: 'What is the value of √144?', optionA: '10', optionB: '12', optionC: '14', optionD: '16', correctAnswer: 'B', marks: 2, order: 1 },
        { test: test._id, questionText: 'If 2x + 5 = 15, what is x?', optionA: '3', optionB: '4', optionC: '5', optionD: '6', correctAnswer: 'C', marks: 2, order: 2 },
        { test: test._id, questionText: 'Area of a circle with radius 7 is (use π=22/7):', optionA: '154', optionB: '144', optionC: '164', optionD: '174', correctAnswer: 'A', marks: 2, order: 3 },
        { test: test._id, questionText: 'Simple interest on 1000 at 10% for 2 years is:', optionA: '100', optionB: '150', optionC: '200', optionD: '250', correctAnswer: 'C', marks: 2, order: 4 },
        { test: test._id, questionText: 'What is 15% of 200?', optionA: '20', optionB: '25', optionC: '30', optionD: '35', correctAnswer: 'C', marks: 2, order: 5 }
      ]);
      console.log('Sample test created');
    }

    
    const courseNames = ['NDA', 'CDS', 'AFCAT', 'SSB', 'Defence Foundation', 'Physical Training'];
    for (const name of courseNames) {
      const exists = await Course.findOne({ name });
      if (!exists) await Course.create({ name, description: name + ' preparation', status: 'ACTIVE' });
    }
    console.log('Courses seeded');

    // Demo public / normal users
    for (let i = 1; i <= 2; i++) {
      const email = `user${i}@example.com`;
      let u = await User.findOne({ email });
      if (!u) {
        await User.create({
          role: 'USER',
          fullName: `Public User ${i}`,
          email,
          mobile: `900000000${i}`,
          password: 'User@123',
          isActive: true
        });
        console.log(`Public user created: ${email} / User@123`);
      }
    }

    console.log('\n=== SEED COMPLETE ===');
    console.log('Admin: admin@msdefenceacademy.com / ChangeMe@123');
    console.log('Students: 9876543211/12/13 / Student@123');
    console.log('Public users: user1@example.com / User@123');
    process.exit(0);
  } catch (err) {
    console.error('Seed error:', err);
    process.exit(1);
  }
};

seed();
