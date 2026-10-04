#!/usr/bin/env node
// real-check: quick, rule-based, read-only check of a public URL. No AI, no account, no code access.
//
// Usage:
//   node check.mjs <http(s)://url> [--lang tr|en] [--brand "Name <email>"] [--outreach] [--control] [--out DIR]
//
// Default: open the home page at desktop (1280) and phone (375) width, check browser errors, links on the
// page and phone layout, and write a one-page report (HTML + PDF) plus findings.json.
// --outreach  also append a row to <out>/outreach.csv.
// --control   no check, no report: only an outreach.csv row for the control group (implies --outreach).
//
// Exit codes: 0 report written / control row written, 2 usage, 3 no findings, 4 site does not open,
// 5 check could not run, 6 home page refused the automated visit (likely bot protection).
// The last stdout line is JSON for exit 0, 3, 4 and 6; exit 2 and 5 write only to stderr.

import { createRequire } from 'node:module';
import { appendFileSync, existsSync, mkdirSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

// Resolve playwright from scripts/node_modules, wherever the skill is installed.
const require = createRequire(import.meta.url);

const USAGE = 'Usage: node check.mjs <http(s)://url> [--lang tr|en] [--brand "Name <email>"] [--outreach] [--control] [--out DIR]';
const USER_AGENT_TOKEN = 'real-check/0.11 (+https://github.com/giraybatiturk/skills)';
const READ_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);
const BROKEN_STATUSES = new Set([404, 410, 500, 502, 504]);
const REFUSED_STATUSES = new Set([401, 403, 429, 503]);
// Links that look like an action are never requested, even with GET. Keywords match as substrings anywhere in the
// decoded, folded path + query text, with no word boundary, so an ordinary address that contains one (for example
// /blog/how-to-remove-404 or /cancellation-policy) is left unchecked too; skipped links are listed in a warning and in
// findings.json. Only the `log/out` forms keep a leading boundary (so /blog/outdoor passes), and `cart/add` must not
// be `cart/address`; a cart address also matches on an action word anywhere in its query (/cart?action=add).
// Two-part keywords take an optional separator (- _ space). Query KEYS are tested apart: see skipUrl.
// Languages: English, Turkish, German, French, Spanish, Italian, Portuguese, Dutch. The non-English words come from
// general knowledge of those languages, not from measured sites; other languages are not covered. Words are written as
// fold() leaves them (löschen is `loschen`, déconnexion is `deconnexion`). A few short words (salir, sair, esci) would skip
// many ordinary addresses as substrings, so they match only as a whole token: no letter directly before or after.
// ponytail: keyword heuristic, deliberately broad: safety over coverage. A site that changes state on a GET under
// another name is not protected.
const SEP = '[-_ ]?';
const SKIP_WORDS = [
  // English
  `log${SEP}(?:out|off)`, `sign${SEP}(?:out|off)`, `opt${SEP}out`, 'unsubscribe', 'delete', 'remove', 'cancel', 'deactivate', `add${SEP}to${SEP}cart`,
  // Turkish
  'cikis', `oturumu?${SEP}kapat`, `sepete${SEP}ekle`,
  // German
  'abmelden', 'ausloggen', 'loschen', 'loeschen', 'kundigen', 'kuendigen', 'stornieren', 'abbestellen', 'entfernen',
  // French
  'deconnex', 'deconnect', 'supprim', 'desabonn', 'desinscri',
  // Spanish
  `cerrar${SEP}sesion`, 'desconectar', 'eliminar', 'borrar', `darse${SEP}de${SEP}baja`,
  // Italian
  'disconnett', 'disconness', 'elimina', 'disiscri', 'rimuovi',
  // Portuguese
  `terminar${SEP}sessao`, `encerrar${SEP}sessao`, 'excluir', 'apagar', 'descadastrar',
  // Dutch
  'uitloggen', 'afmelden', 'verwijderen', 'uitschrijven', 'opzeggen',
  // Shared stem: annuler, annulla, annuleren
  'annul',
];
const SKIP_TOKENS = ['salir', 'sair', 'esci'];
const SKIP_LINK = new RegExp([
  ...SKIP_WORDS,
  `(?<![a-z])(?:${SKIP_TOKENS.join('|')})(?![a-z])`,
  '(?<![a-z0-9])(?:log|sign)/(?:out|off)',
  'cart/(?:add(?!ress)|remove|update|clear|empty)',
  'cart[^?]*[?].*(?:add(?!ress)|update|clear|empty)',
].join('|'));
// A query key is `confirm` or ends in `token` (token, access_token, csrfToken, authtoken).
const SKIP_QUERY_KEY = /^(?:confirm|.*token)$/;
const MAX_LINKS = 50;
const MAX_REDIRECTS = 5;
const LINK_CONCURRENCY = 5;
const LINK_TIMEOUT_MS = 15_000;
const PAGE_TIMEOUT_MS = 30_000;
const SETTLE_MS = 2000;
const GUARD_WINDOW_MS = 2000;
const CLIP = 90;
const DESKTOP = { width: 1280, height: 800 };
const PHONE = { width: 375, height: 812 };

