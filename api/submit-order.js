// api/submit-order.js
// Persists an attendee order to Supabase and notifies agents
// Deploy to Vercel at api.pouredevents.com

const { createClient } = require('@supabase/supabase-js');
const { Resend } = require('resend');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);
const resend = new Resend(process.env.RESEND_API_KEY);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { eventId, cart, contact } = req.body;

  if (!eventId || !cart?.length || !contact?.email) {
    return res.status(400).json({ error: 'eventId, cart, and contact are required' });
  }

  try {
    // 1. Create the order record
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        event_id:         eventId,
        customer_email:   contact.email,
        customer_name:    `${contact.first} ${contact.last}`,
        customer_company: contact.company || null,
        customer_phone:   contact.phone || null,
        contact_pref:     contact.preferred || 'email',
        status:           'pending',
      })
      .select()
      .single();

    if (orderError) throw orderError;

    // 2. Insert order items
    const items = cart.map(item => ({
      order_id:       order.id,
      product_id:     item.productId,
      agent_id:       item.agentId,
      qty_cases:      item.qtyCases || item.qty || 1,
      price_per_case: item.pricePerCase,
    }));

    const { error: itemsError } = await supabase
      .from('order_items')
      .insert(items);

    if (itemsError) throw itemsError;

    // 3. Charge the $1.00 submission fee via Stripe (optional — implement later)
    // For now just record the order

    // 4. Notify each agent whose products were ordered
    const agentEmails = [...new Set(cart.map(i => i.agentEmail).filter(Boolean))];
    for (const agentEmail of agentEmails) {
      const agentItems = cart.filter(i => i.agentEmail === agentEmail);
      const total = agentItems.reduce((s, i) => s + (i.qtyCases || 1) * i.pricePerCase, 0);

      await resend.emails.send({
        from:    'Poured <info@pouredevents.com>',
        to:      agentEmail,
        subject: `New order — ${contact.first} ${contact.last} ($${total.toFixed(2)})`,
        html: `
<p>A new order has been submitted on Poured.</p>
<p><strong>Customer:</strong> ${contact.first} ${contact.last}${contact.company ? `, ${contact.company}` : ''}</p>
<p><strong>Order total:</strong> $${total.toFixed(2)}</p>
<p>Log in to Poured to unlock the order and view full contact details.</p>
<p><a href="https://app.pouredevents.com">Open Poured &rarr;</a></p>
<hr>
<p style="font-size:11px;color:#999">Poured Beverage Events &middot; pouredevents.com</p>`,
      }).catch(err => console.error('Agent notification failed:', err));
    }

    return res.status(200).json({ success: true, orderId: order.id });

  } catch (err) {
    console.error('Submit order error:', err);
    return res.status(500).json({ error: err.message });
  }
};
