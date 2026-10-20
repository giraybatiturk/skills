#!/usr/bin/env node
// real-audit annotated evidence: marks the exact element of each visual finding on a screenshot.
//
// Usage:
//   node annotate-evidence.mjs <spec.json> --out DIR [--recapture]
//
// For every item in the spec: take (or load) the capture, locate the element(s) the finding is about, draw a red
// outline 3 px outside each box and a red label chip (finding ID + defect, white bold text) next to it, crop around the
// marks, optionally upscale, and write the marked crop. Then write a contact sheet of all marked crops to look at.
// The capture itself is kept unchanged. Nothing is drawn that was not measured; a target that cannot be found, is not
// visible, lies outside the capture, or cannot get a label without covering another label stops the run.
//
// Output in DIR:
//   original/<capture>.png|jpg   the unchanged capture (a web capture is written here; an image is copied byte for byte)
//   marked/<item>.png            the marked crop
//   contact-sheet.png            all marked crops on one sheet (contact-sheet-1.png, -2.png ... above `perSheet` items)
//   manifest.json                what was captured and marked, with every box in capture pixels
// Files of an earlier run that the spec no longer produces are left in place; delete them by hand.
// An existing original that differs from the new capture is never replaced unless --recapture is given.
//
// Spec (JSON). Unknown keys are rejected so a typo cannot pass silently. Relative image paths are resolved from the spec file.
//   {
//     "defaults": { "viewport": {"width": 1366, "height": 768}, "margin": 40 },       // optional; any item key below
//     "sheet": { "columns": 3, "cellWidth": 480, "cellHeight": 400, "perSheet": 9 },  // optional
//     "items": [{
//       "id": "A-07", "label": "tabs do not switch",         // required: chip text is "<id> <label>"
//       "name": "a-07-letters",                              // optional output name, default: the id
//       "source": {                                          // a web capture ...
//         "url": "http://127.0.0.1:8765/index.html#letters", "viewport": {"width": 1366, "height": 768},
//         "deviceScaleFactor": 1, "colorScheme": "light", "fullPage": false, "name": "letters-1366",
//         "steps": [{"click": "css"}, {"hover": "css"}, {"focus": "css"}, {"fill": "css", "value": "x"}, {"press": "Tab"},
//                   {"scrollTo": "css"}, {"scroll": {"x": 0, "y": 600}}, {"wait": 300}, {"waitFor": "css"}]
//       },                                                   // ... or an existing image: "source": {"image": "shots/a.png"}
//       "targets": [                                         // at least one; exactly one of selector, text, box
//         {"selector": ".tabs"},                             // any Playwright selector; must match one visible element
//         {"text": "History", "within": "main", "exact": false},   // smallest visible element that contains the text
//         {"box": {"x": 10, "y": 20, "width": 200, "height": 40}}, // capture pixels (native screenshots: points x scale)
//         // per target: "label" (chip text after the id), "nth" (0-based among all matches) or "all": true when a
//         // selector matches several elements, "allowClipped": true to mark a box that runs past the capture edge
//       ],
//       "margin": 40, "upscale": 1.5, "color": "#d00000", "crop": "marks"   // crop: "marks" (default) or "full"
//     }]
//   }
//
// Chip text: a target's own "label" if it has one; otherwise the first target gets "<id> <label>" and further targets
// get "<id>" alone. A chip goes above its box, else below, else inside it, and never covers another chip or outline.
// A web capture measures the boxes before and after the screenshot; a layout that moved in between is an error.
// With fullPage the window is scrolled to the top first, so boxes and screenshot share document coordinates.
//
// Playwright is resolved from this folder, then real-check's scripts folder next to this skill, then the current folder.
// Exit codes: 0 done, 2 usage or spec error, 3 evidence problem (target not found, not visible, outside the capture,
// no room for a label), 4 capture problem (page did not open, step failed, image unreadable), 5 could not run or a file
// was not written. The last stdout line is JSON for exits 0, 3, 4 and for 5 after the run started.

import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { existsSync, mkdirSync, readFileSync, realpathSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const USAGE = 'Usage: node annotate-evidence.mjs <spec.json> --out DIR [--recapture]';
const EXIT = { spec: 2, evidence: 3, capture: 4, output: 5 };
const STYLE = { outline: 3, offset: 3, reach: 6, font: 'bold 16px system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', padX: 8, padY: 3, lineH: 20, chipMaxWidth: 360 };
const LIMITS = { canvas: 16384, tolerance: 1 };
const STEP_KEYS = ['click', 'hover', 'focus', 'fill', 'press', 'scrollTo', 'scroll', 'wait', 'waitFor'];
const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };

class Problem extends Error {
  constructor(kind, message) { super(message); this.kind = kind; }
}
const fail = (kind, message) => { throw new Problem(kind, message); };
const firstLine = (s) => String(s).split('\n')[0];
const q = (s) => JSON.stringify(s);
const rel = (out, file) => path.relative(out, file).split(path.sep).join('/');

// ---------------------------------------------------------------------------------------------------------------------
// Spec

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const only = (obj, allowed, where) => {
  if (!isObj(obj)) fail('spec', `${where} must be an object`);
  for (const k of Object.keys(obj)) if (!allowed.includes(k)) fail('spec', `${where}: unknown key ${q(k)} (allowed: ${allowed.join(', ')})`);
};
const num = (v, where, { min = -Infinity, max = Infinity, int = false } = {}) => {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < min || v > max || (int && !Number.isInteger(v))) {
    fail('spec', `${where} must be ${int ? 'an integer' : 'a number'}${min > -Infinity ? ` >= ${min}` : ''}${max < Infinity ? ` and <= ${max}` : ''}`);
  }
  return v;
};
const str = (v, where) => { if (typeof v !== 'string' || !v.trim()) fail('spec', `${where} must be a non-empty string`); return v; };
const slug = (s) => s.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^[-.]+|[-.]+$/g, '');

