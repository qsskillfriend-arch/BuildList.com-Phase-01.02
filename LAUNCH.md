# BuildList.com — launch version

This is the **launch version**: one advertising position (the banner at the top of the homepage), no public sign-in, and no review system. Both are kept in the code, switched off, for a later release.

**Follow BuildList-Deployment-Guide-Launch.pdf** for the full step-by-step deployment.

# BuildList.com — launch checklist (Vercel)

364 automated checks pass. 235 buttons and links were mapped across ten
pages; none is dead and none falls back to an unrelated page.

## Do these before you announce anything

### 1. Run the updated `supabase/schema.sql`
It adds columns the portal now writes. Safe to run more than once.
Then run `supabase/seed-ads.sql` (30 slots, 180 placeholder campaigns).

### 2. Replace the placeholder contact details
Search the code for these and put in real ones:

| Placeholder | Where it appears |
|---|---|
| `+256 700 000 000` / `256700000000` | Add-your-firm sidebar: Call and WhatsApp buttons |
| `tenders@buildlist.com` | "Email us the notice" on the Tenders page |
| `jobs@buildlist.com` | Every job's Apply button — set each employer's own address in the portal |
| `listings@buildlist.com` | The field-agent download card |
| `x.com/buildlistug`, LinkedIn, Facebook | Footer icons — point them at your real profiles |

### 3. Environment variables in Vercel
`SITE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` (not secret),
`SUPABASE_SERVICE_KEY` (secret), `BUILD_HOOK_URL` (secret) and either
`RESEND_API_KEY` + `FORM_NOTIFY_EMAIL` or `FORM_WEBHOOK_URL`.

### 4. Submit one of every form yourself
Twelve forms. Every one is now registered with the API and accepted —
tested by posting to the real handler — but only a live submission proves
your delivery (email / webhook / database) is set up.

## What changed in this pass, and why it matters

**Six forms would have failed in production.** Claims, removal requests,
tender notices, job alerts, job posts and advertising enquiries were not in
the API's list of accepted forms, so each would have returned "Unknown form".
A test now compares the site's forms against the API list so they cannot
drift apart again.

**Every deploy was quietly erasing data.** `pull.js` rewrote the category and
tier files from the database using only a few columns, which dropped the tier
capabilities (every firm would have shown as Free — no WhatsApp, no photos)
and the homepage flags (the homepage would have shown no categories). It now
merges: the database wins where it has a value, the committed files fill in
the rest. Featured firms, monthly slots, the digest sponsor and legal pages
edited in the portal now reach the site.

**Dead and misrouted controls fixed:** Subscribe, Apply Filters, Find Jobs,
Download Media Kit, Call, WhatsApp, the footer social icons (they all went to
About), Post a Tender Notice (went to Add-your-firm), Post a Job (went to the
tender form — there was no job form, so one was built), and every Apply button
(went to a placeholder inbox).

**Advertising packages:** one action each, all six on one row.

**Tier cards** are generated from the capabilities the site enforces, so what
a card promises is exactly what switches on. Starter was missing; it is back.

**Directory:** a vertical rail of six mixed-size slots (rectangle, half-page,
square, small banner), fixed heights so rotation never moves the page.

**Portal analytics:** 7 / 30 / 90-day periods, tier filter, sortable columns,
search, click a firm to focus the chart on it, a daily chart, a contact-method
breakdown, a count of free firms worth calling, and CSV and print exports.

**Removed:** the staff-portal link from the footer.


## Environment variables (Vercel → Settings → Environment Variables)

Every one the code reads. Mark **Sensitive** only where shown. After adding
or changing any, redeploy — Vercel does not apply them to an existing build.

### Required
| Name | What to put | Sensitive |
|---|---|---|
| `SITE_URL` | `https://buildlist.com` | No |
| `SUPABASE_URL` | Supabase → Settings → API → Project URL | No |
| `SUPABASE_ANON_KEY` | The **anon public** key | No |
| `SUPABASE_SERVICE_KEY` | The **service_role** key | **Yes** |

### Publishing and staff
| Name | What to put | Sensitive |
|---|---|---|
| `BUILD_HOOK_URL` | Vercel → Settings → Git → Deploy Hooks. Needed only for firm, tier and featured changes — everything else is live on save | **Yes** |

### Your company details (anything left unset is simply hidden)
| Name | What to put | Sensitive |
|---|---|---|
| `CONTACT_PHONE` | e.g. `+256 772 123456` | No |
| `CONTACT_WHATSAPP` | Only if different from the phone | No |
| `CONTACT_EMAIL` | Only if not `hello@buildlist.com` | No |
| `ADS_EMAIL` | Only if not `advertising@buildlist.com` | No |
| `COMPANY_ADDRESS` | Registered office | No |
| `COMPANY_URSB_NO` | URSB registration number | No |
| `COMPANY_TIN` | URA TIN | No |

