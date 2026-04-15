# POURED — Claude Code Project Brief

This document is for Claude Code. Read it completely before touching any file.

---

## What this is

**Poured** is a SaaS platform for beverage trade events. It connects three types of users — Event Hosts, Agents/Producers, and Attendees — who all participate in the same event but need completely different tools.

**Christian is the platform owner and operator.** He is not an Event Host. He sells access to the platform to Event Hosts (coordinators of wine trade events) and earns revenue through transaction fees.

The live domain is **pouredevents.com**. The app lives at **app.pouredevents.com**.

---

## Repository structure

```
poured-app/
├── index.html          ← the entire application (rename of poured-full.html)
├── sw.js               ← service worker for PWA offline support
├── landing/
│   └── index.html      ← marketing site (poured-landing.html)
└── CLAUDE.md           ← this file
```

**The backend lives separately:**
```
poured-vercel/
├── api/
│   ├── webhook.js      ← Stripe webhook handler
│   ├── invite-agent.js ← send agent invitation email via Resend
│   └── checkout.js     ← create Stripe Checkout session
├── package.json
└── SETUP.md
```

---

## Architecture — single file app

The entire application (`index.html`) is a **single self-contained HTML file** with no build step, no npm, no bundler. It runs directly in any browser.

- **HTML** — structure, meta tags, PWA manifest inline
- **CSS** — one `<style>` block, ~15KB
- **JavaScript** — one `<script>` block, ~260KB, all logic inline

This was a deliberate architectural decision. It deploys to GitHub Pages by drag-and-drop and requires zero infrastructure to demo. The trade-off is that all JS is in one file. **Do not suggest splitting it into modules or adding a build system** — that breaks the deployment model.

### How the app works

The app is a **client-side SPA** driven by a single state object and a `render()` function.

```javascript
let state = { portal: 'home', ... }

function setState(updates) {
  Object.assign(state, updates);
  render();
}

function render() {
  const app = document.getElementById('app');
  if (!app) return;
  const p = state.portal;
  if (p === 'home')           { app.innerHTML = homeHTML(); }
  if (p === 'coordinator')    { app.innerHTML = loginShell('Event Host', ...); }
  if (p === 'coordinator_in') { app.innerHTML = coordPortalHTML(); }
  // ... etc
}
```

Every screen is a function that returns an HTML string. State changes trigger a full re-render. **There is no virtual DOM, no React, no framework.** All interactivity uses `onclick`, `oninput`, and `onchange` attributes calling `window.*` functions.

### Backend (optional, not yet wired)

The app has a **Supabase integration** that is dynamically loaded only when real keys are configured. Without keys it runs in **demo mode** with hardcoded mock data. The `LIVE_MODE` boolean controls which path runs throughout the app.

```javascript
var LIVE_MODE = false;  // becomes true when Supabase keys are detected
```

---

## The three user portals

### 1. Event Host Portal (`coordinator_in`)
Desktop-first. Full sidebar layout with collapsible navigation.

**What they do:**
- Create events (5-step wizard: Details → Ticket Tiers → Invite Agents → Settings → Review & Publish)
- Manage agent submissions and approve/reject wines
- Run door check-in on event night (admit attendees from a list, walk-up QR)
- Track payout (gross ticket revenue minus platform fees)
- Duplicate past events

**Key functions:** `coordPortalHTML()`, `createEventHTML()`, `coordEventListHTML()`, `qrCheckinHTML()`, `payoutDashboardHTML()`, `approvalPanelHTML()`, `postEventEmailHTML()`, `dupModalHTML()`

**Tabs:** overview, agents, suppliers, approvals, door, payout, create, postemail

### 2. Agent / Producer Portal (`agent_in`)
Desktop-first. Full sidebar layout.

**What they do:**
- Accept event invitations
- Upload wine portfolio via CSV (each unique supplier name becomes a table)
- View and manage orders — orders are locked until the agent pays an unlock fee to see buyer contact details
- Generate invoices, print pour sheets, export CSVs

**Key functions:** `agentPortalHTML()`, `agentEventListHTML()`, `agentOrderCardHTML()`, `invoiceModalHTML()`, `editProductModalHTML()`

**Tabs:** orders, suppliers, upload, export

