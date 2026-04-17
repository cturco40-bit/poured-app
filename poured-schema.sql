-- ============================================================
-- POURED — Database Schema
-- Run this in Supabase SQL Editor (all at once)
-- ============================================================

-- 1. PROFILES (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  company TEXT,
  phone TEXT,
  role TEXT NOT NULL CHECK (role IN ('host', 'agent', 'attendee', 'admin')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, role)
  VALUES (NEW.id, NEW.email, 'attendee');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 2. EVENTS
CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  host_id UUID NOT NULL REFERENCES profiles(id),
  name TEXT NOT NULL,
  date DATE NOT NULL,
  time TEXT,
  venue TEXT,
  address TEXT,
  city TEXT DEFAULT 'Toronto',
  description TEXT,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'upcoming', 'past', 'cancelled')),
  passcode TEXT,
  submission_deadline TIMESTAMPTZ,
  allow_public_browse BOOLEAN DEFAULT false,
  require_passcode BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. TICKET TIERS
CREATE TABLE ticket_tiers (
  id SERIAL PRIMARY KEY,
  event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  label TEXT NOT NULL DEFAULT 'General Admission',
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  capacity INT NOT NULL DEFAULT 100,
  sold INT DEFAULT 0
);

-- 4. TICKET PURCHASES
CREATE TABLE ticket_purchases (
  id SERIAL PRIMARY KEY,
  event_id INT NOT NULL REFERENCES events(id),
  tier_id INT NOT NULL REFERENCES ticket_tiers(id),
  attendee_id UUID NOT NULL REFERENCES profiles(id),
  ticket_code TEXT UNIQUE NOT NULL,
  stripe_payment_id TEXT,
  amount_paid NUMERIC(10,2),
  poured_fee NUMERIC(10,2),
  checked_in BOOLEAN DEFAULT false,
  checked_in_at TIMESTAMPTZ,
  credential TEXT,
  purchased_at TIMESTAMPTZ DEFAULT now()
);

-- 5. AGENT LISTINGS (agent ↔ event relationship)
CREATE TABLE agent_listings (
  id SERIAL PRIMARY KEY,
  event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES profiles(id),
  firm TEXT,
  listing_fee NUMERIC(10,2) DEFAULT 50,
  fee_paid BOOLEAN DEFAULT false,
  stripe_payment_id TEXT,
  featured BOOLEAN DEFAULT false,
  featured_fee_paid BOOLEAN DEFAULT false,
  submitted BOOLEAN DEFAULT false,
  invited_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  UNIQUE(event_id, agent_id)
);

-- 6. PRODUCTS (wines uploaded by agents)
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES profiles(id),
  supplier TEXT NOT NULL,
  name TEXT NOT NULL,
  vintage INT,
  category TEXT DEFAULT 'Red Wine',
  country TEXT,
  region TEXT,
  abv NUMERIC(4,1),
  bottle_size_ml INT DEFAULT 750,
  case_size INT DEFAULT 12,
  price_per_bottle NUMERIC(10,2) NOT NULL,
  price_per_case NUMERIC(10,2) NOT NULL,
  availability TEXT DEFAULT 'In Stock',
  tasting_notes TEXT,
  food_pairings TEXT,
  approved BOOLEAN,  -- null = pending, true = approved, false = rejected
  views INT DEFAULT 0,
  orders_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. ORDERS
CREATE TABLE orders (
  id TEXT PRIMARY KEY, -- e.g. ORD-001
  event_id INT NOT NULL REFERENCES events(id),
  attendee_id UUID NOT NULL REFERENCES profiles(id),
  customer_name TEXT NOT NULL,
  customer_email TEXT NOT NULL,
  customer_phone TEXT,
  customer_company TEXT,
  processing_fee NUMERIC(10,2) DEFAULT 4.25,
  stripe_payment_id TEXT,
  status TEXT DEFAULT 'submitted' CHECK (status IN ('submitted', 'unlocked', 'confirmed', 'cancelled')),
  submitted_at TIMESTAMPTZ DEFAULT now()
);

-- 8. ORDER ITEMS (one per product per order)
CREATE TABLE order_items (
  id SERIAL PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id INT NOT NULL REFERENCES products(id),
  agent_id UUID NOT NULL REFERENCES profiles(id),
  supplier TEXT,
  product_name TEXT,
  qty_cases INT DEFAULT 1,
  case_size INT DEFAULT 12,
  price_per_bottle NUMERIC(10,2),
  price_per_case NUMERIC(10,2),
  bottle_size_ml INT DEFAULT 750
);

