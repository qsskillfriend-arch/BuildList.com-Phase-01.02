/* ═══════════════════════════════════════════════════════════════
   FORM CORE
   BuildList.com — a product of Sharplink Ventures (U) Limited

   The whole form-handling logic, kept platform-neutral so Vercel and
   the serverless function stays thin. The wrapper around it is:

     api/form.js                 Vercel serverless function

   Both expose the same public endpoint, /api/form, so the browser
   calls /api/form, which Vercel serves from api/form.js.

   Delivery is attempted in order and stops at the first that works:
     1. Supabase  SUPABASE_URL + SUPABASE_SERVICE_KEY  → submissions table
     2. Email     RESEND_API_KEY + FORM_NOTIFY_EMAIL
     3. Webhook   FORM_WEBHOOK_URL                      → Slack, Make, Zapier
     4. Logs      nothing configured                    → function log
   ═══════════════════════════════════════════════════════════════ */

export const FORMS = {
  /* Every <form name="..."> on the site must appear here, or the API
     rejects it with "Unknown form". A test checks the two lists match,
     because this list drifting out of step once already meant six forms
     silently failing. */
  'listing-submission':  { label: 'New listing application',       urgent: true  },
  'contact':             { label: 'Contact message',               urgent: true  },
  'newsletter':          { label: 'Digest subscription',           urgent: false },
  'tender-alerts':       { label: 'Tender alert signup',           urgent: false },
  'job-alerts':          { label: 'Job alert signup',              urgent: false },
  'quote-request':       { label: 'Quotation request',             urgent: true  },
  'event-submission':    { label: 'Event submission',              urgent: false },
  'tender-submission':   { label: 'Tender notice submitted',       urgent: true  },
  'job-submission':      { label: 'Vacancy submitted',             urgent: true  },
  'advertising-enquiry': { label: 'ADVERTISING ENQUIRY',           urgent: true  },
  'upgrade-request':     { label: 'UPGRADE REQUEST \u2014 send an invoice', urgent: true  },
  'tender-pro-interest': { label: 'Tender Pro \u2014 registered interest', urgent: false },
  'claim-listing':       { label: 'LISTING CLAIM',                 urgent: true  },
  'project-nomination':  { label: 'Benchmark project nomination',  urgent: false },
  'listing-review':      { label: 'New review to moderate',        urgent: false },
  /* The privacy policy promises 48 hours, and the law expects it. */
  'removal-request':     { label: 'REMOVAL REQUEST \u2014 48 HOURS', urgent: true  }
};

const MAX_FIELD = 4000;
const MAX_FIELDS = 40;

const clean = v => String(v == null ? '' : v).slice(0, MAX_FIELD).trim();

/* Submissions are shown back to staff in the portal, so anything that
   could be read as markup is neutralised here rather than relying on
   every future display site remembering to escape it. */
function sanitise(body) {
  const out = {};
  let n = 0;
  for (const [k, v] of Object.entries(body || {})) {
    if (n++ >= MAX_FIELDS) break;
    if (k === 'bot-field' || k === 'company-website') continue;
    out[k.slice(0, 64)] = clean(v).replace(/[<>]/g, '');
  }
  return out;
}