**Revenue model for agent:** Free to list. Pay 1.25% of order value (capped at $50) to unlock each order and receive the buyer's contact details. Payment is then handled directly between agent and buyer outside the platform.

### 3. Attendee Portal (`customer_in`)
Mobile-first PWA. No sidebar. Wine gradient header.

**What they do:**
- Browse ticket events, purchase tickets (Stripe Checkout)
- At the event: browse all wines by supplier table or category
- Save wines (heart), add tasting notes, rate wines
- Submit orders to agents (one cart, multiple agents, routes automatically)
- View order history across past events

**Key functions:** `custPortalHTML()`, `custEventListHTML()`, `productCardHTML()`, `detailModalHTML()`, `orderHistoryHTML()`, `filterPillsHTML()`, `shareModalHTML()`

**Tabs:** ticket, browse, saved, notes, order, history

### 4. Platform Admin (`admin_in`)
Desktop-first. Christian's portal. Full visibility over the whole platform.

**What they do:**
- View platform-wide revenue stats
- Manage event hosts (approve/reject/suspend/invite)
- Set global fee defaults and per-event fee overrides
- View all events and export CSV

**Key functions:** `adminPortalHTML()`

**Tabs:** dashboard, analytics, events, coordinators, fees

---

## Revenue model

| Fee | Who pays | Rate |
|-----|----------|------|
| Ticket fee | Buyer (attendee) | $1.75 + 6% of face price |
| Agent listing fee | Event Host sets it | ~$50/agent, goes to Event Host |
| Order unlock fee | Agent | 1.25% of order value, capped $50 |
| Order submission fee | Attendee | $1.00 + HST per order submitted |

**Key:** Poured collects the ticket fee and the unlock fee. The listing fee goes to the Event Host.

---

## Design system

**Font:** Nunito Sans (400–900), loaded from Google Fonts. No other typeface.

**Colours:**
```
Wine red:  #7A1020  (primary — buttons, accents, wine gradient)
Gradient:  linear-gradient(135deg, #7A1020, #9B1A2A)
Ink:       #1A1A1A  (primary text)
White:     #FFFFFF
Off-white: #F5F5F5  (backgrounds)
Border:    #E5E5E5
Muted:     #888888  (secondary text)
Green:     #2a7a4a  (success/confirmed)
Blue:      #2a5a8a  (info/unlocked)
```

**B palette** (used throughout JS for inline styles):
```javascript
const B = {
  ink: "#1A1A1A", wine: "#7A1020", pour: "#7A1020",
  gold: "#888888", cream: "#FFFFFF", linen: "#F8F8F8",
  mist: "#EFEFEF", cork: "#888888", sage: "#2a7a4a",
  slate: "#2a5a8a", amber: "#888888"
};
```

**Layout rules:**
- Attendee portal: `max-width: 480px`, centred, mobile-first
- Event Host / Agent / Admin portals: `body.dp` class, `100vh` flex layout, full-width
- Sidebar width: `228px` collapsed to `52px`

**CSS classes** (desktop portals):
`.dp-shell` `.dp-sidebar` `.dp-sidebar-wrap` `.dp-main` `.dp-topbar` `.dp-content`
`.dp-card` `.dp-stat` `.dp-table` `.dp-btn` `.dp-badge` `.dp-nav-item` `.dp-empty`

**Typography:** All section headers, card titles, and stat labels use `text-transform: uppercase; letter-spacing: .08em`.

---

## State object

The full state object is declared as `let state = { ... }` near the top of the JS. Key fields:

```javascript
{
  portal: 'home',             // current screen
  currentUser: null,          // { email, name, role } when logged in
  coordSelectedEventId: null, // which event is open in Event Host portal
  selectedEventId: null,      // which event is open in Agent/Attendee portal
  coordTab: 'overview',       // active tab in Event Host portal
  agentTab: 'orders',         // active tab in Agent portal
  custTab: 'ticket',          // active tab in Attendee portal
  adminTab: 'dashboard',      // active tab in Admin portal
  draft: { ... },             // create event form state
  createStep: 1,              // create event wizard step (1-5)
  cart: [],                   // attendee order cart
  favs: {},                   // saved wines { productId: true }
  notes: {},                  // tasting notes { productId: 'text' }
  unlocked: {},               // agent unlocked orders { orderId: true }
  confirmed: {},              // agent confirmed orders { orderId: true }
  feeOverrides: {},           // per-event fee overrides { eventId: {...} }
  pendingCoords: [],          // pending event host approvals
  coordinators: [],           // active event hosts
}
```

