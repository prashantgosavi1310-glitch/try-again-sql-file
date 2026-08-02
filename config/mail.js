import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);

export async function sendOtpEmail(to, otp) {
  const { data, error } = await resend.emails.send({
    from: "onboarding@resend.dev",
    to,
    subject: "Your OTP Code",
    html: `<p>Your verification code is: <strong>${otp}</strong></p>`,
  });

  if (error) {
    console.error("[mail] Resend send failed:", error);
    throw error;
  }
  return data;
}