function viewportOf(v, where) {
  only(v, ['width', 'height'], where);
  return { width: num(v.width, `${where}.width`, { min: 1, max: 8192, int: true }), height: num(v.height, `${where}.height`, { min: 1, max: 8192, int: true }) };
}

function stepOf(st, where) {
  if (!isObj(st)) fail('spec', `${where} must be an object`);
  const actions = Object.keys(st).filter((k) => STEP_KEYS.includes(k));
  if (actions.length !== 1) fail('spec', `${where} needs exactly one action of ${STEP_KEYS.join(', ')}`);
  const action = actions[0];
  only(st, action === 'fill' ? ['fill', 'value'] : [action], where);
  if (action === 'wait') num(st.wait, `${where}.wait`, { min: 0, max: 30000 });
  else if (action === 'scroll') { only(st.scroll, ['x', 'y'], `${where}.scroll`); num(st.scroll.x ?? 0, `${where}.scroll.x`); num(st.scroll.y ?? 0, `${where}.scroll.y`); }
  else str(st[action], `${where}.${action}`);
  if (action === 'fill' && typeof st.value !== 'string') fail('spec', `${where}.value must be a string`);
  return st;
}

function targetOf(t, where) {
  only(t, ['selector', 'text', 'box', 'within', 'exact', 'nth', 'all', 'label', 'allowClipped'], where);
  const kinds = ['selector', 'text', 'box'].filter((k) => t[k] !== undefined);
  if (kinds.length !== 1) fail('spec', `${where} needs exactly one of selector, text, box`);
  const out = { kind: kinds[0], label: t.label === undefined ? undefined : str(t.label, `${where}.label`), allowClipped: t.allowClipped === true };
  if (t.allowClipped !== undefined && typeof t.allowClipped !== 'boolean') fail('spec', `${where}.allowClipped must be true or false`);
  if (out.kind === 'box') {
    only(t.box, ['x', 'y', 'width', 'height', 'w', 'h'], `${where}.box`);
    const w = t.box.width ?? t.box.w, h = t.box.height ?? t.box.h;
    out.box = { x: num(t.box.x, `${where}.box.x`), y: num(t.box.y, `${where}.box.y`), w: num(w, `${where}.box.width`, { min: 1 }), h: num(h, `${where}.box.height`, { min: 1 }) };
    for (const k of ['within', 'exact', 'nth', 'all']) if (t[k] !== undefined) fail('spec', `${where}: ${k} does not apply to a box`);
  } else {
    out[out.kind] = str(t[out.kind], `${where}.${out.kind}`);
    if (t.within !== undefined) { if (out.kind !== 'text') fail('spec', `${where}: within applies to text targets only`); out.within = str(t.within, `${where}.within`); }
    if (t.exact !== undefined) { if (out.kind !== 'text' || typeof t.exact !== 'boolean') fail('spec', `${where}: exact is true or false and applies to text targets only`); out.exact = t.exact; }
    if (t.nth !== undefined) out.nth = num(t.nth, `${where}.nth`, { min: 0, int: true });
    if (t.all !== undefined) { if (typeof t.all !== 'boolean') fail('spec', `${where}.all must be true or false`); out.all = t.all; }
    if (out.nth !== undefined && out.all) fail('spec', `${where}: nth and all cannot be combined`);
  }
  return out;
}