async function toSupabase(form, fields, meta) {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) return { ok: false, skipped: true };
  const res = await fetch(`${url.replace(/\/$/, '')}/rest/v1/submissions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: key,
      Authorization: `Bearer ${key}`,
      Prefer: 'return=minimal'
    },
    body: JSON.stringify({ form, fields, meta })
  });
  return { ok: res.ok, status: res.status };
}

/* ═══════════════════════════════════════════════════════════════
   EMAIL NOTIFICATION \u2014 one for every submission, of every form
   Written to be acted on from a phone: who it is from in the subject,
   the urgent ones marked, fields under plain names, and Reply going
   straight to the person who wrote in.
   ═══════════════════════════════════════════════════════════════ */
const FIELD_NAMES = {
  name: 'Name', full_name: 'Name', contact: 'Contact', contact_name: 'Contact name', email: 'Email', phone: 'Phone',
  whatsapp: 'WhatsApp', company: 'Company', firm: 'Firm', firm_name: 'Firm', firm_slug: 'Listing',
  'firm-name': 'Firm', role: 'Role', position: 'Role', message: 'Message', details: 'Details', description: 'Description',
  category: 'Category', 'primary-category': 'Category', district: 'District', location: 'Location',
  title: 'Title', ref: 'Reference', org: 'Organisation', deadline: 'Closing date', closes: 'Closing date',
  value: 'Value', salary: 'Salary', type: 'Type', level: 'Level', discipline: 'Discipline',
  apply_email: 'Applications to', website: 'Website', reason: 'Reason', package: 'Package', product: 'Product',
  price: 'Price', budget: 'Budget', start: 'Start date', intent: 'Intent', sectors: 'Sectors', target: 'For',
  project: 'Project', why: 'Why it matters', frequency: 'Frequency', categories: 'Categories', districts: 'Districts',
  matched_suppliers: 'Matched suppliers', lead_alert_firms: 'Firms to forward this to'
};
const niceName = k => FIELD_NAMES[k] || String(k).replace(/[-_]+/g, ' ').replace(/^./, c => c.toUpperCase());
const escH = v => String(v == null ? '' : v).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const INTERNAL = new Set(['form-name', 'bot-field', 'company-website', 'consent', 'page', 'utm']);

export function notificationEmail(form, fields, meta = {}) {
  const def = FORMS[form] || {};
  const label = def.label || form;
  const who = fields.name || fields.full_name || fields.contact_name || fields.company || fields.firm || fields.firm_name || fields.email || '';
  const entries = Object.entries(fields).filter(([k, v]) => !INTERNAL.has(k) && String(v || '').trim() !== '');
  const rows = entries.map(([k, v]) => `<tr>
      <td style="padding:8px 14px 8px 0;color:#6B776F;font-size:13px;vertical-align:top;white-space:nowrap">${escH(niceName(k))}</td>
      <td style="padding:8px 0;font-size:14px;color:#1D2521;white-space:pre-wrap">${escH(v)}</td></tr>`).join('');
  const reply = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(fields.email || '')) ? String(fields.email) : '';
  const phone = String(fields.phone || fields.whatsapp || '').replace(/[^0-9+]/g, '');
  const wa = phone ? phone.replace(/^\+/, '').replace(/^0/, '256') : '';
  const portal = (process.env.SITE_URL || 'https://buildlist.com').replace(/\/$/, '') + '/desk-7k2m9x.html';
  const when = new Date(meta.at || Date.now()).toLocaleString('en-GB', { timeZone: 'Africa/Kampala',
    day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  const subject = (def.urgent ? '\u25CF ' : '') + label + (who ? ' \u2014 ' + String(who).slice(0, 60) : '');
  const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:600px;color:#1D2521">
    <div style="background:#1A3C2A;padding:14px 20px;border-radius:8px 8px 0 0">
      <span style="color:#fff;font-weight:bold;font-size:17px">BuildList<span style="color:#D4AA2A">.com</span></span>
      <span style="color:#A9C2B5;font-size:12px;margin-left:8px">New form submission</span></div>
    <div style="border:1px solid #DDE3DE;border-top:none;border-radius:0 0 8px 8px;padding:18px 20px">
      <h2 style="margin:0 0 4px;font-size:18px;color:#1A3C2A">${escH(label)}</h2>
      <p style="margin:0 0 16px;font-size:13px;color:#6B776F">${escH(when)}${meta.ref ? ' \u00b7 from ' + escH(meta.ref) : ''}</p>
      ${reply || wa ? `<p style="margin:0 0 16px">
        ${reply ? `<a href="mailto:${escH(reply)}" style="background:#C49A16;color:#0F2419;padding:9px 14px;border-radius:6px;text-decoration:none;font-weight:bold;font-size:13px;margin-right:6px">Reply by email</a>` : ''}
        ${wa ? `<a href="https://wa.me/${escH(wa)}" style="background:#1FA855;color:#fff;padding:9px 14px;border-radius:6px;text-decoration:none;font-weight:bold;font-size:13px">WhatsApp them</a>` : ''}</p>` : ''}
      <table style="border-collapse:collapse;width:100%">${rows || '<tr><td style="color:#6B776F">No details were filled in.</td></tr>'}</table>
      <p style="margin:20px 0 0;font-size:12px;color:#8A948D">Also saved in the database, if connected.
        <a href="${escH(portal)}" style="color:#1A3C2A">Open the staff portal</a></p>
    </div></div>`;
  const text = label + '\n' + when + '\n\n' + entries.map(([k, v]) => niceName(k) + ': ' + v).join('\n');
  return { subject, html, text, reply };
}