**setState** is the only way to update state:
```javascript
setState({ portal: 'coordinator_in', currentUser: profile });
```

---

## Mock data

In demo mode the app uses hardcoded data in `const EVENTS = [...]`. There are 4 events:
1. **Grand Cru Spring Tasting** — `status: 'active'` — has products, orders, agents
2. **ICE Italian Trade Tasting 2025** — `status: 'upcoming'`
3. **Wines of Portugal** — `status: 'upcoming'`
4. **Grand Cru Autumn Harvest 2024** — `status: 'past'`

Event 1 has full data: 8 wine products, 4 orders, 4 agents, mock attendees.

**Demo login credentials:**
| Role | Email | Password |
|------|-------|----------|
| Event Host | coordinator@tasting.ca | coord2025 |
| Agent | sophie@maisonprestige.ca | agent2025 |
| Attendee | jane@example.com | jane2025 |
| Admin | admin@pouredevents.com | admin2025 |

---

## PWA

The app is a full PWA:
- **Manifest** generated inline via JS and injected into `<link rel="manifest">`
- **Service worker** registered from `/sw.js` — only activates on `https:` or `http:` origins, silently skipped when opening the file directly
- **iOS banner** — slides up after 4 seconds on iPhone/iPad with instructions to Add to Home Screen
- **Android prompt** — captures `beforeinstallprompt` and shows an install banner after 3 seconds
- **Theme colour:** `#7A1020` (wine red) in the status bar
- **Icons:** SVG inline, wine red background

---

## Supabase integration

The Supabase SDK is loaded dynamically. Replace the two placeholder strings to activate:

```javascript
var U = 'YOUR_SUPABASE_URL';
var A = 'YOUR_SUPABASE_ANON_KEY';
```

When keys are present, `LIVE_MODE = true` and all data operations route through Supabase instead of the mock `EVENTS` array.

**Auth model:**
- `AUTH.signIn(email, password)` → wraps `supabase.auth.signInWithPassword()`
- `AUTH.signUp(email, password, metadata)` → wraps `supabase.auth.signUp()`
- `AUTH.getProfile()` → fetches from `profiles` table by user ID
- `AUTH.signOut()` → `supabase.auth.signOut()`

**DB model:**
- `DB.listEvents()` → fetch events with tiers, agent counts, product counts
- `DB.getEvent(id)` → single event with full relations
- `DB.createEvent(draft)` → insert from create event wizard
- `DB.publishEvent(id)` → set status to 'upcoming'
- `DB.uploadCSV(eventId, file)` → parse and insert products

**Database schema** is in `poured-vercel/supabase/migrations/001_schema.sql`. Tables: `profiles`, `events`, `ticket_tiers`, `agent_listings`, `products`, `orders`, `order_items`, `tickets`, `product_ratings`, `saved_products`, `tasting_notes`, `fee_overrides`.

---

## Vercel API endpoints

Three endpoints need to be deployed to `api.pouredevents.com`:

| Endpoint | File | Purpose |
|----------|------|---------|
| `POST /api/checkout` | `api/checkout.js` | Create Stripe Checkout session, return `{ url }` |
| `POST /api/invite-agent` | `api/invite-agent.js` | Send invitation email via Resend |
| `POST /api/submit-order` | Not yet created | Persist order to Supabase |

These are called from `purchaseTicket()`, `sendAgentInvite()`, and `submitOrderWithContact()` respectively.

---

## What still needs to be built

The following are wired in the frontend but not yet implemented in the backend. These are the priority tasks for Claude Code:

### Priority 1 — Required before first real event
1. **`/api/checkout.js`** — Stripe Checkout session creation. Needs `STRIPE_SECRET_KEY` env var. Takes `{ eventId, tierId }`, returns `{ url }`.
2. **`/api/invite-agent.js`** — Resend email. Needs `RESEND_API_KEY`. Takes `{ name, org, email, eventId }`, sends invitation with a link to `app.pouredevents.com`.
3. **Supabase schema** — Run `001_schema.sql` in Supabase SQL editor to create all tables.
4. **`sw.js`** — Already created. Needs to be in the repo root alongside `index.html`.

