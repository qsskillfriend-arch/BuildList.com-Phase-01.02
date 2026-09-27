# BuildList.com — launch version

This is the **launch version**: one advertising position (the top banner on the directory), no online payments, no public sign-in, and no review system. Both are kept in the code, switched off, for a later release.

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


## Database files, in order

`schema.sql`, `seed.sql`, `PATCH-01` through `PATCH-07`, then `seed-ads.sql`
(which sets up the directory banner position).


## Email notifications for every form

Every form on the site emails you the moment it is submitted: listing
applications, claims, removal requests, quotation requests, tender and
vacancy submissions, advertising enquiries, upgrade requests, alert
sign-ups, event and project submissions, and Tender Pro interest.

Set in Vercel, then redeploy:

| Name | Value | Sensitive |
|---|---|---|
| `RESEND_API_KEY` | From resend.com | **Yes** |
| `FORM_NOTIFY_EMAIL` | Your address; several separated by commas | No |
| `FORM_FROM_EMAIL` | `BuildList.com <hello@buildlist.com>`, on a domain verified in Resend | No |

The subject names the form and the sender; urgent ones start with ●.
**Reply** goes straight to the person, and a WhatsApp button opens a chat.
Each submission is also saved in Supabase → `submissions`.

## What is switched off in this version

- **Online payments.** Every Upgrade, Feature and booking button sends an
  **UPGRADE REQUEST** email with the firm, plan and price. Send an invoice;
  once paid, set the tier (or featured vacancy) in the portal and Publish.
- **Tender Pro** shows as *coming soon* and collects interest by email.
- **Adverts** everywhere except the top banner on the directory. The Advertise page
  has a small **Register your interest** section with your contact details; it emails you an
  ADVERTISING ENQUIRY.
- **Firm sign-in and dashboard.** Owners use the claim form; staff confirm by
  calling the number on the listing.
- **Reviews.** Hidden and refused by the server.

All of these are in the full version (`buildlist-VERCEL.zip`) for a later release.