async function toEmail(form, fields, meta) {
  const key = process.env.RESEND_API_KEY;
  const to = process.env.FORM_NOTIFY_EMAIL;
  if (!key || !to) return { ok: false, skipped: true };
  const m = notificationEmail(form, fields, meta);
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify(Object.assign({
      from: process.env.FORM_FROM_EMAIL || 'BuildList.com <onboarding@resend.dev>',
      /* Several people can be notified: separate addresses with commas */
      to: to.split(',').map(x => x.trim()).filter(Boolean),
      subject: m.subject, html: m.html, text: m.text
    }, m.reply ? { reply_to: m.reply } : {}))
  });
  if (!res.ok) console.error('[form] email failed', res.status, (await res.text().catch(() => '')).slice(0, 200));
  return { ok: res.ok, status: res.status };
}

async function toWebhook(form, fields) {
  const url = process.env.FORM_WEBHOOK_URL;
  if (!url) return { ok: false, skipped: true };
  const label = (FORMS[form] || {}).label || form;
  const text = `*${label}*\n` + Object.entries(fields).map(([k, v]) => `• ${k}: ${v || '—'}`).join('\n');
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, form, fields })
  });
  return { ok: res.ok, status: res.status };
}


/* ═══════════════════════════════════════════════════════════════
   REVIEWS
   A review is written into the reviews table as 'pending' and appears
   only after a member of staff publishes it. Doing it here rather than
   letting the browser insert directly means every review is validated,
   tied to a real listing, and limited to one per email per firm.
   ═══════════════════════════════════════════════════════════════ */
async function toReviews(fields) {
  const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) return { ok: false, skipped: true };
  const H = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };

  const f = await fetch(`${url}/rest/v1/firms?slug=eq.${encodeURIComponent(fields.firm_slug)}&select=id`, { headers: H });
  const firm = (await f.json().catch(() => []))[0];
  if (!firm) return { ok: false, reason: 'That listing no longer exists.' };

  const email = String(fields.email || '').toLowerCase();
  const dup = await fetch(`${url}/rest/v1/reviews?firm_id=eq.${firm.id}&author_email=eq.${encodeURIComponent(email)}&select=id`, { headers: H });
  if ((await dup.json().catch(() => [])).length)
    return { ok: false, reason: 'You have already reviewed this firm. Contact us if you need to change it.' };

  const res = await fetch(`${url}/rest/v1/reviews`, {
    method: 'POST', headers: Object.assign({ Prefer: 'return=minimal' }, H),
    body: JSON.stringify({
      firm_id: firm.id, author_name: fields.name, author_email: email,
      rating: Number(fields.rating), body: fields.review,
      was_customer: fields.was_customer === 'yes' || fields.was_customer === 'on',
      status: 'pending'
    })
  });
  return { ok: res.ok, status: res.status };
}