export function normalizeSpec(raw, specDir) {
  only(raw, ['defaults', 'sheet', 'items'], 'spec');
  const defaults = raw.defaults ?? {};
  only(defaults, ['viewport', 'deviceScaleFactor', 'colorScheme', 'fullPage', 'margin', 'upscale', 'color', 'crop'], 'defaults');
  const sheetIn = raw.sheet ?? {};
  only(sheetIn, ['columns', 'cellWidth', 'cellHeight', 'perSheet'], 'sheet');
  const sheet = {
    columns: num(sheetIn.columns ?? 3, 'sheet.columns', { min: 1, max: 8, int: true }),
    cellWidth: num(sheetIn.cellWidth ?? 480, 'sheet.cellWidth', { min: 100, max: 2000, int: true }),
    cellHeight: num(sheetIn.cellHeight ?? 400, 'sheet.cellHeight', { min: 100, max: 2000, int: true }),
    perSheet: num(sheetIn.perSheet ?? 9, 'sheet.perSheet', { min: 1, max: 40, int: true }),
  };
  if (!Array.isArray(raw.items) || raw.items.length === 0) fail('spec', 'items must be a non-empty array');

  const items = [];
  const names = new Set();
  for (const [i, it] of raw.items.entries()) {
    const where = `items[${i}]`;
    only(it, ['id', 'label', 'name', 'source', 'targets', 'margin', 'upscale', 'color', 'crop'], where);
    const id = str(it.id, `${where}.id`);
    const label = str(it.label, `${where}.label`);
    const name = slug(it.name === undefined ? id : str(it.name, `${where}.name`));
    if (!name) fail('spec', `${where}: name ${q(it.name ?? id)} leaves nothing after removing unsafe characters`);
    if (names.has(name)) fail('spec', `${where}: output name ${q(name)} is used twice; give each item its own "name"`);
    names.add(name);
    const pick = (k) => it[k] ?? defaults[k];
    const margin = num(pick('margin') ?? 40, `${where}.margin`, { min: 0, max: 2000 });
    const upscale = num(pick('upscale') ?? 1, `${where}.upscale`, { min: 1, max: 4 });
    const color = pick('color') ?? '#d00000';
    if (typeof color !== 'string' || !/^#[0-9a-fA-F]{6}$/.test(color)) fail('spec', `${where}.color must look like #d00000`);
    const crop = pick('crop') ?? 'marks';
    if (crop !== 'marks' && crop !== 'full') fail('spec', `${where}.crop must be "marks" or "full"`);
    if (!Array.isArray(it.targets) || it.targets.length === 0) fail('spec', `${where}.targets must be a non-empty array`);
    const targets = it.targets.map((t, j) => targetOf(t, `${where}.targets[${j}]`));

    const src = it.source;
    if (!isObj(src)) fail('spec', `${where}.source must be an object with url or image`);
    let source;
    if (src.image !== undefined) {
      only(src, ['image', 'name'], `${where}.source`);
      const file = path.resolve(specDir, str(src.image, `${where}.source.image`));
      const ext = path.extname(file).toLowerCase();
      if (!MIME[ext]) fail('spec', `${where}.source.image: ${ext || 'no extension'} is not supported (png, jpg, webp)`);
      source = { kind: 'image', file, ext, name: src.name === undefined ? slug(path.basename(file, path.extname(file))) : slug(str(src.name, `${where}.source.name`)), key: `image:${file}` };
      if (targets.some((t) => t.kind !== 'box')) fail('spec', `${where}: an image source has no page to search; use box targets (image coordinates)`);
    } else {
      only(src, ['url', 'name', 'viewport', 'deviceScaleFactor', 'colorScheme', 'fullPage', 'steps'], `${where}.source`);
      const url = str(src.url, `${where}.source.url`);
      let parsed;
      try { parsed = new URL(url); } catch { fail('spec', `${where}.source.url is not a valid URL`); }
      if (!['http:', 'https:', 'file:'].includes(parsed.protocol)) fail('spec', `${where}.source.url must be http, https or file`);
      const viewportIn = src.viewport ?? defaults.viewport;
      if (viewportIn === undefined) fail('spec', `${where}.source needs a viewport (set it in the source or in defaults)`);
      const dsf = num(src.deviceScaleFactor ?? defaults.deviceScaleFactor ?? 1, `${where}.source.deviceScaleFactor`, { min: 0.5, max: 4 });
      const scheme = src.colorScheme ?? defaults.colorScheme;
      if (scheme !== undefined && !['light', 'dark'].includes(scheme)) fail('spec', `${where}.source.colorScheme must be "light" or "dark"`);
      const fullPage = src.fullPage ?? defaults.fullPage ?? false;
      if (typeof fullPage !== 'boolean') fail('spec', `${where}.source.fullPage must be true or false`);
      if (src.steps !== undefined && !Array.isArray(src.steps)) fail('spec', `${where}.source.steps must be an array`);
      const steps = (src.steps ?? []).map((st, j) => stepOf(st, `${where}.source.steps[${j}]`));
      source = { kind: 'web', url, viewport: viewportOf(viewportIn, `${where}.source.viewport`), deviceScaleFactor: dsf, colorScheme: scheme, fullPage, steps, name: src.name === undefined ? undefined : slug(str(src.name, `${where}.source.name`)) };
      source.key = `web:${JSON.stringify([source.url, source.viewport, dsf, scheme ?? null, fullPage, steps])}`;
    }
    items.push({ index: i, id, label, name, source, targets, margin, upscale, color, crop });
  }

  // One capture per distinct source: findings on the same state reuse it.
  const captures = new Map();
  const taken = new Map();
  for (const item of items) {
    let cap = captures.get(item.source.key);
    if (!cap) {
      const name = item.source.name || item.name;
      if (!name) fail('spec', `items[${item.index}]: capture name is empty`);
      if (taken.has(name)) fail('spec', `items[${item.index}]: two different captures would be saved as ${q(name)}; give each source its own "name"`);
      cap = { name, source: item.source, items: [] };
      captures.set(item.source.key, cap);
      taken.set(name, true);
    }
    cap.items.push(item);
    item.capture = cap;
  }
  return { items, captures: [...captures.values()], sheet };
}

// ---------------------------------------------------------------------------------------------------------------------
// Layout (pure: no browser, no files). Sizes are in output pixels; boxes are {x, y, r, b} in scaled capture pixels.

const overlaps = (a, c) => a.x < c.r && c.x < a.r && a.y < c.b && c.y < a.b;
const inflate = (a, n) => ({ x: a.x - n, y: a.y - n, r: a.r + n, b: a.b + n });
const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);

const bands = (o, t) => [
  { x: o.x, y: o.y, r: o.r, b: o.y + t }, { x: o.x, y: o.b - t, r: o.r, b: o.b },
  { x: o.x, y: o.y, r: o.x + t, b: o.b }, { x: o.r - t, y: o.y, r: o.r, b: o.b },
];

