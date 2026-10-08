const Notification=require('../models/Notification');const {HttpError}=require('../middleware/errors');
async function list(req,res){const records=await Notification.find({userId:req.user._id}).sort({createdAt:-1}).limit(100);res.json({ok:true,data:records});}
async function markRead(req,res){const record=await Notification.findOneAndUpdate({_id:req.params.id,userId:req.user._id},{readAt:new Date()},{new:true});if(!record)throw new HttpError(404,'Notification not found');res.json({ok:true,data:record});}
async function remove(req,res){const record=await Notification.findOneAndDelete({_id:req.params.id,userId:req.user._id});if(!record)throw new HttpError(404,'Notification not found');res.json({ok:true,data:{message:'Notification deleted'}});}
module.exports={list,markRead,remove};
