const crypto = require('crypto');
const mongoose = require('mongoose');
const User = require('../models/User');
const StudentProfile = require('../models/StudentProfile');
const Batch = require('../models/Batch');
const Attendance = require('../models/Attendance');
const TrainingSession = require('../models/TrainingSession');
const Test = require('../models/Test');
const Question = require('../models/Question');
const TestAttempt = require('../models/TestAttempt');
const Notice = require('../models/Notice');
const Fee = require('../models/Fee');
const Notification = require('../models/Notification');
const { HttpError } = require('../middleware/errors');
const exams = require('../services/exams');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });
const studentProfile = async userId => {
  const profile = await StudentProfile.findOne({ userId }).populate('userId', 'name email phone').populate('batchId');
  if (!profile) throw new HttpError(404, 'Student profile not found');
  return profile;
};
const todayRange = (value = new Date()) => { const d = new Date(value); const from = new Date(d); from.setHours(0,0,0,0); const to = new Date(from); to.setDate(to.getDate()+1); return { $gte: from, $lt: to }; };

async function getProfile(req,res) { return respond(res, await studentProfile(req.user.id)); }
async function getStudent(req,res) { const p = await StudentProfile.findById(req.params.id).populate('userId','name email phone').populate('batchId'); if (!p) throw new HttpError(404,'Student not found'); return respond(res,p); }
async function listStudents(req,res) {
  const filter = {};
  if (req.query.batchId) filter.batchId = req.query.batchId;
  if (req.query.q) { const regex = new RegExp(String(req.query.q).replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'i'); const users = await User.find({role:'student',name:regex}).select('_id'); filter.userId = { $in: users.map(u=>u._id) }; }
  const data = await StudentProfile.find(filter).populate('userId','name email phone isActive').populate('batchId').limit(100).sort({createdAt:-1});
  return respond(res,data);
}
async function createStudent(req,res) {
  const { name,email,phone,password,studentId,batchId,course,address,joiningDate } = req.body;
  if (!name || !email || !password || !studentId) throw new HttpError(400,'name, email, password and studentId are required');
  if (password.length < 10) throw new HttpError(400,'Initial password must be at least 10 characters');
  const user = await User.create({name,email,phone,passwordHash:await User.hashPassword(password),role:'student'});
  try { const profile = await StudentProfile.create({userId:user._id,studentId,batchId,course,address,joiningDate}); return respond(res,{user,profile},201); }
  catch(e) { await User.findByIdAndDelete(user._id); throw e; }
}
async function updateStudent(req,res) {
  const p = await StudentProfile.findById(req.params.id); if (!p) throw new HttpError(404,'Student not found');
  const fields = ['studentId','batchId','course','address','photo','joiningDate']; fields.forEach(k=>{if(req.body[k]!==undefined)p[k]=req.body[k];}); await p.save();
  if (req.body.name || req.body.phone || req.body.email) await User.findByIdAndUpdate(p.userId,{...(req.body.name?{name:req.body.name}:{}),...(req.body.phone?{phone:req.body.phone}:{}),...(req.body.email?{email:req.body.email}:{})});
  return respond(res,await StudentProfile.findById(p.id).populate('userId','name email phone isActive').populate('batchId'));
}
async function deactivateStudent(req,res) { const p=await StudentProfile.findById(req.params.id); if(!p)throw new HttpError(404,'Student not found'); await User.findByIdAndUpdate(p.userId,{isActive:false}); return respond(res,{message:'Student deactivated'}); }
async function studentQr(req,res) { const p=await StudentProfile.findOne({userId:req.user.id}).select('+qrToken').populate('userId','name').populate('batchId','name'); if(!p)throw new HttpError(404,'Student profile not found'); return respond(res,{token:p.qrToken,studentId:p.studentId,name:p.userId.name,batch:p.batchId?.name||''}); }
async function lookupQr(req, res) {
  const token = String(req.body.token || '');
  if (token.length < 32) throw new HttpError(400, 'QR token is invalid');
  const profile = await StudentProfile.findOne({ qrToken: token })
    .select('+qrToken')
    .populate('userId', 'name phone isActive')
    .populate('batchId', 'name');
  if (!profile || !profile.userId?.isActive) {
    throw new HttpError(404, 'Student QR was not recognized');
  }
  const attendanceDate = String(req.body.attendanceDate || '');
  const day = attendanceDate ? new Date(`${attendanceDate}T00:00:00.000Z`) : new Date();
  if (Number.isNaN(day.getTime())) throw new HttpError(400, 'Invalid attendance date');
  day.setUTCHours(0, 0, 0, 0);
  const currentAttendance = await Attendance.findOne({
    studentId: profile._id,
    date: day,
    status: 'present',
  }).sort({ time: -1 });
  return respond(res, {
    profile: {
      id: profile.id,
      studentId: profile.studentId,
      name: profile.userId.name,
      phone: profile.userId.phone,
      batch: profile.batchId?.name || '',
      photo: profile.photo,
      course: profile.course || '',
      dateOfBirth: profile.dateOfBirth,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      chestCm: profile.chestCm,
      joiningDate: profile.joiningDate,
    },
    currentAttendance: currentAttendance ? {
      id: currentAttendance.id,
      entryAt: currentAttendance.entryAt || currentAttendance.time,
      exitAt: currentAttendance.exitAt,
      state: currentAttendance.exitAt ? 'exited' : 'inside',
    } : null,
  });
}
async function listAttendance(req,res) {
  const filter={};
  if(req.query.studentId) { if(!mongoose.isValidObjectId(req.query.studentId)) throw new HttpError(400,'Student ID is invalid'); filter.studentId=req.query.studentId; }
  if(req.query.batchId) { if(!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400,'Batch ID is invalid'); filter.batchId=req.query.batchId; }
  if(req.query.from||req.query.to) {
    const from=req.query.from?new Date(req.query.from):null, to=req.query.to?new Date(req.query.to):null;
    if((from&&Number.isNaN(from.getTime()))||(to&&Number.isNaN(to.getTime()))||(from&&to&&to<from)) throw new HttpError(400,'Attendance date range is invalid');
    filter.date={...(from?{$gte:from}:{}),...(to?{$lte:to}:{})};
  }
  if(req.user.role==='student')filter.studentId=(await studentProfile(req.user.id))._id;
  const data=await Attendance.find(filter).populate({path:'studentId',populate:{path:'userId',select:'name phone'}}).populate('batchId','name').populate('markedBy','name').sort({date:-1,time:-1}).limit(1000);
  const present=data.filter(x=>x.status==='present').length, total=data.length;
  return respond(res,{records:data,summary:{totalClasses:total,present,absent:data.filter(x=>x.status==='absent').length,percentage:total?Math.round(present/total*10000)/100:0}});
}
async function markAttendance(req,res) {
  const {token,studentProfileId,trainingSessionId,status='present',date=new Date(),attendanceDate,markedAt,action='entry'}=req.body;
  let profile;
  if(token) profile=await StudentProfile.findOne({qrToken:token}).select('+qrToken');
  else if(studentProfileId) profile=await StudentProfile.findById(studentProfileId);
  if(!profile)throw new HttpError(404,'Student not found for attendance');
  const batchId=profile.batchId;
  const day=new Date(attendanceDate || date); if(Number.isNaN(day.getTime()))throw new HttpError(400,'Invalid attendance date'); day.setUTCHours(0,0,0,0);
  const markedTime=markedAt ? new Date(markedAt) : new Date(); if(Number.isNaN(markedTime.getTime()))throw new HttpError(400,'Invalid attendance time');
  const openEntry = await Attendance.findOne({ studentId: profile._id, date: day, status: 'present', exitAt: null }).sort({ time: -1 });
  if (action === 'exit') {
    if (!openEntry) throw new HttpError(409, 'No open entry was found for this student today');
    openEntry.exitAt = markedTime;
    await openEntry.save();
    return respond(res, { attendance: openEntry, action: 'exit' });
  }
  if (openEntry) return respond(res, { attendance: openEntry, action: 'already_inside' });
  const entry=await Attendance.create({studentId:profile._id,batchId,trainingSessionId:trainingSessionId||null,date:day,time:markedTime,entryAt:markedTime,status,markedBy:req.user._id});
  return respond(res,{attendance:entry,action:'entry'},201);
}
async function listBatches(_req,res) { return respond(res,await Batch.find().sort({name:1})); }
async function createBatch(req,res) { if(!req.body.name)throw new HttpError(400,'Batch name is required'); return respond(res,await Batch.create(req.body),201); }
async function updateBatch(req,res) { const b=await Batch.findByIdAndUpdate(req.params.id,req.body,{new:true,runValidators:true}); if(!b)throw new HttpError(404,'Batch not found'); return respond(res,b); }
async function listTraining(req,res) {
  const filter={status:{$ne:'cancelled'}};
  if(req.user.role==='student'){const p=await studentProfile(req.user.id);if(!p.batchId) return respond(res,[]);filter.batchId=p.batchId._id;}
  else if(req.query.batchId)filter.batchId=req.query.batchId;
  if(req.query.from)filter.date={$gte:new Date(req.query.from)};
  const data=await TrainingSession.find(filter).populate('batchId','name').sort({date:1}).limit(100);return respond(res,data);
}
async function createTraining(req,res) { if(!req.body.title||!req.body.batchId||!req.body.date)throw new HttpError(400,'title, batchId and date are required'); return respond(res,await TrainingSession.create({...req.body,createdBy:req.user._id}),201); }
async function listTests(req,res) {
  let filter=req.user.role==='admin'?{}:{status:'published',startTime:{$lte:new Date()},endTime:{$gte:new Date()}};
  if(req.user.role==='student'){const p=await studentProfile(req.user.id);if(!p.batchId)return respond(res,[]);filter.batchId=p.batchId._id;}
  const tests=await Test.find(filter).populate('batchId','name').sort({startTime:1}).limit(100);
  const result=await Promise.all(tests.map(async t=>({ ...t.toJSON(), questionCount:await Question.countDocuments({testId:t._id}), ...(req.user.role==='student'?{attempt:await TestAttempt.findOne({testId:t._id,studentId:(await studentProfile(req.user.id))._id}).sort({createdAt:-1}).select('status percentage obtainedMarks submittedAt')}: {}) })));
  return respond(res,result);
}
async function createTest(req,res) { const b=req.body; if(!b.title||!b.batchId||!b.startTime||!b.endTime||!b.duration)throw new HttpError(400,'title, batchId, startTime, endTime and duration are required'); if(new Date(b.endTime)<=new Date(b.startTime))throw new HttpError(400,'endTime must be after startTime'); return respond(res,await Test.create({...b,createdBy:req.user._id}),201); }
async function addQuestion(req,res) { const test=await Test.findById(req.params.id); if(!test)throw new HttpError(404,'Test not found'); if(test.status==='closed')throw new HttpError(409,'Closed tests cannot be changed'); const {questionText,options,correctAnswer,marks=1}=req.body; if(!questionText||!Array.isArray(options)||options.length!==4||!Number.isInteger(correctAnswer)||correctAnswer<0||correctAnswer>3)throw new HttpError(400,'Question requires text, four options, and correctAnswer index 0-3'); const q=await Question.create({testId:test._id,questionText,options,correctAnswer,marks,order:await Question.countDocuments({testId:test._id})}); test.totalMarks+=Number(marks); await test.save(); return respond(res,q,201); }
async function publishTest(req,res) { const test=await Test.findById(req.params.id); if(!test)throw new HttpError(404,'Test not found'); if(!await Question.countDocuments({testId:test.id}))throw new HttpError(409,'Add at least one question before publishing'); test.status=req.body.status||'published'; await test.save(); return respond(res,test); }
async function getTest(req,res) { const t=await Test.findById(req.params.id).populate('batchId','name'); if(!t)throw new HttpError(404,'Test not found'); if(req.user.role==='student'&&(t.status!=='published'||String(t.batchId?._id)!==String((await studentProfile(req.user.id)).batchId?._id)))throw new HttpError(404,'Test not found'); const questions=await Question.find({testId:t.id}).select('questionText options marks order').sort({order:1}); return respond(res,{test:t,questions}); }
async function startTest(req,res) { const p=await studentProfile(req.user.id); const data=await exams.startAttempt(req.params.id,p._id); const result=Array.isArray(data)?{questions:data}:data; return respond(res,result,201); }
async function submitTest(req,res) { const p=await studentProfile(req.user.id); return respond(res,await exams.submitAttempt(req.params.id,p._id,req.body.answers||[])); }
async function listResults(req,res) { const filter={status:'submitted'}; if(req.user.role==='student')filter.studentId=(await studentProfile(req.user.id))._id; else if(req.query.studentId)filter.studentId=req.query.studentId; const data=await TestAttempt.find(filter).populate('testId','title totalMarks').populate({path:'studentId',populate:{path:'userId',select:'name'}}).sort({submittedAt:-1}).limit(200); return respond(res,data); }
async function createNotice(req,res) { const {title,description}=req.body;if(!title||!description)throw new HttpError(400,'title and description are required');const notice=await Notice.create({...req.body,createdBy:req.user._id});const profiles=await StudentProfile.find(notice.batchId?{batchId:notice.batchId}:{}).select('userId');if(profiles.length)await Notification.insertMany(profiles.map(p=>({userId:p.userId,title:notice.title,message:notice.description,type:'notice',data:{noticeId:notice._id}})));return respond(res,notice,201); }
async function listNotices(req,res) { const filter=req.user.role==='admin'?{}:{isPublished:true}; if(req.user.role==='student'){const p=await studentProfile(req.user.id);filter.$or=[{batchId:null},{batchId:p.batchId?._id}];} return respond(res,await Notice.find(filter).populate('batchId','name').sort({publishedAt:-1}).limit(100)); }
async function getFees(req,res) {
  const filter = {};
  if (req.user.role === 'student') {
    filter.studentId = (await studentProfile(req.user.id))._id;
  } else {
    if (req.query.studentId) {
      if (!mongoose.isValidObjectId(req.query.studentId)) throw new HttpError(400, 'Student ID is invalid');
      filter.studentId = req.query.studentId;
    }
    if (req.query.batchId) {
      if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
      const members = await StudentProfile.find({ batchId: req.query.batchId }).select('_id').lean();
      filter.$or = [
        { batchId: req.query.batchId },
        { batchId: null, studentId: { $in: members.map(profile => profile._id) } },
      ];
    }
    const profileFilter = req.query.studentId
      ? { _id: req.query.studentId }
      : req.query.batchId
          ? { batchId: req.query.batchId }
          : {};
    const profiles = await StudentProfile.find(profileFilter)
      .populate('userId', 'name phone')
      .populate('batchId', 'name')
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();
    const fees = await Fee.find({ studentId: { $in: profiles.map(profile => profile._id) } })
      .populate('batchId', 'name')
      .populate({
        path: 'studentId',
        select: 'studentId photo course batchId',
        populate: [
          { path: 'userId', select: 'name phone' },
          { path: 'batchId', select: 'name' },
        ],
      })
      .sort({ createdAt: -1 });
    const feeStudentIds = new Set(fees.map(fee => String(fee.studentId?._id || fee.studentId)));
    const zeroRows = profiles
      .filter(profile => !feeStudentIds.has(String(profile._id)))
      .map(profile => ({
        _id: null,
        studentId: profile,
        batchId: profile.batchId,
        totalFees: 0,
        paidAmount: 0,
        remainingAmount: 0,
        status: 'due',
        payments: [],
        adjustments: [],
        noFeeRecord: true,
      }));
    return respond(res, [...fees, ...zeroRows]);
  }
  const fees = await Fee.find(filter)
    .populate('batchId', 'name')
    .populate({
      path: 'studentId',
      select: 'studentId photo course batchId',
      populate: [
        { path: 'userId', select: 'name phone' },
        { path: 'batchId', select: 'name' },
      ],
    })
    .sort({ createdAt: -1 });
  return respond(res, fees);
}
async function feeSummary(req,res) {
  const match = {};
  if (req.query.batchId) {
    if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
    const members = await StudentProfile.find({ batchId: req.query.batchId }).select('_id').lean();
    match.$or = [{ batchId: req.query.batchId }, { batchId: null, studentId: { $in: members.map(x => x._id) } }];
  }
  const rows = await Fee.aggregate([{ $match: match }, { $group: { _id: null, totalFees: { $sum: '$totalFees' }, totalIncome: { $sum: '$paidAmount' }, records: { $sum: 1 } } }]);
  const row = rows[0] || { totalFees: 0, totalIncome: 0, records: 0 };
  return respond(res, { totalFees: row.totalFees, totalIncome: row.totalIncome, totalDue: Math.max(0, row.totalFees - row.totalIncome), records: row.records });
}
async function createFee(req,res) { const {studentId,totalFees}=req.body;if(!studentId||!Number.isFinite(Number(totalFees))||Number(totalFees)<0)throw new HttpError(400,'studentId and a valid totalFees amount are required');return respond(res,await Fee.create({studentId,totalFees,paidAmount:0}),201); }
async function recordPayment(req,res) { const fee=await Fee.findById(req.params.id);if(!fee)throw new HttpError(404,'Fee record not found');const amount=Number(req.body.amount);if(!Number.isFinite(amount)||amount<=0||amount>fee.totalFees-fee.paidAmount)throw new HttpError(400,'Payment amount must be positive and cannot exceed the remaining balance');const paymentMethod=String(req.body.paymentMethod||'cash').toLowerCase();if(!['cash','online'].includes(paymentMethod))throw new HttpError(400,'Payment method must be cash or online');const transactionId=String(req.body.transactionId||'').trim();if(paymentMethod==='online'&&!transactionId)throw new HttpError(400,'Transaction ID is required for online payments');const paymentDate=req.body.paymentDate?new Date(req.body.paymentDate):new Date();if(Number.isNaN(paymentDate.getTime()))throw new HttpError(400,'Payment date/time is invalid');fee.paidAmount+=amount;fee.payments.push({amount,paymentDate,paymentMethod,transactionId:paymentMethod==='online'?transactionId:'',note:String(req.body.note||'').trim(),recordedBy:req.user._id});fee.status=fee.paidAmount>=fee.totalFees?'paid':'partial';await fee.save();return respond(res,fee); }
async function dashboard(req,res) { if(req.user.role==='student'){const p=await studentProfile(req.user.id);const [att,tests,trainings,notices,fees]=await Promise.all([Attendance.find({studentId:p._id}).sort({date:-1}).limit(100),Test.find({batchId:p.batchId?._id,status:'published',endTime:{$gte:new Date()}}).sort({startTime:1}).limit(5),TrainingSession.find({batchId:p.batchId?._id,date:{$gte:todayRange().$gte},status:'scheduled'}).sort({date:1}).limit(5),Notice.find({isPublished:true,$or:[{batchId:null},{batchId:p.batchId?._id}]}).sort({publishedAt:-1}).limit(3),Fee.find({studentId:p._id}).sort({createdAt:-1}).limit(1)]);const present=att.filter(a=>a.status==='present').length;return respond(res,{profile:p,attendance:{records:att,total:att.length,present,percentage:att.length?Math.round(present/att.length*10000)/100:0},tests,trainings,notices,fees});}
  const today=todayRange();const [students,present,batches,classes,latest]=await Promise.all([StudentProfile.countDocuments(),Attendance.countDocuments({date:today,status:'present'}),Batch.countDocuments({status:'active'}),TrainingSession.countDocuments({date:today,status:{$ne:'cancelled'}}),Attendance.find({date:today}).populate({path:'studentId',populate:{path:'userId',select:'name'}}).sort({time:-1}).limit(8)]);return respond(res,{stats:{totalStudents:students,todayPresent:present,totalBatches:batches,todayClasses:classes},recentAttendance:latest});
}
async function academySettings(_req,res) { return respond(res,{name:process.env.ACADEMY_NAME||'MS Defence Academy',location:process.env.ACADEMY_LOCATION||'',phone:process.env.ACADEMY_PHONE||''}); }
module.exports={getProfile,getStudent,listStudents,createStudent,updateStudent,deactivateStudent,studentQr,lookupQr,listAttendance,markAttendance,listBatches,createBatch,updateBatch,listTraining,createTraining,listTests,createTest,addQuestion,publishTest,getTest,startTest,submitTest,listResults,createNotice,listNotices,getFees,feeSummary,createFee,recordPayment,dashboard,academySettings};
