#!/usr/bin/env node
// real-test visual: collects the fixtures' screenshots and observations from a Playwright JSON report, compares each screen
// with the previous report's and writes one self-contained page. Node standard library only, no network, no model.
//
//   node visual.mjs <results.json> --report <report-dir> [--baseline <earlier-report-dir>]
//
// For every test that carries a `real-test-screen` attachment (tests/real-test.fixtures.ts adds it):
//   - copies it to <report>/screens/<spec-slug>--<project>.png. That folder is the next run's baseline;
//   - compares it with the baseline's file of the same name. --baseline defaults to the newest earlier sibling of <report>
//     named <same-host>-<date>[-n] that has a screens/ folder (SKILL.md step 7 passes it explicitly). Status per screen:
//       same           same size, at most 0.1 % of the pixels differ (by more than 8 per channel)
//       changed        same size, more than 0.1 % differ; `diff` is the percent
//       size-changed   another width or height (a full-page screen grows with the page)
//       new            no baseline file (also for every screen when there is no baseline)
//       missing        a baseline screen this run did not produce (the flow or project did not run, or has no screen)
//       not-comparable a PNG that is not 8-bit RGB or RGBA without interlacing (Chromium, Firefox and WebKit write those)
//   - writes <report>/visual.html: images embedded as base64, no external file, no script. One section per flow, the
//     projects side by side; for a changed screen the baseline next to the current one and a difference overlay
//     (mix-blend-mode: difference; black is unchanged); per flow the console errors, page errors, responses with status 400
//     or more, failed requests and the accessibility violations the fixtures recorded.
// stdout: one JSON line {counts, baseline, html, flows}; `flows` has one entry per flow with, per project, the screen status,
// `diff` and the observation counts. Screens and observations are evidence: nothing here fails the run.
// Exit 0: written. Exit 2: usage error or unreadable report.

import { existsSync, mkdirSync, readFileSync, readdirSync, realpathSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { inflateSync } from 'node:zlib';

const TOLERANCE = 8; // per channel, out of 255: anti-aliasing noise is not a change
const THRESHOLD = 0.1; // percent of differing pixels from which a screen is `changed`
const LIST_LIMIT = 20;
const STATUSES = ['same', 'changed', 'size-changed', 'new', 'missing', 'not-comparable'];
const SEED = /(?:^|[\\/])seed\.spec\.[cm]?[jt]sx?$/;
const STAMP = /^(.+)-(\d{4}-\d{2}-\d{2})(?:-(\d+))?$/;
const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const relative = (file) => {
  const rel = path.relative(process.cwd(), file);
  return rel.startsWith('..') || path.isAbsolute(rel) ? file : rel.split(path.sep).join('/');
};

// [[key, items]] in first-seen order (Map.groupBy needs Node 21).
const groupBy = (items, key) => {
  const groups = new Map();
  for (const item of items) groups.set(key(item), [...(groups.get(key(item)) ?? []), item]);
  return [...groups];
};

// ---------------------------------------------------------------------------------------------------------------------
// PNG and comparison
// ---------------------------------------------------------------------------------------------------------------------

/** The IHDR fields of a PNG: { width, height, depth, color, interlace }. Throws on anything that is not a PNG. */
function pngHeader(png) {
  if (png.length < 33 || !png.subarray(0, 8).equals(SIGNATURE) || png.toString('latin1', 12, 16) !== 'IHDR') throw new Error('not a PNG');
  return { width: png.readUInt32BE(16), height: png.readUInt32BE(20), depth: png[24], color: png[25], interlace: png[28] };
}

/** { width, height, data } with data as RGBA bytes. Only 8-bit RGB and RGBA without interlacing; else throws. */
export function decodePng(png) {
  const { width, height, depth, color, interlace } = pngHeader(png);
  if (depth !== 8 || (color !== 2 && color !== 6) || interlace !== 0 || width === 0 || height === 0) {
    throw new Error(`unsupported PNG (bit depth ${depth}, color type ${color}, interlace ${interlace})`);
  }
  const parts = [];
  for (let at = 8; at + 8 <= png.length; ) {
    const length = png.readUInt32BE(at);
    const type = png.toString('latin1', at + 4, at + 8);
    if (type === 'IDAT') parts.push(png.subarray(at + 8, at + 8 + length));
    if (type === 'IEND') break;
    at += 12 + length;
  }
  const bpp = color === 2 ? 3 : 4;
  const stride = width * bpp;
  const raw = inflateSync(Buffer.concat(parts));
  if (raw.length !== (stride + 1) * height) throw new Error('PNG data has the wrong length');

  const px = Buffer.alloc(stride * height); // assigning a byte wraps modulo 256, as the PNG filters require
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const from = y * (stride + 1) + 1;
    const row = y * stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? px[row + x - bpp] : 0;
      const b = y > 0 ? px[row - stride + x] : 0;
      const c = x >= bpp && y > 0 ? px[row - stride + x - bpp] : 0;
      let predicted;
      if (filter === 0) predicted = 0;
      else if (filter === 1) predicted = a;
      else if (filter === 2) predicted = b;
      else if (filter === 3) predicted = (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a);
        const pb = Math.abs(p - b);
        const pc = Math.abs(p - c);
        predicted = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      } else throw new Error(`bad PNG filter ${filter}`);
      px[row + x] = raw[from + x] + predicted;
    }
  }
  if (bpp === 4) return { width, height, data: px };
  const data = Buffer.alloc(width * height * 4);
  for (let i = 0, j = 0; i < px.length; i += 3, j += 4) {
    data[j] = px[i];
    data[j + 1] = px[i + 1];
    data[j + 2] = px[i + 2];
    data[j + 3] = 255;
  }
  return { width, height, data };
}