const TEXT = {
  en: {
    title: (h) => `Site check for ${h}`,
    intro: (h, d) => `We opened ${h} on ${d} at desktop (1280 px) and phone (375 px) widths. Below are the findings a visitor could notice.`,
    console: {
      title: 'The browser reports errors while the page loads',
      why: 'These errors are usually invisible, but they can mean a button, a form or an analytics script silently does not work.',
    },
    links: {
      title: 'Some links on the home page are broken',
      why: 'Visitors who click them land on an error page, and search engines treat broken links as a negative signal.',
    },
    mobile: {
      title: 'On phones the page does not fit the screen',
      why: 'Visitors have to scroll sideways and content or buttons spill off the screen. Most traffic comes from phones.',
    },
    noViewport: {
      title: 'The page is not adapted to phones; it is shown zoomed out',
      why: 'Text and buttons are tiny, and visitors have to pinch-zoom to read or tap anything. Most traffic comes from phones.',
      detail: 'The page does not tell phones to use their own screen width, so they show the desktop layout shrunk to fit.',
    },
    saw: 'What we saw',
    matters: 'Why it matters',
    desktop: 'Desktop (1280 px)',
    phone: 'Phone (375 px)',
    scope: 'This check is automated and read-only: it opens the home page and looks at browser errors, links on the home page and phone width. Form submission, checkout and pages behind a login were not checked.',
    preparedBy: (b) => `Prepared by ${b}.`,
    questions: (e) => `Questions: ${e}`,
    pageWidth: (w) => `Page width ${w} px, screen 375 px.`,
    spilling: 'First elements spilling past the right edge',
    locale: 'en-GB',
  },
  tr: {
    title: (h) => `${h} için site kontrolü`,
    intro: (h, d) => `${h} adresini ${d} tarihinde masaüstü (1280 px) ve telefon (375 px) genişliğinde açtık. Aşağıda ziyaretçinin fark edebileceği bulgular var.`,
    console: {
      title: 'Sayfa açılırken tarayıcıda hata oluşuyor',
      why: 'Bu hatalar çoğu zaman görünmez, ama bir butonun, formun ya da ölçüm kodunun sessizce çalışmadığını gösterebilir.',
    },
    links: {
      title: 'Ana sayfada çalışmayan bağlantılar var',
      why: 'Ziyaretçi tıkladığında hata sayfasıyla karşılaşır; arama motorları da kırık bağlantıları olumsuz bir sinyal olarak görür.',
    },
    mobile: {
      title: 'Telefonda sayfa ekrana sığmıyor',
      why: 'Ziyaretçi sayfayı yana kaydırmak zorunda kalır; içerik ve butonlar ekranın dışına taşar. Trafiğin büyük kısmı telefondan gelir.',
    },
    noViewport: {
      title: 'Sayfa telefona uyarlanmamış; küçültülmüş gösteriliyor',
      why: 'Yazılar ve butonlar çok küçük kalır; ziyaretçi okumak ya da dokunmak için ekranı yakınlaştırmak zorunda kalır. Trafiğin büyük kısmı telefondan gelir.',
      detail: 'Sayfa, telefona kendi ekran genişliğini kullanmasını söylemiyor; telefonlar masaüstü düzenini küçülterek gösteriyor.',
    },
    saw: 'Ne gördük',
    matters: 'Neden önemli',
    desktop: 'Masaüstü (1280 px)',
    phone: 'Telefon (375 px)',
    scope: 'Bu kontrol otomatik ve yalnız okuma yapar: ana sayfayı açar, tarayıcı hatalarına, ana sayfadaki bağlantılara ve telefon genişliğine bakar. Form gönderimi, ödeme ve giriş gerektiren sayfalar kontrol edilmedi.',
    preparedBy: (b) => `Bu raporu ${b} hazırladı.`,
    questions: (e) => `Sorular için ${e}`,
    pageWidth: (w) => `Sayfa genişliği ${w} px, ekran 375 px.`,
    spilling: 'Ekranın sağına taşan ilk öğeler',
    locale: 'tr-TR',
  },
};

const emit = (obj) => console.log(JSON.stringify(obj));
const fail = (message) => { console.error(message); return 2; };
const firstLine = (s) => String(s).split('\n')[0].trim();
const unique = (a) => [...new Set(a)];
const clip = (s, n = CLIP) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
// Decodes percent escapes one valid UTF-8 sequence at a time; an invalid escape (%FF) becomes a space, so it cannot
// leave the rest of the URL undecoded or glue itself to a neighbouring word.
export const decoded = (s) => s.replace(/%[0-7][0-9a-f]|%[cd][0-9a-f]%[89ab][0-9a-f]|%e[0-9a-f](?:%[89ab][0-9a-f]){2}|%f[0-7](?:%[89ab][0-9a-f]){3}|%[0-9a-f]{2}/gi, (m) => { try { return decodeURIComponent(m); } catch { return ' '; } });
const slugify = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

