const express=require('express');const {asyncHandler}=require('../middleware/errors');const auth=require('../controllers/auth');const notifications=require('../controllers/notifications');const {authenticate,allowRoles}=require('../middleware/auth');const c=require('../controllers/academy');
const r=express.Router();r.post('/auth/login',asyncHandler(auth.login));r.get('/auth/me',authenticate,asyncHandler(auth.me));
r.use('/students',require('./students'));r.use('/attendance',require('./attendance'));r.use('/',require('./academy'));r.use('/tests',require('./tests'));
r.get('/notices',authenticate,asyncHandler(c.listNotices));r.post('/notices',authenticate,allowRoles('admin'),asyncHandler(c.createNotice));r.get('/fees',authenticate,asyncHandler(c.getFees));r.post('/fees',authenticate,allowRoles('admin'),asyncHandler(c.createFee));r.post('/fees/:id/payments',authenticate,allowRoles('admin'),asyncHandler(c.recordPayment));
r.get('/notifications',authenticate,asyncHandler(notifications.list));r.patch('/notifications/:id/read',authenticate,asyncHandler(notifications.markRead));
module.exports=r;