/** { status, diff?, note? } for two PNG buffers: same, changed (diff = percent of pixels), size-changed or not-comparable. */
export function compare(baseline, current) {
  if (baseline.equals(current)) return { status: 'same', diff: 0 };
  let a;
  let b;
  try {
    a = decodePng(baseline);
    b = decodePng(current);
  } catch (error) {
    return { status: 'not-comparable', note: error.message };
  }
  if (a.width !== b.width || a.height !== b.height) return { status: 'size-changed', note: `${a.width}x${a.height} before, ${b.width}x${b.height} now` };
  let differing = 0;
  for (let i = 0; i < a.data.length; i += 4) {
    if (Math.abs(a.data[i] - b.data[i]) > TOLERANCE || Math.abs(a.data[i + 1] - b.data[i + 1]) > TOLERANCE || Math.abs(a.data[i + 2] - b.data[i + 2]) > TOLERANCE || Math.abs(a.data[i + 3] - b.data[i + 3]) > TOLERANCE) differing++;
  }
  const diff = Math.round((differing * 10000) / (a.width * a.height)) / 100;
  return { status: diff > THRESHOLD ? 'changed' : 'same', diff };
}

// ---------------------------------------------------------------------------------------------------------------------
// Report data
// ---------------------------------------------------------------------------------------------------------------------

/** The newest earlier sibling of `reportDir` for the same host (`<host>-<date>[-n]`) that has a screens/ folder, or undefined. */
export function previousReport(reportDir) {
  const own = STAMP.exec(path.basename(reportDir));
  const root = path.dirname(reportDir);
  if (!own || !existsSync(root)) return undefined;
  const order = (m) => `${m[2]}-${String(m[3] ?? 1).padStart(6, '0')}`;
  const earlier = readdirSync(root)
    .map((name) => ({ name, m: STAMP.exec(name) }))
    .filter(({ name, m }) => m && m[1] === own[1] && order(m) < order(own) && existsSync(path.join(root, name, 'screens')))
    .sort((x, y) => order(y.m).localeCompare(order(x.m)));
  return earlier.length ? path.join(root, earlier[0].name) : undefined;
}

const bytesOf = (attachment) => {
  if (!attachment) return undefined;
  try {
    return attachment.path ? readFileSync(attachment.path) : attachment.body ? Buffer.from(attachment.body, 'base64') : undefined;
  } catch {
    return undefined;
  }
};