export function layoutItem({ size, boxes, chips, margin, full, style = STYLE }) {
  const outer = boxes.map((b) => ({ x: b.x - style.reach, y: b.y - style.reach, r: b.r + style.reach, b: b.b + style.reach }));
  const rings = outer.map((o) => bands(o, style.outline));
  const placed = [];
  for (const [i, b] of boxes.entries()) {
    const o = outer[i], chip = chips[i];
    if (chip.w > size.w || chip.h > size.h) fail('evidence', `the label of target ${i + 1} (${chip.w}x${chip.h} px) is larger than the capture`);
    const xs = [o.x, o.r - chip.w, Math.round((o.x + o.r - chip.w) / 2), ...placed.flatMap((p) => [p.r + 3, p.x - chip.w - 3])]
      .map((x) => clamp(Math.round(x), 0, size.w - chip.w))
      .filter((x, k, all) => all.indexOf(x) === k && x < o.r && x + chip.w > o.x);
    const candidates = [
      ...xs.map((x) => ({ x, y: o.y - chip.h, side: 'above' })),
      ...xs.map((x) => ({ x, y: o.b, side: 'below' })),
      ...(chip.w <= b.r - b.x && chip.h <= b.b - b.y ? [{ x: b.x, y: b.y, side: 'inside' }] : []),
    ].map((c) => ({ ...c, w: chip.w, h: chip.h, r: c.x + chip.w, b: c.y + chip.h }));
    const spot = candidates.find((c) => c.x >= 0 && c.y >= 0 && c.r <= size.w && c.b <= size.h
      && !placed.some((p) => overlaps(inflate(c, 2), p)) && !rings.some((rs) => rs.some((band) => overlaps(c, band))));
    if (!spot) fail('evidence', `no free place for the label of target ${i + 1}: above, below and inside the box are cut off by the capture edge or taken by another label or outline. Split the item into one per box or shorten the label`);
    placed.push(spot);
  }
  let x0 = 0, y0 = 0, x1 = size.w, y1 = size.h;
  if (!full) {
    const parts = [...outer.map((o) => ({ x: Math.max(o.x, 0), y: Math.max(o.y, 0), r: Math.min(o.r, size.w), b: Math.min(o.b, size.h) })), ...placed];
    x0 = Math.max(0, Math.floor(Math.min(...parts.map((p) => p.x)) - margin));
    y0 = Math.max(0, Math.floor(Math.min(...parts.map((p) => p.y)) - margin));
    x1 = Math.min(size.w, Math.ceil(Math.max(...parts.map((p) => p.r)) + margin));
    y1 = Math.min(size.h, Math.ceil(Math.max(...parts.map((p) => p.b)) + margin));
  }
  const crop = { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
  if (crop.w > LIMITS.canvas || crop.h > LIMITS.canvas) fail('evidence', `the crop would be ${crop.w}x${crop.h} px; the drawing surface allows ${LIMITS.canvas}. Mark fewer boxes in this item or lower the upscale`);
  for (const [i, p] of placed.entries()) {
    if (p.x < crop.x || p.y < crop.y || p.r > crop.x + crop.w || p.b > crop.y + crop.h) fail('evidence', `the label of target ${i + 1} would be cut off by the crop`);
  }
  return { crop, chips: placed };
}

// Match choice shared by selector and text targets. `found` is [{x, y, w, h, visible}] in document order, in capture pixels.
export function chooseMatches(found, target, describe) {
  if (found.length === 0) fail('evidence', `${describe} was not found`);
  let pool = found;
  if (target.nth !== undefined) {
    pool = [found[target.nth]];
    if (!pool[0]) fail('evidence', `${describe}: nth ${target.nth} but only ${found.length} match${found.length === 1 ? '' : 'es'}`);
    if (!pool[0].visible) fail('evidence', `${describe}: match ${target.nth} is hidden or has no size`);
    return pool;
  }
  const visible = found.filter((f) => f.visible);
  if (visible.length === 0) fail('evidence', `${describe} matches ${found.length} element${found.length === 1 ? '' : 's'}, none visible with a size`);
  if (target.all) return visible;
  if (visible.length > 1) fail('evidence', `${describe} matches ${visible.length} visible elements (${visible.slice(0, 4).map((v) => `${Math.round(v.x)},${Math.round(v.y)} ${Math.round(v.w)}x${Math.round(v.h)}`).join('; ')}${visible.length > 4 ? '; ...' : ''}). Make it specific, or set nth or all`);
  return visible;
}

// Box against the capture. Returns the box clipped to the capture and whether it was clipped.
export function fitBox(b, size, allowClipped, describe, inPage = true) {
  const t = LIMITS.tolerance;
  const where = `box ${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.w)}x${Math.round(b.h)}; capture ${size.w}x${size.h}`;
  const move = inPage ? 'scroll it into view with a scrollTo step, or capture the full page' : 'check the coordinates against the image size';
  if (!(b.w >= 1 && b.h >= 1)) fail('evidence', `${describe} has no size (${b.w}x${b.h})`);
  const x0 = Math.max(b.x, 0), y0 = Math.max(b.y, 0), x1 = Math.min(b.x + b.w, size.w), y1 = Math.min(b.y + b.h, size.h);
  if (x1 - x0 < 1 || y1 - y0 < 1) fail('evidence', `${describe} lies outside the capture (${where}). ${move}`);
  const clipped = b.x < -t || b.y < -t || b.x + b.w > size.w + t || b.y + b.h > size.h + t;
  if (clipped && !allowClipped) {
    const sides = [b.x < -t && 'left', b.y < -t && 'top', b.x + b.w > size.w + t && 'right', b.y + b.h > size.h + t && 'bottom'].filter(Boolean).join(' and ');
    fail('evidence', `${describe} runs past the ${sides} edge of the capture (${where}). If that overflow is the finding, set allowClipped on the target; otherwise ${move}`);
  }
  return { box: { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }, clipped };
}

// ---------------------------------------------------------------------------------------------------------------------
// Functions that run inside the browser. Playwright serializes them, so each must stay self-contained.

async function pageLoadImage({ key, b64, mime }) {
  const img = new Image();
  const done = new Promise((resolve, reject) => { img.onload = resolve; img.onerror = () => reject(new Error('the image could not be decoded')); });
  img.src = `data:${mime};base64,${b64}`;
  await done;
  (window.__imgs ||= new Map()).set(key, img);
  return { w: img.naturalWidth, h: img.naturalHeight };
}

function pageMeasure({ texts, font, padX, padY, lineH, maxWidth }) {
  const ctx = document.createElement('canvas').getContext('2d');
  ctx.font = font;
  return texts.map((text) => {
    const lines = [];
    let line = '';
    for (const word of text.split(/\s+/).filter(Boolean)) {
      const next = line ? `${line} ${word}` : word;
      if (line && ctx.measureText(next).width > maxWidth - 2 * padX) { lines.push(line); line = word; } else line = next;
    }
    lines.push(line);
    const width = Math.max(...lines.map((l) => ctx.measureText(l).width));
    return { lines, w: Math.ceil(width) + 2 * padX, h: lines.length * lineH + 2 * padY };
  });
}

async function pagePaint({ key, scale, crop, marks, color, style }) {
  const img = window.__imgs.get(key);
  const cv = document.createElement('canvas');
  cv.width = crop.w;
  cv.height = crop.h;
  const ctx = cv.getContext('2d');
  ctx.imageSmoothingEnabled = scale !== 1;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(img, crop.x / scale, crop.y / scale, crop.w / scale, crop.h / scale, 0, 0, crop.w, crop.h);
  ctx.strokeStyle = color;
  ctx.lineWidth = style.outline;
  const d = style.offset + style.outline / 2;
  for (const m of marks) ctx.strokeRect(m.box.x - crop.x - d, m.box.y - crop.y - d, m.box.r - m.box.x + 2 * d, m.box.b - m.box.y + 2 * d);
  ctx.font = style.font;
  ctx.textBaseline = 'middle';
  for (const m of marks) {
    ctx.fillStyle = color;
    ctx.fillRect(m.chip.x - crop.x, m.chip.y - crop.y, m.chip.w, m.chip.h);
    ctx.fillStyle = '#ffffff';
    m.chip.lines.forEach((l, i) => ctx.fillText(l, m.chip.x - crop.x + style.padX, m.chip.y - crop.y + style.padY + style.lineH * i + style.lineH / 2));
  }
  return cv.toDataURL('image/png');
}

async function pageSheet({ cells, columns, cellWidth, cellHeight, font }) {
  const gap = 16, cap = 44;
  const items = cells.map((c) => {
    const img = window.__imgs.get(c.key);
    const k = Math.min(1, cellWidth / img.naturalWidth, cellHeight / img.naturalHeight);
    return { ...c, img, k, dw: Math.max(1, Math.round(img.naturalWidth * k)), dh: Math.max(1, Math.round(img.naturalHeight * k)) };
  });
  const cols = Math.min(columns, items.length);
  const rows = [];
  for (let i = 0; i < items.length; i += cols) rows.push(items.slice(i, i + cols));
  const heights = rows.map((r) => cap + Math.max(...r.map((c) => c.dh)));
  const width = gap + cols * (cellWidth + gap);
  const height = gap + heights.reduce((a, h) => a + h + gap, 0);
  const cv = document.createElement('canvas');
  cv.width = width;
  cv.height = height;
  const ctx = cv.getContext('2d');
  ctx.fillStyle = '#e9e9e9';
  ctx.fillRect(0, 0, width, height);
  ctx.textBaseline = 'top';
  const fit = (text, max) => { let t = text; while (t.length > 1 && ctx.measureText(t).width > max) t = t.slice(0, -1); return t === text ? t : `${t.slice(0, -2)}..`; };
  let y = gap;
  rows.forEach((r, ri) => {
    r.forEach((c, ci) => {
      const x = gap + ci * (cellWidth + gap);
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(x, y, cellWidth, heights[ri]);
      ctx.fillStyle = '#111111';
      ctx.font = `bold 14px ${font}`;
      ctx.fillText(fit(c.title, cellWidth - 12), x + 6, y + 5);
      ctx.fillStyle = '#444444';
      ctx.font = `13px ${font}`;
      ctx.fillText(fit(`${c.sub}  shown at ${Math.round(c.k * 100)}%`, cellWidth - 12), x + 6, y + 24);
      ctx.drawImage(c.img, x + Math.round((cellWidth - c.dw) / 2), y + cap, c.dw, c.dh);
      ctx.strokeStyle = '#bbbbbb';
      ctx.lineWidth = 1;
      ctx.strokeRect(x + 0.5, y + 0.5, cellWidth - 1, heights[ri] - 1);
    });
    y += heights[ri] + gap;
  });
  return { url: cv.toDataURL('image/png'), w: width, h: height };
}

// In the captured page: boxes of the elements a selector matches (all of them, in document order).
function pageRects(els) {
  return els.map((el) => {
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    return { x: r.x, y: r.y, w: r.width, h: r.height, visible: r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none' };
  });
}

// In the captured page: the smallest elements whose text contains the needle (a match inside a child is preferred to its parent).
function pageFindText({ text, within, exact }) {
  const norm = (s) => s.replace(/\s+/g, ' ').trim();
  const needle = norm(text);
  const root = within ? document.querySelector(within) : document.body;
  if (!root) return { missingRoot: true, hits: [] };
  const skip = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'HEAD', 'TITLE', 'META', 'LINK']);
  const hits = [];
  const walk = (el) => {
    if (skip.has(el.tagName)) return false;
    const t = norm(el.textContent || '');
    if (!(exact ? t === needle : t.includes(needle))) return false;
    let deeper = false;
    for (const c of el.children) if (walk(c)) deeper = true;
    if (!deeper) hits.push(el);
    return true;
  };
  walk(root);
  return { missingRoot: false, hits: hits.map((el) => {
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    return { x: r.x, y: r.y, w: r.width, h: r.height, visible: r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none' };
  }) };
}

// ---------------------------------------------------------------------------------------------------------------------
// Capture and measurement

const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');
const pngSize = (buf) => (buf.length > 24 && buf.readUInt32BE(0) === 0x89504e47 ? { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) } : null);
const describeTarget = (t) => (t.kind === 'selector' ? `selector ${q(t.selector)}` : t.kind === 'text' ? `text ${q(t.text)}${t.within ? ` within ${q(t.within)}` : ''}` : `box ${q(t.box)}`);

