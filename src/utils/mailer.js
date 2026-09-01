const nodemailer = require('nodemailer');

let transporter = null;

const getTransporter = () => {
  if (transporter) return transporter;
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER) {
    return null;
  }
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });
  return transporter;
};

exports.sendOtpEmail = async (to, otp) => {
  const t = getTransporter();
  const from = process.env.SMTP_FROM || process.env.SMTP_USER || 'noreply@msdefenceacademy.com';
  const subject = 'MS Defence Academy - Password Reset OTP';
  const text = `Your password reset OTP is ${otp}. It expires in 5 minutes. Do not share this code.`;
  const html = `<p>Your password reset OTP is <strong>${otp}</strong>.</p><p>It expires in 5 minutes.</p><p>MS Defence Academy</p>`;

  if (!t) {
    if (process.env.NODE_ENV !== 'production') {
      console.log(`[DEV OTP] to=${to} otp=${otp}`);
      return { sent: false, devLogged: true };
    }
    throw new Error('SMTP not configured');
  }

  await t.sendMail({ from, to, subject, text, html });
  return { sent: true };
};
