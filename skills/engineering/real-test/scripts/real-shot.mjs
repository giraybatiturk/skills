#!/usr/bin/env node
// real-shot: one before and after loop for a UI change. It opens a page in headless Chromium at a phone and a desktop
// width, takes a screenshot, measures a few layout facts, and after the change writes one self-contained comparison page.
// Node standard library plus Playwright, which it loads at run time. No model, no network except the URL that you give.
//
//   node real-shot.mjs --url URL --tag TAG [--selector SEL] [--widths 375,1280] [--baseline|--after] [--out DIR]
//
//   --url       The page. Only http: or https:. A URL with a user name or a password is refused.
//   --tag       The name of the task, for the folder: ^[a-z0-9][a-z0-9._-]{0,63}$, without "..".
//   --widths    Whole pixels from 200 to 3840, separated by commas. Default 375,1280. A width below 768 gets a phone profile.
//   --baseline  Take the "before" shots. --after takes the "after" shots and compares them. Not both.
//               With neither flag: baseline when <dir>/before-<first width>.png is missing, else after.
//   --selector  Screenshot of the first matching element only (waits up to 10 s). The measures stay page wide.
//   --out       The shots root. Default <root>/.real/shots. <root> is the top folder of the git repo of the current folder,
//               else the current folder. The files go to <out>/<tag>/.
//
// Outputs, in <out>/<tag>/:
//   before-<w>.png, before.json   baseline mode. The measures, the URL and the time. Once the capture worked, it deletes the
//                                 files of the earlier task: before-*.png, after-*.png, after.json and compare.html.
//   after-<w>.png, after.json     after mode, then compare.html (before and after side by side, the measures, the changed share).
//                                 After a successful after run it also writes <root>/.real/ui-shot: one line with the epoch
//                                 seconds of the start of the capture. The Stop hook real-ui-stop.sh reads it.
// stdout: one JSON line {mode, tag, url, dir, targetMin, lockWaitMs, widths, compare, show, lines}. All paths are absolute.
//   `lines` has one short line for each width. `show` is the real-show.sh command that gives a link to compare.html, or null.
//
// Measures, for each width. A list holds at most 10 items. A count is complete. An item names an element as tag#id.class.class.
//   overflow  the page is wider than the window: scrollWidth > innerWidth, where innerWidth is the width that real-shot set
//             (window.innerWidth grows to the page width in the phone profile, so it would hide the overflow)
//   wide      visible elements wider than their parent, when the parent does not scroll or clip
//   targets   links, buttons and other controls with a box under the target size, in px (ui.target-min, default 40)
//   longText  elements with text that runs out of their own box and do not scroll
// They are checks, not proof. A page with a clock, an advert or a carousel changes pixels without a real change.
//
// Settings. ui.target-min (whole number from 1 to 200, default 40): the environment variable REAL_UI_TARGET_MIN, then the line
// "ui.target-min = N" in <root>/.real-hooks, then git config real.hooks.ui.target-min. REAL_SHOT_SETTLE_MS: the wait after the
// load, default 2500. REAL_SHOT_LOCK_WAIT: seconds to wait for another capture, default 120.
//
// One capture runs at a time on the machine. The lock is the folder ${XDG_STATE_HOME:-$HOME/.local/state}/real/shot/lock.
// It is taken before the browser starts and released at the end, also after an error, SIGINT or SIGTERM.
//
// Playwright: the module `playwright` or `@playwright/test`, found from the project, the current folder, this folder, and the
// install of real-check next to this skill (skills/engineering/real-check/scripts). Install it in the project with
// `npm install -D @playwright/test`, then `npx playwright install chromium`.
// On macOS the caller runs it with `taskpolicy -c background`; on Linux with `nice`.
//
// Exit codes: 0 written. 1 any other error (for example a folder that cannot be written). 2 usage or config.
// 3 the page (no server, HTTP 400 or more, timeout, no match for the selector). 4 Playwright or the browser. 5 lock wait over.
// On an error nothing goes to stdout. One line "real-shot: ..." goes to stderr, the browser is closed and the lock is released.

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { decodePng } from './visual.mjs';

