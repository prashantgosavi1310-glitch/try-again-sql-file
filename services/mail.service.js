// =====================================================================
// Resend — HTTP-based email API (replaces Gmail SMTP).
// SMTP was blocked/timing out from cloud hosts (Railway, Render).
// Resend sends over HTTPS (port 443), which isn't blocked.
// Requires RESEND_API_KEY env var, from resend.com → API Keys.
// =====================================================================
import { Resend } from "resend";
import dotenv from "dotenv";
dotenv.config();

const resend = new Resend(process.env.RESEND_API_KEY);

export async function sendMail({ to, subject, html, text }) {
  const { data, error } = await resend.emails.send({
    from: "onboarding@resend.dev",
    to,
    subject,
    html,
    text,
  });

  if (error) {
    console.error("[mail] Resend send failed:", error);
    throw error;
  }

  console.log("[mail] Email sent via Resend:", data?.id);
  return data;
}