function isoDate() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// Registrable domain = last two labels. Known limitation: for multi-part public suffixes (co.uk, com.tr)
// two unrelated sites under one suffix compare as the same domain, so a failed third-party resource there is
// reported as a finding instead of a warning, and their links count as same-site. Kept simple on purpose;
// a public-suffix list is not worth a dependency here.
export const registrable = (hostname) => hostname.split('.').slice(-2).join('.');

function parseBrand(raw) {
  if (!raw || !raw.trim()) return null;
  const m = raw.match(/^\s*(.*?)\s*<([^<>]+)>\s*$/);
  if (!m) return { name: raw.trim(), email: null };
  const email = m[2].trim();
  return { name: m[1].trim() || email, email: m[1].trim() ? email : null };
}

function parseCli(argv) {
  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      allowPositionals: true,
      options: {
        lang: { type: 'string' },
        brand: { type: 'string' },
        outreach: { type: 'boolean' },
        control: { type: 'boolean' },
        out: { type: 'string' },
      },
    });
  } catch (e) {
    return { error: `${firstLine(e.message)}\n${USAGE}` };
  }
  const { values, positionals } = parsed;
  const url = positionals[0];
  const lang = values.lang ?? 'en';
  if (positionals.length !== 1 || !/^https?:\/\//i.test(url)) return { error: USAGE };
  if (!(lang in TEXT)) return { error: `--lang must be tr or en\n${USAGE}` };
  let parsedUrl;
  try { parsedUrl = new URL(url); } catch { return { error: `Not a valid URL: ${url}\n${USAGE}` }; }
  const host = parsedUrl.host.toLowerCase();
  // Host slug, plus a path slug (max 40 chars) when the URL is not the site root, so two pages of one site do not share a folder.
  const pathSlug = parsedUrl.pathname === '/' ? '' : slugify(parsedUrl.pathname).slice(0, 40).replace(/-+$/, '');
  return {
    url: parsedUrl.href,
    host,
    hostname: parsedUrl.hostname.toLowerCase(),
    slug: [slugify(host), pathSlug].filter(Boolean).join('-'),
    lang,
    brand: parseBrand(values.brand),
    control: Boolean(values.control),
    outreach: Boolean(values.outreach || values.control),
    out: path.resolve(values.out ?? 'real-check-reports'),
    date: isoDate(),
  };
}

const csvField = (v) => {
  const s = String(v).replace(/\s*[\r\n]+\s*/g, ' ');
  return /[",]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

// Tracking row for an outreach experiment. Returns the CSV path.
function trackRow(opts, group, status, note) {
  mkdirSync(opts.out, { recursive: true });
  const file = path.join(opts.out, 'outreach.csv');
  if (!existsSync(file)) writeFileSync(file, 'date,site,group,status,reply,meeting,proposal,note\n');
  appendFileSync(file, [opts.date, opts.host, group, status, '', '', '', note].map(csvField).join(',') + '\n');
  return file;
}

// Run folder `<slug>-<date>`; a second run on the same day gets `-2`, `-3`, ...
function runDir(opts) {
  const base = path.join(opts.out, `${opts.slug}-${opts.date}`);
  let dir = base;
  for (let n = 2; existsSync(dir); n++) dir = `${base}-${n}`;
  mkdirSync(dir, { recursive: true });
  return dir;
}

// Loopback, private and link-local destinations. The URL parser has already normalised forms like 2130706433 or
// 0x7f.1 to 127.0.0.1 and IPv4-mapped IPv6 to hex groups.
// ponytail: literal hosts only, no DNS resolution; a public name that resolves to a private address is not caught.
// Upgrade path: resolve the name and test the address before the request.
export function isPrivateHost(hostname) {
  const h = hostname.toLowerCase().replace(/^\[|\]$|\.$/g, '');
  if (h === 'localhost' || h.endsWith('.localhost')) return true;
  const v4 = h.match(/^(\d+)\.(\d+)\.\d+\.\d+$/);
  if (v4) {
    const [a, b] = [Number(v4[1]), Number(v4[2])];
    return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
  }
  const mapped = h.match(/^::ffff:([0-9a-f]+):([0-9a-f]+)$/);
  if (mapped) {
    const [hi, lo] = [parseInt(mapped[1], 16), parseInt(mapped[2], 16)];
    return isPrivateHost(`${hi >> 8}.${hi & 255}.${lo >> 8}.${lo & 255}`);
  }
  return h === '::' || h === '::1' || /^f[cd][0-9a-f]{2}:/.test(h) || /^fe[89ab][0-9a-f]:/.test(h);
}
const isPrivateUrl = (url) => { try { return isPrivateHost(new URL(url).hostname); } catch { return false; } };

const newGuard = () => ({ writes: [], blocked: [], hops: [], aborts: [], sockets: [], navBlocked: '', main: null });
// Only the checked page's own main frame counts: a popup's navigation is just a blocked request. request.frame() throws
// when the request has no frame yet (a navigation opened by window.open).
const isMainNavigation = (request, guard) => { try { return request.isNavigationRequest() && request.frame() === guard.main?.mainFrame(); } catch { return false; } };

// Read-only protection: every HTTP request other than GET/HEAD/OPTIONS is aborted, whatever the origin, and
// every WebSocket is closed before it reaches the server. Unless the checked URL is itself local, requests the page
// sends straight to a literal loopback, private or link-local address are aborted too. Not covered: redirect hops
// (see the request listener in runCheck) and public names that resolve to a private address (see isPrivateHost).
// `aborts` holds each aborted URL and when, to tell the console errors it causes from genuine ones.
async function protectWrites(context, guard, allowPrivate) {
  await context.route('**/*', (route) => {
    const request = route.request();
    if (!READ_METHODS.has(request.method())) {
      guard.writes.push(`${request.method()} ${request.url()}`);
    } else if (allowPrivate || !isPrivateUrl(request.url())) {
      return route.fallback();
    } else {
      guard.blocked.push(request.url());
      if (isMainNavigation(request, guard)) guard.navBlocked = request.url();
    }
    guard.aborts.push({ url: request.url(), at: Date.now() });
    return route.abort().catch(() => {});
  });
  await context.routeWebSocket(/.*/, async (ws) => {
    guard.sockets.push(ws.url());
    await ws.close().catch(() => {});
  });
}

async function pool(items, size, worker) {
  const results = new Array(items.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(size, items.length) }, async () => {
    while (next < items.length) {
      const i = next++;
      results[i] = await worker(items[i]);
    }
  }));
  return results;
}