const USAGE = 'Usage: node real-shot.mjs --url URL --tag TAG [--selector SEL] [--widths 375,1280] [--baseline|--after] [--out DIR]';
const TOLERANCE = 8; // per channel, out of 255: the same value as TOLERANCE in visual.mjs
const DEFAULT_WIDTHS = '375,1280';
const TARGET_MIN_DEFAULT = 40;
const LOCK_POLL_MS = 250;
const LOCK_STALE_MS = 10 * 60 * 1000;
const PAGE_TIMEOUT_MS = 30000;
const SELECTOR_TIMEOUT_MS = 10000;
const INSTALL_HINT = 'Playwright is not installed. In the project: npm install -D @playwright/test, then npx playwright install chromium.';

/** An error that ends the run with an exit code and one line on stderr. */
class Fail extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const firstLine = (text) => String(text).split('\n')[0].trim();
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const quote = (text) => `'${text.replace(/'/g, `'\\''`)}'`;
const esc = (text) => String(text ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

// ---------------------------------------------------------------------------------------------------------------------
// Arguments and settings
// ---------------------------------------------------------------------------------------------------------------------

function parseArgs(argv) {
  const values = new Map([['--url', 'url'], ['--tag', 'tag'], ['--selector', 'selector'], ['--widths', 'widths'], ['--out', 'out']]);
  const flags = new Map([['--baseline', 'baseline'], ['--after', 'after']]);
  const opts = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const key = values.get(arg) ?? flags.get(arg);
    if (!key) throw new Fail(2, `unknown argument: ${arg.slice(0, 60)}`);
    if (key in opts) throw new Fail(2, `${arg} is given twice`);
    if (flags.has(arg)) {
      opts[key] = true;
      continue;
    }
    const value = argv[++i];
    if (!value || value.startsWith('--')) throw new Fail(2, `${arg} needs a value`);
    opts[key] = value;
  }
  if (!opts.url) throw new Fail(2, '--url is required');
  if (!opts.tag) throw new Fail(2, '--tag is required');
  if (opts.baseline && opts.after) throw new Fail(2, '--baseline and --after exclude each other');

  let url;
  try {
    url = new URL(opts.url);
  } catch {
    throw new Fail(2, '--url is not a valid URL');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') throw new Fail(2, '--url must start with http: or https:');
  if (url.username || url.password) throw new Fail(2, '--url must not hold a user name or a password');
  if (!/^[a-z0-9][a-z0-9._-]{0,63}$/.test(opts.tag) || opts.tag.includes('..')) {
    throw new Fail(2, '--tag must match ^[a-z0-9][a-z0-9._-]{0,63}$ and must not contain ".."');
  }
  const widths = [];
  for (const item of (opts.widths ?? DEFAULT_WIDTHS).split(',')) {
    const width = /^\d{1,4}$/.test(item) ? Number(item) : NaN;
    if (!(width >= 200 && width <= 3840)) throw new Fail(2, '--widths must be whole numbers from 200 to 3840, separated by commas');
    if (!widths.includes(width)) widths.push(width);
  }
  return { url, tag: opts.tag, selector: opts.selector, widths, baseline: Boolean(opts.baseline), after: Boolean(opts.after), out: opts.out };
}

function projectRoot() {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 10000 }).trim() || process.cwd();
  } catch {
    return process.cwd();
  }
}

/** A hook setting, in the order of rh_cfg in hooks/claude/lib.sh: the environment, the .real-hooks file, git config. */
function hookSetting(root, key) {
  const fromEnv = process.env[`REAL_${key.toUpperCase().replace(/[.-]/g, '_')}`];
  if (fromEnv) return fromEnv;
  try {
    for (const line of readFileSync(path.join(root, '.real-hooks'), 'utf8').split('\n')) {
      const hit = line.match(/^\s*([^=\s]+)\s*=\s*(.*?)\s*$/);
      if (hit && hit[1] === key) {
        if (hit[2]) return hit[2];
        break; // the first line of the key decides, like head -n 1 in rh_cfg
      }
    }
  } catch {
    // no .real-hooks file
  }
  try {
    return execFileSync('git', ['-C', root, 'config', '--get', `real.hooks.${key}`], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 10000 }).trim() || undefined;
  } catch {
    return undefined;
  }
}

function targetMin(root) {
  const raw = hookSetting(root, 'ui.target-min');
  if (raw === undefined) return TARGET_MIN_DEFAULT;
  if (!/^\d{1,3}$/.test(raw) || Number(raw) < 1 || Number(raw) > 200) {
    throw new Fail(2, `ui.target-min must be a whole number from 1 to 200 (got ${JSON.stringify(raw.slice(0, 20))})`);
  }
  return Number(raw);
}

function envNumber(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  if (!/^\d{1,9}$/.test(raw)) throw new Fail(2, `${name} must be a whole number`);
  return Number(raw);
}

// ---------------------------------------------------------------------------------------------------------------------
// Playwright
// ---------------------------------------------------------------------------------------------------------------------

/** The `chromium` launcher of `playwright` or `@playwright/test`, from the first place that has one. */
function loadChromium(root) {
  const here = path.dirname(realpathSync(fileURLToPath(import.meta.url)));
  const typed = process.argv[1] ? path.dirname(path.resolve(process.argv[1])) : here; // the skill can be a symlink
  const bases = [root, process.cwd(), here, path.resolve(here, '../../real-check/scripts'), path.resolve(typed, '../../real-check/scripts')];
  for (const base of new Set(bases)) {
    for (const name of ['playwright', '@playwright/test']) {
      try {
        const { chromium } = createRequire(path.join(base, 'noop.js'))(name);
        if (chromium) return chromium;
      } catch {
        // try the next place
      }
    }
  }
  throw new Fail(4, INSTALL_HINT);
}

// ---------------------------------------------------------------------------------------------------------------------
// Lock: one capture at a time on the machine
// ---------------------------------------------------------------------------------------------------------------------

let heldLock = null;

const lockFolder = () => path.join(process.env.XDG_STATE_HOME || path.join(os.homedir(), '.local', 'state'), 'real', 'shot', 'lock');

function lockPid(lock) {
  try {
    const pid = Number(readFileSync(path.join(lock, 'pid'), 'utf8').trim());
    return Number.isInteger(pid) && pid > 0 ? pid : null;
  } catch {
    return null;
  }
}

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error.code !== 'ESRCH'; // EPERM: the process exists
  }
}

/** Takes the lock. Waits for a live holder. Takes over a lock of a dead process or one older than 10 minutes. */
async function takeLock(waitMs) {
  const lock = lockFolder();
  mkdirSync(path.dirname(lock), { recursive: true, mode: 0o700 });
  const began = Date.now();
  for (;;) {
    try {
      mkdirSync(lock); // atomic: only one process creates it
      try {
        writeFileSync(path.join(lock, 'pid'), `${process.pid}\n`);
      } catch (error) {
        rmSync(lock, { recursive: true, force: true });
        throw error;
      }
      heldLock = lock;
      return Date.now() - began;
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
    }
    const pid = lockPid(lock);
    let age;
    try {
      age = Date.now() - statSync(lock).mtimeMs;
    } catch {
      continue; // the holder just released it
    }
    // shortcut: two waiters can take over the same stale lock in the same instant, upgrade to a file lock (flock) if that happens
    if ((pid !== null && !isAlive(pid)) || age > LOCK_STALE_MS) {
      rmSync(lock, { recursive: true, force: true });
      continue;
    }
    const waited = Date.now() - began;
    if (waited >= waitMs) throw new Fail(5, `another capture runs (pid ${pid ?? 'unknown'}). Waited ${Math.round(waited / 1000)} s.`);
    await sleep(LOCK_POLL_MS);
  }
}

/** Removes the lock only when its pid file holds our own PID. */
function releaseLock() {
  if (heldLock && lockPid(heldLock) === process.pid) rmSync(heldLock, { recursive: true, force: true });
  heldLock = null;
}

// ---------------------------------------------------------------------------------------------------------------------
// Capture
// ---------------------------------------------------------------------------------------------------------------------

/** Runs inside the page: only its argument and the page globals exist there. `width` is the window width that real-shot set. */
function measure({ min, width }) {
  const LIMIT = 10;
  const TARGETS = 'a[href], button, input:not([type=hidden]), select, textarea, summary, [role=button], [role=link], [role=checkbox], [role=radio], [role=tab], [role=menuitem], [role=switch], [onclick], [tabindex]:not([tabindex="-1"])';
  const cut = (text) => text.slice(0, 40);
  const name = (el) => {
    const id = el.getAttribute('id');
    const classes = (el.getAttribute('class') || '').split(/\s+/).filter(Boolean).slice(0, 2);
    return el.tagName.toLowerCase() + (id ? `#${cut(id)}` : '') + classes.map((c) => `.${cut(c)}`).join('');
  };
  const shown = [];
  for (const el of document.body.querySelectorAll('*')) {
    const style = getComputedStyle(el);
    const box = el.getBoundingClientRect();
    if (style.display !== 'none' && style.visibility !== 'hidden' && box.width > 0) shown.push({ el, style, box });
  }
  const wide = shown.filter(({ el, box }) => {
    const parent = el.parentElement;
    return parent && parent.clientWidth > 0 && getComputedStyle(parent).overflowX === 'visible' && box.width > parent.clientWidth + 1;
  });
  const targets = shown.filter(({ el, box }) => el.matches(TARGETS) && (box.width < min || box.height < min));
  const longText = shown.filter(
    ({ el, style }) =>
      el.clientWidth > 0 &&
      el.scrollWidth > el.clientWidth + 1 &&
      style.overflowX !== 'auto' &&
      style.overflowX !== 'scroll' &&
      [...el.childNodes].some((node) => node.nodeType === 3 && node.nodeValue.trim() !== ''),
  );
  const root = document.documentElement;
  return {
    // window.innerWidth is not used: in the phone profile it grows to the width of the page, so the overflow would never show.
    overflow: { value: root.scrollWidth > width, scrollWidth: root.scrollWidth, innerWidth: width },
    wide: {
      count: wide.length,
      items: wide.slice(0, LIMIT).map(({ el, box }) => ({ el: name(el), width: Math.round(box.width), parentWidth: Math.round(el.parentElement.clientWidth) })),
    },
    targets: {
      count: targets.length,
      min,
      items: targets.slice(0, LIMIT).map(({ el, box }) => ({ el: name(el), width: Math.round(box.width), height: Math.round(box.height) })),
    },
    longText: {
      count: longText.length,
      items: longText.slice(0, LIMIT).map(({ el }) => ({ el: name(el), scrollWidth: el.scrollWidth, clientWidth: el.clientWidth })),
    },
  };
}