const jsonOf = (attachment) => {
  try {
    return JSON.parse(bytesOf(attachment)?.toString('utf8'));
  } catch {
    return undefined;
  }
};

/** One entry per test and project of a Playwright JSON report, seed excluded, with the fixtures' attachments of its last try. */
function collect(report) {
  const rootDir = report.config?.rootDir ?? process.cwd();
  const out = [];
  const visit = (suite, titles) => {
    for (const spec of suite.specs ?? []) {
      const file = path.resolve(rootDir, spec.file);
      if (SEED.test(file)) continue;
      for (const test of spec.tests) {
        const attachments = test.results.at(-1)?.attachments ?? [];
        const named = (name) => attachments.find((a) => a.name === name);
        out.push({
          file: relative(file),
          slug: path.basename(file).replace(/\.(?:spec|test)\.[cm]?[jt]sx?$/, ''),
          title: [...titles, spec.title].join(' > '),
          project: test.projectName,
          outcome: test.results.at(-1)?.status, // passed, failed, timedOut, skipped (fixme), interrupted
          png: bytesOf(named('real-test-screen')),
          observations: jsonOf(named('real-test-observations')),
          a11y: jsonOf(named('real-test-a11y')),
        });
      }
    }
    for (const child of suite.suites ?? []) visit(child, [...titles, child.title]);
  };
  for (const suite of report.suites ?? []) visit(suite, []);
  return out;
}

/** Copy the screens into <report>/screens and compare them with the baseline's. Returns one row per screen, in report order. */
function compareAll(tests, reportDir, baselineDir) {
  const screens = path.join(reportDir, 'screens');
  mkdirSync(screens, { recursive: true });
  const baselineOf = (name) => {
    const file = baselineDir && path.join(baselineDir, 'screens', `${name}.png`);
    return file && existsSync(file) ? readFileSync(file) : undefined;
  };
  const names = new Set();
  const rows = [];
  for (const t of tests) {
    let name = `${t.slug}--${t.project}`;
    for (let n = 2; names.has(name); n++) name = `${t.slug}--${t.project}-${n}`;
    names.add(name);
    const baseline = baselineOf(name);
    if (t.png) writeFileSync(path.join(screens, `${name}.png`), t.png);
    const result = t.png ? (baseline ? compare(baseline, t.png) : { status: 'new' }) : baseline ? { status: 'missing' } : {};
    rows.push({ ...t, name, baseline, ...result });
  }
  if (baselineDir) {
    for (const file of readdirSync(path.join(baselineDir, 'screens')).filter((f) => f.endsWith('.png')).sort()) {
      const name = file.slice(0, -4);
      if (names.has(name)) continue;
      const at = name.lastIndexOf('--');
      rows.push({ slug: name.slice(0, at), title: '', project: name.slice(at + 2), name, baseline: baselineOf(name), status: 'missing' });
    }
  }
  return rows;
}

// ---------------------------------------------------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------------------------------------------------

