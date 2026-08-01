// =====================================================================
// Nodemailer transporter — Gmail SMTP.
// EMAIL_USER / EMAIL_PASS must be a Gmail address + a 16-character
// "App Password" (Google Account → Security → App Passwords). Regular
// account passwords will not work if 2FA is enabled, and using them
// is not recommended even if it does.
//
// NOTE: uses explicit host/port 587 (STARTTLS) instead of the
// `service: "gmail"` shorthand (implicit port 465/SSL). Some hosts,
// including Railway on certain plans/regions, block or are unreliable
// on port 465 outbound, which surfaces as a silent connection timeout
// rather than an auth error. Port 587 + STARTTLS is more broadly
// permitted. Explicit timeouts are set so a network-level block fails
// fast and visibly instead of hanging.
// =====================================================================
import nodemailer from "nodemailer";
import dotenv from "dotenv";

dotenv.config();

const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 587,
  secure: false, // STARTTLS upgrades the connection; must be false for port 587
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  connectionTimeout: 10000, // fail fast (10s) instead of hanging on a blocked port
  greetingTimeout: 10000,
  socketTimeout: 10000,
});

// Verify the SMTP connection once at startup so misconfiguration shows
// up in the logs immediately instead of on the first user's OTP request.
transporter.verify((err) => {
  if (err) {
    console.error("[mail] SMTP transporter verification failed:", err.message);
  } else {
    console.log("[mail] SMTP transporter ready.");
  }
});

export default transporter;