function listenForErrors(page, sink) {
  page.on('console', (m) => {
    if (m.type() !== 'error') return;
    const url = m.location().url;
    const text = m.text();
    sink.push({ text, url, line: (url ? `${text} (${url})` : text).replace(/\s+/g, ' ').trim(), at: Date.now() });
  });
  page.on('pageerror', (e) => sink.push({ text: e.message, url: '', line: e.message.replace(/\s+/g, ' ').trim(), at: Date.now() }));
}

// A failed load (network error or HTTP error) of a resource on another registrable domain usually comes from the
// machine running the check (DNS filter, ad blocker, TLS-inspecting proxy) or from someone else's server, not from
// the site. It is a warning, not a finding. `ownDomains` holds the requested and the final (post-redirect) domain.
function isThirdPartyFailedLoad(entry, ownDomains) {
  if (!/net::ERR_|^Failed to load resource/.test(entry.text) || !entry.url) return false;
  try { return !ownDomains.has(registrable(new URL(entry.url).hostname)); } catch { return false; }
}

// Lower-case, strip diacritics and fold Turkish dotless ı, so ÇIKIŞ, çıkış and cikis all compare as cikis.
export const fold = (s) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/ı/g, 'i').toLowerCase();
export const skipUrl = (u) =>
  SKIP_LINK.test(fold(decoded(u.pathname)) + fold(decoded(u.search))) ||
  [...new URLSearchParams(u.search).keys()].some((k) => SKIP_QUERY_KEY.test(k.toLowerCase()));

// GET one link. Redirects are followed by hand, only while the target stays on an allowed host and does not look
// like an action (see SKIP_LINK); a redirect that leaves the site ends the check for that link (neither broken nor requested).
async function fetchLink(context, url, allowedHosts, userAgent) {
  let current = url;
  try {
    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      const response = await context.request.get(current, { timeout: LINK_TIMEOUT_MS, maxRedirects: 0, headers: { 'User-Agent': userAgent } });
      const status = response.status();
      const location = response.headers().location;
      if (status < 300 || status >= 400 || !location) return { url, status };
      let next;
      try { next = new URL(location, current); } catch { return { url, status }; }
      if (!/^https?:$/.test(next.protocol) || !allowedHosts.has(next.host.toLowerCase()) || skipUrl(next)) return { url, status };
      current = next.href;
    }
    return { url, error: 'error: too many redirects' };
  } catch (e) {
    return { url, error: `error: ${firstLine(e.message)}` };
  }
}