async function runStep(page, st) {
  const timeout = 5000;
  if (st.click !== undefined) await page.locator(st.click).click({ timeout });
  else if (st.hover !== undefined) await page.locator(st.hover).hover({ timeout });
  else if (st.focus !== undefined) await page.locator(st.focus).focus({ timeout });
  else if (st.fill !== undefined) await page.locator(st.fill).fill(st.value, { timeout });
  else if (st.press !== undefined) await page.keyboard.press(st.press);
  else if (st.scrollTo !== undefined) await page.locator(st.scrollTo).scrollIntoViewIfNeeded({ timeout });
  else if (st.scroll !== undefined) await page.evaluate(({ x, y }) => window.scrollTo(x ?? 0, y ?? 0), st.scroll);
  else if (st.wait !== undefined) await page.waitForTimeout(st.wait);
  else if (st.waitFor !== undefined) await page.locator(st.waitFor).waitFor({ state: 'visible', timeout });
}

// Boxes of one web target in capture pixels. Throws Problem('evidence') when it cannot be marked as asked.
async function resolveWeb(page, t, dsf) {
  const describe = describeTarget(t);
  let found;
  if (t.kind === 'selector') {
    try {
      found = await page.locator(t.selector).evaluateAll(pageRects);
    } catch (e) {
      fail('evidence', `${describe} could not be evaluated: ${firstLine(e.message)}`);
    }
  } else {
    const res = await page.evaluate(pageFindText, { text: t.text, within: t.within, exact: t.exact === true });
    if (res.missingRoot) fail('evidence', `${describe}: the "within" container was not found`);
    found = res.hits;
  }
  return chooseMatches(found, t, describe).map((f) => ({ x: f.x * dsf, y: f.y * dsf, w: f.w * dsf, h: f.h * dsf }));
}