-- 9. ORDER UNLOCKS (agent pays to see buyer details)
CREATE TABLE order_unlocks (
  id SERIAL PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id),
  agent_id UUID NOT NULL REFERENCES profiles(id),
  order_value NUMERIC(10,2) NOT NULL,
  unlock_fee NUMERIC(10,2) NOT NULL,
  unlock_fee_hst NUMERIC(10,2) NOT NULL,
  total_charged NUMERIC(10,2) NOT NULL,
  stripe_payment_id TEXT,
  unlocked_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(order_id, agent_id)
);

-- 10. TASTING NOTES (attendee notes on wines)
CREATE TABLE tasting_notes (
  id SERIAL PRIMARY KEY,
  product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  attendee_id UUID NOT NULL REFERENCES profiles(id),
  rating INT CHECK (rating >= 1 AND rating <= 5),
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(product_id, attendee_id)
);

-- 11. SAVED WINES (favourites)
CREATE TABLE saved_wines (
  id SERIAL PRIMARY KEY,
  product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  attendee_id UUID NOT NULL REFERENCES profiles(id),
  saved_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(product_id, attendee_id)
);

-- 12. PAYOUTS (host payouts)
CREATE TABLE payouts (
  id SERIAL PRIMARY KEY,
  event_id INT NOT NULL REFERENCES events(id),
  host_id UUID NOT NULL REFERENCES profiles(id),
  gross_ticket_revenue NUMERIC(10,2),
  poured_ticket_fees NUMERIC(10,2),
  listing_revenue NUMERIC(10,2),
  poured_commission NUMERIC(10,2),
  featured_revenue NUMERIC(10,2),
  poured_featured_cut NUMERIC(10,2),
  net_payout NUMERIC(10,2),
  stripe_transfer_id TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid')),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_events_host ON events(host_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_ticket_purchases_event ON ticket_purchases(event_id);
CREATE INDEX idx_ticket_purchases_attendee ON ticket_purchases(attendee_id);
CREATE INDEX idx_agent_listings_event ON agent_listings(event_id);
CREATE INDEX idx_agent_listings_agent ON agent_listings(agent_id);
CREATE INDEX idx_products_event ON products(event_id);
CREATE INDEX idx_products_agent ON products(agent_id);
CREATE INDEX idx_orders_event ON orders(event_id);
CREATE INDEX idx_orders_attendee ON orders(attendee_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_agent ON order_items(agent_id);
CREATE INDEX idx_order_unlocks_agent ON order_unlocks(agent_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasting_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_wines ENABLE ROW LEVEL SECURITY;
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;

-- PROFILES: users can read own, admins can read all
CREATE POLICY profiles_select ON profiles FOR SELECT USING (
  auth.uid() = id OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY profiles_update ON profiles FOR UPDATE USING (auth.uid() = id);

-- EVENTS: anyone can read active/upcoming, hosts can CRUD own
CREATE POLICY events_select ON events FOR SELECT USING (
  status IN ('active', 'upcoming', 'past') OR
  host_id = auth.uid() OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY events_insert ON events FOR INSERT WITH CHECK (host_id = auth.uid());
CREATE POLICY events_update ON events FOR UPDATE USING (
  host_id = auth.uid() OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- TICKET TIERS: readable if event is visible
CREATE POLICY tiers_select ON ticket_tiers FOR SELECT USING (
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND (status IN ('active','upcoming','past') OR host_id = auth.uid()))
);
CREATE POLICY tiers_insert ON ticket_tiers FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND host_id = auth.uid())
);
CREATE POLICY tiers_update ON ticket_tiers FOR UPDATE USING (
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND host_id = auth.uid())
);

-- TICKET PURCHASES: attendee sees own, host sees event's
CREATE POLICY purchases_select ON ticket_purchases FOR SELECT USING (
  attendee_id = auth.uid() OR
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND host_id = auth.uid())
);
CREATE POLICY purchases_insert ON ticket_purchases FOR INSERT WITH CHECK (attendee_id = auth.uid());

-- AGENT LISTINGS: agent sees own, host sees event's, attendees see event's
CREATE POLICY listings_select ON agent_listings FOR SELECT USING (
  agent_id = auth.uid() OR
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND (host_id = auth.uid() OR status IN ('active','upcoming')))
);
CREATE POLICY listings_insert ON agent_listings FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND host_id = auth.uid())
);
CREATE POLICY listings_update ON agent_listings FOR UPDATE USING (
  agent_id = auth.uid() OR
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND host_id = auth.uid())
);

