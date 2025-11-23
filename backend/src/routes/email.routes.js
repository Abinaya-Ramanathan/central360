import { Router } from 'express';
import nodemailer from 'nodemailer';

const router = Router();

// Create transporter - configure with your SMTP settings
const createTransporter = () => {
  const smtpUser = process.env.SMTP_USER;
  const smtpPassword = process.env.SMTP_PASSWORD;

  if (!smtpUser || !smtpPassword) {
    throw new Error('SMTP credentials are not configured. Please set SMTP_USER and SMTP_PASSWORD environment variables.');
  }

  return nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587'),
    secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
    auth: {
      user: smtpUser,
      pass: smtpPassword,
    },
  });
};

router.post('/send-pdf', async (req, res) => {
  try {
    const { emailAddress, pdfBase64, subject, body } = req.body;

    if (!emailAddress || !pdfBase64) {
      return res.status(400).json({ message: 'Email address and PDF data are required' });
    }

    let transporter;
    try {
      transporter = createTransporter();
    } catch (configError) {
      return res.status(500).json({ 
        message: 'Email service is not configured', 
        error: configError.message,
        hint: 'Please configure SMTP_USER and SMTP_PASSWORD in your .env file'
      });
    }

    const mailOptions = {
      from: process.env.SMTP_USER || 'noreply@central360.com',
      to: emailAddress,
      subject: subject || 'Statement Report',
      html: body || '<p>Please find attached the requested statement report.</p>',
      attachments: [
        {
          filename: 'statement.pdf',
          content: pdfBase64,
          encoding: 'base64',
        },
      ],
    };

    await transporter.sendMail(mailOptions);

    res.json({ message: 'Email sent successfully' });
  } catch (error) {
    console.error('Error sending email:', error);
    res.status(500).json({ message: 'Failed to send email', error: error.message });
  }
});

export default router;

