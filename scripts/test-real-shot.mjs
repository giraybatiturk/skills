// Local test for real-shot.mjs and for the two UI hooks, real-ui-track.sh and real-ui-stop.sh. Run from the repository root:
//
//   node scripts/test-real-shot.mjs
//
// It needs Playwright and Chromium installed in skills/engineering/real-check/scripts, as scripts/test-real-check.mjs does:
//   npm ci --prefix skills/engineering/real-check/scripts
//   npx --prefix skills/engineering/real-check/scripts playwright install chromium
// Without them the suite fails at the start with these commands. It never skips silently. It is not part of the skill,
// so scripts/build-zips.sh does not ship it.
//
// Isolation: one temporary folder (mkdtemp) with its own HOME and XDG_STATE_HOME, GIT_CONFIG_GLOBAL=/dev/null, and a fresh
// git repo for every case. Every child process gets a clean environment: no REAL_* variable and no NODE_PATH (a NODE_PATH
// can point at another Playwright, and the test must use the install above). The pages come from a node:http server on
// 127.0.0.1 that this file starts and closes. The browser is always headless, and the lock allows one browser at a time.
// The test stops only the one child that it started itself, and only in the SIGTERM case.
//
// Covered: the measures (overflow, wide elements, small targets, long text), baseline, after, auto mode, the comparison
// page, the changed share, the lock (wait, stale lock, wait limit, release on SIGTERM), the errors (no server, HTTP 404,
// usage, missing Playwright, missing browser), --selector, the ui.target-min sources, and both hooks with and without jq.
//
// NOT covered: the real-show.sh link (scripts/test-real-show.sh covers that script), a real dev server, a visible browser,
// Firefox and WebKit, macOS and BSD tools (the hooks run with the tools of this machine), and two waiters that take over
// the same stale lock in the same instant.

import assert from 'node:assert/strict';
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, utimesSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { decodePng } from '../skills/engineering/real-test/scripts/visual.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SCRIPTS = path.join(ROOT, 'skills/engineering/real-test/scripts');
const SHOT = path.join(SCRIPTS, 'real-shot.mjs');
const VISUAL = path.join(SCRIPTS, 'visual.mjs');
const TRACK = path.join(ROOT, 'hooks/claude/real-ui-track.sh');
const STOP = path.join(ROOT, 'hooks/claude/real-ui-stop.sh');
const INSTALL = path.join(ROOT, 'skills/engineering/real-check/scripts');
const INSTALL_HINT = `Playwright or Chromium is not installed, so real-shot cannot run. This is a failure, not a pass.
Install them: npm ci --prefix skills/engineering/real-check/scripts
              npx --prefix skills/engineering/real-check/scripts playwright install chromium`;
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const UI_URL = 'http://127.0.0.1:5173/';

// The browser cache of the real HOME. The test runs the children with another HOME, so it hands them this path.
const BROWSERS = (() => {
  if (process.env.PLAYWRIGHT_BROWSERS_PATH) return process.env.PLAYWRIGHT_BROWSERS_PATH;
  if (process.platform === 'darwin') return path.join(os.homedir(), 'Library', 'Caches', 'ms-playwright');
  return path.join(process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache'), 'ms-playwright');
})();

let tmp;
let home;
let state;
let server;
let base;
let projects = 0;
const routes = new Map(); // pathname -> { body, status, delayMs }
const seen = new Set(); // pathnames that the server received

const page = (body, head = '') =>
  `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>fixture</title><style>body{margin:0;font:16px sans-serif}${head}</style></head><body>${body}</body></html>`;

const firstLine = (text) => String(text).split('\n')[0];
const lockFolder = () => path.join(state, 'real', 'shot', 'lock');
const until = async (check, what, ms = 30000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (check()) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.fail(`timed out: ${what}`);
};

/** The environment of every child: no REAL_* variable, no NODE_PATH, an isolated HOME and state folder. */
function childEnv(extra = {}) {
  const env = {};
  for (const [key, value] of Object.entries(process.env)) if (!key.startsWith('REAL_') && key !== 'NODE_PATH') env[key] = value;
  return {
    ...env,
    HOME: home,
    XDG_STATE_HOME: state,
    GIT_CONFIG_GLOBAL: '/dev/null',
    GIT_CONFIG_NOSYSTEM: '1',
    PLAYWRIGHT_BROWSERS_PATH: BROWSERS,
    REAL_SHOT_SETTLE_MS: '200',
    ...extra, // a value of undefined removes the variable
  };
}

/** A fresh git repo: the project that real-shot and the hooks work in. */
function project(files = {}) {
  const dir = path.join(tmp, `project-${++projects}`);
  mkdirSync(dir);
  execFileSync('git', ['init', '-q'], { cwd: dir, env: childEnv() });
  for (const [name, text] of Object.entries(files)) writeFileSync(path.join(dir, name), text);
  return dir;
}

/** Runs a node script as a child (async: the fixture server lives in this process). Resolves { code, signal, stdout, stderr }. */
function run(args, { cwd, env = {}, script = SHOT, timeoutMs = 120000 } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [script, ...args], { cwd, env: childEnv(env) });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => (stdout += chunk));
    child.stderr.on('data', (chunk) => (stderr += chunk));
    const timer = setTimeout(() => child.kill('SIGKILL'), timeoutMs); // our own child only
    child.on('error', reject);
    child.on('close', (code, signal) => {
      clearTimeout(timer);
      resolve({ code, signal, stdout, stderr });
    });
  });
}