const esc = (text) => String(text ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const list = (items, render) => (items.length ? `<ul>${items.slice(0, LIST_LIMIT).map((item) => `<li>${render(item)}</li>`).join('')}${items.length > LIST_LIMIT ? `<li>${items.length - LIST_LIMIT} more in the attachment of the Playwright report</li>` : ''}</ul>` : '');

const STYLE = `:root{color-scheme:light dark;--bg:#f6f7f9;--card:#fff;--fg:#1a1a1a;--muted:#5b6170;--line:#dde0e6;--ok:#0a6b2d;--warn:#8a5a00;--info:#1a56a8;--bad:#b3261e}
@media (prefers-color-scheme:dark){:root{--bg:#111316;--card:#1a1d21;--fg:#ececec;--muted:#a3a9b5;--line:#2e333a;--ok:#6fd28d;--warn:#f0b955;--info:#8ab4f8;--bad:#f2b8b5}}
*{box-sizing:border-box}body{font:15px/1.5 system-ui,sans-serif;background:var(--bg);color:var(--fg);margin:0 auto;max-width:72rem;padding:1.5rem 1rem 4rem}
h1{font-size:1.6rem;margin:0 0 .25rem}h2{font-size:1.05rem;margin:0}h3{font-size:.95rem;margin:1rem 0 .4rem}.muted{color:var(--muted);font-weight:400}
a{color:var(--info)}code{font-size:.85em;overflow-wrap:anywhere}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(9rem,1fr));gap:.75rem;margin:1.25rem 0}
.stat{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:.75rem 1rem}.stat b{display:block;font-size:1.6rem;line-height:1.2}
table{border-collapse:collapse;width:100%;background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden}
th,td{border-bottom:1px solid var(--line);padding:.5rem .75rem;text-align:left;vertical-align:top}th{font-size:.8rem;text-transform:uppercase;letter-spacing:.03em;color:var(--muted)}
tr:last-child td{border-bottom:0}
.flow{background:var(--card);border:1px solid var(--line);border-radius:10px;margin:.75rem 0}
.flow>summary{list-style:none;display:flex;flex-wrap:wrap;gap:.5rem 1rem;align-items:center;padding:.75rem 1rem;cursor:pointer}
.flow>summary::-webkit-details-marker{display:none}.flow>summary::before{content:"▸";color:var(--muted)}.flow[open]>summary::before{content:"▾"}
.flow>summary h2{flex:1 1 20rem}.body{padding:0 1rem 1rem;border-top:1px solid var(--line)}
.screens{display:flex;flex-wrap:wrap;gap:1.25rem;align-items:flex-start;margin-top:1rem}
figure{margin:0}figcaption{font-size:.85rem;margin-bottom:.35rem}
.frame{display:block;max-height:28rem;overflow-y:auto;border:1px solid var(--line);border-radius:6px}
.shot{display:block;width:min(100%,calc(var(--w) * .45px));aspect-ratio:var(--w)/var(--h);background-size:100% 100%;background-repeat:no-repeat}
.frame .shot{width:calc(var(--w) * .45px);max-width:100%}
.overlay{position:relative;isolation:isolate;width:min(100%,calc(var(--w) * .45px));aspect-ratio:var(--w)/var(--h);background:#000}
.layer{position:absolute;left:0;top:0;width:calc(var(--lw)/var(--w)*100%);aspect-ratio:var(--lw)/var(--lh);background-size:100% 100%;background-repeat:no-repeat}
.layer+.layer{mix-blend-mode:difference}
.badge{display:inline-block;border:1px solid currentColor;border-radius:999px;padding:0 .55em;font-size:.78rem;font-weight:600;white-space:nowrap}
.same,.passed{color:var(--ok)}.changed,.size-changed,.issue{color:var(--warn)}.new{color:var(--info)}.missing,.not-comparable,.skipped{color:var(--muted)}.failed,.timedOut,.interrupted{color:var(--bad)}
details details{margin:.75rem 0}details details summary{cursor:pointer;font-weight:600}
ul{margin:.25rem 0 .5rem;padding-left:1.25rem}.note{font-size:.85rem;color:var(--muted);margin-top:2rem}
.brand{margin:0 0 .5rem;font-size:.8rem;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--info)}
h1{letter-spacing:-.01em}.stat{box-shadow:0 1px 2px rgb(0 0 0 / .04)}.flow{box-shadow:0 1px 2px rgb(0 0 0 / .04)}
.flow>summary h2 .muted{display:block;font-size:.75rem;margin-top:.15rem}`;

function buildPage({ rows, counts, baselineLabel, resultsLabel, playwrightReport }) {
  const images = new Map();
  const image = (png) => {
    if (!images.has(png)) images.set(png, `i${images.size}`);
    return images.get(png);
  };
  const size = (png) => {
    const { width, height } = pngHeader(png);
    return { width, height };
  };
  const shot = (png, label) => {
    const { width, height } = size(png);
    return `<div class="shot ${image(png)}" role="img" aria-label="${esc(label)}" style="--w:${width};--h:${height}"></div>`;
  };
  const badge = (status) => `<span class="badge ${esc(status)}">${esc(status)}</span>`; // outcome comes from results.json
  const percent = (row) => (row.diff === undefined ? '' : ` ${row.diff}% of the pixels differ.`);

  const overlay = (row) => {
    const a = size(row.baseline);
    const b = size(row.png);
    const layer = (png, s) => `<div class="layer ${image(png)}" style="--lw:${s.width};--lh:${s.height}"></div>`;
    return `<div class="overlay" role="img" aria-label="Difference between the baseline and the current screen, ${esc(row.project)}" style="--w:${Math.max(a.width, b.width)};--h:${Math.max(a.height, b.height)}">${layer(row.baseline, a)}${layer(row.png, b)}</div>`;
  };

  const issuesOf = (row) => {
    const o = row.observations;
    if (!o) return [];
    return [
      [o.console?.length, 'console error'],
      [o.pageErrors?.length, 'page error'],
      [o.badResponses?.length, 'response 400+'],
      [o.failedRequests?.length, 'failed request'],
      [row.a11y?.violations?.length, 'accessibility'],
    ].filter(([n]) => n);
  };
  const chips = (row) => {
    if (!row.observations) return '<span class="muted">no observations</span>';
    const found = issuesOf(row);
    return found.length ? found.map(([n, what]) => `<span class="badge issue">${n} ${what}</span>`).join(' ') : '<span class="muted">clean</span>';
  };

  const observed = (row) => {
    const o = row.observations;
    if (!o) return `<p class="muted">No observations for ${esc(row.project)}: the spec does not use the fixtures, or the test did not run.</p>`;
    if (!issuesOf(row).length && !o.errors?.length) return '';
    const violations = row.a11y?.violations ?? [];
    return `<h3>${esc(row.project)}</h3>
${o.console?.length ? `<p>Console errors</p>${list(o.console, (e) => `${esc(e.text)} <span class="muted">(<code>${esc(e.url)}</code> ${esc(e.party)})</span>`)}` : ''}
${o.pageErrors?.length ? `<p>Page errors</p>${list(o.pageErrors, (e) => esc(e.message))}` : ''}
${o.badResponses?.length ? `<p>Responses with status 400 or more</p>${list(o.badResponses, (e) => `${esc(e.status)} ${esc(e.method)} <code>${esc(e.url)}</code> <span class="muted">${esc(e.party)}</span>`)}` : ''}
${o.failedRequests?.length ? `<p>Failed requests</p>${list(o.failedRequests, (e) => `${esc(e.method)} <code>${esc(e.url)}</code> ${esc(e.error)} <span class="muted">${esc(e.party)}</span>`)}` : ''}
${violations.length ? `<p>Accessibility violations (axe-core, WCAG 2.0 and 2.1 A and AA)</p>${list(violations, (v) => `<strong>${esc(v.impact)}</strong> <code>${esc(v.id)}</code>: ${esc(v.help)} <span class="muted">(${esc(v.nodes)} ${v.nodes === 1 ? 'element' : 'elements'})</span>`)}` : ''}
${o.errors?.length ? `<p>The fixtures could not record everything</p>${list(o.errors, esc)}` : ''}`;
  };

  const flows = groupBy(rows, (row) => row.slug);
  const projects = [...new Set(rows.map((row) => row.project))];
  const overview = flows
    .map(([slug, group]) => {
      const first = group.find((row) => row.file) ?? group[0];
      const cells = projects.map((p) => {
        const row = group.find((r) => r.project === p);
        return `<td>${row?.outcome ? badge(row.outcome) : '<span class="muted">-</span>'} ${row?.status ? `<span class="muted">screen</span> ${badge(row.status)}` : ''}<br>${row ? chips(row) : ''}</td>`;
      });
      return `<tr><td><a href="#flow-${esc(slug)}">${esc((first.title || slug).split(' > ').at(-1))}</a></td>${cells.join('')}</tr>`;
    })
    .join('\n');
  const sections = flows
    .map(([slug, group]) => {
      const first = group.find((row) => row.file) ?? group[0];
      const figures = group
        .map((row) => {
          const label = `${row.project}: ${row.status ?? 'no screen'}`;
          const body = row.png ? shot(row.png, `Screen of ${slug}, ${label}`) : row.baseline ? shot(row.baseline, `Baseline screen of ${slug}, ${row.project}`) : '<p class="muted">No screen: the spec does not use the fixtures, or the test did not run.</p>';
          const link = row.png ? `<a class="frame" href="screens/${esc(row.name)}.png" title="Open full size">${body}</a>` : `<div class="frame">${body}</div>`;
          return `<figure><figcaption><strong>${esc(row.project)}</strong> ${row.outcome ? badge(row.outcome) : ''} ${row.status ? badge(row.status) : ''}${esc(percent(row))}${row.note ? ` <span class="muted">${esc(row.note)}</span>` : ''}${row.status === 'missing' ? ' <span class="muted">(baseline shown)</span>' : ''}</figcaption>${link}</figure>`;
        })
        .join('\n');
      const compared = group
        .filter((row) => row.png && row.baseline && ['changed', 'size-changed', 'not-comparable'].includes(row.status))
        .map(
          (row) => `<details${row.status === 'not-comparable' ? '' : ' open'}><summary>Baseline and current, ${esc(row.project)}</summary><div class="screens"><figure><figcaption>Baseline (${esc(baselineLabel)})</figcaption><div class="frame">${shot(row.baseline, `Baseline screen of ${slug}, ${row.project}`)}</div></figure><figure><figcaption>Current</figcaption><div class="frame">${shot(row.png, `Current screen of ${slug}, ${row.project}`)}</div></figure></div></details>
${row.status === 'not-comparable' ? '' : `<details><summary>Difference overlay, ${esc(row.project)} (black is unchanged)</summary><div class="frame">${overlay(row)}</div></details>`}`,
        )
        .join('\n');
      const ran = group.filter((row) => row.file);
      const attention = group.some((row) => (row.outcome && row.outcome !== 'passed') || ['changed', 'size-changed', 'missing'].includes(row.status));
      const details = ran.map(observed).join('\n');
      return `<details class="flow" id="flow-${esc(slug)}"${attention ? ' open' : ''}><summary><h2>${esc((first.title || slug).split(' > ').at(-1))} <span class="muted"><code>${esc(first.file ?? 'only in the baseline')}</code></span></h2>${group.map((row) => `<span>${esc(row.project.replace(/^real-test-/, ''))} ${row.outcome ? badge(row.outcome) : ''}</span>`).join(' ')}</summary><div class="body">
<div class="screens">${figures}</div>
${compared}
${ran.length ? details : '<p class="muted">No test of this flow ran in this report.</p>'}
</div></details>`;
    })
    .join('\n');

  const OUTCOMES = ['passed', 'failed', 'timedOut', 'interrupted', 'skipped'];
  const outcomes = Object.fromEntries(OUTCOMES.map((o) => [o, rows.filter((row) => row.outcome === o).length]));
  const withIssues = rows.filter((row) => issuesOf(row).length).length;
  const stat = (n, label, cls = '') => `<div class="stat"><b class="${cls}">${n}</b>${label}</div>`;
  const css = [...images].map(([png, name]) => `.${name}{background-image:url(data:image/png;base64,${png.toString('base64')})}`).join('\n');
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>real-test report</title>
<style>${STYLE}</style><style>${css}</style></head><body>
<p class="brand">real-test · by Giray Batıtürk</p>
<h1>Test report</h1>
<p class="muted">${flows.length} flows · ${projects.map(esc).join(', ')} · results <code>${esc(resultsLabel)}</code> · baseline ${baselineLabel ? `<code>${esc(baselineLabel)}</code>` : 'none, so every screen is new'}${playwrightReport ? ' · <a href="html/index.html">Playwright report</a> (steps, errors, traces)' : ''}</p>
<div class="stats">
${stat(outcomes.passed, 'tests passed', 'passed')}
${stat(outcomes.failed + outcomes.timedOut + outcomes.interrupted, 'tests failed', outcomes.failed + outcomes.timedOut + outcomes.interrupted ? 'failed' : '')}
${outcomes.skipped ? stat(outcomes.skipped, 'skipped (fixme)', 'skipped') : ''}
${stat(counts.changed + counts['size-changed'], 'screens changed', counts.changed + counts['size-changed'] ? 'changed' : '')}
${stat(withIssues, 'tests with findings', withIssues ? 'issue' : '')}
</div>
<table><thead><tr><th scope="col">Flow</th>${projects.map((p) => `<th scope="col">${esc(p)}</th>`).join('')}</tr></thead><tbody>
${overview}
</tbody></table>
<p class="muted">Screens by status: ${STATUSES.map((s) => `${s} ${counts[s]}`).join(' · ')}</p>
${sections || '<p>No screens: no test of this run used the fixtures.</p>'}
<p class="note">Screens, console errors, failed requests and accessibility violations are observations, not test results: nothing on this page fails the run. axe-core finds only a subset of WCAG issues. Dynamic content (dates, ads, animations, live data) makes a screen differ between runs without a real change. Click a screen to open it full size.</p>
<footer class="note">Made with real-test, a skill by Giray Batıtürk · github.com/giraybatiturk/skills</footer>
</body></html>
`;
}

// ---------------------------------------------------------------------------------------------------------------------
// Command line
// ---------------------------------------------------------------------------------------------------------------------

const USAGE = 'Usage: node visual.mjs <results.json> --report <report-dir> [--baseline <earlier-report-dir>]';

function main(argv) {
  const args = [...argv];
  const take = (flag) => {
    const at = args.indexOf(flag);
    return at === -1 ? undefined : (args.splice(at, 2)[1] ?? null);
  };
  const reportArg = take('--report');
  const baselineArg = take('--baseline');
  const [file, ...extra] = args;
  if (!file || extra.length || !reportArg || baselineArg === null) {
    console.error(USAGE);
    return 2;
  }
  let report;
  try {
    report = JSON.parse(readFileSync(file, 'utf8'));
  } catch (error) {
    console.error(`Cannot read ${file}: ${error.message}`);
    return 2;
  }
  const reportDir = path.resolve(reportArg);
  const baselineDir = baselineArg ? path.resolve(baselineArg) : previousReport(reportDir);
  if (baselineArg && (baselineDir === reportDir || !existsSync(path.join(baselineDir, 'screens')) || !statSync(path.join(baselineDir, 'screens')).isDirectory())) {
    console.error(`Not an earlier report folder with screens/: ${baselineArg}\n${USAGE}`);
    return 2;
  }

  const rows = compareAll(collect(report), reportDir, baselineDir);
  const counts = Object.fromEntries(STATUSES.map((status) => [status, rows.filter((row) => row.status === status).length]));
  const baselineLabel = baselineDir ? relative(baselineDir) : '';
  const html = path.join(reportDir, 'visual.html');
  writeFileSync(html, buildPage({ rows, counts, baselineLabel, resultsLabel: relative(path.resolve(file)), playwrightReport: existsSync(path.join(reportDir, 'html/index.html')) }));

  const flows = groupBy(rows, (row) => row.slug).map(([flow, group]) => ({
    flow,
    file: group.find((row) => row.file)?.file ?? null,
    projects: Object.fromEntries(
      group.map((row) => [
        row.project,
        {
          screen: row.status ?? 'none',
          diff: row.diff ?? null,
          observed: Boolean(row.observations),
          console: row.observations?.console?.length ?? 0,
          pageErrors: row.observations?.pageErrors?.length ?? 0,
          badResponses: row.observations?.badResponses?.length ?? 0,
          failedRequests: row.observations?.failedRequests?.length ?? 0,
          a11y: row.a11y?.violations?.length ?? 0,
        },
      ]),
    ),
  }));
  console.log(JSON.stringify({ counts, baseline: baselineLabel || null, html: relative(html), flows }));
  return 0;
}

// Run only as a script (see guard.mjs: compare real paths because the skill is installed as a symlink).
const isEntry = (() => {
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
})();
if (isEntry) process.exitCode = main(process.argv.slice(2));