-- PRODUCTS: visible if event is active/upcoming, agents can CRUD own
CREATE POLICY products_select ON products FOR SELECT USING (
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND (status IN ('active','upcoming','past') OR host_id = auth.uid())) OR
  agent_id = auth.uid()
);
CREATE POLICY products_insert ON products FOR INSERT WITH CHECK (agent_id = auth.uid());
CREATE POLICY products_update ON products FOR UPDATE USING (
  agent_id = auth.uid() OR
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND host_id = auth.uid())
);
CREATE POLICY products_delete ON products FOR DELETE USING (agent_id = auth.uid());

-- ORDERS: attendee sees own, agents see orders containing their items
CREATE POLICY orders_select ON orders FOR SELECT USING (
  attendee_id = auth.uid() OR
  EXISTS (SELECT 1 FROM order_items WHERE order_id = id AND agent_id = auth.uid()) OR
  EXISTS (SELECT 1 FROM events WHERE id = event_id AND host_id = auth.uid())
);
CREATE POLICY orders_insert ON orders FOR INSERT WITH CHECK (attendee_id = auth.uid());

-- ORDER ITEMS: visible if parent order is visible
CREATE POLICY items_select ON order_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM orders WHERE id = order_id AND (
    attendee_id = auth.uid() OR
    EXISTS (SELECT 1 FROM events WHERE id = orders.event_id AND host_id = auth.uid())
  )) OR
  agent_id = auth.uid()
);
CREATE POLICY items_insert ON order_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM orders WHERE id = order_id AND attendee_id = auth.uid())
);

-- ORDER UNLOCKS: agent sees own
CREATE POLICY unlocks_select ON order_unlocks FOR SELECT USING (agent_id = auth.uid());
CREATE POLICY unlocks_insert ON order_unlocks FOR INSERT WITH CHECK (agent_id = auth.uid());

-- TASTING NOTES: attendee sees own
CREATE POLICY notes_select ON tasting_notes FOR SELECT USING (attendee_id = auth.uid());
CREATE POLICY notes_insert ON tasting_notes FOR INSERT WITH CHECK (attendee_id = auth.uid());
CREATE POLICY notes_update ON tasting_notes FOR UPDATE USING (attendee_id = auth.uid());
CREATE POLICY notes_delete ON tasting_notes FOR DELETE USING (attendee_id = auth.uid());

-- SAVED WINES: attendee sees own
CREATE POLICY saved_select ON saved_wines FOR SELECT USING (attendee_id = auth.uid());
CREATE POLICY saved_insert ON saved_wines FOR INSERT WITH CHECK (attendee_id = auth.uid());
CREATE POLICY saved_delete ON saved_wines FOR DELETE USING (attendee_id = auth.uid());

-- PAYOUTS: host sees own, admin sees all
CREATE POLICY payouts_select ON payouts FOR SELECT USING (
  host_id = auth.uid() OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Generate unique order ID
CREATE OR REPLACE FUNCTION generate_order_id()
RETURNS TEXT AS $$
DECLARE
  new_id TEXT;
  counter INT;
BEGIN
  SELECT COUNT(*) + 1 INTO counter FROM orders;
  new_id := 'ORD-' || LPAD(counter::TEXT, 4, '0');
  RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Generate unique ticket code
CREATE OR REPLACE FUNCTION generate_ticket_code(tier_label TEXT)
RETURNS TEXT AS $$
DECLARE
  prefix TEXT;
  counter INT;
BEGIN
  prefix := CASE
    WHEN tier_label ILIKE '%vip%' THEN 'VIP'
    WHEN tier_label ILIKE '%trade%' THEN 'TR'
    ELSE 'GA'
  END;
  SELECT COUNT(*) + 1 INTO counter FROM ticket_purchases;
  RETURN prefix || '-' || LPAD(counter::TEXT, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Update event updated_at timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER events_updated
  BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
