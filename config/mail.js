// =====================================================================
// Resend email client.
// RESEND_API_KEY and EMAIL_FROM must be set in the environment.
// EMAIL_FROM must be a verified sender/domain in your Resend account.
// =====================================================================
import { Resend } from "resend";
import dotenv from "dotenv";

dotenv.config();

const resend = new Resend(process.env.RESEND_API_KEY);

/**
 * Generic send function — services/*.service.js files build the
 * subject/html/text and call this, mirroring the old Nodemailer
 * transporter.sendMail() call shape so only the import + call site
 * changes in callers, not their templates.
 */
export async function sendMail({ to, subject, html, text }) {
  const { data, error } = await resend.emails.send({
    from: process.env.EMAIL_FROM,
    to,
    subject,
    html,
    text,
  });

  if (error) {
    console.error("[mail] Resend send failed:", error.message || error);
    throw new Error(error.message || "Failed to send email via Resend.");
  }

  return data;
}