/** real-shot against a fixture route. Adds `json` (the parsed stdout line) when there is one. */
async function capture(cwd, route, tag, args = [], options = {}) {
  const result = await run(['--url', `${base}${route}`, '--tag', tag, ...args], { cwd, ...options });
  return { ...result, json: result.stdout.trim() ? JSON.parse(result.stdout) : null };
}

/** A capture that must have worked: exit 0, an empty stderr, exactly one JSON line on stdout. */
function worked(result) {
  assert.equal(result.code, 0, result.stderr);
  assert.equal(result.stdout.trim().split('\n').length, 1, 'one line on stdout');
  return result.json;
}

/** A capture that must have failed with this exit code: nothing on stdout, one real-shot line on stderr, the lock released. */
function failed(result, code, text) {
  assert.equal(result.code, code, `exit code (stderr: ${result.stderr})`);
  assert.equal(result.stdout, '', 'nothing on stdout');
  assert.match(result.stderr, /^real-shot: /);
  assert.ok(result.stderr.includes(text), `stderr has "${text}": ${result.stderr}`);
  if (code !== 5) assert.equal(existsSync(lockFolder()), false, 'the lock is released');
}

const shotsDir = (cwd, tag) => path.join(cwd, '.real', 'shots', tag);
const isPng = (file) => readFileSync(file).subarray(0, 8).equals(PNG_SIGNATURE);
const widthOf = (json, width) => json.widths.find((entry) => entry.width === width);

/** Runs a hook script with the JSON input on stdin. */
function hook(script, input, env = {}) {
  return spawnSync(script, { input: JSON.stringify(input), env: childEnv(env), encoding: 'utf8', timeout: 30000 });
}