const sameBoxes = (a, b) => a.length === b.length && a.every((list, i) => list.length === b[i].length && list.every((x, j) => ['x', 'y', 'w', 'h'].every((k) => Math.abs(x[k] - b[i][j][k]) <= LIMITS.tolerance)));

async function measureAll(page, cap, dsf) {
  const results = [];
  for (const item of cap.items) {
    for (const t of item.targets) {
      if (t.kind === 'box') { results.push({ item, t, boxes: [{ ...t.box }], error: null }); continue; }
      try {
        results.push({ item, t, boxes: await resolveWeb(page, t, dsf), error: null });
      } catch (e) {
        if (!(e instanceof Problem)) throw e;
        results.push({ item, t, boxes: [], error: e });
      }
    }
  }
  return results;
}

async function captureWeb(browser, cap, ctx) {
  const s = cap.source;
  const context = await browser.newContext({ viewport: s.viewport, deviceScaleFactor: s.deviceScaleFactor, colorScheme: s.colorScheme });
  try {
    const page = await context.newPage();
    let status = null;
    try {
      const resp = await page.goto(s.url, { waitUntil: 'load', timeout: 30000 });
      status = resp ? resp.status() : null;
    } catch (e) {
      fail('capture', `${s.url} did not open: ${firstLine(e.message)}`);
    }
    if (status !== null && status >= 400) console.error(`warning: ${s.url} answered ${status}; the capture shows that response`);
    for (const [i, st] of s.steps.entries()) {
      try { await runStep(page, st); } catch (e) { fail('capture', `step ${i + 1} ${JSON.stringify(st)} failed: ${firstLine(e.message)}`); }
    }
    await page.evaluate(() => (document.fonts ? document.fonts.ready.then(() => true) : true));
    if (s.fullPage) await page.evaluate(() => window.scrollTo(0, 0));
    const before = await measureAll(page, cap, s.deviceScaleFactor);
    const buf = await page.screenshot({ type: 'png', fullPage: s.fullPage });
    const after = await measureAll(page, cap, s.deviceScaleFactor);
    const movedAt = before.findIndex((b, i) => !b.error && (after[i].error || !sameBoxes([b.boxes], [after[i].boxes])));
    if (movedAt >= 0) fail('capture', `the layout moved while capturing (${describeTarget(before[movedAt].t)}). Add a wait or waitFor step so the state is still, then run again`);
    const dims = pngSize(buf);
    if (!dims) fail('capture', 'the browser returned something that is not a PNG');
    if (!s.fullPage && (dims.w !== Math.round(s.viewport.width * s.deviceScaleFactor) || dims.h !== Math.round(s.viewport.height * s.deviceScaleFactor))) {
      fail('capture', `the screenshot is ${dims.w}x${dims.h} px, not the viewport ${s.viewport.width}x${s.viewport.height} at scale ${s.deviceScaleFactor}`);
    }
    return { buf, ext: '.png', mime: 'image/png', measured: before, meta: { status, capturedAt: new Date().toISOString(), browser: ctx.browserVersion } };
  } finally {
    await context.close();
  }
}

function captureImage(cap) {
  const s = cap.source;
  let buf;
  try { buf = readFileSync(s.file); } catch (e) { fail('capture', `image ${s.file} could not be read: ${firstLine(e.message)}`); }
  if (buf.length === 0) fail('capture', `image ${s.file} is empty`);
  const measured = [];
  for (const item of cap.items) for (const t of item.targets) measured.push({ item, t, boxes: [{ ...t.box }], error: null });
  return { buf, ext: s.ext, mime: MIME[s.ext], measured, meta: { sourcePath: s.file } };
}

// ---------------------------------------------------------------------------------------------------------------------
// Files

function writeChecked(file, buf, expect = {}) {
  try {
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, buf);
  } catch (e) {
    fail('output', `${file} could not be written: ${firstLine(e.message)}`);
  }
  let back;
  try {
    if (statSync(file).size !== buf.length) fail('output', `${file} was written with the wrong size`);
    back = readFileSync(file);
  } catch (e) {
    if (e instanceof Problem) throw e;
    fail('output', `${file} is missing after writing: ${firstLine(e.message)}`);
  }
  if (!back.equals(buf)) fail('output', `${file} does not hold the bytes that were written`);
  if (expect.w) {
    const got = pngSize(back);
    if (!got || got.w !== expect.w || got.h !== expect.h) fail('output', `${file} is not a PNG of ${expect.w}x${expect.h} px`);
  }
}

function saveOriginal(cap, shot, out, recapture) {
  const file = path.join(out, 'original', `${cap.name}${shot.ext}`);
  if (existsSync(file)) {
    if (cap.source.kind === 'image' && path.resolve(cap.source.file) === path.resolve(file)) return file;
    if (!readFileSync(file).equals(shot.buf)) {
      if (!recapture) fail('output', `${rel(out, file)} already exists and differs from this capture. Originals are not replaced; pass --recapture to take the capture again, or give the source another name`);
    } else return file;
  }
  writeChecked(file, shot.buf, cap.source.kind === 'web' ? pngSize(shot.buf) : {});
  return file;
}