/** Opens the page. A network error, an HTTP status of 400 or more and a timeout end the run with exit code 3. */
async function openPage(page, url) {
  const where = url.origin + url.pathname;
  let response;
  try {
    response = await page.goto(url.href, { waitUntil: 'load', timeout: PAGE_TIMEOUT_MS });
  } catch (error) {
    const message = String(error.message);
    if (error.name === 'TimeoutError') throw new Fail(3, `the page did not load in 30 s: ${where}`);
    if (/net::ERR_(CONNECTION|NAME_NOT_RESOLVED|ADDRESS|INTERNET|EMPTY|NETWORK|TIMED_OUT)/.test(message)) {
      throw new Fail(3, `no server answers at ${url.origin}. Start the dev server, then run real-shot again.`);
    }
    throw new Fail(3, `the page could not load: ${where} (${/net::ERR_[A-Z_]+/.exec(message)?.[0] ?? firstLine(message)})`);
  }
  if (response && response.status() >= 400) throw new Fail(3, `${where} answered HTTP ${response.status()}.`);
}

async function shoot(browser, width, { url, selector, settleMs, min }) {
  const phone = width < 768;
  const context = await browser.newContext({
    viewport: { width, height: phone ? 812 : 800 },
    isMobile: phone,
    hasTouch: phone,
    deviceScaleFactor: 1,
    colorScheme: 'light',
  });
  try {
    const page = await context.newPage();
    await openPage(page, url);
    await sleep(settleMs);
    const look = { animations: 'disabled', caret: 'hide' };
    let png;
    if (selector) {
      const element = page.locator(selector).first();
      try {
        await element.waitFor({ timeout: SELECTOR_TIMEOUT_MS });
      } catch (error) {
        if (error.name === 'TimeoutError') throw new Fail(3, 'no element matches the selector');
        throw new Fail(2, `the selector is not valid: ${firstLine(error.message)}`);
      }
      png = await element.screenshot(look);
    } else {
      png = await page.screenshot({ ...look, fullPage: true });
    }
    return { width, png, measures: await page.evaluate(measure, { min, width }) };
  } finally {
    await context.close().catch(() => {});
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Comparison
// ---------------------------------------------------------------------------------------------------------------------

/** Share of changed pixels, in percent with 3 decimals. The canvas is the larger width by the larger height. */
function changedShare(a, b) {
  const total = Math.max(a.width, b.width) * Math.max(a.height, b.height);
  const width = Math.min(a.width, b.width);
  const height = Math.min(a.height, b.height);
  let changed = total - width * height; // pixels outside one of the images
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * a.width + x) * 4;
      const j = (y * b.width + x) * 4;
      if (Math.abs(a.data[i] - b.data[j]) > TOLERANCE || Math.abs(a.data[i + 1] - b.data[j + 1]) > TOLERANCE || Math.abs(a.data[i + 2] - b.data[j + 2]) > TOLERANCE || Math.abs(a.data[i + 3] - b.data[j + 3]) > TOLERANCE) changed++;
    }
  }
  return Math.round((changed * 100000) / total) / 1000;
}