export function validateReview(b) {
  const r = Number(b.rating);
  if (!Number.isInteger(r) || r < 1 || r > 5) return 'Choose a rating from one to five stars.';
  if (String(b.name || '').trim().length < 2) return 'Add your name.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(b.email || ''))) return 'Add a valid email. It is never shown.';
  const t = String(b.review || '').trim();
  if (t.length < 30) return 'Say a little more \u2014 at least a sentence or two about the work.';
  if (t.length > 2000) return 'Please keep it under 2,000 characters.';
  if (!b.firm_slug) return 'Which firm is this about?';
  return '';
}


/* ═══════════════════════════════════════════════════════════════
   LEAD ALERTS
   When somebody asks for quotations, find the live firms in that
   category whose tier includes lead alerts — same district first — and
   attach them to the notification, so whoever receives it can forward
   the request straight away.

   Deliberately not emailed to the firms automatically: an unsolicited
   email to a firm that never asked for one is spam sent in BuildList's
   name, and a person glancing at the request first also stops junk
   reaching the firms who are paying.
   ═══════════════════════════════════════════════════════════════ */
const LEAD_TIERS_FALLBACK = ['verified', 'premium', 'platinum'];

async function leadMatches(fields) {
  const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key || !fields.category) return [];
  const H = { apikey: key, Authorization: `Bearer ${key}` };

  let tiers = LEAD_TIERS_FALLBACK;
  try {
    const t = await (await fetch(`${url}/rest/v1/tiers?select=slug,caps`, { headers: H })).json();
    const withCaps = (t || []).filter(x => x.caps && Object.keys(x.caps).length);
    if (withCaps.length) tiers = withCaps.filter(x => x.caps.leadAlerts).map(x => x.slug);
  } catch (e) { /* fall back */ }
  if (!tiers.length) return [];

  const q = `select=name,slug,email,phone,district,tier,firm_categories!inner(categories!inner(slug))` +
            `&firm_categories.categories.slug=eq.${encodeURIComponent(fields.category)}` +
            `&status=eq.live&tier=in.(${tiers.join(',')})&limit=40`;
  const r = await fetch(`${url}/rest/v1/firms?${q}`, { headers: H });
  if (!r.ok) return [];
  const firms = await r.json().catch(() => []);
  const d = String(fields.district || '');
  return firms
    .sort((a, b) => (b.district === d) - (a.district === d))
    .slice(0, 12)
    .map(f => ({ name: f.name, email: f.email || '', phone: f.phone || '', district: f.district, tier: f.tier }));
}


/* ═══════════════════════════════════════════════════════════════
   LEADS
   A quotation request becomes a lead for every live firm in that
   category (up to 25, same district first). Firms whose tier includes
   lead alerts get it unlocked; the rest get it locked, which their
   dashboard shows as "leads you missed" and which upgrading unlocks.
   ═══════════════════════════════════════════════════════════════ */
async function createLeads(fields) {
  const url = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key || !fields.category) return 0;
  const H = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };

  let unlocked = LEAD_TIERS_FALLBACK;
  try {
    const t = await (await fetch(`${url}/rest/v1/tiers?select=slug,caps`, { headers: H })).json();
    const withCaps = (t || []).filter(x => x.caps && Object.keys(x.caps).length);
    if (withCaps.length) unlocked = withCaps.filter(x => x.caps.leadAlerts).map(x => x.slug);
  } catch (e) { /* fall back */ }

  const q = `select=id,district,tier,tier_expires_at,firm_categories!inner(categories!inner(slug))` +
            `&firm_categories.categories.slug=eq.${encodeURIComponent(fields.category)}&status=eq.live&limit=60`;
  const r = await fetch(`${url}/rest/v1/firms?${q}`, { headers: H });
  if (!r.ok) return 0;
  const d = String(fields.district || '');
  const firms = (await r.json()).sort((a, b) => (b.district === d) - (a.district === d)).slice(0, 25);
  if (!firms.length) return 0;

  const now = new Date();
  const live = f => !f.tier_expires_at || new Date(f.tier_expires_at) > now;
  const rows = firms.map(f => ({
    firm_id: f.id, category: fields.category, district: fields.district || null,
    summary: String(fields.details || '').slice(0, 1200),
    contact_name: fields.name || null, contact_phone: fields.phone || null, contact_email: fields.email || null,
    locked: !(unlocked.includes(f.tier) && live(f))
  }));
  const ins = await fetch(`${url}/rest/v1/leads`, { method: 'POST',
    headers: Object.assign({ Prefer: 'return=minimal' }, H), body: JSON.stringify(rows) });
  return ins.ok ? rows.length : 0;
}