describe('real-shot', () => {
  before(async () => {
    tmp = realpathSync(mkdtempSync(path.join(os.tmpdir(), 'real-shot-test-')));
    home = path.join(tmp, 'home');
    state = path.join(tmp, 'state');
    mkdirSync(home);
    mkdirSync(state);
    if (!existsSync(path.join(INSTALL, 'node_modules', 'playwright', 'package.json'))) throw new Error(INSTALL_HINT);
    const probe = spawnSync(process.execPath, ['-e', "require('playwright').chromium.launch({ headless: true }).then((browser) => browser.close())"], { cwd: INSTALL, env: childEnv(), encoding: 'utf8', timeout: 60000 });
    if (probe.status !== 0) throw new Error(`${INSTALL_HINT}\n${firstLine(probe.stderr)}`);

    server = http.createServer((request, response) => {
      const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
      seen.add(pathname);
      const route = routes.get(pathname);
      if (!route) {
        response.writeHead(404, { 'content-type': 'text/plain' });
        response.end('not found');
        return;
      }
      const send = () => {
        response.writeHead(route.status ?? 200, { 'content-type': 'text/html; charset=utf-8' });
        response.end(route.body);
      };
      if (!route.delayMs) return send();
      const timer = setTimeout(send, route.delayMs);
      request.on('close', () => clearTimeout(timer));
    });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    base = `http://127.0.0.1:${server.address().port}`;

    routes.set('/overflow', { body: page('<div id="fixed" style="width:600px;height:80px;background:#9cf">fixed 600 px</div>') });
    routes.set('/targets', { body: page('<button id="small" style="box-sizing:border-box;width:20px;height:20px;padding:0"></button><button id="big" style="box-sizing:border-box;width:48px;height:48px;padding:0"></button>') });
    routes.set('/late', {
      body: page('<div id="mount"></div><script>setTimeout(() => { document.getElementById("mount").innerHTML = \'<div id="long" style="white-space:nowrap;width:200px">A long sentence that does not fit into a box of two hundred pixels.</div>\'; }, 1000);</script>'),
    });
    routes.set('/stable', {
      body: page('<h1 style="margin:16px">Stable page</h1><p style="margin:16px">Some text that does not change.</p><div style="height:120px;margin:16px;background:#2a7;color:#fff">block</div>'),
    });
    routes.set('/selector', {
      body: page('<h1 style="margin:16px">Selector page</h1><div id="box" style="width:200px;height:100px;margin:16px;background:#c33"></div><button style="box-sizing:border-box;width:20px;height:20px;padding:0"></button>'),
    });
    routes.set('/slow', { body: page('slow'), delayMs: 60000 });
  });

  after(async () => {
    if (server) {
      server.closeAllConnections();
      await new Promise((resolve) => server.close(resolve));
    }
    if (tmp) rmSync(tmp, { recursive: true, force: true });
  });

  // -------------------------------------------------------------------------------------------------------------------
  // Measures
  // -------------------------------------------------------------------------------------------------------------------

  it('1. overflow: a 600 px block overflows at 375 and not at 1280', async () => {
    const json = worked(await capture(project(), '/overflow', 'overflow'));
    const phone = widthOf(json, 375).measures;
    assert.equal(phone.overflow.value, true);
    assert.ok(phone.overflow.scrollWidth >= 600, `scrollWidth ${phone.overflow.scrollWidth}`);
    assert.equal(phone.overflow.innerWidth, 375);
    assert.ok(phone.wide.count >= 1);
    assert.equal(phone.wide.items[0].el, 'div#fixed');
    assert.equal(phone.wide.items[0].width, 600);
    assert.equal(widthOf(json, 1280).measures.overflow.value, false);
    assert.match(json.lines[0], /^375: overflow \d+ > 375, targets <40px: 0, wide: 1, long text: ok$/);
    assert.match(json.lines[1], /^1280: overflow none, targets <40px: 0, wide: 0, long text: ok$/);
  });

  it('2. small target: the 20 px button counts, the 48 px button does not, and ui.target-min changes it', async () => {
    const cwd = project();
    const json = worked(await capture(cwd, '/targets', 'targets'));
    for (const width of [375, 1280]) {
      const { targets } = widthOf(json, width).measures;
      assert.equal(targets.count, 1, `width ${width}`);
      assert.equal(targets.min, 40);
      assert.deepEqual(targets.items, [{ el: 'button#small', width: 20, height: 20 }]);
    }
    const lenient = worked(await capture(cwd, '/targets', 'targets-lenient', [], { env: { REAL_UI_TARGET_MIN: '10' } }));
    assert.equal(lenient.targetMin, 10);
    for (const width of [375, 1280]) {
      assert.equal(widthOf(lenient, width).measures.targets.count, 0, `width ${width}`);
      assert.equal(widthOf(lenient, width).measures.targets.min, 10);
    }
  });

  it('3. long text: a nowrap box of 200 px is found; the default settle time waits for late content', async () => {
    // This is the one case that leaves REAL_SHOT_SETTLE_MS at its default (2500 ms). The box appears after 1000 ms.
    const json = worked(await capture(project(), '/late', 'longtext', [], { env: { REAL_SHOT_SETTLE_MS: undefined } }));
    for (const width of [375, 1280]) {
      const { longText } = widthOf(json, width).measures;
      assert.ok(longText.count >= 1, `width ${width}`);
      assert.equal(longText.items[0].el, 'div#long');
      assert.equal(longText.items[0].clientWidth, 200);
      assert.ok(longText.items[0].scrollWidth > 200);
    }
    assert.match(json.lines[0], /long text: [1-9]/);
  });

  it('extra: ui.target-min is read from .real-hooks and from git config; the environment wins', async () => {
    const fromFile = project({ '.real-hooks': 'ui.url = http://127.0.0.1:5173/\nui.target-min = 10\n' });
    assert.equal(worked(await capture(fromFile, '/targets', 'cfg', ['--widths', '1280'])).targetMin, 10);
    const fromGit = project();
    execFileSync('git', ['config', 'real.hooks.ui.target-min', '60'], { cwd: fromGit, env: childEnv() });
    const viaGit = worked(await capture(fromGit, '/targets', 'cfg', ['--widths', '1280']));
    assert.equal(viaGit.targetMin, 60);
    assert.equal(viaGit.widths[0].measures.targets.count, 2);
    assert.equal(worked(await capture(fromFile, '/targets', 'cfg-env', ['--widths', '1280'], { env: { REAL_UI_TARGET_MIN: '30' } })).targetMin, 30);
  });

  it('extra: --selector shoots the first match only, and the measures stay page wide', async () => {
    const cwd = project();
    const json = worked(await capture(cwd, '/selector', 'sel', ['--selector', '#box', '--widths', '1280']));
    const png = decodePng(readFileSync(widthOf(json, 1280).before));
    assert.deepEqual([png.width, png.height], [200, 100]);
    assert.equal(widthOf(json, 1280).measures.targets.count, 1, 'the button outside #box is still measured');
  });

  it('extra: --selector without a match exits 3', async () => {
    failed(await capture(project(), '/selector', 'nosel', ['--selector', '#absent', '--widths', '375']), 3, 'real-shot: no element matches the selector');
  });

  // -------------------------------------------------------------------------------------------------------------------
  // Baseline, after, comparison
  // -------------------------------------------------------------------------------------------------------------------

  it('4. baseline then after with no change: files, comparison page, changed share 0, stamp file', async () => {
    const cwd = project();
    const dir = shotsDir(cwd, 'same');
    const stamp = path.join(cwd, '.real', 'ui-shot');
    const query = '?note=<b>x</b>';

    const baseline = worked(await capture(cwd, `/stable${query}`, 'same', ['--baseline']));
    assert.equal(baseline.mode, 'baseline');
    assert.equal(baseline.dir, dir);
    assert.equal(baseline.compare, null);
    assert.equal(baseline.show, null);
    assert.equal(typeof baseline.lockWaitMs, 'number');
    for (const width of [375, 1280]) {
      const entry = widthOf(baseline, width);
      assert.equal(entry.before, path.join(dir, `before-${width}.png`));
      assert.equal(entry.after, null);
      assert.equal(entry.changedPercent, null);
      assert.ok(isPng(entry.before), `PNG signature at ${width}`);
      assert.equal(decodePng(readFileSync(entry.before)).width, width);
    }
    assert.ok(existsSync(path.join(dir, 'before.json')));
    assert.equal(existsSync(stamp), false, 'no stamp after a baseline');

    const startedAt = Math.floor(Date.now() / 1000);
    const result = worked(await capture(cwd, `/stable${query}`, 'same', ['--after']));
    assert.equal(result.mode, 'after');
    assert.equal(result.targetMin, 40);
    for (const width of [375, 1280]) {
      const entry = widthOf(result, width);
      assert.equal(entry.before, path.join(dir, `before-${width}.png`));
      assert.equal(entry.after, path.join(dir, `after-${width}.png`));
      assert.ok(isPng(entry.before) && isPng(entry.after));
      assert.equal(entry.changedPercent, 0, `changed share at ${width}`);
      assert.equal(entry.note, undefined);
    }
    assert.ok(existsSync(path.join(dir, 'after.json')));
    assert.match(result.lines[0], /^375: overflow none, targets <40px: 0, wide: 0, long text: ok, changed 0%$/);
    assert.match(result.lines[1], /^1280: overflow none, targets <40px: 0, wide: 0, long text: ok, changed 0%$/);
    assert.equal(result.compare, path.join(dir, 'compare.html'));
    assert.ok(result.show.startsWith("sh '") && result.show.endsWith(` '${result.compare}'`) && result.show.includes('real-show.sh'), result.show);
    assert.ok(existsSync(result.show.split("'")[1]), 'the real-show.sh of the repo exists');

    const html = readFileSync(result.compare, 'utf8');
    assert.ok(html.includes('<title>real-shot same</title>'));
    assert.ok(html.includes('background:#fff'));
    assert.ok(html.includes('color-scheme:light only'));
    assert.ok(html.includes('max-width:100%'));
    assert.equal(html.split('data:image/png;base64,').length - 1, 4, 'two images for each width');
    assert.doesNotMatch(html, /<script/i);
    assert.doesNotMatch(html, /(?:src|href)=["'](?!data:)/, 'no external file');
    assert.ok(html.includes('Targets under 40 px: 0'));
    assert.ok(html.includes(`${base}/stable`), 'origin and path');
    assert.ok(!html.includes('note='), 'the query is not shown');
    assert.match(html, /^[\x00-\x7f]*$/, 'ASCII only');

    const stampText = readFileSync(stamp, 'utf8');
    assert.match(stampText, /^\d{10}\n$/);
    assert.ok(Number(stampText) >= startedAt && Number(stampText) <= Math.floor(Date.now() / 1000), 'the stamp is the start of the capture');

    // A new baseline deletes the files of the earlier task.
    worked(await capture(cwd, '/stable', 'same', ['--baseline']));
    for (const name of ['after-375.png', 'after-1280.png', 'after.json', 'compare.html']) assert.equal(existsSync(path.join(dir, name)), false, name);
    assert.ok(isPng(path.join(dir, 'before-375.png')));
  });

  it('5. after a change: the changed share is above 0', async () => {
    const cwd = project();
    routes.set('/change', { body: page('<div style="height:300px;background:#c00"></div>') });
    worked(await capture(cwd, '/change', 'changed', ['--baseline']));
    routes.set('/change', { body: page('<div style="height:300px;background:#c00"></div><div style="height:200px;background:#00c"></div>') });
    const json = worked(await capture(cwd, '/change', 'changed', ['--after']));
    for (const [at, width] of [[0, 375], [1, 1280]]) {
      const entry = widthOf(json, width);
      assert.ok(entry.changedPercent > 0 && entry.changedPercent <= 100, `changed share at ${width}: ${entry.changedPercent}`);
      assert.ok(json.lines[at].endsWith(`, changed ${entry.changedPercent}%`), json.lines[at]);
    }
    assert.match(readFileSync(json.compare, 'utf8'), /Changed pixels: [0-9.]+ %/);
  });

  it('6. auto mode: the first run on a new tag is a baseline, the second is an after run', async () => {
    const cwd = project();
    assert.equal(worked(await capture(cwd, '/stable', 'auto')).mode, 'baseline');
    assert.equal(worked(await capture(cwd, '/stable', 'auto')).mode, 'after');
  });

  it('extra: an after run without a baseline gives null and a note, and the page says no baseline', async () => {
    const cwd = project();
    const json = worked(await capture(cwd, '/stable', 'nobase', ['--after', '--widths', '375']));
    assert.equal(json.widths[0].before, null);
    assert.equal(json.widths[0].changedPercent, null);
    assert.ok(json.widths[0].note);
    assert.ok(json.lines[0].endsWith(', changed n/a'));
    assert.ok(readFileSync(json.compare, 'utf8').includes('no baseline'));
  });

  // -------------------------------------------------------------------------------------------------------------------
  // Lock
  // -------------------------------------------------------------------------------------------------------------------

  it('7. lock: two captures at the same time both work, and one waits for the other', async () => {
    const [a, b] = await Promise.all([capture(project(), '/stable', 'lock-a', ['--baseline']), capture(project(), '/stable', 'lock-b', ['--baseline'])]);
    const waits = [worked(a).lockWaitMs, worked(b).lockWaitMs];
    assert.ok(Math.max(...waits) >= 200, `waits: ${waits}`);
    assert.ok(Math.min(...waits) < 250, `waits: ${waits}`);
    assert.equal(existsSync(lockFolder()), false);
  });

  it('8. stale lock: a lock of a dead process, and a lock older than 10 minutes, are taken over', async () => {
    const dead = spawnSync(process.execPath, ['-e', '']).pid; // a process that this test started and that has ended
    mkdirSync(lockFolder(), { recursive: true });
    writeFileSync(path.join(lockFolder(), 'pid'), `${dead}\n`);
    const first = worked(await capture(project(), '/stable', 'stale-dead', ['--baseline', '--widths', '375']));
    assert.ok(first.lockWaitMs < 250, `no wait for a dead holder: ${first.lockWaitMs}`);
    assert.equal(existsSync(lockFolder()), false);

    mkdirSync(lockFolder(), { recursive: true });
    writeFileSync(path.join(lockFolder(), 'pid'), `${process.pid}\n`); // this process is alive, so only the age counts
    const old = new Date(Date.now() - 11 * 60 * 1000);
    utimesSync(lockFolder(), old, old);
    const second = worked(await capture(project(), '/stable', 'stale-old', ['--baseline', '--widths', '375']));
    assert.ok(second.lockWaitMs < 250, `no wait for an old lock: ${second.lockWaitMs}`);
    assert.equal(existsSync(lockFolder()), false);
  });

  it('extra: the wait limit gives exit 5 and leaves the lock of the other capture alone', async () => {
    mkdirSync(lockFolder(), { recursive: true });
    writeFileSync(path.join(lockFolder(), 'pid'), `${process.pid}\n`); // alive, and not ours to remove
    try {
      const result = await capture(project(), '/stable', 'busy', ['--baseline'], { env: { REAL_SHOT_LOCK_WAIT: '1' } });
      failed(result, 5, `another capture runs (pid ${process.pid}). Waited 1 s.`);
      assert.equal(readFileSync(path.join(lockFolder(), 'pid'), 'utf8').trim(), String(process.pid), 'the lock is untouched');
    } finally {
      rmSync(lockFolder(), { recursive: true, force: true });
    }
  });

  it('extra: SIGTERM releases the lock and exits 143', async () => {
    const cwd = project();
    const child = spawn(process.execPath, [SHOT, '--url', `${base}/slow`, '--tag', 'term', '--baseline'], { cwd, env: childEnv() });
    let stdout = '';
    child.stdout.on('data', (chunk) => (stdout += chunk));
    const closed = new Promise((resolve) => child.on('close', (code) => resolve(code)));
    try {
      await until(() => seen.has('/slow'), 'the browser asks for the slow page');
      assert.equal(readFileSync(path.join(lockFolder(), 'pid'), 'utf8').trim(), String(child.pid), 'the child holds the lock');
    } finally {
      child.kill('SIGTERM'); // the child that this test started
    }
    assert.equal(await closed, 143);
    assert.equal(stdout, '');
    assert.equal(existsSync(lockFolder()), false);
  });

  // -------------------------------------------------------------------------------------------------------------------
  // Errors
  // -------------------------------------------------------------------------------------------------------------------

  it('9. no dev server: a closed port gives exit 3 and releases the lock', async () => {
    const probe = http.createServer();
    await new Promise((resolve) => probe.listen(0, '127.0.0.1', resolve));
    const { port } = probe.address();
    await new Promise((resolve) => probe.close(resolve));
    const result = await run(['--url', `http://127.0.0.1:${port}/`, '--tag', 'closed'], { cwd: project() });
    failed(result, 3, `no server answers at http://127.0.0.1:${port}.`);
  });

  it('10. HTTP 404 gives exit 3 with the status', async () => {
    failed(await capture(project(), '/does-not-exist', 'missing'), 3, `${base}/does-not-exist answered HTTP 404.`);
  });

  it('11. usage errors give exit 2, one real-shot line and the usage line', async () => {
    const url = `${base}/stable`;
    const cases = [
      ['a bad tag', ['--url', url, '--tag', '../x']],
      ['a tag with two dots', ['--url', url, '--tag', 'a..b']],
      ['an upper case tag', ['--url', url, '--tag', 'Tag']],
      ['both modes', ['--url', url, '--tag', 'x', '--baseline', '--after']],
      ['a file URL', ['--url', 'file:///x', '--tag', 'x']],
      ['a URL with a password', ['--url', 'http://user:secret@127.0.0.1/', '--tag', 'x']],
      ['a width below 200', ['--url', url, '--tag', 'x', '--widths', '10']],
      ['a width above 3840', ['--url', url, '--tag', 'x', '--widths', '3841']],
      ['a width that is not a number', ['--url', url, '--tag', 'x', '--widths', '375,wide']],
      ['no URL', ['--tag', 'x']],
      ['no tag', ['--url', url]],
      ['an unknown argument', ['--url', url, '--tag', 'x', '--nope']],
      ['a missing value', ['--url', url, '--tag']],
      ['a repeated option', ['--url', url, '--url', url, '--tag', 'x']],
    ];
    const cwd = project();
    for (const [name, args] of cases) {
      const result = await run(args, { cwd });
      assert.equal(result.code, 2, `${name}: ${result.stderr}`);
      assert.equal(result.stdout, '', name);
      assert.match(result.stderr, /^real-shot: .+\nUsage: node real-shot\.mjs --url URL --tag TAG/, name);
    }
    for (const value of ['0', '201', 'many']) {
      const result = await run(['--url', url, '--tag', 'x'], { cwd, env: { REAL_UI_TARGET_MIN: value } });
      assert.equal(result.code, 2, `ui.target-min ${value}`);
      assert.ok(result.stderr.includes('ui.target-min'), result.stderr);
    }
    assert.equal(existsSync(lockFolder()), false);
  });

  it('12. Playwright missing: exit 4 with the install hint', async () => {
    const lone = path.join(tmp, 'lone', 'skill', 'scripts');
    mkdirSync(lone, { recursive: true });
    copyFileSync(SHOT, path.join(lone, 'real-shot.mjs'));
    copyFileSync(VISUAL, path.join(lone, 'visual.mjs'));
    const cwd = path.join(tmp, 'lone', 'work');
    mkdirSync(cwd);
    const result = await run(['--url', `${base}/stable`, '--tag', 'none'], { cwd, script: path.join(lone, 'real-shot.mjs') });
    failed(result, 4, 'Playwright is not installed. In the project: npm install -D @playwright/test, then npx playwright install chromium.');
  });

  it('extra: a missing browser gives exit 4 with the install command and releases the lock', async () => {
    const empty = path.join(tmp, 'no-browsers');
    mkdirSync(empty);
    const result = await capture(project(), '/stable', 'nobrowser', ['--baseline'], { env: { PLAYWRIGHT_BROWSERS_PATH: empty } });
    failed(result, 4, 'real-shot: the browser could not start:');
    assert.ok(result.stderr.includes('Run: npx playwright install chromium'), result.stderr);
  });

  // -------------------------------------------------------------------------------------------------------------------
  // Hooks
  // -------------------------------------------------------------------------------------------------------------------

  for (const noJq of [false, true]) {
    const mode = noJq ? 'without jq' : 'with jq';
    const env = noJq ? { REAL_NO_JQ: '1' } : {};
    const hooksFile = `ui.url = ${UI_URL}\n`;

    describe(`13. real-ui-track ${mode}`, () => {
      /** Runs the hook. Exit 0 and no output every time. Returns the content of .real/ui-dirty, or null. */
      const track = (cwd, input, extraEnv = {}) => {
        rmSync(path.join(cwd, '.real'), { recursive: true, force: true });
        const result = hook(TRACK, { cwd, ...input }, { ...env, ...extraEnv });
        assert.equal(result.status, 0);
        assert.equal(result.stdout, '');
        assert.equal(result.stderr, '');
        const file = path.join(cwd, '.real', 'ui-dirty');
        return existsSync(file) ? readFileSync(file, 'utf8') : null;
      };
      const tool = (cwd, name, file) => ({ tool_name: name, tool_input: { file_path: file } });
      const patch = (...lines) => ({ tool_name: 'apply_patch', tool_input: { command: ['*** Begin Patch', ...lines, '*** End Patch'].join('\n') } });

      it('an edit of a UI file writes the time to .real/ui-dirty', () => {
        const cwd = project({ '.real-hooks': hooksFile });
        const before = Math.floor(Date.now() / 1000);
        const written = track(cwd, tool(cwd, 'Edit', path.join(cwd, 'src', 'a.tsx')));
        assert.match(written, /^\d{10}\n$/);
        assert.ok(Number(written) >= before && Number(written) <= Math.floor(Date.now() / 1000) + 1);
        for (const name of ['Write', 'MultiEdit']) assert.ok(track(cwd, tool(cwd, name, path.join(cwd, 'src', 'b.css'))), name);
        assert.ok(track(cwd, tool(cwd, 'Edit', 'src/c.vue')), 'a relative path is matched as given');
        assert.ok(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'index.html'))), '* also matches a path without a folder');
      });

      it('an edit of another file does nothing', () => {
        const cwd = project({ '.real-hooks': hooksFile });
        assert.equal(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'notes.md'))), null);
        assert.equal(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'src', 'a.ts'))), null);
      });

      it('an absolute path outside the repo does nothing', () => {
        const cwd = project({ '.real-hooks': hooksFile });
        assert.equal(track(cwd, tool(cwd, 'Edit', path.join(tmp, 'elsewhere', 'a.tsx'))), null);
        assert.equal(track(cwd, tool(cwd, 'Edit', `${cwd}-sibling/a.tsx`)), null, 'a folder whose name starts like the repo');
      });

      it('Codex apply_patch: Update, Add, Delete and Move to lines count; a patch of other files does not', () => {
        const cwd = project({ '.real-hooks': hooksFile });
        assert.ok(track(cwd, patch('*** Update File: src/x.css', '@@', '-a', '+b')));
        assert.ok(track(cwd, patch('*** Add File: src/new.jsx', '+x')));
        assert.ok(track(cwd, patch('*** Delete File: src/old.scss')));
        assert.ok(track(cwd, patch('*** Update File: src/a.ts', '@@', '-a', '+b', '*** Move to: src/a.svelte')));
        assert.ok(track(cwd, patch('*** Update File: notes.md', '@@', '-a', '+b', '*** Update File: ' + path.join(cwd, 'web', 'x.html'), '@@', '-a', '+b')), 'one UI file in a patch of two');
        assert.equal(track(cwd, patch('*** Update File: notes.md', '@@', '-a', '+b')), null);
        assert.equal(track(cwd, patch('*** Update File: src/a.ts', '@@', '-x.css', '+y.css')), null, 'only the file lines count');
      });

      it('ui.globs replaces the default list, and blanks around the items are trimmed', () => {
        const cwd = project({ '.real-hooks': `${hooksFile}ui.globs = *.md , docs/*.txt\n` });
        assert.ok(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'notes.md'))));
        assert.ok(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'docs', 'a.txt'))));
        assert.equal(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'src', 'a.tsx'))), null);
        assert.ok(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'src', 'a.tsx')), { REAL_UI_GLOBS: '*.tsx' }), 'the environment wins');
      });

      it('without ui.url, or with REAL_UI_LOOP=0, nothing is written', () => {
        const none = project();
        assert.equal(track(none, tool(none, 'Edit', path.join(none, 'src', 'a.tsx'))), null);
        const cwd = project({ '.real-hooks': hooksFile });
        assert.equal(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'src', 'a.tsx')), { REAL_UI_LOOP: '0' }), null);
        assert.ok(track(cwd, tool(cwd, 'Edit', path.join(cwd, 'src', 'a.tsx')), { REAL_UI_URL: UI_URL }), 'ui.url from the environment');
      });
    });

    describe(`14. real-ui-stop ${mode}`, () => {
      const stamp = (cwd, name, value) => {
        mkdirSync(path.join(cwd, '.real'), { recursive: true });
        writeFileSync(path.join(cwd, '.real', name), `${value}\n`);
      };
      /** Runs the hook. Exit 0 every time. Returns stdout. */
      const stop = (cwd, extra = {}, extraEnv = {}) => {
        const result = hook(STOP, { cwd, stop_hook_active: false, ...extra }, { ...env, ...extraEnv });
        assert.equal(result.status, 0, result.stderr);
        return result.stdout;
      };

      it('blocks when dirty is newer than shot, and names real-shot', () => {
        const cwd = project({ '.real-hooks': `ui.url = ${UI_URL}\n` });
        stamp(cwd, 'ui-shot', 100);
        stamp(cwd, 'ui-dirty', 200);
        const out = stop(cwd);
        const answer = JSON.parse(out);
        assert.equal(answer.decision, 'block');
        assert.ok(out.includes('"decision":"block"'));
        assert.ok(answer.reason.startsWith('UI files changed after the last real-shot capture.'), answer.reason);
        assert.ok(answer.reason.includes(`--url ${UI_URL} --tag <tag> --after`), answer.reason);
        assert.ok(answer.reason.endsWith('Then give the comparison link and the numbers.'));
        const script = /node (\S+real-shot\.mjs) /.exec(answer.reason)[1];
        assert.equal(script, realpathSync(SHOT));
        assert.ok(existsSync(script));
        assert.equal(readFileSync(path.join(cwd, '.real', 'ui-nagged'), 'utf8').trim(), '200');
      });

      it('blocks once for one edit time stamp, and again for a new one', () => {
        const cwd = project({ '.real-hooks': `ui.url = ${UI_URL}\n` });
        stamp(cwd, 'ui-dirty', 200);
        assert.ok(stop(cwd).includes('"decision":"block"'), 'no shot yet: block');
        assert.equal(stop(cwd), '', 'the same stamp again');
        assert.equal(stop(cwd), '', 'and again');
        stamp(cwd, 'ui-dirty', 300);
        assert.ok(stop(cwd).includes('"decision":"block"'), 'a new stamp blocks again');
        assert.equal(stop(cwd), '');
      });

      it('stays silent when stop_hook_active is true', () => {
        const cwd = project({ '.real-hooks': `ui.url = ${UI_URL}\n` });
        stamp(cwd, 'ui-dirty', 200);
        assert.equal(stop(cwd, { stop_hook_active: true }), '');
        assert.equal(existsSync(path.join(cwd, '.real', 'ui-nagged')), false, 'it did not use up the stamp');
        assert.ok(stop(cwd).includes('"decision":"block"'));
      });

      it('stays silent when shot is as new as dirty or newer', () => {
        const cwd = project({ '.real-hooks': `ui.url = ${UI_URL}\n` });
        stamp(cwd, 'ui-dirty', 200);
        stamp(cwd, 'ui-shot', 200);
        assert.equal(stop(cwd), '');
        stamp(cwd, 'ui-shot', 250);
        assert.equal(stop(cwd), '');
      });

      it('stays silent without ui.url, with REAL_UI_LOOP=0, and without a usable dirty file', () => {
        const none = project();
        stamp(none, 'ui-dirty', 200);
        assert.equal(stop(none), '');
        const cwd = project({ '.real-hooks': `ui.url = ${UI_URL}\n` });
        assert.equal(stop(cwd), '', 'no dirty file');
        stamp(cwd, 'ui-dirty', 'soon');
        assert.equal(stop(cwd), '', 'dirty is not a number');
        stamp(cwd, 'ui-dirty', 200);
        assert.equal(stop(cwd, {}, { REAL_UI_LOOP: '0' }), '');
        assert.ok(stop(cwd).includes('"decision":"block"'), 'the same repo blocks when the loop is on');
      });
    });
  }

  it('15. hook and capture: after a real --after run, an older dirty stamp does not block', async () => {
    const cwd = project({ '.real-hooks': `ui.url = ${UI_URL}\n` });
    worked(await capture(cwd, '/stable', 'loop', ['--baseline', '--widths', '375']));
    worked(await capture(cwd, '/stable', 'loop', ['--after', '--widths', '375']));
    const shot = Number(readFileSync(path.join(cwd, '.real', 'ui-shot'), 'utf8'));
    assert.ok(shot > 1e9);
    const stop = () => {
      const result = hook(STOP, { cwd, stop_hook_active: false });
      assert.equal(result.status, 0, result.stderr);
      return result.stdout;
    };
    writeFileSync(path.join(cwd, '.real', 'ui-dirty'), `${shot - 5}\n`);
    assert.equal(stop(), '', 'the edit came before the capture');
    writeFileSync(path.join(cwd, '.real', 'ui-dirty'), `${shot + 5}\n`);
    assert.ok(stop().includes('"decision":"block"'), 'an edit after the capture blocks');
  });
});