/** { changedPercent, note? } for the before and after PNG of one width. A missing or unreadable image gives null and a note. */
function compareImages(beforePng, afterPng) {
  if (!beforePng) return { changedPercent: null, note: 'no baseline image for this width' };
  try {
    return { changedPercent: changedShare(decodePng(beforePng), decodePng(afterPng)) };
  } catch (error) {
    return { changedPercent: null, note: `not comparable: ${firstLine(error.message)}` };
  }
}

const summaryLine = (width, m, changed) => {
  const overflow = m.overflow.value ? `${m.overflow.scrollWidth} > ${m.overflow.innerWidth}` : 'none';
  const tail = changed === undefined ? '' : `, changed ${changed === null ? 'n/a' : `${changed}%`}`;
  return `${width}: overflow ${overflow}, targets <${m.targets.min}px: ${m.targets.count}, wide: ${m.wide.count}, long text: ${m.longText.count || 'ok'}${tail}`;
};

const STYLE =
  ':root{color-scheme:light only}html,body{background:#fff}body{margin:0;padding:16px;color:#1a1a1a;font:16px/1.5 system-ui,sans-serif}' +
  'h1{font-size:1.4rem;margin:0 0 .5rem}h2{font-size:1.1rem;margin:2rem 0 .5rem}h3{font-size:1rem;margin:0 0 .5rem}p{margin:.25rem 0}' +
  '.cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}.col{min-width:0}img{display:block;max-width:100%;height:auto;border:1px solid #767676}' +
  'ul{margin:.5rem 0 0;padding-left:1.25rem}@media (max-width:700px){.cols{grid-template-columns:1fr}}';

