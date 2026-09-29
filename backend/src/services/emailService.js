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

async function sendOtpEmail({ email, name, otp, purpose = 'VERIFICATION' }) {
  const client = getBrevoClient();
  const senderEmail = process.env.BREVO_SENDER_EMAIL || env.brevoSenderEmail || 'no-reply@dhsgu.ac.in';
  const senderName = process.env.BREVO_SENDER_NAME || env.brevoSenderName || 'Campus Bus DHSGU';

  const isReset = purpose === 'RESET_PASSWORD';

  const badgeText = isReset ? 'SECURITY VERIFICATION' : 'ACCOUNT VERIFICATION';
  const titleText = isReset ? 'Reset Your Password' : 'Verify Your Email Address';
  const actionText = isReset
    ? 'We received a request to reset the password for your Campus Bus student account. Please use the 6-digit code below to set your new password:'
    : 'Thank you for registering with Campus Bus. Please use the following 6-digit verification code to confirm your student email and activate your account:';
  const securityWarning = isReset
    ? 'This code is single-use and will expire in <strong>5 minutes</strong>. If you did not request a password reset, you can safely ignore this email. Your current password remains secure.'
    : 'This code is single-use and will expire in <strong>5 minutes</strong>. If you did not request this verification, please safely ignore this email.';

  const subject = isReset
    ? `[Campus Bus] ${otp} is your password reset code`
    : `[Campus Bus] ${otp} is your verification code`;

  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <title>${titleText}</title>
      <!--[if mso]>
      <noscript>
        <xml>
          <o:OfficeDocumentSettings>
            <o:PixelsPerInch>96</o:PixelsPerInch>
          </o:OfficeDocumentSettings>
        </xml>
      </noscript>
      <![endif]-->
      <style>
        body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
        table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
        img { -ms-interpolation-mode: bicubic; border: 0; outline: none; text-decoration: none; }
        body { margin: 0; padding: 0; width: 100% !important; background-color: #f1f5f9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
      </style>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f1f5f9; -webkit-font-smoothing: antialiased;">
      <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f1f5f9; padding: 32px 12px;">
        <tr>
          <td align="center">
            <!-- Main Container -->
            <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 540px; background-color: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.025);">
              
              <!-- Brand Header Bar -->
              <tr>
                <td style="background: linear-gradient(135deg, #1e3a8a 0%, #1d4ed8 100%); background-color: #1e3a8a; padding: 28px 32px; text-align: left;">
                  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                    <tr>
                      <td>
                        <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                          <tr>
                            <td style="background-color: rgba(255, 255, 255, 0.18); border-radius: 10px; width: 38px; height: 38px; text-align: center; vertical-align: middle; font-size: 20px;">
                              🚌
                            </td>
                            <td style="padding-left: 12px;">
                              <div style="color: #ffffff; font-size: 19px; font-weight: 800; letter-spacing: 0.5px; line-height: 1.2;">
                                CAMPUS BUS
                              </div>
                              <div style="color: #bfdbfe; font-size: 12px; font-weight: 500; letter-spacing: 0.3px;">
                                Dr. Harisingh Gour Vishwavidyalaya, Sagar
                              </div>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Email Body Content -->
              <tr>
                <td style="padding: 36px 32px 28px 32px;">
                  
                  <!-- Badge -->
                  <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="margin-bottom: 18px;">
                    <tr>
                      <td style="background-color: #eff6ff; border: 1px solid #bfdbfe; border-radius: 20px; padding: 5px 14px; font-size: 11px; font-weight: 700; color: #1d4ed8; letter-spacing: 0.8px; text-transform: uppercase;">
                        ${badgeText}
                      </td>
                    </tr>
                  </table>

                  <!-- Heading -->
                  <h1 style="color: #0f172a; font-size: 24px; font-weight: 800; line-height: 1.3; margin: 0 0 14px 0; letter-spacing: -0.3px;">
                    ${titleText}
                  </h1>

                  <!-- Greeting & Description -->
                  <p style="color: #334155; font-size: 15px; line-height: 1.6; margin: 0 0 16px 0;">
                    Hello${name ? ` <strong>${name}</strong>` : ''},
                  </p>
                  <p style="color: #475569; font-size: 15px; line-height: 1.6; margin: 0 0 24px 0;">
                    ${actionText}
                  </p>

                  <!-- OTP Box -->
                  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="margin: 28px 0;">
                    <tr>
                      <td align="center" style="background: #f8fafc; border: 2px dashed #93c5fd; border-radius: 14px; padding: 24px 16px;">
                        <div style="font-size: 11px; font-weight: 700; color: #64748b; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 8px;">
                          ONE-TIME PASSCODE (OTP)
                        </div>
                        <div style="font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, Courier, monospace; font-size: 38px; font-weight: 900; letter-spacing: 10px; color: #1e3a8a; line-height: 1.2;">
                          ${otp}
                        </div>
                        <div style="font-size: 12px; color: #64748b; font-weight: 500; margin-top: 8px;">
                          ⏱️ Expires in <strong>5 minutes</strong> &bull; Single-use only
                        </div>
                      </td>
                    </tr>
                  </table>

                  <!-- Security Advisory Box -->
                  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top: 24px; background-color: #fffbeb; border: 1px solid #fde68a; border-radius: 10px;">
                    <tr>
                      <td style="padding: 14px 16px;">
                        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                          <tr>
                            <td valign="top" style="width: 24px; font-size: 16px; line-height: 1;">
                              🔒
                            </td>
                            <td style="padding-left: 8px; color: #92400e; font-size: 13px; line-height: 1.5;">
                              <strong>Security Reminder:</strong> Never share this code with anyone. DHSGU Bus administration or drivers will never ask for your verification code.
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>

                  <!-- Safe to ignore note -->
                  <p style="color: #64748b; font-size: 13px; line-height: 1.5; margin: 20px 0 0 0;">
                    ${securityWarning}
                  </p>

                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="background-color: #f8fafc; border-top: 1px solid #e2e8f0; padding: 24px 32px; text-align: center;">
                  <div style="color: #64748b; font-size: 13px; font-weight: 600; line-height: 1.4; margin-bottom: 4px;">
                    Campus Bus Service &bull; DHSGU Sagar
                  </div>
                  <div style="color: #94a3b8; font-size: 12px; line-height: 1.4;">
                    Dr. Harisingh Gour Vishwavidyalaya (A Central University)<br>
                    Sagar, Madhya Pradesh 470003, India
                  </div>
                  <div style="color: #cbd5e1; font-size: 11px; margin-top: 12px;">
                    This is an automated system email. Please do not reply directly to this message.
                  </div>
                </td>
              </tr>

            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;

  const textContent = isReset
    ? `Your Campus Bus password reset code is: ${otp}. It will expire in 5 minutes. If you did not request a password reset, please ignore this email.`
    : `Your Campus Bus verification code is: ${otp}. It will expire in 5 minutes. If you did not request this, please ignore this email.`;

  // Development/Test fallback when BREVO_API_KEY is not configured yet
  if (!client) {
    if (env.isProd) {
      throw new Error('BREVO_API_KEY is not configured in production environment');
    }
    console.log(`[BREVO_DEV_FALLBACK] Simulating ${purpose} OTP email delivery to ${maskEmail(email)}: OTP=${otp}`);
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
      subject,
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