/**
 * Handle one submission.
 * @param {object} body    parsed request body
 * @param {object} headers request headers, lowercased keys
 * @returns {{status:number, body:object}}
 */
export async function handleSubmission(body = {}, headers = {}) {
  /* Honeypot. A person never fills a hidden field; a bot fills every
     field. Return success so the bot learns nothing from the response. */
  if (body['bot-field'] || body['company-website']) {
    return { status: 200, body: { ok: true, received: true } };
  }

  const form = clean(body['form-name'] || body.form);
  if (!form || !FORMS[form]) {
    return { status: 400, body: { ok: false, error: 'Unknown form' } };
  }

  const fields = sanitise(body);
  delete fields['form-name'];

  if (form === 'quote-request') {
    await createLeads(fields).catch(e => console.error('[leads]', e.message));
    const matches = await leadMatches(fields).catch(() => []);
    fields.lead_alert_firms = matches.length
      ? matches.map(m => `${m.name} (${m.tier}, ${m.district}) ${m.email || m.phone}`).join(' | ')
      : 'No firm in this category is on a tier with lead alerts yet.';
  }

  if (form === 'listing-review') {
    /* Reviews are not part of the launch: refuse them even if someone
       posts one directly, rather than filling a queue nobody reads. */
    if (String(process.env.FEATURE_REVIEWS || '').toLowerCase() !== 'on')
      return { status: 403, body: { ok: false, error: 'Reviews are not open yet.' } };
    const problem = validateReview(fields);
    if (problem) return { status: 400, body: { ok: false, error: problem } };
    const r = await toReviews(fields).catch(e => ({ ok: false, reason: e.message }));
    if (!r.ok && r.reason) return { status: 409, body: { ok: false, error: r.reason } };
  }

  const meta = {
    at: new Date().toISOString(),
    ua: clean(headers['user-agent']).slice(0, 200),
    ref: clean(headers.referer || headers.referrer).slice(0, 200),
    /* Kept for rate limiting and abuse only. Never displayed. */
    ip: clean(headers['x-forwarded-for']).split(',')[0]
  };

  const results = {};
  for (const [name, fn] of [['db', toSupabase], ['email', toEmail], ['hook', toWebhook]]) {
    try { results[name] = await (name === 'hook' ? fn(form, fields) : fn(form, fields, meta)); }
    catch (e) { results[name] = { ok: false, detail: e.message }; }
  }

  const stored = results.db.ok || results.email.ok || results.hook.ok;
  if (!stored) {
    /* Nothing configured, or everything failed. Log it so the
       submission exists somewhere, and say so rather than pretending
       it was filed. */
    console.log('[form] UNSTORED', form, JSON.stringify(fields), JSON.stringify(results));
  }

  return {
    status: 200,
    body: {
      ok: true,
      stored,
      form,
      message: stored
        ? 'Received.'
        : 'Received, but no delivery target is configured yet — check the function logs.'
    }
  };
}

/** Parse a body that may arrive as JSON, form-encoded, or already parsed. */
export function parseBody(raw, contentType = '') {
  if (raw && typeof raw === 'object') return raw;
  if (typeof raw !== 'string' || !raw) return {};
  if (contentType.includes('application/json')) {
    try { return JSON.parse(raw); } catch { /* fall through */ }
  }
  try { return JSON.parse(raw); }
  catch { return Object.fromEntries(new URLSearchParams(raw)); }
}
