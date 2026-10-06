const express=require('express');const c=require('../controllers/academy');const {asyncHandler}=require('../middleware/errors');const {authenticate,allowRoles}=require('../middleware/auth');
const r=express.Router();r.use(authenticate);
r.get('/profile',allowRoles('student'),asyncHandler(c.getProfile));r.get('/profile/qr',allowRoles('student'),asyncHandler(c.studentQr));
r.get('/',allowRoles('admin'),asyncHandler(c.listStudents));r.post('/',allowRoles('admin'),asyncHandler(c.createStudent));r.get('/:id',allowRoles('admin'),asyncHandler(c.getStudent));r.patch('/:id',allowRoles('admin'),asyncHandler(c.updateStudent));r.delete('/:id',allowRoles('admin'),asyncHandler(c.deactivateStudent));
module.exports=r;