function facts(m) {
  const overflow = m.overflow.value ? `${m.overflow.scrollWidth} px wide in a window of ${m.overflow.innerWidth} px` : 'none';
  return `<ul><li>Overflow: ${esc(overflow)}</li><li>Targets under ${esc(m.targets.min)} px: ${esc(m.targets.count)}</li><li>Wider than the parent: ${esc(m.wide.count)}</li><li>Long text: ${esc(m.longText.count)}</li></ul>`;
}

/** One self-contained page: no script, no external file. Every text goes through esc(). */
function comparePage({ tag, url, time, min, rows }) {
  const column = (label, side, width) => {
    const image = side.png ? `<img src="data:image/png;base64,${side.png.toString('base64')}" alt="${esc(label)}, ${esc(width)} px">` : '<p>no baseline</p>';
    return `<div class="col"><h3>${esc(label)}</h3>${image}${side.measures ? facts(side.measures) : ''}</div>`;
  };
  const sections = rows
    .map(({ width, before, after, changedPercent, note }) => {
      const changed = changedPercent === null ? `not compared (${note})` : `${changedPercent} %`;
      return `<section><h2>${esc(width)} px</h2><div class="cols">${column('Before', before, width)}${column('After', after, width)}</div><p>Changed pixels: ${esc(changed)}</p></section>`;
    })
    .join('');
  return (
    '<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
    `<title>real-shot ${esc(tag)}</title><style>${STYLE}</style></head><body>` +
    `<h1>real-shot ${esc(tag)}</h1><p>Page: ${esc(url.origin + url.pathname)}</p><p>Captured: ${esc(time)}</p><p>Target size: ${esc(min)} px</p>` +
    `${sections}</body></html>\n`
  );
}

// ---------------------------------------------------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------------------------------------------------

const readOrNull = (file) => (existsSync(file) ? readFileSync(file) : null);

/** The measures of the baseline for one width, from before.json. */
function baselineMeasures(dir, width) {
  try {
    return JSON.parse(readFileSync(path.join(dir, 'before.json'), 'utf8')).widths.find((entry) => entry.width === width)?.measures ?? null;
  } catch {
    return null;
  }
}

