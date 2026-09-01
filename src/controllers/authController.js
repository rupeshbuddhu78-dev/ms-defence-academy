const User = require('../models/User');
const Student = require('../models/Student');
const Admin = require('../models/Admin');
const generateToken = require('../utils/generateToken');
const { logAudit } = require('../utils/auditLogger');
const crypto = require('crypto');

// @desc    Student registration
// @route   POST /api/auth/student/register
exports.studentRegister = async (req, res, next) => {
  try {
    const {
      fullName, fatherName, motherName, mobile, alternateMobile,
      dateOfBirth, gender, address, district, state, course, password, confirmPassword
    } = req.body;

    if (!fullName || !mobile || !password) {
      return res.status(400).json({
        success: false,
        message: 'Full name, mobile and password are required',
        code: 'VALIDATION_ERROR'
      });
    }

    if (password !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Passwords do not match',
        code: 'PASSWORD_MISMATCH'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
        code: 'WEAK_PASSWORD'
      });
    }

    const existingUser = await User.findOne({ mobile });
    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Mobile number already registered',
        code: 'MOBILE_EXISTS'
      });
    }

    const studentId = await Student.generateStudentId();
    const qrIdentifier = Student.generateQrIdentifier();

    const user = await User.create({
      role: 'STUDENT',
      mobile,
      password,
      isActive: false // pending admin approval
    });

    const student = await Student.create({
      user: user._id,
      studentId,
      fullName,
      fatherName,
      motherName,
      mobile,
      alternateMobile,
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : undefined,
      gender,
      address,
      district,
      state: state || 'Bihar',
      course: course || 'NDA',
      qrIdentifier,
      status: 'PENDING'
    });

    res.status(201).json({
      success: true,
      message: 'Registration successful. Please wait for admin approval.',
      data: {
        studentId: student.studentId,
        fullName: student.fullName,
        status: student.status
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Student login
// @route   POST /api/auth/student/login
exports.studentLogin = async (req, res, next) => {
  try {
    const { studentIdOrMobile, password } = req.body;

    if (!studentIdOrMobile || !password) {
      return res.status(400).json({
        success: false,
        message: 'Student ID/Mobile and password are required',
        code: 'VALIDATION_ERROR'
      });
    }

    let student = await Student.findOne({
      $or: [
        { studentId: studentIdOrMobile.toUpperCase() },
        { mobile: studentIdOrMobile }
      ]
    }).populate('batch', 'name course startTime endTime instructor');

    if (!student) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    const user = await User.findById(student.user).select('+password');
    if (!user || user.role !== 'STUDENT') {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    if (user.isLocked && user.isLocked()) {
      return res.status(401).json({
        success: false,
        message: 'Account temporarily locked due to multiple failed attempts',
        code: 'ACCOUNT_LOCKED'
      });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      user.failedLoginAttempts = (user.failedLoginAttempts || 0) + 1;
      if (user.failedLoginAttempts >= 5) {
        user.lockUntil = new Date(Date.now() + 30 * 60 * 1000);
      }
      await user.save();
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    if (!user.isActive || student.status !== 'ACTIVE') {
      return res.status(403).json({
        success: false,
        message: 'Account not active. Please contact academy admin.',
        code: 'ACCOUNT_INACTIVE'
      });
    }

    user.failedLoginAttempts = 0;
    user.lockUntil = undefined;
    user.lastLogin = new Date();
    await user.save();

    const token = generateToken(user._id, user.role);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        role: 'STUDENT',
        mustChangePassword: user.mustChangePassword,
        student: {
          id: student._id,
          studentId: student.studentId,
          fullName: student.fullName,
          photoUrl: student.photoUrl,
          batch: student.batch,
          course: student.course,
          status: student.status
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Admin login
// @route   POST /api/auth/admin/login
exports.adminLogin = async (req, res, next) => {
  try {
    const { adminIdOrEmailOrMobile, password } = req.body;

    if (!adminIdOrEmailOrMobile || !password) {
      return res.status(400).json({
        success: false,
        message: 'Admin ID/Email/Mobile and password are required',
        code: 'VALIDATION_ERROR'
      });
    }

    let admin = await Admin.findOne({
      $or: [
        { adminId: adminIdOrEmailOrMobile },
        { email: adminIdOrEmailOrMobile.toLowerCase() },
        { mobile: adminIdOrEmailOrMobile }
      ]
    });

    let user;
    if (admin) {
      user = await User.findById(admin.user).select('+password');
    } else {
      // Try by email/mobile on User
      user = await User.findOne({
        $or: [
          { email: adminIdOrEmailOrMobile.toLowerCase() },
          { mobile: adminIdOrEmailOrMobile }
        ],
        role: 'ADMIN'
      }).select('+password');
      if (user) {
        admin = await Admin.findOne({ user: user._id });
      }
    }

    if (!user || user.role !== 'ADMIN') {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    if (user.isLocked && user.isLocked()) {
      return res.status(401).json({
        success: false,
        message: 'Account temporarily locked',
        code: 'ACCOUNT_LOCKED'
      });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      user.failedLoginAttempts = (user.failedLoginAttempts || 0) + 1;
      if (user.failedLoginAttempts >= 5) {
        user.lockUntil = new Date(Date.now() + 30 * 60 * 1000);
      }
      await user.save();
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Account deactivated',
        code: 'ACCOUNT_INACTIVE'
      });
    }

    user.failedLoginAttempts = 0;
    user.lockUntil = undefined;
    user.lastLogin = new Date();
    await user.save();

    await logAudit({
      adminId: user._id,
      action: 'ADMIN_LOGIN',
      entityType: 'Admin',
      entityId: admin?._id,
      req
    });

    const token = generateToken(user._id, user.role);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        role: 'ADMIN',
        mustChangePassword: user.mustChangePassword,
        admin: {
          id: admin?._id,
          adminId: admin?.adminId,
          fullName: admin?.fullName || 'Admin',
          email: admin?.email,
          mobile: admin?.mobile
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Change password
// @route   POST /api/auth/change-password
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword, confirmPassword } = req.body;

    if (!currentPassword || !newPassword || !confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'All password fields are required',
        code: 'VALIDATION_ERROR'
      });
    }

    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'New passwords do not match',
        code: 'PASSWORD_MISMATCH'
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
        code: 'WEAK_PASSWORD'
      });
    }

    const user = await User.findById(req.user._id).select('+password');
    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Current password is incorrect',
        code: 'INVALID_PASSWORD'
      });
    }

    user.password = newPassword;
    user.mustChangePassword = false;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Password changed successfully'
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Forgot password (request reset)
// @route   POST /api/auth/forgot-password
exports.forgotPassword = async (req, res, next) => {
  try {
    const { mobileOrEmail } = req.body;
    if (!mobileOrEmail) {
      return res.status(400).json({
        success: false,
        message: 'Mobile or email is required',
        code: 'VALIDATION_ERROR'
      });
    }

    const user = await User.findOne({
      $or: [
        { mobile: mobileOrEmail },
        { email: mobileOrEmail.toLowerCase() }
      ]
    });

    // Always return success to prevent enumeration
    if (!user) {
      return res.status(200).json({
        success: true,
        message: 'If the account exists, a reset token has been generated. Contact admin for OTP.'
      });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    user.passwordResetToken = crypto.createHash('sha256').update(resetToken).digest('hex');
    user.passwordResetExpires = Date.now() + 30 * 60 * 1000;
    await user.save({ validateBeforeSave: false });

    // In production: send OTP via SMS/Email. For now return token only in non-prod for testing.
    const response = {
      success: true,
      message: 'If the account exists, a reset token has been generated. Contact admin for OTP.'
    };
    if (process.env.NODE_ENV !== 'production') {
      response.resetToken = resetToken; // only for development
    }
    res.status(200).json(response);
  } catch (error) {
    next(error);
  }
};

// @desc    Reset password
// @route   POST /api/auth/reset-password
exports.resetPassword = async (req, res, next) => {
  try {
    const { token, newPassword, confirmPassword } = req.body;
    if (!token || !newPassword || !confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Token and new password are required',
        code: 'VALIDATION_ERROR'
      });
    }
    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Passwords do not match',
        code: 'PASSWORD_MISMATCH'
      });
    }

    const hashed = crypto.createHash('sha256').update(token).digest('hex');
    const user = await User.findOne({
      passwordResetToken: hashed,
      passwordResetExpires: { $gt: Date.now() }
    }).select('+passwordResetToken +passwordResetExpires');

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired reset token',
        code: 'INVALID_TOKEN'
      });
    }

    user.password = newPassword;
    user.passwordResetToken = undefined;
    user.passwordResetExpires = undefined;
    user.mustChangePassword = false;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Password reset successful'
    });
  } catch (error) {
    next(error);
  }
};
