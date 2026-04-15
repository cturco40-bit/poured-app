// api/checkout.js
// Creates a Stripe Checkout session for ticket purchase
// Deploy to Vercel at api.pouredevents.com

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { eventId, tierId } = req.body;

  if (!eventId || !tierId) {
    return res.status(400).json({ error: 'eventId and tierId are required' });
  }

  try {
    // In production: fetch event + tier details from Supabase
    // const { data: tier } = await supabase
    //   .from('ticket_tiers')
    //   .select('*, events(name, date, venue)')
    //   .eq('id', tierId)
    //   .single();

    // For now: use the values passed from the frontend
    const { price, label, eventName } = req.body;

    const ticketFlatFee = 175; // $1.75 in cents
    const ticketPctFee  = Math.round((price * 0.06) * 100); // 6% in cents
    const buyerPrice    = (price * 100) + ticketFlatFee + ticketPctFee;

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'cad',
            product_data: {
              name: `${label} — ${eventName}`,
              description: 'Poured beverage trade event ticket. Includes $1.75 + 6% platform fee.',
            },
            unit_amount: buyerPrice,
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: `https://app.pouredevents.com/?ticket=success&event=${eventId}`,
      cancel_url:  `https://app.pouredevents.com/?ticket=cancel&event=${eventId}`,
      metadata: {
        eventId:  String(eventId),
        tierId:   String(tierId),
      },
    });

    return res.status(200).json({ url: session.url });

  } catch (err) {
    console.error('Stripe checkout error:', err);
    return res.status(500).json({ error: err.message });
  }
};