// ---------------------------------------------------------------------------------------------------------------------
// Playwright

function loadPlaywright() {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const typed = process.argv[1] ? path.dirname(path.resolve(process.argv[1])) : here;
  const bases = [
    here,
    path.resolve(here, '../../../engineering/real-check/scripts'),
    path.resolve(here, '../../real-check/scripts'),
    path.resolve(typed, '../../real-check/scripts'),
    process.cwd(),
  ];
  for (const base of bases) {
    try { return createRequire(path.join(base, 'noop.js'))('playwright'); } catch { /* try the next place */ }
  }
  return null;
}

// ---------------------------------------------------------------------------------------------------------------------
// Run

async function run(spec, out, opts) {
  const result = { ok: false, out, items: [], captures: [], sheets: [], errors: [] };
  const playwright = loadPlaywright();
  if (!playwright) {
    console.error('Playwright is not installed. Run: npm install --prefix <skills>/engineering/real-check/scripts && npx --prefix <skills>/engineering/real-check/scripts playwright install chromium (this script reuses real-check\'s install when it sits next to real-audit; otherwise install playwright in this folder or the current one).');
    return { code: EXIT.output, silent: true, result };
  }
  let browser;
  try {
    browser = await playwright.chromium.launch();
  } catch (e) {
    const hint = /Executable doesn't exist|browserType\.launch/.test(e.message) ? '\nThe Chromium browser is missing. Run: npx playwright install chromium (in the folder where Playwright is installed)' : '';
    console.error(`The browser could not start: ${firstLine(e.message)}${hint}`);
    return { code: EXIT.output, silent: true, result };
  }
  const problems = [];
  const note = (item, e) => {
    if (!(e instanceof Problem)) throw e;
    problems.push({ id: item ? item.id : null, name: item ? item.name : null, kind: e.kind, message: e.message });
    console.error(`ERROR${item ? ` [${item.id}]` : ''}: ${e.message}`);
  };
  const sheets = [];
  try {
    mkdirSync(out, { recursive: true });
    const draw = await browser.newPage();
    await draw.goto('about:blank');
    const ctx = { browserVersion: `Chromium ${browser.version()}` };
    const captured = new Map();

    for (const cap of spec.captures) {
      try {
        const shot = cap.source.kind === 'web' ? await captureWeb(browser, cap, ctx) : captureImage(cap);
        let size;
        try {
          size = await draw.evaluate(pageLoadImage, { key: `cap:${cap.name}`, b64: shot.buf.toString('base64'), mime: shot.mime });
        } catch (e) {
          fail('capture', `${cap.name}: ${firstLine(e.message)}`);
        }
        const file = saveOriginal(cap, shot, out, opts.recapture);
        captured.set(cap, { shot, size, file });
        result.captures.push({
          name: cap.name, kind: cap.source.kind, original: rel(out, file), sha256: sha256(shot.buf), width: size.w, height: size.h,
          ...(cap.source.kind === 'web'
            ? { url: cap.source.url, viewport: cap.source.viewport, deviceScaleFactor: cap.source.deviceScaleFactor, colorScheme: cap.source.colorScheme ?? null, fullPage: cap.source.fullPage, steps: cap.source.steps, httpStatus: shot.meta.status, capturedAt: shot.meta.capturedAt, browser: shot.meta.browser }
            : { sourceImage: cap.source.file }),
        });
        console.log(`captured ${cap.name} ${size.w}x${size.h} px -> ${rel(out, file)}`);
      } catch (e) {
        note({ id: cap.items.map((item) => item.id).join(', '), name: cap.name }, e);
      }
    }

    for (const cap of spec.captures) {
      const got = captured.get(cap);
      if (!got) continue;
      for (const item of cap.items) {
        try {
          result.items.push(await markItem(item, got, draw, out));
        } catch (e) {
          note(item, e);
        }
      }
    }

    if (problems.length === 0) {
      const order = spec.items.map((it) => it.name);
      const marked = result.items.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));
      for (let from = 0, n = 1; from < marked.length; from += spec.sheet.perSheet, n++) {
        const group = marked.slice(from, from + spec.sheet.perSheet);
        const name = marked.length <= spec.sheet.perSheet ? 'contact-sheet.png' : `contact-sheet-${n}.png`;
        try {
          const cells = [];
          for (const [i, m] of group.entries()) {
            const buf = readFileSync(path.join(out, m.marked));
            await draw.evaluate(pageLoadImage, { key: `marked:${m.name}`, b64: buf.toString('base64'), mime: 'image/png' });
            cells.push({ key: `marked:${m.name}`, title: `${from + i + 1}. ${m.id}  ${m.label}`, sub: `${path.basename(m.marked)} ${m.width}x${m.height}` });
          }
          const sheet = await draw.evaluate(pageSheet, { cells, columns: spec.sheet.columns, cellWidth: spec.sheet.cellWidth, cellHeight: spec.sheet.cellHeight, font: STYLE.font });
          const buf = Buffer.from(sheet.url.split(',')[1], 'base64');
          writeChecked(path.join(out, name), buf, { w: sheet.w, h: sheet.h });
          sheets.push(name);
          console.log(`contact sheet ${name} ${sheet.w}x${sheet.h} px (${group.length} crops)`);
        } catch (e) {
          note(null, e);
        }
      }
    }
  } finally {
    await browser.close();
  }
  result.sheets = sheets;
  result.errors = problems;
  result.ok = problems.length === 0;
  const code = problems.length === 0 ? 0 : Math.max(...problems.map((p) => EXIT[p.kind]));
  return { code, silent: false, result };
}