### Form delivery (set at least one, or submissions only reach the database)
| Name | What to put | Sensitive |
|---|---|---|
| `RESEND_API_KEY` | From resend.com, to email each submission | **Yes** |
| `FORM_NOTIFY_EMAIL` | Where those emails go | No |
| `FORM_FROM_EMAIL` | The sender address, on a domain verified in Resend | No |
| `FORM_WEBHOOK_URL` | Slack or Make.com, if you use one | **Yes** |

### Analytics and features
| Name | What to put | Sensitive |
|---|---|---|
| `GA_MEASUREMENT_ID` | `G-XXXXXXXXXX`. Also switches on the cookie notice | No |
| `GA_PROPERTY_ID` | Numeric property ID, for the portal's links | No |
| `FEATURE_REVIEWS` | Leave unset: reviews are off in the launch version | No |

The build refuses to run if `SUPABASE_ANON_KEY` is set to the service key.


## Online payments (MTN MoMo, Airtel Money, cards)

Payments go through **Flutterwave**. Until the keys below are set, every
"Upgrade" and "Feature" button still works: the request reaches the team as
an **UPGRADE REQUEST** so an invoice can be sent, and the customer is told so.

### Switching it on
1. Open a Flutterwave business account and complete their verification (KYC).
2. Flutterwave dashboard → **Settings → API keys**: copy the **Secret key**.
3. **Settings → Webhooks**: set the URL to `https://buildlist.com/api/pay-webhook`
   and choose a **Secret hash** (any long random string).
4. Add to Vercel and redeploy:

| Name | Value | Sensitive |
|---|---|---|
| `FLW_SECRET_KEY` | Flutterwave secret key | **Yes** |
| `FLW_WEBHOOK_HASH` | The secret hash you chose in step 3 | **Yes** |
| `CRON_SECRET` | Any long random string (lets the nightly rebuild run) | **Yes** |

5. Run `supabase/PATCH-04.sql` (the orders table and expiry dates).
6. Make one real payment of the cheapest item yourself, and check it appears
   under **Portal → Orders** as paid and switched on.

### What each purchase does, automatically
| Product | Price (UGX) | Switches on |
|---|---|---|
| Verified / Premium / Platinum | 150,000 / 400,000 / 1,500,000 a year | The firm's tier, for 12 months (early renewals add to the end date) |
| Featured vacancy | 50,000 | Pinned and featured for 30 days |
| Category sponsorship | 250,000 a month | A campaign in the portal awaiting the sponsor's logo |

Prices are set in `lib/pay-core.js`. The site never sends a price: the
server decides, so it cannot be edited in the browser. Every payment is
re-checked with Flutterwave before anything switches on, and a payment is
never fulfilled twice. A nightly rebuild at 03:00 lets expired tiers and
featured vacancies lapse.


## Tender Pro (paid tender alerts)

UGX 50,000 a month or 450,000 a year. Sold from the Tenders page. A
subscriber chooses the sectors they follow and gets:

- **A 7am email every morning** with each new tender in those sectors
  (no email on days with nothing new)
- **A reminder three days before** any matching tender closes
- **A private calendar feed** of every matching deadline, which Google
  Calendar, Outlook and iPhone subscribe to and refresh themselves

It runs by itself once switched on. Needs: `PATCH-06.sql`, the payment keys,
`RESEND_API_KEY`, `FORM_FROM_EMAIL` and `CRON_SECRET`. Each subscriber gets a
welcome email with their calendar link the moment they pay.

**What makes it worth paying for is tenders being posted promptly.** Add new
notices in the portal the day they are advertised: a morning email that
arrives after a contractor has already seen the notice elsewhere is not worth
UGX 50,000.

To change a subscriber's sectors, edit their row in Supabase →
`tender_subscriptions`.



## Database files, in order

`schema.sql`, `seed.sql`, `PATCH-01` through `PATCH-07`, then `seed-ads.sql`
(which sets up the single homepage banner position).

## What is switched off in this version

- **Adverts** everywhere except the homepage banner. The Advertise page sells
  what exists at launch: the homepage banner, featured firms, digest sponsorship
  and sponsored stories.
- **Firm sign-in and dashboard.** Owners claim their listing with the claim form;
  staff confirm by calling the number on the listing and make changes for them.
  Quotation requests still reach staff with the matching firms listed.
- **Reviews.** Hidden on the site and refused by the server. To bring them back
  later: `FEATURE_REVIEWS=on`, then redeploy.