async function checkLinks(context, page, opts, userAgent, warnings) {
  const finalUrl = new URL(page.url());
  const finalHost = finalUrl.host.toLowerCase();
  // Same-site links only. If the home page redirected to another host, links are checked there; a redirect to a
  // different registrable domain replaces the requested host instead of adding to it.
  const allowedHosts = new Set([opts.host]);
  if (finalHost !== opts.host) {
    if (registrable(finalUrl.hostname) === registrable(opts.hostname)) {
      allowedHosts.add(finalHost);
    } else {
      allowedHosts.clear();
      allowedHosts.add(finalHost);
      warnings.push(`The home page redirected to ${finalHost}, a different domain; links on ${finalHost} were checked instead of ${opts.host}.`);
    }
  }
  // getAttribute + base URL: `a.href` is not a string on SVG anchors.
  const hrefs = await page.$$eval('a[href]', (as) => as.map((a) => { try { return new URL(a.getAttribute('href'), document.baseURI).href; } catch { return ''; } }));
  const sameSite = unique(hrefs.map((h) => h.split('#')[0])).filter((h) => {
    let u;
    try { u = new URL(h); } catch { return false; }
    return /^https?:$/.test(u.protocol) && allowedHosts.has(u.host.toLowerCase());
  });
  const skipped = sameSite.filter((h) => skipUrl(new URL(h)));
  const eligible = sameSite.filter((h) => !skipUrl(new URL(h)));
  const links = eligible.slice(0, MAX_LINKS);
  if (skipped.length) {
    warnings.push(`${skipped.length} link(s) were not checked because they look like actions (log out, delete, cancel, cart): ${skipped.slice(0, 5).join('; ')}${skipped.length > 5 ? `; and ${skipped.length - 5} more` : ''}.`);
  }
  if (eligible.length > links.length) {
    warnings.push(`The home page has ${eligible.length} same-site links to check; only the first ${links.length} were checked.`);
  }
  const results = await pool(links, LINK_CONCURRENCY, (url) => fetchLink(context, url, allowedHosts, userAgent));
  const broken = results.filter((r) => BROKEN_STATUSES.has(r.status)).map((r) => `${r.status} ${r.url}`);
  // Everything else that failed (401/403/429/503, other 4xx/5xx, network errors) is often bot protection
  // (for example a Cloudflare challenge) while a real visitor sees the page; warn, do not report.
  const unclear = results.filter((r) => r.error || (r.status >= 400 && !BROKEN_STATUSES.has(r.status))).map((r) => `${r.error ?? r.status} ${r.url}`);
  return { checked: links.length, found: eligible.length, skipped, broken, unclear };
}

function renderHtml(T, opts, findings, shots) {
  const dateText = new Date().toLocaleDateString(T.locale, { day: 'numeric', month: 'long', year: 'numeric' });
  const brandLine = opts.brand
    ? `<p class="soft">${esc(T.preparedBy(opts.brand.name))}${opts.brand.email ? ` ${esc(T.questions(opts.brand.email))}` : ''}</p>`
    : '';
  const image = (b64, label) => `<figure><img alt="${esc(label)}" src="data:image/jpeg;base64,${b64}"><figcaption>${esc(label)}</figcaption></figure>`;
  const figures = [shots.desktop && image(shots.desktop, T.desktop), shots.phone && image(shots.phone, T.phone)].filter(Boolean).join('\n');
  // Displayed details are clipped so a long URL cannot push the report past one page; findings.json keeps the full text.
  return `<!doctype html>
<html lang="${opts.lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(T.title(opts.host))}</title>
<style>
:root{color-scheme:light only;--ink:#22252a;--soft:#6f7379;--accent:#1c1c8e;--line:#e4e4e2}
html,body{background:#fff}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;font-size:16px;line-height:1.58;color:var(--ink)}
main{max-width:640px;margin:0 auto;padding:40px 20px 56px}
h1{font-size:22px;font-weight:600;margin:0 0 8px;overflow-wrap:anywhere}
h2{font-size:16px;font-weight:600;margin:0 0 6px}
p{margin:0 0 12px}
.soft{color:var(--soft);font-size:14px;overflow-wrap:anywhere}
.finding{border-top:1px solid var(--line);padding:20px 0 8px;break-inside:avoid}
.no{color:var(--accent);font-weight:600;margin-right:6px}
.label{font-size:13px;color:var(--soft);margin:10px 0 2px}
ul{margin:0 0 8px;padding-left:18px}
li{font-size:14px;overflow-wrap:anywhere}
.shots{display:grid;grid-template-columns:3fr 1fr;gap:16px;align-items:start;border-top:1px solid var(--line);padding-top:20px;margin-top:8px;break-inside:avoid}
figure{margin:0}img{width:100%;height:auto;border:1px solid var(--line);display:block}
figcaption{font-size:13px;color:var(--soft);margin-top:6px}
footer{border-top:1px solid var(--line);margin-top:28px;padding-top:16px}
@media (max-width:560px){.shots{grid-template-columns:1fr}}
@page{size:A4;margin:14mm}
@media print{main{padding:0}body{font-size:14.5px}h1{font-size:20px}p{margin:0 0 8px}.finding{padding:10px 0 0}.label{margin:4px 0 0}.shots{padding-top:10px;max-width:72%}footer{margin-top:12px;padding-top:8px}}
</style></head><body><main>
<h1>${esc(T.title(opts.host))}</h1>
<p class="soft">${esc(T.intro(opts.host, dateText))}</p>
${findings.map((f, i) => `<section class="finding"><h2><span class="no">${i + 1}.</span>${esc(f.title)}</h2>
<p class="label">${esc(T.saw)}</p><ul>${f.details.map((d) => `<li>${esc(clip(d))}</li>`).join('')}${f.more > 0 ? `<li>+${f.more}</li>` : ''}</ul>
<p class="label">${esc(T.matters)}</p><p>${esc(f.why)}</p></section>`).join('\n')}
<div class="shots">${figures}</div>
<footer><p class="soft">${esc(T.scope)}</p>${brandLine}</footer>
</main></body></html>`;
}

// Pages in a Chromium PDF: page objects are `/Type /Page`; the page tree is `/Type /Pages`.
const pdfPageCount = (file) => (readFileSync(file).toString('latin1').match(/\/Type\s*\/Page(?![s\w])/g) ?? []).length;

