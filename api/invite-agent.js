// api/invite-agent.js
// Sends an agent invitation email via Resend
// Deploy to Vercel at api.pouredevents.com

const { Resend } = require('resend');
const resend = new Resend(process.env.RESEND_API_KEY);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { name, org, email, eventId } = req.body;

  if (!name || !email) {
    return res.status(400).json({ error: 'name and email are required' });
  }

  // In production: fetch event details from Supabase
  // const { data: event } = await supabase
  //   .from('events')
  //   .select('name, date, venue')
  //   .eq('id', eventId)
  //   .single();

  const eventName = req.body.eventName || 'an upcoming event';
  const eventDate = req.body.eventDate || '';
  const eventVenue = req.body.eventVenue || '';

  const signupUrl = `https://app.pouredevents.com/?invite=agent&event=${eventId}`;

  try {
    const { data, error } = await resend.emails.send({
      from:    'Poured <info@pouredevents.com>',
      to:      email,
      subject: `You have been invited to list wines at ${eventName}`,
      html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body style="margin:0;padding:0;background:#F5F5F5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F5F5F5;padding:40px 20px">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" style="background:#FFFFFF;border-radius:8px;overflow:hidden">
          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#7A1020,#9B1A2A);padding:24px 32px">
              <div style="font-size:20px;font-weight:900;color:#FFFFFF;letter-spacing:.16em;text-transform:uppercase">POURED</div>
              <div style="font-size:11px;color:rgba(255,255,255,.6);letter-spacing:.16em;text-transform:uppercase;margin-top:2px">Beverage Events</div>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:32px">
              <p style="margin:0 0 16px;font-size:16px;font-weight:700;color:#1A1A1A">Hello${name ? ` ${name}` : ''},</p>
              <p style="margin:0 0 16px;font-size:14px;color:#555;line-height:1.7">
                You have been invited to list wines at <strong>${eventName}</strong>${eventDate ? ` on ${eventDate}` : ''}${eventVenue ? ` at ${eventVenue}` : ''}.
              </p>
              <p style="margin:0 0 24px;font-size:14px;color:#555;line-height:1.7">
                Create your Poured account to accept the invitation and upload your wine portfolio. Each supplier in your upload becomes a separate table at the event.
              </p>
              <!-- CTA Button -->
              <table cellpadding="0" cellspacing="0" style="margin-bottom:24px">
                <tr>
                  <td style="background:#1A1A1A;border-radius:8px">
                    <a href="${signupUrl}" style="display:block;padding:14px 28px;color:#FFFFFF;text-decoration:none;font-size:13px;font-weight:700;letter-spacing:.08em;text-transform:uppercase">Accept Invitation &rarr;</a>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 8px;font-size:13px;color:#888;line-height:1.7">
                Once you've created your account you can upload your full portfolio by CSV. Buyers will browse your wines at the event and submit orders directly to you.
              </p>
              <p style="margin:0;font-size:11px;color:#BBB;line-height:1.6">
                If you were not expecting this invitation, you can ignore this email.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:#F8F8F8;padding:20px 32px;border-top:1px solid #EEEEEE">
              <p style="margin:0;font-size:11px;color:#BBBBBB;line-height:1.7">
                Poured Beverage Events &middot; pouredevents.com<br>
                Poured facilitates event ticketing and order introductions only. Beverage sales are conducted directly between agents and customers.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`,
    });

    if (error) {
      console.error('Resend error:', error);
      return res.status(500).json({ error: error.message });
    }

    return res.status(200).json({ success: true, id: data.id });

  } catch (err) {
    console.error('Invite agent error:', err);
    return res.status(500).json({ error: err.message });
  }
};