async function run(argv) {
  const opts = parseArgs(argv);
  const root = projectRoot();
  const min = targetMin(root);
  const settleMs = envNumber('REAL_SHOT_SETTLE_MS', 2500);
  const lockWaitS = envNumber('REAL_SHOT_LOCK_WAIT', 120);
  const dir = path.join(opts.out ? path.resolve(opts.out) : path.join(root, '.real', 'shots'), opts.tag);
  const chromium = loadChromium(root);

  let browser;
  try {
    const lockWaitMs = await takeLock(lockWaitS * 1000);
    const mode = opts.baseline ? 'baseline' : opts.after ? 'after' : existsSync(path.join(dir, `before-${opts.widths[0]}.png`)) ? 'after' : 'baseline';
    const startedAt = Date.now(); // after the lock, before the first page load
    try {
      browser = await chromium.launch({ headless: true });
    } catch (error) {
      const hint = /Executable doesn't exist/.test(error.message) ? ' Run: npx playwright install chromium' : '';
      throw new Fail(4, `the browser could not start: ${firstLine(error.message)}${hint}`);
    }
    const shots = [];
    for (const width of opts.widths) shots.push(await shoot(browser, width, { url: opts.url, selector: opts.selector, settleMs, min }));

    // Everything is captured. Only now the folder changes, so a failed capture keeps the earlier files.
    const phase = mode === 'baseline' ? 'before' : 'after';
    mkdirSync(dir, { recursive: true });
    if (mode === 'baseline') {
      for (const name of readdirSync(dir)) if (/^(before|after)-.*\.png$/.test(name) || name === 'after.json' || name === 'compare.html') rmSync(path.join(dir, name));
    }
    const time = new Date(startedAt).toISOString();
    const rows = shots.map((shot) => {
      writeFileSync(path.join(dir, `${phase}-${shot.width}.png`), shot.png);
      if (mode === 'baseline') return { ...shot, before: { png: shot.png, measures: shot.measures }, after: { png: null, measures: null }, changedPercent: null };
      const beforePng = readOrNull(path.join(dir, `before-${shot.width}.png`));
      return {
        ...shot,
        before: { png: beforePng, measures: beforePng ? baselineMeasures(dir, shot.width) : null },
        after: { png: shot.png, measures: shot.measures },
        ...compareImages(beforePng, shot.png),
      };
    });
    const record = { tag: opts.tag, url: opts.url.href, time, targetMin: min, widths: shots.map(({ width, measures }) => ({ width, measures })) };
    writeFileSync(path.join(dir, `${phase}.json`), `${JSON.stringify(record, null, 2)}\n`);

    let compare = null;
    if (mode === 'after') {
      compare = path.join(dir, 'compare.html');
      writeFileSync(compare, comparePage({ tag: opts.tag, url: opts.url, time, min, rows }));
      mkdirSync(path.join(root, '.real'), { recursive: true });
      writeFileSync(path.join(root, '.real', 'ui-shot'), `${Math.floor(startedAt / 1000)}\n`);
    }
    const showScript = path.resolve(path.dirname(realpathSync(fileURLToPath(import.meta.url))), '../../../../scripts/real-show.sh');
    return {
      mode,
      tag: opts.tag,
      url: opts.url.href,
      dir,
      targetMin: min,
      lockWaitMs,
      widths: rows.map((row) => ({
        width: row.width,
        before: mode === 'baseline' || row.before.png ? path.join(dir, `before-${row.width}.png`) : null,
        after: mode === 'after' ? path.join(dir, `after-${row.width}.png`) : null,
        measures: row.measures,
        changedPercent: row.changedPercent,
        ...(row.note ? { note: row.note } : {}),
      })),
      compare,
      show: compare && existsSync(showScript) ? `sh ${quote(showScript)} ${quote(compare)}` : null,
      lines: rows.map((row) => summaryLine(row.width, row.measures, mode === 'after' ? row.changedPercent : undefined)),
    };
  } finally {
    if (browser) await browser.close().catch(() => {});
    releaseLock();
  }
}

async function main(argv) {
  for (const [signal, code] of [['SIGINT', 130], ['SIGTERM', 143]]) {
    process.on(signal, () => {
      releaseLock();
      process.exit(code); // the exit handler of Playwright stops the browser
    });
  }
  try {
    console.log(JSON.stringify(await run(argv)));
    return 0;
  } catch (error) {
    if (error instanceof Fail) {
      console.error(`real-shot: ${error.message}`);
      if (error.code === 2) console.error(USAGE);
      return error.code;
    }
    console.error(`real-shot: ${firstLine(error.message ?? error)}`);
    return 1;
  }
}

// Run only as a script (compare real paths because the skill is installed as a symlink).
const isEntry = (() => {
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
})();
if (isEntry) process.exitCode = await main(process.argv.slice(2));