### Priority 2 — For data persistence
5. **Wire Supabase keys** — Replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with real values (use environment variables if serving from a proper host, or inline for GitHub Pages).
6. **`/api/submit-order.js`** — Persist order to Supabase `orders` and `order_items` tables when an attendee submits.

### Priority 3 — Nice to have
7. **Generate Passcode fix** — `genPasscode()` correctly sets `state.draft.passcode` but the create event step 4 input field has a static `value=` that doesn't update reactively. Fix: after `genPasscode()` runs, directly set `document.querySelector('[data-field="passcode"]').value = newCode`.
8. **Door check-in persistence** — `admitAttendee()` currently updates the DOM directly. In live mode it should `PATCH /api/tickets/{id}/admit`.
9. **Post-event email** — `postEventEmailHTML()` generates the email template. Needs a Vercel endpoint that sends it via Resend to all ticket holders.

---

## Known patterns — important for editing

### Adding a new screen
1. Create a function `myScreenHTML()` that returns an HTML string
2. Add a portal route: `if(p === 'my_screen') { app.innerHTML = myScreenHTML(); }`
3. Add any new interactive functions as `window.myFunction = function() { ... }`
4. Navigate to it: `setState({ portal: 'my_screen' })`

### Adding a button
All buttons use inline `onclick` attributes calling named `window.*` functions:
```javascript
// In a screen function:
content += '<button onclick="myAction()">Click me</button>';

// As a window function:
window.myAction = function() {
  setState({ someKey: newValue });
};
```

**Never use** `document.querySelector` to add event listeners — it won't survive re-renders.

### Avoiding quote hell
HTML strings are built with single-quoted JS strings. Double quotes are used for HTML attributes. Single quotes inside onclick attributes must be escaped with `\\'`.

Use DOM API for complex overlays (modals) — see `showInviteAgentModal()` for the pattern.

### Adding a tab
```javascript
// In the nav:
navItem('my_tab', '-', 'My Tab')

// In the tab content:
if (tab === 'my_tab') {
  content += '<div>...</div>';
}

// Nav item function already defined in each portal as a local helper
```

### Toasts instead of alerts
Never use `alert()` or `confirm()` in UI flows. Use:
```javascript
showToast('Your message here');       // 2.8 second auto-dismiss
showToast('Your message here', 5000); // custom duration in ms
```
For confirms/destructive actions, build a DOM modal — see `suspendCoordinator()` for the pattern.

---

## Common mistakes to avoid

1. **Don't add `<script>` tags inside any HTML string** — the parser will close the JS block early. Split closing tags: `'</' + 'script>'`
2. **Don't use template literals with backtick strings for the outer JS string** — the whole app uses single-quoted string concatenation. Use template literals only inside JS function bodies, not in HTML string builders
3. **Don't call `render()` inside a `render()` loop** — setState triggers render; don't call setState from inside a render function
4. **Don't use `new Set()` for state** — state gets serialised; use plain objects `{}` instead of Sets or Maps
5. **Don't add npm dependencies** — the app has no package.json, no node_modules, no build step. CDN only if needed, dynamically loaded
6. **Don't break the single-file constraint** — everything except `sw.js` lives in `index.html`

---

## File naming for deployment

| File | Deploy as |
|------|-----------|
| `poured-full.html` | `index.html` in `app.pouredevents.com` repo |
| `sw.js` | `sw.js` in same repo root |
| `poured-landing.html` | `index.html` in `pouredevents.com` repo |

GitHub Pages serves `index.html` at the root URL. The service worker registration requires the file to be named exactly `sw.js` at the root.

---

## Environment variables needed

For Vercel deployment (`poured-vercel/`):

```
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
RESEND_API_KEY=re_...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

For the frontend (inline in `index.html` or via a config endpoint):
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

---

## Brand voice

- **Direct** — say what it does, not what it feels like
- **No startup language** — never "seamless", "powerful", "effortless", "curated", "game-changing"
- **No exclamation marks** in UI copy
- **Specific numbers** over vague claims
- **Role names:** Event Host / Agent / Producer / Attendee (never Coordinator, Trade Buyer, Consumer)

---

## Contact / domain

- Domain: pouredevents.com
- App: app.pouredevents.com
- Email: info@pouredevents.com
- Owner: Christian (platform operator — not an Event Host)
