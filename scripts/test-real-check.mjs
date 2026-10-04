// Local test for the real-check skill. Run from the repository root:
//
//   node scripts/test-real-check.mjs
//
// Node standard library only. It never contacts anything but 127.0.0.1 and localhost: the fixture sites are served from
// inside this file. It is not part of the skill, so scripts/build-zips.sh does not ship it.
//
// Unit cases import the pure helpers from check.mjs. End-to-end cases spawn `node check.mjs` against the fixture servers
// and assert the exit code, the JSON line, findings.json and the servers' request logs. The browser cases (all but 05, 06
// and 12) need Playwright and Chromium; without them check.mjs exits 5 and those cases FAIL with install instructions
// (they never pass silently).
//
// NOT covered here:
//   - the private-address guard end to end: it only applies when the checked host is not local, so it needs a non-local
//     host name (verified by hand with a Chromium host-mapping argument, see docs/real-hardening-status.md);
//   - real sites, real bot protection (Cloudflare and similar), natural-language routing to the skill;
//   - the roughly 2 s window that ties a console error to a blocked request (timing, not stable enough for a test);
//   - popups, late navigations, redirect hops to private addresses, WebSockets, the Turkish report text and the
//     other statuses (410, 500, 401, 429, 503) as links: checked by hand only;
//   - action words in a query string for the non-English cart forms (only the English `cart` rule has that), and the
//     skip words themselves: they come from general knowledge, so the tables show what the rule does, not that it is
//     complete for those languages;
//   - HEAD and OPTIONS requests from the page (the guard lets them through), and Chromium's own background traffic
//     (the server logs show nothing else on 127.0.0.1 and localhost, but nothing is observed at network level).