async function markItem(item, got, draw, out) {
  const { shot, size, file } = got;
  const W = size.w, H = size.h;
  const s = item.upscale;
  const S = { w: Math.ceil(W * s), h: Math.ceil(H * s) };
  const mine = shot.measured.filter((m) => m.item === item);
  const targets = [];
  for (const m of mine) {
    if (m.error) throw m.error;
    const describe = describeTarget(m.t);
    for (const raw of m.boxes) {
      const { box, clipped } = fitBox(raw, { w: W, h: H }, m.t.allowClipped, describe, m.t.kind !== 'box');
      targets.push({ t: m.t, describe, box, clipped, first: m.boxes[0] === raw });
    }
  }
  // Chip text: a target's own label, else "<id> <label>" for the very first box; every other box gets "<id>" alone.
  const texts = targets.map((x, i) => `${item.id}${x.first ? (x.t.label ? ` ${x.t.label}` : i === 0 ? ` ${item.label}` : '') : ''}`);
  const sizes = await draw.evaluate(pageMeasure, { texts, font: STYLE.font, padX: STYLE.padX, padY: STYLE.padY, lineH: STYLE.lineH, maxWidth: Math.min(STYLE.chipMaxWidth, S.w - 2) });
  const boxes = targets.map((x) => ({ x: Math.floor(x.box.x * s), y: Math.floor(x.box.y * s), r: Math.ceil((x.box.x + x.box.w) * s), b: Math.ceil((x.box.y + x.box.h) * s) }));
  const placed = layoutItem({ size: S, boxes, chips: sizes, margin: item.margin * s, full: item.crop === 'full' });
  const marks = boxes.map((box, i) => ({ box, chip: { ...placed.chips[i], lines: sizes[i].lines } }));
  const url = await draw.evaluate(pagePaint, { key: `cap:${item.capture.name}`, scale: s, crop: placed.crop, marks, color: item.color, style: STYLE });
  const buf = Buffer.from(url.split(',')[1], 'base64');
  const markedFile = path.join(out, 'marked', `${item.name}.png`);
  writeChecked(markedFile, buf, { w: placed.crop.w, h: placed.crop.h });
  console.log(`marked ${item.id} ${targets.length} box${targets.length === 1 ? '' : 'es'} -> ${rel(out, markedFile)} ${placed.crop.w}x${placed.crop.h} px`);
  const r2 = (n) => Math.round(n * 100) / 100;
  return {
    id: item.id, label: item.label, name: item.name, capture: item.capture.name, original: rel(out, file), marked: rel(out, markedFile),
    width: placed.crop.w, height: placed.crop.h, scale: s,
    crop: { x: r2(placed.crop.x / s), y: r2(placed.crop.y / s), width: r2(placed.crop.w / s), height: r2(placed.crop.h / s) },
    targets: targets.map((x, i) => ({ found: x.describe, box: { x: r2(x.box.x), y: r2(x.box.y), width: r2(x.box.w), height: r2(x.box.h) }, clippedToCapture: x.clipped, chip: texts[i], chipSide: placed.chips[i].side })),
  };
}

async function main(argv) {
  let parsed;
  try {
    parsed = parseArgs({ args: argv, allowPositionals: true, options: { out: { type: 'string' }, recapture: { type: 'boolean' }, help: { type: 'boolean', short: 'h' } } });
  } catch (e) {
    console.error(`${firstLine(e.message)}\n${USAGE}`);
    return EXIT.spec;
  }
  const { values, positionals } = parsed;
  if (values.help) { console.log(USAGE); return 0; }
  if (positionals.length !== 1 || !values.out) { console.error(USAGE); return EXIT.spec; }
  if (Number(process.versions.node.split('.')[0]) < 20) { console.error(`This script needs Node 20 or newer (found ${process.versions.node}).`); return EXIT.output; }
  const specFile = path.resolve(positionals[0]);
  let spec;
  try {
    let raw;
    try { raw = JSON.parse(readFileSync(specFile, 'utf8')); } catch (e) { fail('spec', `${specFile} could not be read as JSON: ${firstLine(e.message)}`); }
    spec = normalizeSpec(raw, path.dirname(specFile));
  } catch (e) {
    if (!(e instanceof Problem)) throw e;
    console.error(`Spec error: ${e.message}\n${USAGE}`);
    return EXIT.spec;
  }
  const out = path.resolve(values.out);
  for (const cap of spec.captures) {
    if (cap.source.kind !== 'image') continue;
    const inOut = path.relative(out, cap.source.file);
    if (!inOut.startsWith('..') && !path.isAbsolute(inOut) && !inOut.startsWith(`original${path.sep}`)) {
      console.error(`Spec error: ${cap.source.file} is inside the output folder but not in original/; it could be overwritten. Move it or use another --out.\n${USAGE}`);
      return EXIT.spec;
    }
  }
  const { code, silent, result } = await run(spec, out, { recapture: values.recapture === true });
  if (!silent) {
    const manifest = path.join(out, 'manifest.json');
    try {
      writeChecked(manifest, Buffer.from(`${JSON.stringify({ ...result, generatedAt: new Date().toISOString(), spec: specFile }, null, 2)}\n`));
    } catch (e) {
      if (!(e instanceof Problem)) throw e;
      console.error(`ERROR: ${e.message}`);
      return EXIT.output;
    }
    console.log(JSON.stringify({ ok: result.ok, out, manifest, sheets: result.sheets, items: result.items.map((i) => ({ id: i.id, marked: i.marked })), errors: result.errors }));
  }
  return code;
}

// Run only as a script. The skill is installed as a symlink: compare real paths.
const isEntry = (() => { try { return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url)); } catch { return false; } })();
if (isEntry) {
  try {
    process.exitCode = await main(process.argv.slice(2));
  } catch (e) {
    console.error(`The run could not finish: ${firstLine(e.stack || e.message)}`);
    process.exitCode = EXIT.output;
  }
}
