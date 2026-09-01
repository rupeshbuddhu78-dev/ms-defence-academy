const User = require('../models/User');
const generateToken = require('../utils/generateToken');
const { logAudit } = require('../utils/auditLogger');

// Public / normal user registration (role = USER, not student)
exports.registerUser = async (req, res, next) => {
  try {
    const { fullName, email, mobile, password, confirmPassword } = req.body;

    if (!fullName || !password) {
      return res.status(400).json({
        success: false,
        message: 'Full name and password are required',
        code: 'VALIDATION_ERROR'
      });
    }
    if (!email && !mobile) {
      return res.status(400).json({
        success: false,
        message: 'Email or mobile is required',
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

    if (mobile) {
      const exists = await User.findOne({ mobile });
      if (exists) {
        return res.status(409).json({
          success: false,
          message: 'Mobile number already registered',
          code: 'MOBILE_EXISTS'
        });
      }
    }
    if (email) {
      const exists = await User.findOne({ email: email.toLowerCase() });
      if (exists) {
        return res.status(409).json({
          success: false,
          message: 'Email already registered',
          code: 'EMAIL_EXISTS'
        });
      }
    }

    const user = await User.create({
      role: 'USER',
      fullName,
      email: email ? email.toLowerCase() : undefined,
      mobile,
      password,
      isActive: true
    });

    const token = generateToken(user._id, user.role);

    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      data: {
        token,
        role: 'USER',
        user: {
          id: user._id,
          fullName: user.fullName,
          email: user.email,
          mobile: user.mobile
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// Public / normal user login
exports.userLogin = async (req, res, next) => {
  try {
    const { emailOrMobile, password } = req.body;
    if (!emailOrMobile || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email/Mobile and password are required',
        code: 'VALIDATION_ERROR'
      });
    }

    const user = await User.findOne({
      $or: [
        { email: emailOrMobile.toLowerCase() },
        { mobile: emailOrMobile }
      ],
      role: 'USER'
    }).select('+password');

    if (!user) {
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

    const token = generateToken(user._id, user.role);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        role: 'USER',
        user: {
          id: user._id,
          fullName: user.fullName,
          email: user.email,
          mobile: user.mobile,
          photoUrl: user.photoUrl
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// Admin: list all public (USER) registrations
exports.adminListUsers = async (req, res, next) => {
  try {
    const { search, page = 1, limit = 20 } = req.query;
    const query = { role: 'USER' };
    if (search) {
      query.$or = [
        { fullName: new RegExp(search, 'i') },
        { email: new RegExp(search, 'i') },
        { mobile: new RegExp(search, 'i') }
      ];
    }
    const skip = (Math.max(1, parseInt(page)) - 1) * Math.min(100, parseInt(limit) || 20);
    const lim = Math.min(100, parseInt(limit) || 20);

    const [users, total] = await Promise.all([
      User.find(query)
        .select('-password -passwordResetToken -passwordResetExpires -fcmTokens')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(lim),
      User.countDocuments(query)
    ]);

    res.status(200).json({
      success: true,
      data: {
        users,
        pagination: {
          page: parseInt(page) || 1,
          limit: lim,
          total,
          pages: Math.ceil(total / lim)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// Admin: list pending student registrations
exports.adminPendingStudents = async (req, res, next) => {
  try {
    const Student = require('../models/Student');
    const students = await Student.find({ status: 'PENDING' })
      .populate('user', 'email isActive createdAt')
      .sort({ createdAt: -1 });
    res.status(200).json({
      success: true,
      data: { students, count: students.length }
    });
  } catch (error) {
    next(error);
  }
};

// Public content home (videos + notices for everyone)
exports.publicHome = async (req, res, next) => {
  try {
    const Media = require('../models/Media');
    const Notice = require('../models/Notice');

    const [videos, gallery, notices] = await Promise.all([
      Media.find({ isPublished: true, type: 'VIDEO', visibility: { $in: ['PUBLIC', undefined] } })
        .sort({ isFeatured: -1, sortOrder: 1, createdAt: -1 })
        .limit(20),
      Media.find({ isPublished: true, type: 'IMAGE', visibility: { $in: ['PUBLIC', undefined] } })
        .sort({ createdAt: -1 })
        .limit(12),
      Notice.find({
        isPublished: true,
        audience: { $in: ['EVERYONE', 'PUBLIC'] }
      }).sort({ priority: -1, createdAt: -1 }).limit(10)
    ]);

    // Also include notices with no audience set (legacy)
    const allPublicNotices = await Notice.find({
      isPublished: true,
      $or: [
        { audience: { $in: ['EVERYONE', 'PUBLIC'] } },
        { audience: { $exists: false } },
        { audience: null }
      ]
    }).sort({ priority: -1, createdAt: -1 }).limit(10);

    res.status(200).json({
      success: true,
      data: {
        academy: {
          name: 'MS DEFENCE ACADEMY',
          tagline: 'Train With Discipline. Prepare With Purpose.',
          location: 'Shahpur Patori, Samastipur, Bihar',
          phone: ['8228949212', '9117841390'],
          mapsUrl: 'https://maps.app.goo.gl/RaMjJkFijdRPSZie8?g_st=aw'
        },
        highlights: [
          { title: 'NDA Preparation', desc: 'Complete written + SSB guidance' },
          { title: 'Physical Training', desc: 'Daily PT, running, endurance' },
          { title: 'Written Exam', desc: 'Math, English, GK modules' },
          { title: 'SSB Guidance', desc: 'Interview & personality development' },
          { title: 'Discipline', desc: 'Leadership & academy routine' },
          { title: 'Mock Tests', desc: 'Regular practice tests' }
        ],
        videos: videos.length ? videos : [],
        gallery: gallery.length ? gallery : [],
        notices: allPublicNotices
      }
    });
  } catch (error) {
    next(error);
  }
};

// USER profile
exports.getUserProfile = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    if (!user || user.role !== 'USER') {
      return res.status(404).json({ success: false, message: 'Profile not found', code: 'NOT_FOUND' });
    }
    res.status(200).json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
};

exports.updateUserProfile = async (req, res, next) => {
  try {
    const allowed = ['fullName', 'mobile', 'email'];
    const updates = {};
    allowed.forEach(f => { if (req.body[f] !== undefined) updates[f] = req.body[f]; });
    const user = await User.findByIdAndUpdate(req.user._id, updates, { new: true, runValidators: true })
      .select('-password');
    res.status(200).json({ success: true, message: 'Profile updated', data: user });
  } catch (error) {
    next(error);
  }
};