import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { after, before, describe, it, test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { decoded, fold, isPrivateHost, registrable, skipUrl } from '../skills/engineering/real-check/scripts/check.mjs';

const SKILL = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../skills/engineering/real-check');
const SCRIPTS = path.join(SKILL, 'scripts');
const CHECK = path.join(SCRIPTS, 'check.mjs');
const INSTALL_HINT = `Playwright or Chromium is not installed, so the browser cases cannot run. This is a failure, not a pass.
Install them: cd ${SCRIPTS} && npm install && npx playwright install chromium`;

// ---------------------------------------------------------------------------------------------------------------------
// Unit cases
// ---------------------------------------------------------------------------------------------------------------------

const skips = (address) => skipUrl(new URL(address, 'http://site.test'));
const wrongOnes = (list, expected) => list.filter((address) => skips(address) !== expected);

const MUST_SKIP = {
  'English words': [
    '/logout', '/log-out', '/log_out', '/log%20out', '/logoff', '/Account/LogOff', '/signout', '/sign-off', '/optout', '/opt-out',
    '/unsubscribe', '/delete', '/remove', '/cancel', '/deactivate', '/add-to-cart', '/add_to_cart', '/addtocart?id=1',
  ],
  'glued and camelCase forms': [
    '/logout2', '/api/v1/logout1', '/Account/LogOff2', '/signout1', '/userlogout', '/doLogout.do', '/logoutUser', '/deleteAccount',
    '/removeItem?id=1', '/cancelOrder/7', '/x?do=deleteAll', '/unsubscribeme',
  ],
  'log/out and sign/out': ['/sign/out', '/log/out', '/sign/off', '/log/off', '/account/log/out'],
  'cart actions': [
    '/cart/add?id=1', '/cart/add/5', '/cart?action=add', '/cart?add=1', '/cart?operation=update', '/cart/clear', '/cart/remove?id=1',
    '/cart/update', '/cart/empty',
  ],
  'query keys': ['/p?access_token=1', '/p?csrfToken=1', '/p?confirm=1', '/p?confirm', '/p?authtoken=1', '/p?token=abc', '/p?a=1&TOKEN=2'],
  'bad and encoded escapes': [
    '/log%6Fut?x=%FF', '/log%FFout', '/%C3%A7%C4%B1k%C4%B1%C5%9F?q=%E7', '/x%E7%FD?do=log%6Fut', '/cikis%2Fnow',
  ],
  'Turkish': [
    '/cikis', '/cikisyap', '/çıkış', '/%C3%A7%C4%B1k%C4%B1%C5%9F', '/ÇIKIŞ', '/%C3%87IKI%C5%9E', '/Cikis',
    '/%C4%B0stanbul/%C3%A7IKI%C5%9F', '/hesap?islem=çıkış', '/oturumu-kapat', '/oturum-kapat', '/oturumukapat', '/oturumu%20kapat',
    '/OTURUM_KAPAT', '/sepete-ekle', '/sepete_ekle', '/sepeteekle',
  ],
  'German': [
    '/abmelden', '/ausloggen', '/konto-löschen', '/konto-loeschen', '/KONTO-LÖSCHEN', '/vertrag-kündigen', '/vertrag-kuendigen',
    '/bestellung-stornieren', '/newsletter-abbestellen', '/warenkorb-entfernen',
    '/abmeldung', '/newsletter-abmeldung', '/kuendigung', '/kündigung', '/konto-loeschung', '/stornierung', '/storno', '/abbestellung',
    '/newsletter-austragen', '/in-den-warenkorb?id=3', '/abo/kundigen',
  ],
  'French': [
    '/déconnexion', '/deconnexion', '/se-deconnecter', '/supprimer-le-compte', '/profil/supprimer', '/se-désabonner',
    '/desabonnement', '/désinscription', '/se-desinscrire',
    '/suppression-compte', '/resilier', '/résiliation', '/effacer', '/fermer-session', '/fermer-la-session', '/desactiver-compte',
    '/panier/ajouter?id=1', '/ajouter-au-panier',
  ],
  'Spanish': [
    '/cerrar-sesión', '/cerrar_sesion', '/cerrarsesion', '/cerrar%20sesion', '/Cerrar-Sesion', '/desconectar', '/eliminar-cuenta',
    '/borrar-cuenta', '/darse-de-baja', '/darsedebaja', '/darse_de_baja',
    '/anular', '/anular-pedido', '/baja', '/dar-de-baja', '/darme-de-baja', '/newsletter/baja', '/desuscribirse', '/desconexion',
    '/cerrar-la-sesion', '/finalizar-sesion', '/eliminar', '/account/elimina', '/carrito/agregar', '/añadir-al-carrito', '/agregar-al-carrito',
  ],
  'Italian': [
    '/disconnetti', '/disconnessione', '/elimina-account', '/disiscriviti', '/rimuovi',
    '/disdetta', '/disdici', '/rimozione', '/disattiva-account', '/uscita', '/aggiungi-al-carrello', '/carrello/aggiungi',
  ],
  'Portuguese': [
    '/terminar-sessão', '/terminar_sessao', '/terminarsessao', '/encerrar-sessão', '/encerrarsessao', '/excluir-conta', '/apagar-conta',
    '/descadastrar',
    '/deslogar', '/deletar-conta', '/exclusao-de-conta', '/exclusão-de-conta', '/descadastro', '/descadastre-se', '/desinscrever',
    '/anular', '/terminar-a-sessao', '/fechar-sessao', '/adicionar-ao-carrinho', '/carrinho/adicionar',
  ],
  'Dutch': [
    '/uitloggen', '/afmelden', '/verwijderen', '/uitschrijven', '/opzeggen', '/account-opzeggen',
    '/log-uit', '/loguit', '/verwijder', '/account/verwijder', '/afmelding', '/uitschrijving', '/opzegging', '/winkelwagen/toevoegen',
  ],
  'shared stem annul': ['/annuler', '/annulla', '/annuleren', '/commande/annuler?id=3', '/x?do=annuleren', '/order-annulation'],
  'short words as whole tokens': [
    '/salir', '/sair', '/esci', '/ESCI', '/Salir', '/user/esci', '/salir.php', '/conta/sair?x=1', '/x?go=sair', '/salir2',
    '/esci-ora', '/sair_da_conta', '/p?a=1&b=salir', '/baja?x=1', '/uscita-ora',
  ],
};

const MUST_KEEP = {
  'ordinary pages': ['/', '/about', '/pricing', '/contact?lang=en', '/blog/post-1?page=2', '/products/shoes'],
  'log/out only at the start of a word': ['/blog/outdoor', '/catalog/output', '/blog/outlook'],
  'cart addresses': ['/cart', '/cart/address', '/cart/addresses', '/cart?address=home', '/warenkorb', '/panier', '/carrito', '/carrello', '/carrinho', '/winkelwagen'],
  'token text that is not a query key': ['/tokens-info', '/token/abc', '/a%3Ftoken=1', '/p?next=%2Fpage%3Ftoken%3Dx', '/x?tokens=1', '/x?confirmation=1', '/confirm'],
  'short words inside a longer word': ['/pesci', '/fresci', '/ensaio', '/sairon', '/bajar-app', '/embajada'],
  'kundig inside ordinary Dutch and German words': [
    '/verpleegkundige', '/onze-deskundigheid', '/bouwkundig-advies', '/ankündigung', '/ankuendigungen', '/fachkundige-beratung',
  ],
  // Documented misses: a stem with a leading boundary does not match when glued to a letter, and only English has cart actions
  // other than add. If one of these becomes skipped that is an improvement: move it to MUST_SKIP and update SKILL.md.
  'documented misses: glued foreign forms and other cart actions': [
    '/doEliminar.do', '/cuentaeliminar', '/userAnnuler', '/commandeannuler', '/vertragskuendigung', '/panier/vider', '/warenkorb/leeren',
  ],
  'English words that contain a foreign stem': [
    '/preliminary-results', '/preliminary-program', '/annulment', '/annular-cutters', '/cannula', '/granular', '/resilience-planning',
    '/resilient-design', '/exclusive-offers', '/exclusivo', '/blog-uitgelicht',
  ],
  'ordinary pages in other languages': [
    '/uber-uns', '/kontakt', '/produkte', '/preise', '/impressum', '/nous-contacter', '/a-propos', '/contacto', '/acerca-de',
    '/chi-siamo', '/sobre-nos', '/over-ons', '/annual-report',
  ],
};

// Keyword matching skips ordinary pages that contain a keyword, also in the other languages (everyday uses of a skip word,
// a stem at the start of an English word). This is documented (SKILL.md Boundaries); asserting it means a change of
// behaviour is noticed instead of slipping through.
const DOCUMENTED_FALSE_SKIPS = [
  '/cancellation-policy', '/blogoffers', '/blog-outreach', '/design-outlet', '/yeni-cikislar', '/blog/how-to-remove-404', '/deleted',
  '/unsubscribed', '/eliminate-waste', '/elimination-diet', '/suppressor', '/tattoo-entfernen', '/kfz-abmelden', '/asbest-verwijderen',
  '/donde-salir', '/onde-sair-em-lisboa', '/conditions-d-annulation', '/baja-california', '/feuerlöscher', '/stornobedingungen',
  '/planta-baja', '/data-di-uscita', '/rimozione-amianto', '/noise-suppression',
];

const PRIVATE_HOSTS = [
  'http://127.0.0.1/', 'http://127.1.2.3/', 'http://2130706433/', 'http://0x7f.1/', 'http://10.0.0.1/', 'http://10.255.255.255/',
  'http://172.16.0.1/', 'http://172.31.255.255/', 'http://192.168.0.1/', 'http://192.168.255.255/', 'http://169.254.169.254/',
  'http://0.0.0.0/', 'http://localhost/', 'http://LOCALHOST/', 'http://localhost./', 'http://a.localhost/', 'http://[::1]/',
  'http://[fc00::1]/', 'http://[fd12:3456::1]/', 'http://[fe80::1]/', 'http://[febf::1]/', 'http://[::ffff:127.0.0.1]/',
  'http://[::ffff:10.0.0.1]/', 'http://[::ffff:192.168.1.1]/',
];
const PUBLIC_HOSTS = [
  'http://10.example.com/', 'http://localhost.example.com/', 'http://8.8.8.8/', 'http://172.32.0.1/', 'http://172.15.255.255/',
  'http://192.169.0.1/', 'http://169.253.0.1/', 'http://11.0.0.1/', 'http://example.com/', 'http://[2001:4860:4860::8888]/',
  'http://[::ffff:8.8.8.8]/', 'http://[fec0::1]/',
];
const isPrivate = (address) => isPrivateHost(new URL(address).hostname);

describe('unit: skip rule', () => {
  for (const [group, list] of Object.entries(MUST_SKIP)) {
    it(`skips ${group}`, (t) => {
      t.diagnostic(`${list.length} addresses`);
      assert.deepEqual(wrongOnes(list, true), [], 'these addresses must be skipped but were not');
    });
  }
  for (const [group, list] of Object.entries(MUST_KEEP)) {
    it(`keeps ${group}`, (t) => {
      t.diagnostic(`${list.length} addresses`);
      assert.deepEqual(wrongOnes(list, false), [], 'these addresses must be checked but were skipped');
    });
  }
  it('still skips the documented false positives', (t) => {
    t.diagnostic(`${DOCUMENTED_FALSE_SKIPS.length} addresses`);
    assert.deepEqual(wrongOnes(DOCUMENTED_FALSE_SKIPS, true), [], 'the substring rule changed: update SKILL.md and the status doc too');
  });
});

describe('unit: helpers', () => {
  it('classifies private and public hosts', (t) => {
    t.diagnostic(`${PRIVATE_HOSTS.length} private, ${PUBLIC_HOSTS.length} public`);
    assert.deepEqual(PRIVATE_HOSTS.filter((a) => !isPrivate(a)), [], 'must be private');
    assert.deepEqual(PUBLIC_HOSTS.filter((a) => isPrivate(a)), [], 'must not be private');
  });
  it('folds case, diacritics and the Turkish dotless i', () => {
    assert.equal(fold('ÇIKIŞ'), 'cikis');
    assert.equal(fold('çıkış'), 'cikis');
    assert.equal(fold('İstanbul'), 'istanbul');
    assert.equal(fold('Déconnexion'), 'deconnexion');
    assert.equal(fold('löschen'), 'loschen');
  });
  it('decodes valid escapes and turns an invalid one into a space', () => {
    assert.equal(decoded('log%6Fut'), 'logout');
    assert.equal(decoded('%C3%A7%C4%B1'), 'çı');
    assert.equal(decoded('a%FFb'), 'a b');
    assert.equal(decoded('a%zzb'), 'a%zzb');
  });
  it('takes the last two host labels as the registrable domain (known limit under co.uk)', () => {
    assert.equal(registrable('www.example.com'), 'example.com');
    assert.equal(registrable('example.com'), 'example.com');
    assert.equal(registrable('localhost'), 'localhost');
    assert.equal(registrable('127.0.0.1'), '0.1');
    assert.equal(registrable('shop.example.co.uk'), 'co.uk');
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// Fixture servers: one site on 127.0.0.1 and a second port reached as `localhost` (a different registrable domain, so it
// stands for a third party). Each request is logged in memory as { method, path }; every case owns a path prefix.
// ---------------------------------------------------------------------------------------------------------------------

const logs = { site: [], third: [] };
const ports = { site: 0, third: 0, dead: 0 };
const servers = [];
const tmpDirs = [];

const page = (body) => `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>fixture</title><link rel="icon" href="data:,"></head><body>${body}</body></html>`;
const GIF = Buffer.from('R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==', 'base64');
const send = (res, status, type, body, headers = {}) => {
  res.writeHead(status, { 'content-type': type, 'cache-control': 'no-store', ...headers });
  res.end(body);
};
const siteUrl = (p) => `http://127.0.0.1:${ports.site}${p}`;
const thirdUrl = (p) => `http://localhost:${ports.third}${p}`;
const anchors = (hrefs) => hrefs.map((href, i) => `<a href="${href}">link ${i}</a>`).join('\n');

// What each case's home page contains. Functions, because they need the ports.
const C07_ACTIONS = [
  'log-out', 'account/delete', 'unsubscribe', 'sign/out',                          // English
  'çıkış', 'oturumu-kapat', 'sepete-ekle',                                         // Turkish
  'abmelden', 'konto-löschen', 'kündigen',                                         // German
  'déconnexion', 'supprimer-le-compte', 'désabonner',                              // French
  'cerrar-sesión', 'eliminar-cuenta', 'darse-de-baja',                             // Spanish
  'disconnetti', 'rimuovi', 'elimina-account',                                     // Italian
  'terminar-sessão', 'excluir-conta', 'sair',                                      // Portuguese
  'uitloggen', 'verwijderen', 'opzeggen',                                          // Dutch
  'annuleren', 'cart/add?id=1', 'x?access_token=1',                                // shared stem, cart, query key
].map((w) => `/c07/s/${w}`);
const C07_ORDINARY = ['/c07/ok/about', '/c07/ok/blog/outdoor', '/c07/ok/pesci', '/c07/ok/cart', '/c07/ok/cart/address', '/c07/ok/tokens-info', '/c07/ok/annual-report'];
const C07_REDIRECT = '/c07/ok/redir'; // answers 302 to an action address
const C10_LINKS = Array.from({ length: 60 }, (_, i) => `/c10/p/${i + 1}`);

const PAGES = {
  '/c01/': () => page('<div style="width:640px;background:#ddd">wide</div><a href="/c01/ok">ok</a> <a href="/c01/missing">missing</a><script>throw new Error("boom")</script>'),
  '/c02/': () => page('<p>hello</p><a href="/c02/ok">ok</a>'),
  '/c07/': () => page(anchors([...C07_ACTIONS, ...C07_ORDINARY, C07_REDIRECT])),
  '/c08/': () => page(`<p>writes</p><iframe name="sink" hidden></iframe>
<form id="f" method="post" action="/c08/form" target="sink"><input name="a" value="1"></form>
<script>
fetch('/c08/api', { method: 'POST', body: 'x' }).catch(() => {});
for (const method of ['PUT', 'DELETE', 'PATCH']) fetch('/c08/api', { method, body: 'x' }).catch(() => {});
fetch('http://localhost:${ports.third}/c08/cross', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' }).catch(() => {});
navigator.sendBeacon('/c08/beacon', 'x');
document.getElementById('f').submit();
</script>`),
  // The same form submitted in the page's own frame: the guard aborts the navigation and the page ends on a browser error page.
  '/c08b/': () => page('<p>top-level form</p><form id="f" method="post" action="/c08b/form"><input name="a" value="1"></form><script>document.getElementById("f").submit()</script>'),
  // A blocked write, then a navigation that fails for another reason (nothing listens on the port): not a write-on-load stop.
  '/c08c/': () => page(`<p>blocked write, then a dead address</p><script>
fetch('/c08c/api', { method: 'POST', body: 'x' }).catch(() => {});
setTimeout(() => { location.href = 'http://127.0.0.1:${ports.dead}/'; }, 500);
</script>`),
  '/c09/': () => page(`<p>third party</p><img src="${thirdUrl('/c09/missing.png')}" width="10" height="10"><a href="/c09/ok">ok</a>`),
  '/c10/': () => page(anchors(C10_LINKS)),
  '/c11/': () => page('<p>hello</p><a href="/c11/ok">ok</a>'),
  // A link to the other host, a same-site link that redirects to the other host, and one address four times.
  '/c13/': () => page(anchors([thirdUrl('/c13/offsite'), '/c13/hop', '/c13/dup', '/c13/dup', '/c13/dup#a', '/c13/dup#b', '/c13/ok'])),
};
const REDIRECTS = { [C07_REDIRECT]: () => '/c07/s/logout?via=redirect', '/c13/hop': () => thirdUrl('/c13/landed') };

function siteHandler(req, res) {
  logs.site.push({ method: req.method, path: req.url });
  req.resume();
  const { pathname } = new URL(req.url, 'http://fixture.test');
  if (req.method !== 'GET') return send(res, 204, 'text/plain', ''); // never expected; the log lets the test notice
  if (pathname === '/c04/') return send(res, 403, 'text/html', page('<p>blocked</p>'));
  if (PAGES[pathname]) return send(res, 200, 'text/html; charset=utf-8', PAGES[pathname]());
  if (REDIRECTS[pathname]) return send(res, 302, 'text/plain', '', { location: REDIRECTS[pathname]() });
  if (pathname.includes('missing')) return send(res, 404, 'text/html', page('<p>not found</p>'));
  return send(res, 200, 'text/html; charset=utf-8', page('<p>ok</p>'));
}

function thirdHandler(req, res) {
  logs.third.push({ method: req.method, path: req.url });
  req.resume();
  if (req.method !== 'GET') return send(res, 204, 'text/plain', '');
  if (req.url.includes('missing')) return send(res, 404, 'image/gif', GIF);
  return send(res, 200, 'image/gif', GIF);
}

const listen = (handler) => new Promise((resolve, reject) => {
  const server = http.createServer(handler);
  server.once('error', reject);
  server.listen(0, '127.0.0.1', () => { servers.push(server); resolve(server.address().port); });
});

// A port that nothing listens on: bind to an OS-assigned port, then release it.
const freePort = () => new Promise((resolve, reject) => {
  const server = http.createServer();
  server.once('error', reject);
  server.listen(0, '127.0.0.1', () => { const { port } = server.address(); server.close(() => resolve(port)); });
});

before(async () => {
  ports.site = await listen(siteHandler);
  ports.third = await listen(thirdHandler);
  ports.dead = await freePort();
});

after(() => {
  for (const server of servers) { server.closeAllConnections(); server.close(); }
  for (const dir of tmpDirs) rmSync(dir, { recursive: true, force: true });
});

const tmp = () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'real-check-test-'));
  tmpDirs.push(dir);
  return dir;
};
const hits = (prefix, log = logs.site) => log.filter((r) => r.path.startsWith(prefix));

// Runs `node <script> ...args`. Resolves with the exit code, both streams and the last stdout line parsed as JSON.
function run(args, script = CHECK) {
  return new Promise((resolve, reject) => {
    execFile(process.execPath, [script, ...args], { timeout: 150_000, maxBuffer: 32 * 1024 * 1024 }, (err, stdout, stderr) => {
      const code = err ? (typeof err.code === 'number' ? err.code : -1) : 0;
      if (code === 5 && /Playwright is not installed|Chromium browser is missing/.test(stderr)) return reject(new Error(`${INSTALL_HINT}\n\n${stderr.trim()}`));
      let json = null;
      try { json = JSON.parse(stdout.trim().split('\n').at(-1)); } catch { /* exit 2 and 5 print no JSON */ }
      resolve({ code, stdout, stderr, json });
    });
  });
}
const expectExit = (r, code) => assert.equal(r.code, code, `exit code (stderr: ${r.stderr.trim().slice(-400) || 'empty'}; stdout: ${r.stdout.trim().slice(-400) || 'empty'})`);
const readJson = (file) => JSON.parse(readFileSync(file, 'utf8'));
const csvRows = (file) => readFileSync(file, 'utf8').trim().split('\n').map((line) => line.split(','));

describe('end to end', { concurrency: 4 }, () => {
  it('01 page with a script error, a broken link and a 640 px block: exit 0, three findings, HTML and PDF', { timeout: 150_000 }, async () => {
    const out = tmp();
    const r = await run([siteUrl('/c01/'), '--out', out]);
    expectExit(r, 0);
    assert.equal(r.json.status, 'report');
    assert.deepEqual(r.json.findings.map((f) => f.type).sort(), ['console', 'links', 'mobile375']);
    const byType = Object.fromEntries(r.json.findings.map((f) => [f.type, f]));
    assert.ok(byType.console.details.some((d) => d.includes('boom')), 'console finding names the script error');
    assert.deepEqual(byType.links.details, [`404 ${siteUrl('/c01/missing')}`]);
    assert.match(byType.mobile375.details[0], /^Page width \d+ px, screen 375 px\.$/);
    assert.ok(!r.json.warnings.some((w) => /PDF runs to/.test(w)), `one-page PDF, got warnings ${JSON.stringify(r.json.warnings)}`);
    assert.ok(existsSync(r.json.html) && readFileSync(r.json.html, 'utf8').includes('<title>Site check for 127.0.0.1:'), 'HTML report written');
    assert.equal(readFileSync(r.json.pdf).subarray(0, 5).toString('latin1'), '%PDF-', 'PDF report written');
    const { slug, json, dir, csv, ...summary } = r.json;
    assert.deepEqual(readJson(json), summary, 'findings.json matches the JSON line');
    assert.equal(hits('/c01/ok').length, 1, 'each link is requested once');
    assert.equal(hits('/c01/missing').length, 1);
  });

  it('02 defect-free page: exit 3, no report files', { timeout: 150_000 }, async () => {
    const r = await run([siteUrl('/c02/'), '--out', tmp()]);
    expectExit(r, 3);
    assert.equal(r.json.status, 'no-findings');
    assert.deepEqual(r.json.findings, []);
    assert.equal(r.json.html, null);
    assert.equal(r.json.pdf, null);
    assert.deepEqual(readdirSync(r.json.dir), ['findings.json']);
    assert.equal(hits('/c02/ok').length, 1);
  });

  it('03 unreachable address: exit 4', { timeout: 150_000 }, async () => {
    const r = await run([`http://127.0.0.1:${await freePort()}/`, '--out', tmp()]);
    expectExit(r, 4);
    assert.equal(r.json.status, 'does-not-open');
    assert.ok(r.json.reason.length > 0);
    assert.doesNotMatch(r.json.reason, /submits a form or sends a write request/, 'an unreachable address is not a write-on-load stop');
  });

  it('04 home page answers 403: exit 6', { timeout: 150_000 }, async () => {
    const r = await run([siteUrl('/c04/'), '--out', tmp()]);
    expectExit(r, 6);
    assert.equal(r.json.status, 'blocked');
    assert.match(r.json.reason, /HTTP 403/);
  });

  it('05 bad input: exit 2, usage on stderr, nothing requested', { timeout: 150_000 }, async () => {
    const out = tmp();
    for (const args of [['not-a-url'], ['ftp://127.0.0.1/'], [siteUrl('/c05/'), '--lang', 'de'], []]) {
      const r = await run([...args, '--out', out]);
      expectExit(r, 2);
      assert.match(r.stderr, /Usage: node check\.mjs/);
      assert.equal(r.stdout, '');
    }
    assert.equal(hits('/c05/').length, 0);
    assert.deepEqual(readdirSync(out), [], 'no output written');
  });

  it('06 --control: exit 0, a control row and zero requests', { timeout: 150_000 }, async () => {
    const out = tmp();
    const r = await run([siteUrl('/c06/'), '--control', '--out', out]);
    expectExit(r, 0);
    assert.equal(r.json.status, 'control');
    assert.equal(hits('/c06/').length, 0, 'control makes no request');
    const rows = csvRows(r.json.csv);
    assert.equal(rows.length, 2);
    assert.deepEqual([rows[1][2], rows[1][3]], ['control', 'draft']);
    assert.ok(existsSync(r.json.dir), 'run folder for the message draft exists');
  });

  it('07 action links in eight languages are never requested; a redirect to one is not followed', { timeout: 150_000 }, async () => {
    const r = await run([siteUrl('/c07/'), '--out', tmp()]);
    expectExit(r, 3);
    const summary = readJson(r.json.json);
    assert.deepEqual(summary.findings, []);
    assert.deepEqual(summary.links.skipped.sort(), C07_ACTIONS.map((p) => siteUrl(p)).map((u) => new URL(u).href).sort(), 'every action link is listed as skipped');
    assert.equal(summary.links.found, C07_ORDINARY.length + 1);
    assert.ok(r.json.warnings.some((w) => /^\d+ link\(s\) were not checked because they look like actions/.test(w)));
    assert.deepEqual(hits('/c07/s/'), [], 'no action address reached the server, including the redirect target');
    const requested = new Set(hits('/c07/ok/').map((q) => q.path));
    for (const p of [...C07_ORDINARY, C07_REDIRECT]) assert.ok(requested.has(p), `${p} should be requested`);
  });

  it('08 write guard: POST, PUT, DELETE, PATCH, cross-origin POST, sendBeacon and form POSTs never reach a server', { timeout: 150_000 }, async () => {
    const [r, top, other] = await Promise.all([
      run([siteUrl('/c08/'), '--out', tmp()]),
      run([siteUrl('/c08b/'), '--outreach', '--out', tmp()]),
      run([siteUrl('/c08c/'), '--outreach', '--out', tmp()]),
    ]);
    const writes = [...hits('/c08', logs.site), ...hits('/c08', logs.third)].filter((q) => q.method !== 'GET');
    assert.deepEqual(writes, [], 'the read-only guard let a write reach a server');
    // A form submitted in the page's own frame: the guard's abort leaves the page on a browser error page. The run stops
    // (exit 4) but says that the guard did it, not that the site does not open.
    expectExit(top, 4);
    assert.equal(top.json.status, 'does-not-open');
    assert.match(top.json.reason, /^the page submits a form or sends a write request as it loads \(POST http:\/\/127\.0\.0\.1:\d+\/c08b\/form\); the read-only check blocked it and cannot continue$/);
    const note = csvRows(top.json.csv)[1].slice(7).join(',');
    assert.equal(csvRows(top.json.csv)[1][3], 'does-not-open');
    assert.match(note, /^not checked: the page submits a form or sends a write request as it loads/);
    assert.ok(!note.includes('site does not open'), 'the tracking note does not also say the site does not open');
    // A blocked fetch POST on a page that then ends on a browser error page for another reason keeps the plain reason and note.
    expectExit(other, 4);
    assert.equal(other.json.reason, 'the page ended on a browser error page');
    assert.equal(csvRows(other.json.csv)[1].slice(7).join(','), 'site does not open: the page ended on a browser error page');
    expectExit(r, 3);
    assert.deepEqual(r.json.findings, [], 'errors caused by blocked writes are not findings');
    const warning = r.json.warnings.find((w) => /write request\(s\) were blocked by the read-only guard/.test(w));
    assert.ok(warning, `the page did fire writes and the guard said so; warnings: ${JSON.stringify(r.json.warnings)}`);
    assert.match(warning, /^7 write request\(s\)/); // POST, PUT, DELETE, PATCH, cross-origin POST, sendBeacon, form
  });

  it('09 third-party image answering 404 is a warning, not a finding', { timeout: 150_000 }, async () => {
    const r = await run([siteUrl('/c09/'), '--out', tmp()]);
    expectExit(r, 3);
    assert.deepEqual(r.json.findings, []);
    assert.ok(r.json.warnings.some((w) => /third-party resource\(s\) failed to load/.test(w)), `warnings: ${JSON.stringify(r.json.warnings)}`);
    assert.ok(hits('/c09/missing.png', logs.third).length > 0, 'the image was requested on the second port');
  });

  it('10 more than 50 links: exactly 50 are requested and the cut is reported', { timeout: 150_000 }, async () => {
    const r = await run([siteUrl('/c10/'), '--out', tmp()]);
    expectExit(r, 3);
    const requested = hits('/c10/p/').map((q) => q.path);
    assert.equal(requested.length, 50);
    assert.deepEqual([...requested].sort(), C10_LINKS.slice(0, 50).sort(), 'the first 50 in page order');
    assert.ok(r.json.warnings.some((w) => /has 60 same-site links to check; only the first 50 were checked/.test(w)));
    const { links } = readJson(r.json.json);
    assert.deepEqual([links.checked, links.found], [50, 60]);
  });

  it('11 --outreach on a clean page: a no-findings tracking row', { timeout: 150_000 }, async () => {
    const out = tmp();
    const r = await run([siteUrl('/c11/'), '--outreach', '--out', out]);
    expectExit(r, 3);
    assert.equal(path.dirname(r.json.csv), out);
    const rows = csvRows(r.json.csv);
    assert.equal(rows.length, 2, 'header and one row');
    assert.deepEqual([rows[1][1], rows[1][2], rows[1][3]], [`127.0.0.1:${ports.site}`, 'report', 'no-findings']);
  });

  it('12 the CLI runs through a symlinked directory, and importing check.mjs does not run it', { timeout: 150_000 }, async () => {
    // install-local.sh links the whole skill directory; scripts/ is linked here too. A guard that compares
    // import.meta.url with process.argv[1] as typed would exit 0 and print nothing.
    const base = tmp();
    symlinkSync(SKILL, path.join(base, 'skill-link'), 'dir');
    symlinkSync(SCRIPTS, path.join(base, 'scripts-link'), 'dir');
    for (const script of [path.join(base, 'skill-link', 'scripts', 'check.mjs'), path.join(base, 'scripts-link', 'check.mjs')]) {
      const out = path.join(base, `out-${path.basename(path.dirname(script))}`);
      const r = await run([siteUrl('/c12/'), '--control', '--out', out], script);
      expectExit(r, 0);
      assert.equal(r.json?.status, 'control', `no JSON line through ${script}: stdout was ${JSON.stringify(r.stdout)}`);
      assert.deepEqual(csvRows(r.json.csv).at(-1).slice(2, 4), ['control', 'draft']);
    }
    // Importing from another script, with CLI-looking arguments, must not run the CLI.
    const importer = path.join(base, 'importer.mjs');
    writeFileSync(importer, `import ${JSON.stringify(pathToFileURL(CHECK).href)};\nconsole.log('imported');\n`);
    const out = path.join(base, 'out-import');
    const r = await run([siteUrl('/c12/'), '--control', '--out', out], importer);
    expectExit(r, 0);
    assert.equal(r.stdout.trim(), 'imported');
    assert.equal(existsSync(out), false, 'importing wrote nothing');
    assert.equal(hits('/c12/').length, 0);
  });

  it('13 same-site scope and de-duplication: other hosts are not requested, a link repeated or with fragments is requested once', { timeout: 150_000 }, async () => {
    const r = await run([siteUrl('/c13/'), '--out', tmp()]);
    expectExit(r, 3);
    assert.deepEqual(hits('/c13/', logs.third), [], 'neither the third-party link nor the redirect target was requested');
    for (const p of ['/c13/hop', '/c13/dup', '/c13/ok']) assert.equal(hits(p).length, 1, `${p} is requested once`);
    const { links } = readJson(r.json.json);
    assert.deepEqual([links.checked, links.found], [3, 3]);
  });
});

test('no non-GET request reached either server in any case', () => {
  assert.ok(logs.site.length > 50 && logs.third.length > 0, 'the end-to-end cases ran and logged requests');
  const writes = [...logs.site, ...logs.third].filter((r) => r.method !== 'GET');
  assert.deepEqual(writes, []);
});