function summaryOf(opts, status, findings, warnings, extra = {}) {
  return {
    status,
    host: opts.host,
    url: opts.url,
    lang: opts.lang,
    date: opts.date,
    findings: findings.map(({ type, title, details, total }) => ({ type, title, details, total })),
    warnings,
    ...extra,
  };
}

async function runCheck(opts, chromium) {
  const T = TEXT[opts.lang];
  const warnings = [];
  const guard = newGuard();
  const allowPrivate = isPrivateHost(opts.hostname);
  const errors = [];
  const shots = {};
  let browser;
  try {
    browser = await chromium.launch();

    // Append the check's identity to Chromium's own user agent; do not hide that the visit is automated.
    const probe = await browser.newContext({ serviceWorkers: 'block' });
    await protectWrites(probe, guard, allowPrivate);
    const defaultUa = await (await probe.newPage()).evaluate(() => navigator.userAgent);
    await probe.close();
    const userAgent = `${defaultUa} ${USER_AGENT_TOKEN}`;

    const open = async (extra) => {
      const context = await browser.newContext({ ...extra, userAgent, serviceWorkers: 'block' });
      await protectWrites(context, guard, allowPrivate);
      const page = await context.newPage();
      guard.main = page;
      listenForErrors(page, errors);
      // Redirect hops are not routed: Playwright sees them only after Chromium has followed them, so they can be reported, not aborted.
      // ponytail: detection only; upgrade path is a proxy or PAC file that refuses private destinations on every hop
      // (it would replace the system proxy settings, so it is not done here).
      page.on('request', (r) => {
        if (allowPrivate || !r.redirectedFrom() || !isPrivateUrl(r.url())) return;
        guard.hops.push(r.url());
        if (isMainNavigation(r, guard)) guard.navBlocked = r.url();
      });
      return { context, page };
    };
    // goto waits for the document only; a page that never fires `load` is still checked (with a warning).
    const load = async (page, label) => {
      const started = Date.now();
      const response = await page.goto(opts.url, { waitUntil: 'domcontentloaded', timeout: PAGE_TIMEOUT_MS });
      const left = Math.max(1000, PAGE_TIMEOUT_MS - (Date.now() - started));
      await page.waitForLoadState('load', { timeout: left }).catch(() => {
        warnings.push(`The page did not finish loading within ${PAGE_TIMEOUT_MS / 1000} s at ${label} width; the check used what had loaded.`);
      });
      return response;
    };

    // 1. opens (desktop)
    const desktop = await open({ viewport: DESKTOP });
    let response = null;
    let reason = '';
    try {
      response = await load(desktop.page, 'desktop');
      if (!response) reason = 'no response';
    } catch (e) {
      reason = firstLine(e.message);
    }
    const doesNotOpen = (why) => {
      const csv = opts.outreach ? trackRow(opts, 'report', 'does-not-open', `site does not open: ${why}`) : undefined;
      emit({ status: 'does-not-open', host: opts.host, reason: why, csv });
      return 4;
    };
    const redirectedAway = () => `the page redirected to a private or local address (${new URL(guard.navBlocked).host}); the check does not continue there`;
    if (guard.navBlocked) reason = redirectedAway();
    if (response && !guard.navBlocked) {
      const status = response.status();
      if (REFUSED_STATUSES.has(status) || response.headers()['cf-mitigated']) {
        const refused = `HTTP ${status}: the automated visit was refused (likely bot protection); verify in your own browser`;
        const csv = opts.outreach ? trackRow(opts, 'report', 'blocked', refused) : undefined;
        emit({ status: 'blocked', host: opts.host, reason: refused, csv });
        return 6;
      }
      if (status >= 400) reason = `HTTP ${status}`;
    }
    if (reason) return doesNotOpen(reason);
    // 2. console: errors and page errors through load + 2 s
    await desktop.page.waitForTimeout(SETTLE_MS);
    // A navigation the guard aborted after load (meta refresh, timer) leaves the page on a browser error page; never
    // measure or check links there.
    if (guard.navBlocked) return doesNotOpen(redirectedAway());
    if (desktop.page.url().startsWith('chrome-error:')) return doesNotOpen('the page ended on a browser error page');
    // The site's own registrable domains: the one typed and the one the home page ended on after redirects.
    const ownDomains = new Set([registrable(opts.hostname), registrable(new URL(desktop.page.url()).hostname)]);
    shots.desktop = (await desktop.page.screenshot({ type: 'jpeg', quality: 72 })).toString('base64');

    // 3. links (desktop page, GET only)
    const links = await checkLinks(desktop.context, desktop.page, opts, userAgent, warnings);
    await desktop.context.close();

    // 4. phone layout
    let layout = null;
    const phone = await open({ viewport: PHONE, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    try {
      const phoneResponse = await load(phone.page, 'phone');
      if (!phoneResponse || phoneResponse.status() >= 400) {
        warnings.push(`The phone-width visit answered HTTP ${phoneResponse?.status() ?? 'none'}; phone layout was not checked.`);
      } else {
        await phone.page.waitForTimeout(SETTLE_MS);
        if (phone.page.url().startsWith('chrome-error:')) throw new Error('the page ended on a browser error page');
        // Layout width, not window.innerWidth: without a viewport meta tag innerWidth inflates to 980.
        layout = await phone.page.evaluate((width) => {
          const over = [...document.querySelectorAll('body *')].filter((e) => e.getBoundingClientRect().right > width);
          return {
            meta: document.querySelector('meta[name="viewport" i]')?.getAttribute('content') ?? '',
            inner: window.innerWidth,
            scroll: document.documentElement.scrollWidth,
            count: over.length,
            samples: over.slice(0, 4).map((e) => {
              const cls = e.getAttribute('class')?.trim().split(/\s+/).filter(Boolean).join('.');
              return `${e.tagName.toLowerCase()}${cls ? `.${cls}` : ''} (${Math.round(e.getBoundingClientRect().width)}px)`.slice(0, 160);
            }),
          };
        }, PHONE.width);
        shots.phone = (await phone.page.screenshot({ type: 'jpeg', quality: 72 })).toString('base64');
      }
    } catch (e) {
      warnings.push(`The phone-width check could not load the page (${firstLine(e.message)}); phone layout was not checked.`);
    }
    await phone.context.close();

    // --- findings and warnings ---
    const findings = [];
    const blockedWrites = unique(guard.writes);
    const blockedPrivate = unique(guard.blocked);
    const followedHops = unique(guard.hops);
    const blockedSockets = unique(guard.sockets);
    const guardActive = blockedWrites.length + blockedPrivate.length + blockedSockets.length > 0;

    // Console errors the guard itself caused are not the site's defects.
    // 1) "Failed to load resource" whose URL is an aborted request (the URL on that line is the request URL), logged
    //    shortly after that abort.
    // 2) Generic network errors raised by page code after an aborted fetch/XHR carry the script or page URL, not the
    //    request URL, so they are matched by text and by time: logged shortly after any abort.
    //    ponytail: time correlation is a heuristic (a genuine failure inside the window is dropped too, and kept in
    //    findings.json); upgrade path is matching the error to the request that caused it by initiator.
    const afterAbort = (e, url) => guard.aborts.some((a) => (!url || a.url === url) && e.at >= a.at && e.at - a.at <= GUARD_WINDOW_MS);
    // Closed WebSockets: matched by text while any socket was closed (no time window).
    const guardSideEffect = (e) =>
      (/^Failed to load resource/i.test(e.text) && e.url && afterAbort(e, e.url)) ||
      (afterAbort(e) && /Failed to fetch|NetworkError|Load failed|net::ERR_FAILED/i.test(e.text)) ||
      (blockedSockets.length > 0 && /WebSocket/i.test(e.text));
    // Classify before de-duplicating: the same text can be a side effect at one moment and a genuine error at another.
    const dedupe = (list) => { const seen = new Set(); return list.filter((e) => !seen.has(e.line) && seen.add(e.line)); };
    const dropped = dedupe(errors.filter(guardSideEffect));
    const relevant = dedupe(errors.filter((e) => !guardSideEffect(e)));
    const thirdParty = relevant.filter((e) => isThirdPartyFailedLoad(e, ownDomains));
    const own = relevant.filter((e) => !thirdParty.includes(e));

    if (thirdParty.length) {
      warnings.push(`${thirdParty.length} third-party resource(s) failed to load (for example ${thirdParty[0].line.slice(0, 160)}); not counted as a finding. A network failure can come from this machine (DNS filter, ad blocker, TLS-inspecting proxy), an HTTP error from the third party's own server. Verify in your own browser. Remaining console errors may be a side effect of the same failure.`);
    }
    if (own.length) {
      const lines = own.map((e) => e.line.slice(0, 220));
      findings.push({ type: 'console', title: T.console.title, why: T.console.why, details: lines.slice(0, 5), total: lines.length, more: Math.max(0, lines.length - 5) });
    }
    if (links.unclear.length) {
      warnings.push(`${links.unclear.length} link(s) did not answer the automated request but were not counted as broken (may be bot protection, e.g. Cloudflare challenge): ${links.unclear.slice(0, 3).join('; ')}`);
    }
    if (links.broken.length) {
      findings.push({ type: 'links', title: T.links.title, why: T.links.why, details: links.broken.slice(0, 5), total: links.broken.length, more: Math.max(0, links.broken.length - 5) });
    }
    if (layout) {
      const hasViewport = /width\s*=\s*device-width/i.test(layout.meta);
      if (!hasViewport && layout.inner > PHONE.width) {
        // Without a viewport setting the phone lays the page out at ~980 px, so overflow would only repeat that root cause.
        findings.push({ type: 'noViewport', title: T.noViewport.title, why: T.noViewport.why, details: [T.noViewport.detail], total: 1, more: 0 });
      } else if (layout.scroll > PHONE.width) {
        findings.push({
          type: 'mobile375',
          title: T.mobile.title,
          why: T.mobile.why,
          details: [T.pageWidth(layout.scroll), ...layout.samples.map((s) => `${T.spilling}: ${s}`)],
          total: layout.count,
          more: Math.max(0, layout.count - layout.samples.length),
        });
      }
    }
    if (guardActive) {
      const parts = [];
      if (blockedWrites.length) parts.push(`${blockedWrites.length} write request(s) were blocked by the read-only guard (for example ${blockedWrites[0].slice(0, 160)})`);
      if (blockedPrivate.length) parts.push(`${blockedPrivate.length} request(s) to private or local addresses were blocked (for example ${blockedPrivate[0].slice(0, 160)})`);
      if (blockedSockets.length) parts.push(`${blockedSockets.length} WebSocket connection(s) were closed by the read-only guard`);
      warnings.push(`${parts.join('; ')}.${dropped.length ? ` ${dropped.length} console error(s) possibly caused by them were not counted as findings.` : ''}`);
      if (own.length) warnings.push('Console findings may be a side effect of blocked requests; verify in your own browser.');
    }

    if (followedHops.length) {
      warnings.push(`${followedHops.length} redirect(s) led to a private or local address (for example ${followedHops[0].slice(0, 160)}); the browser followed them before they could be stopped.`);
    }
    // Kept in findings.json so nothing the guard or the link rules left out is lost.
    const detail = { links: { checked: links.checked, found: links.found, skipped: links.skipped }, droppedConsole: dropped.map((e) => e.line) };
    if (!findings.length) {
      const dir = runDir(opts);
      const jsonPath = path.join(dir, 'findings.json');
      const summary = summaryOf(opts, 'no-findings', [], warnings, { html: null, pdf: null, ...detail });
      writeFileSync(jsonPath, JSON.stringify(summary, null, 2));
      const csv = opts.outreach ? trackRow(opts, 'report', 'no-findings', 'automated check found nothing worth reporting; not suitable for a report-based outreach') : undefined;
      emit({ ...summary, slug: opts.slug, json: jsonPath, dir, csv });
      return 3;
    }

    // --- report ---
    const dir = runDir(opts);
    const htmlPath = path.join(dir, `${opts.slug}-report-${opts.lang}.html`);
    const pdfPath = path.join(dir, `${opts.slug}-report-${opts.lang}.pdf`);
    const jsonPath = path.join(dir, 'findings.json');
    writeFileSync(htmlPath, renderHtml(T, opts, findings, shots));
    // The report is static: print it without scripts, service workers or network writes.
    const printer = await browser.newContext({ serviceWorkers: 'block', javaScriptEnabled: false });
    await protectWrites(printer, newGuard(), false);
    const printPage = await printer.newPage();
    await printPage.goto(pathToFileURL(htmlPath).href);
    await printPage.pdf({ path: pdfPath, format: 'A4', printBackground: true });
    await printer.close();
    const pages = pdfPageCount(pdfPath);
    if (pages > 1) warnings.push(`The PDF runs to ${pages} pages instead of one; check the report before sending it.`);
    const summary = summaryOf(opts, 'report', findings, warnings, { html: htmlPath, pdf: pdfPath, ...detail });
    writeFileSync(jsonPath, JSON.stringify(summary, null, 2));
    const csv = opts.outreach ? trackRow(opts, 'report', 'draft', `${findings.length} findings: ${findings.map((f) => f.type).join(', ')}`) : undefined;
    emit({ ...summary, slug: opts.slug, json: jsonPath, dir, csv });
    return 0;
  } finally {
    await browser?.close().catch(() => {});
  }
}

async function main() {
  const opts = parseCli(process.argv.slice(2));
  if (opts.error) return fail(opts.error);

  if (opts.control) {
    const csv = trackRow(opts, 'control', 'draft', 'control group: no check, neutral message draft');
    emit({ status: 'control', host: opts.host, slug: opts.slug, csv, dir: runDir(opts) });
    return 0;
  }

  // Playwright 1.63 requires Node 20+.
  if (Number(process.versions.node.split('.')[0]) < 20) {
    console.error(`real-check needs Node 20 or newer (found ${process.versions.node}).`);
    return 5;
  }
  let chromium;
  try {
    ({ chromium } = require('playwright'));
  } catch {
    console.error('Playwright is not installed. Run: npm install --prefix <skill>/scripts && npx --prefix <skill>/scripts playwright install chromium');
    return 5;
  }
  try {
    return await runCheck(opts, chromium);
  } catch (e) {
    const hint = /Executable doesn't exist|browserType\.launch/.test(e.message) ? '\nThe Chromium browser is missing. Run: npx --prefix <skill>/scripts playwright install chromium' : '';
    console.error(`The check could not run: ${firstLine(e.message)}${hint}`);
    return 5;
  }
}

// Run only as a script, not when a test imports the helpers above. The skill is installed as a symlink: process.argv[1]
// is the path as typed and import.meta.url the resolved one, so compare real paths.
const isEntry = (() => { try { return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { return false; } })();
if (isEntry) process.exitCode = await main();
