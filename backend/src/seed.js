require('dotenv').config();
const {connectDatabase}=require('./config/db');const User=require('./models/User');const Batch=require('./models/Batch');const StudentProfile=require('./models/StudentProfile');
async function seed(){await connectDatabase();let batch=await Batch.findOne({name:'Army GD (Morning)'});if(!batch)batch=await Batch.create({name:'Army GD (Morning)',course:'Army GD',trainer:'Instructor Sharma',startTime:'06:00',endTime:'08:00',location:process.env.ACADEMY_LOCATION||'Academy Ground'});
const ensure=async({name,email,phone,password,role})=>{let user=await User.findOne({email});if(!user)user=await User.create({name,email,phone,role,passwordHash:await User.hashPassword(password)});return user;};
await ensure({name:'Academy Admin',email:'admin@msda.local',phone:'8228949212',password:'Admin@12345',role:'admin'});
const student=await ensure({name:'Ravi Kumar',email:'student@msda.local',phone:'9000000000',password:'Student@12345',role:'student'});
if(!await StudentProfile.findOne({userId:student._id}))await StudentProfile.create({userId:student._id,studentId:'MSDA1256',batchId:batch._id,course:'Army GD',address:'Shahpur Patori, Samastipur'});
console.log('Seed complete. Demo admin: admin@msda.local / Admin@12345; student: student@msda.local / Student@12345. Change these before any shared or production use.');await require('mongoose').disconnect();}
seed().catch(e=>{console.error(e);process.exit(1);});
