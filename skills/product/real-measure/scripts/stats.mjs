#!/usr/bin/env node
// stats.mjs: the arithmetic of real-measure. Node 20+, standard library only, no network, no model.
//
//   node scripts/stats.mjs <input.json>     read the input from a file
//   node scripts/stats.mjs -                read the input from standard input
//
// The input holds aggregates. The output is one JSON document: an interval, a sample check and a status for each metric,
// and one verdict for the run. The agent never does this arithmetic itself. See references/metrics.md for the input format.
//
// Exit code: 0 the result is printed, 2 the input is not valid (the message is on standard error).

import { readFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const DEFAULTS = { alpha: 0.05, minEvents: 100, minUnits: 30, bootstrapRounds: 2000, seed: 12345 };

class InputError extends Error {}
const fail = (message) => {
  throw new InputError(message);
};

// ---------------------------------------------------------------------------------------------------------------------
// Distributions
// ---------------------------------------------------------------------------------------------------------------------

/** Standard normal CDF, from the complementary error function. */
export function normalCdf(x) {
  return 0.5 * erfc(-x / Math.SQRT2);
}

function erfc(x) {
  const z = Math.abs(x);
  let result;
  if (z < 3) {
    // Maclaurin series of erf. It converges fast for |x| < 3.
    let term = z;
    let sum = z;
    for (let n = 1; n < 100; n++) {
      term *= (-z * z) / n;
      const add = term / (2 * n + 1);
      sum += add;
      if (Math.abs(add) < 1e-17 * Math.abs(sum)) break;
    }
    result = 1 - (2 / Math.sqrt(Math.PI)) * sum;
  } else {
    // Continued fraction of erfc for large |x|.
    let f = 0;
    for (let k = 60; k >= 1; k--) f = k / 2 / (z + f);
    result = Math.exp(-z * z) / Math.sqrt(Math.PI) / (z + f);
  }
  return x >= 0 ? result : 2 - result;
}

/** Inverse of the standard normal CDF (Acklam's rational fit plus one Halley step). Argument in (0, 1). */
export function normalQuantile(p) {
  if (!(p > 0 && p < 1)) fail(`normalQuantile needs 0 < p < 1, got ${p}`);
  const a = [-39.69683028665376, 220.9460984245205, -275.9285104469687, 138.357751867269, -30.66479806614716, 2.506628277459239];
  const b = [-54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972, -13.28068155288572];
  const c = [-0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734, 4.374664141464968, 2.938163982698783];
  const d = [0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416];
  let x;
  if (p < 0.02425) {
    const q = Math.sqrt(-2 * Math.log(p));
    x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  } else if (p > 1 - 0.02425) {
    const q = Math.sqrt(-2 * Math.log(1 - p));
    x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  } else {
    const q = p - 0.5;
    const r = q * q;
    x = ((((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q) / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
  }
  const e = normalCdf(x) - p;
  const u = e * Math.sqrt(2 * Math.PI) * Math.exp((x * x) / 2);
  return x - u / (1 + (x * u) / 2);
}

function logGamma(x) {
  // Lanczos approximation, g = 7.
  const g = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7];
  if (x < 0.5) return Math.log(Math.PI / Math.sin(Math.PI * x)) - logGamma(1 - x);
  const y = x - 1;
  let sum = g[0];
  for (let i = 1; i < 9; i++) sum += g[i] / (y + i);
  const t = y + 7.5;
  return 0.5 * Math.log(2 * Math.PI) + (y + 0.5) * Math.log(t) - t + Math.log(sum);
}

/** Regularized incomplete beta function I_x(a, b), by the continued fraction of Lentz. */
function incompleteBeta(x, a, b) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  const front = Math.exp(logGamma(a + b) - logGamma(a) - logGamma(b) + a * Math.log(x) + b * Math.log(1 - x));
  const fraction = (x, a, b) => {
    const tiny = 1e-300;
    let c = 1;
    let d = 1 - ((a + b) * x) / (a + 1);
    d = Math.abs(d) < tiny ? 1 / tiny : 1 / d;
    let h = d;
    for (let m = 1; m <= 500; m++) {
      const m2 = 2 * m;
      let aa = (m * (b - m) * x) / ((a + m2 - 1) * (a + m2));
      d = 1 + aa * d;
      d = Math.abs(d) < tiny ? tiny : d;
      c = 1 + aa / c;
      c = Math.abs(c) < tiny ? tiny : c;
      d = 1 / d;
      h *= d * c;
      aa = (-(a + m) * (a + b + m) * x) / ((a + m2) * (a + m2 + 1));
      d = 1 + aa * d;
      d = Math.abs(d) < tiny ? tiny : d;
      c = 1 + aa / c;
      c = Math.abs(c) < tiny ? tiny : c;
      d = 1 / d;
      const delta = d * c;
      h *= delta;
      if (Math.abs(delta - 1) < 1e-15) break;
    }
    return h;
  };
  return x < (a + 1) / (a + b + 2) ? (front * fraction(x, a, b)) / a : 1 - (front * fraction(1 - x, b, a)) / b;
}

/** CDF of Student's t with df degrees of freedom (df may be fractional). */
export function tCdf(t, df) {
  const x = df / (df + t * t);
  const tail = 0.5 * incompleteBeta(x, df / 2, 0.5);
  return t > 0 ? 1 - tail : tail;
}

/** Quantile of Student's t. Bisection on the CDF. */
export function tQuantile(p, df) {
  if (!(p > 0 && p < 1)) fail(`tQuantile needs 0 < p < 1, got ${p}`);
  if (!(df > 0)) fail(`tQuantile needs df > 0, got ${df}`);
  if (p === 0.5) return 0;
  if (p < 0.5) return -tQuantile(1 - p, df);
  let lo = 0;
  let hi = 1;
  while (tCdf(hi, df) < p) hi *= 2;
  for (let i = 0; i < 200; i++) {
    const mid = (lo + hi) / 2;
    if (tCdf(mid, df) < p) lo = mid;
    else hi = mid;
    if (hi - lo < 1e-13 * Math.max(1, hi)) break;
  }
  return (lo + hi) / 2;
}

// ---------------------------------------------------------------------------------------------------------------------
// Intervals for the difference "after minus before"
// ---------------------------------------------------------------------------------------------------------------------

const interval = (diff, se, crit, p) => ({ diff, se, lo: diff - crit * se, hi: diff + crit * se, p });

/** Two rates. Wald interval of the difference, unpooled. The p value is the pooled two-proportion z test. */
export function rateInterval(before, after, alpha = DEFAULTS.alpha) {
  const p1 = before.num / before.den;
  const p2 = after.num / after.den;
  const se = Math.sqrt((p1 * (1 - p1)) / before.den + (p2 * (1 - p2)) / after.den);
  const pooled = (before.num + after.num) / (before.den + after.den);
  const sePooled = Math.sqrt(pooled * (1 - pooled) * (1 / before.den + 1 / after.den));
  const z = sePooled > 0 ? (p2 - p1) / sePooled : 0;
  const p = 2 * (1 - normalCdf(Math.abs(z)));
  return { before: p1, after: p2, ...interval(p2 - p1, se, normalQuantile(1 - alpha / 2), p), method: 'two-proportion (Wald interval)' };
}

/** Two means from summary numbers { n, mean, sd }. Welch interval, Satterthwaite degrees of freedom. */
export function meanInterval(before, after, alpha = DEFAULTS.alpha) {
  const v1 = (before.sd * before.sd) / before.n;
  const v2 = (after.sd * after.sd) / after.n;
  const se = Math.sqrt(v1 + v2);
  const diff = after.mean - before.mean;
  if (se === 0) return { before: before.mean, after: after.mean, diff, se, lo: diff, hi: diff, p: diff === 0 ? 1 : 0, df: Infinity, method: 'Welch (zero spread)' };
  const df = (v1 + v2) ** 2 / ((v1 * v1) / (before.n - 1) + (v2 * v2) / (after.n - 1));
  const p = 2 * (1 - tCdf(Math.abs(diff / se), df));
  return { before: before.mean, after: after.mean, ...interval(diff, se, tQuantile(1 - alpha / 2, df), p), df, method: 'Welch' };
}

/** A small seeded generator (mulberry32). The same seed gives the same interval on every run. */
function generator(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const average = (values) => values.reduce((sum, v) => sum + v, 0) / values.length;
const middle = (values) => {
  const sorted = [...values].sort((x, y) => x - y);
  const half = sorted.length >> 1;
  return sorted.length % 2 ? sorted[half] : (sorted[half - 1] + sorted[half]) / 2;
};

/** Percentile bootstrap of the difference of means (or medians) for skewed values. Values are anonymous units. */
export function bootstrapInterval(before, after, { alpha = DEFAULTS.alpha, rounds = DEFAULTS.bootstrapRounds, seed = DEFAULTS.seed, statistic = 'mean' } = {}) {
  const stat = statistic === 'median' ? middle : average;
  const random = generator(seed);
  const draw = (values) => Array.from({ length: values.length }, () => values[Math.floor(random() * values.length)]);
  const diffs = [];
  for (let i = 0; i < rounds; i++) diffs.push(stat(draw(after)) - stat(draw(before)));
  diffs.sort((x, y) => x - y);
  const at = (q) => diffs[Math.min(diffs.length - 1, Math.max(0, Math.floor(q * diffs.length)))];
  const diff = stat(after) - stat(before);
  const crossed = diffs.filter((d) => d <= 0).length / diffs.length;
  return { before: stat(before), after: stat(after), diff, se: null, lo: at(alpha / 2), hi: at(1 - alpha / 2), p: Math.min(1, 2 * Math.min(crossed, 1 - crossed)), method: `bootstrap of the ${statistic} (${rounds} rounds, seed ${seed})` };
}

// ---------------------------------------------------------------------------------------------------------------------
// Sample minimum, status of one metric, verdict of the run
// ---------------------------------------------------------------------------------------------------------------------

/** Minimum sample. A rate needs minEvents events and minEvents non-events in each window. A mean needs minUnits units in each window. */
export function minimumSample(metric, { minEvents = DEFAULTS.minEvents, minUnits = DEFAULTS.minUnits } = {}) {
  const shortfall = {};
  const windows = ['before', 'after'];
  if (metric.kind === 'rate') {
    for (const w of windows) {
      const { num, den } = metric[w];
      const events = Math.max(0, minEvents - num);
      const rest = Math.max(0, minEvents - (den - num));
      if (events) shortfall[`${w}_events`] = events;
      if (rest) shortfall[`${w}_non_events`] = rest;
    }
  } else {
    for (const w of windows) {
      const n = metric.kind === 'mean' ? metric[w].n : metric[w].length;
      if (n < minUnits) shortfall[`${w}_units`] = minUnits - n;
    }
  }
  return { ok: Object.keys(shortfall).length === 0, shortfall };
}

const sizeOf = (metric, w) => (metric.kind === 'rate' ? metric[w].den : metric.kind === 'mean' ? metric[w].n : metric[w].length);

/** Convert an interval for "after minus before" into one for "improvement", with the sign set by the good direction. */
function improvement(interval, direction) {
  if (direction === 'up') return { d: interval.diff, lo: interval.lo, hi: interval.hi };
  return { d: -interval.diff, lo: -interval.hi, hi: -interval.lo };
}

/** One number from an absolute or a relative setting. A relative setting is a fraction of the before value. */
function absolute(metric, abs, rel, label) {
  if (abs !== undefined && rel !== undefined) fail(`${metric.name}: give ${label}_abs or ${label}_rel, not both`);
  if (abs !== undefined) return abs;
  if (rel !== undefined) {
    const base = metric.kind === 'rate' ? metric.before.num / metric.before.den : metric.kind === 'mean' ? metric.before.mean : average(metric.before);
    return Math.abs(base) * rel;
  }
  return undefined;
}

/** Status of one metric. The caller sets the thresholds in the input. */
export function analyzeMetric(metric, options = {}) {
  const alpha = options.alpha ?? DEFAULTS.alpha;
  const sample = minimumSample(metric, { minEvents: metric.min_events ?? options.minEvents, minUnits: metric.min_units ?? options.minUnits });
  const empty = sizeOf(metric, 'before') === 0 || sizeOf(metric, 'after') === 0;
  const result = { name: metric.name, role: metric.role, kind: metric.kind, direction: metric.direction, sample, sample_size: { before: sizeOf(metric, 'before'), after: sizeOf(metric, 'after') } };
  if (empty) return { ...result, status: 'empty-window', reason: 'a window has no data. This is a data-health finding, not a result.' };
  const stats =
    metric.kind === 'rate'
      ? rateInterval(metric.before, metric.after, alpha)
      : metric.kind === 'mean'
        ? meanInterval(metric.before, metric.after, alpha)
        : bootstrapInterval(metric.before, metric.after, { alpha, rounds: options.bootstrapRounds, seed: options.seed, statistic: metric.statistic });
  const imp = improvement(stats, metric.direction);
  const target = absolute(metric, metric.target_abs, metric.target_rel, 'target');
  const limit = absolute(metric, metric.limit_abs, metric.limit_rel, 'limit');
  const relative = stats.before !== 0 ? stats.diff / Math.abs(stats.before) : null;
  Object.assign(result, { before: stats.before, after: stats.after, change: stats.diff, change_relative: relative, interval: { lo: stats.lo, hi: stats.hi, level: 1 - alpha }, p_value: stats.p, method: stats.method, improvement: imp });
  if (target !== undefined) result.target = target;
  if (limit !== undefined) result.limit = limit;

  if (metric.role === 'guardrail') {
    if (limit === undefined) fail(`${metric.name}: a guardrail needs limit_abs or limit_rel`);
    // Harm is the worsening of the metric. The limit is the largest worsening that the plan accepts.
    const harm = { d: -imp.d, lo: -imp.hi, hi: -imp.lo };
    if (!sample.ok) result.status = 'unknown';
    else if (harm.lo > limit) result.status = 'breached';
    else if (harm.d > limit) result.status = 'possible-breach';
    else result.status = 'ok';
    result.harm = harm;
    return result;
  }
  if (!sample.ok) {
    result.status = 'small-sample';
    return result;
  }
  const goal = target ?? 0;
  if (imp.lo > 0 && imp.d >= goal) result.status = 'hit';
  else if (imp.hi < goal) result.status = 'miss';
  else result.status = 'inconclusive';
  if (result.status === 'inconclusive' && imp.d !== goal && stats.se) {
    // Rough size of the sample that settles the question if the estimate stays the same. It is an estimate, not a promise.
    const margin = imp.d > goal ? imp.d : goal - imp.d;
    const z = normalQuantile(1 - alpha / 2);
    result.sample_factor_to_resolve = Math.max(1, Math.ceil((z * stats.se / margin) ** 2 * 10) / 10);
  }
  return result;
}

const FIRST = { breached: 0, 'possible-breach': 1, unknown: 2 };

/** The verdict of the run: hit, miss or inconclusive. Could not measure is a status of the skill, not a verdict. */
export function verdict(analyzed, flags = {}) {
  const primary = analyzed.find((m) => m.role === 'primary');
  if (!primary) fail('the input needs one metric with role "primary"');
  const guardrails = analyzed.filter((m) => m.role === 'guardrail').sort((a, b) => (FIRST[a.status] ?? 9) - (FIRST[b.status] ?? 9));
  const reasons = [];
  let result;
  const breached = guardrails.filter((g) => g.status === 'breached');
  if (breached.length) {
    result = 'miss';
    reasons.push(`guardrail breached: ${breached.map((g) => g.name).join(', ')}`);
  } else if (primary.status === 'hit') result = 'hit';
  else if (primary.status === 'miss') result = 'miss';
  else result = 'inconclusive';

  if (primary.status === 'small-sample') reasons.push('primary metric: the sample is under the minimum');
  if (primary.status === 'empty-window') reasons.push('primary metric: a window has no data');
  if (primary.status === 'inconclusive') reasons.push('primary metric: the interval holds both zero and the target');
  if (primary.status === 'hit') reasons.push('primary metric: the interval excludes zero and the estimate reaches the target');
  if (primary.status === 'miss') reasons.push('primary metric: the upper end of the interval is below the target');
  for (const g of guardrails) {
    if (g.status === 'possible-breach') reasons.push(`guardrail ${g.name}: the estimate is past the limit, the interval is not`);
    if (g.status === 'unknown') reasons.push(`guardrail ${g.name}: the sample is under the minimum`);
    if (g.status === 'empty-window') reasons.push(`guardrail ${g.name}: a window has no data`);
  }
  // A hit needs every guardrail to be ok and a clean data health. Anything else caps the verdict at inconclusive.
  if (result === 'hit') {
    const open = guardrails.filter((g) => g.status !== 'ok');
    if (open.length) result = 'inconclusive';
  }
  if (flags.data_health_ok === false) {
    reasons.push('data health: the run has a tracking gap or a filter problem');
    result = 'inconclusive';
  }
  if (flags.early_look) {
    reasons.push('early look: the run is before the planned measure date');
    result = 'inconclusive';
  }
  return { verdict: result, reasons, first: guardrails.find((g) => g.status !== 'ok')?.name ?? null };
}

// ---------------------------------------------------------------------------------------------------------------------
// Input check and command line
// ---------------------------------------------------------------------------------------------------------------------

const KINDS = ['rate', 'mean', 'bootstrap'];
const ROLES = ['primary', 'guardrail', 'secondary'];

function count(value, label) {
  if (!Number.isInteger(value) || value < 0) fail(`${label} must be a whole number of 0 or more`);
}
function real(value, label) {
  if (typeof value !== 'number' || !Number.isFinite(value)) fail(`${label} must be a finite number`);
}

export function validate(input) {
  if (!input || typeof input !== 'object' || !Array.isArray(input.metrics) || input.metrics.length === 0) fail('the input needs a "metrics" list');
  const alpha = input.alpha ?? DEFAULTS.alpha;
  if (!(alpha > 0 && alpha < 0.5)) fail('alpha must be above 0 and below 0.5');
  const names = new Set();
  for (const m of input.metrics) {
    if (typeof m.name !== 'string' || !m.name) fail('each metric needs a name');
    if (names.has(m.name)) fail(`the metric name ${m.name} is used twice`);
    names.add(m.name);
    if (!ROLES.includes(m.role)) fail(`${m.name}: role must be one of ${ROLES.join(', ')}`);
    if (!KINDS.includes(m.kind)) fail(`${m.name}: kind must be one of ${KINDS.join(', ')}`);
    if (!['up', 'down'].includes(m.direction)) fail(`${m.name}: direction must be "up" or "down"`);
    for (const w of ['before', 'after']) {
      const v = m[w];
      if (m.kind === 'rate') {
        if (!v) fail(`${m.name}: ${w} needs num and den`);
        count(v.num, `${m.name}.${w}.num`);
        count(v.den, `${m.name}.${w}.den`);
        if (v.num > v.den) fail(`${m.name}.${w}: num is larger than den`);
      } else if (m.kind === 'mean') {
        if (!v) fail(`${m.name}: ${w} needs n, mean and sd`);
        count(v.n, `${m.name}.${w}.n`);
        real(v.mean, `${m.name}.${w}.mean`);
        real(v.sd, `${m.name}.${w}.sd`);
        if (v.sd < 0) fail(`${m.name}.${w}.sd must not be negative`);
        if (v.n === 1) fail(`${m.name}.${w}.n must be 0 or at least 2`);
      } else {
        if (!Array.isArray(v)) fail(`${m.name}: ${w} must be a list of numbers`);
        v.forEach((x, i) => real(x, `${m.name}.${w}[${i}]`));
      }
    }
    for (const key of ['target_abs', 'target_rel', 'limit_abs', 'limit_rel']) {
      if (m[key] !== undefined) {
        real(m[key], `${m.name}.${key}`);
        if (m[key] < 0) fail(`${m.name}.${key} must not be negative`);
      }
    }
    if (m.role === 'guardrail' && m.limit_abs === undefined && m.limit_rel === undefined) fail(`${m.name}: a guardrail needs limit_abs or limit_rel`);
  }
  if (input.metrics.filter((m) => m.role === 'primary').length !== 1) fail('the input needs exactly one metric with role "primary"');
  return alpha;
}

export function analyze(input) {
  const alpha = validate(input);
  const options = { alpha, minEvents: input.min_events, minUnits: input.min_units, bootstrapRounds: input.bootstrap_rounds, seed: input.seed };
  const metrics = input.metrics.map((m) => analyzeMetric(m, options));
  return { alpha, ...verdict(metrics, { data_health_ok: input.data_health_ok, early_look: input.early_look }), metrics };
}

function main(args) {
  const source = args[0];
  if (!source) {
    process.stderr.write('Usage: node stats.mjs <input.json | ->\n');
    return 2;
  }
  try {
    const text = source === '-' ? readFileSync(0, 'utf8') : readFileSync(source, 'utf8');
    let input;
    try {
      input = JSON.parse(text);
    } catch {
      fail('the input is not valid JSON');
    }
    process.stdout.write(JSON.stringify(analyze(input), null, 2) + '\n');
    return 0;
  } catch (error) {
    if (error instanceof InputError) {
      process.stderr.write(`Invalid input: ${error.message}\n`);
      return 2;
    }
    if (error && error.code === 'ENOENT') {
      process.stderr.write('Invalid input: the file does not exist\n');
      return 2;
    }
    throw error;
  }
}

// Run only as a script, not when a test imports the helpers. The skill can be installed as a symlink, so compare real paths.
const isEntry = (() => {
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
})();
if (isEntry) process.exitCode = main(process.argv.slice(2));
