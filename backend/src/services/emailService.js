const { BrevoClient } = require('@getbrevo/brevo');
const { env } = require('../config/env');

let brevoClient = null;

function getBrevoClient() {
  const apiKey = process.env.BREVO_API_KEY || env.brevoApiKey || '';
  if (!apiKey || apiKey === 'your-brevo-api-key-here') {
    return null;
  }
  if (!brevoClient) {
    brevoClient = new BrevoClient({ apiKey });
  }
  return brevoClient;
}

function maskEmail(email) {
  if (!email || typeof email !== 'string') return '';
  const parts = email.split('@');
  if (parts.length !== 2) return email;
  const [local, domain] = parts;
  if (local.length <= 2) {
    return `${local[0]}*@${domain}`;
  }
  const visible = local.slice(0, 2);
  return `${visible}****@${domain}`;
}

async function sendOtpEmail({ email, name, otp }) {
  const client = getBrevoClient();
  const senderEmail = process.env.BREVO_SENDER_EMAIL || env.brevoSenderEmail || 'no-reply@dhsgu.ac.in';
  const senderName = process.env.BREVO_SENDER_NAME || env.brevoSenderName || 'Campus Bus DHSGU';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Email Verification Code</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; }
        .card { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; padding: 36px 32px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
        .logo-badge { display: inline-block; background-color: #1d4ed8; color: #ffffff; font-weight: 800; font-size: 14px; padding: 6px 14px; border-radius: 8px; letter-spacing: 0.5px; margin-bottom: 20px; }
        h1 { color: #0f172a; font-size: 22px; font-weight: 800; margin: 0 0 12px 0; }
        p { color: #475569; font-size: 15px; line-height: 1.6; margin: 0 0 20px 0; }
        .otp-container { background: #eff6ff; border: 2px dashed #93c5fd; border-radius: 12px; padding: 20px; text-align: center; margin: 28px 0; }
        .otp-code { font-family: 'Courier New', Courier, monospace; font-size: 34px; font-weight: 900; letter-spacing: 8px; color: #1e3a8a; }
        .footer { font-size: 13px; color: #94a3b8; border-top: 1px solid #f1f5f9; padding-top: 20px; margin-top: 28px; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo-badge">CAMPUS BUS • DHSGU</div>
        <h1>Verify Your Email Address</h1>
        <p>Hello${name ? ` ${name}` : ''},</p>
        <p>Use the following 6-digit verification code to complete your student registration on Campus Bus:</p>
        <div class="otp-container">
          <div class="otp-code">${otp}</div>
        </div>
        <p style="font-size: 14px; color: #64748b;">This verification code is single-use and will expire in <strong>5 minutes</strong>. If you did not request this verification, please safely ignore this email.</p>
        <div class="footer">
          Dr. Harisingh Gour University Campus Bus Service<br>
          This is an automated system email sent via Brevo. Please do not reply.
        </div>
      </div>
    </body>
    </html>
  `;

  const textContent = `Your Campus Bus verification code is: ${otp}. It will expire in 5 minutes.`;

  // Development/Test fallback when BREVO_API_KEY is not configured yet
  if (!client) {
    if (env.isProd) {
      throw new Error('BREVO_API_KEY is not configured in production environment');
    }
    console.log(`[BREVO_DEV_FALLBACK] Simulating OTP email delivery to ${maskEmail(email)}`);
    return {
      messageId: `dev-simulated-${Date.now()}`,
      status: 'simulated',
    };
  }

  try {
    const response = await client.transactionalEmails.sendTransacEmail({
      sender: {
        name: senderName,
        email: senderEmail,
      },
      to: [
        {
          email,
          name: name || 'Student',
        },
      ],
      subject: `${otp} is your Campus Bus verification code`,
      htmlContent: html,
      textContent,
    });

    return response;
  } catch (err) {
    console.error(`[BREVO_SEND_ERROR] Failed sending transactional email to ${maskEmail(email)}:`, err?.message || err);
    throw err;
  }
}

module.exports = {
  sendOtpEmail,
  maskEmail,
};
