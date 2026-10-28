// Local test for the real-measure skill. Run from the repository root:
//
//   node scripts/test-real-measure.mjs
//
// Node standard library only. No browser, no network, no model. It is not part of the skill, so scripts/build-zips.sh does not ship it.
//
// Covered: the distribution functions of stats.mjs against known table values; the interval of a rate, of a mean and of a
// bootstrap; the sample minimum; the status of a primary metric and of a guardrail; every verdict rule (hit, miss,
// inconclusive, early look, data health, guardrail breach); input checks; the command line and its exit codes; the example in
// references/metrics.md; and that SKILL.md, the plan block, the routing and the installer agree.
//
// NOT covered: that an agent follows SKILL.md (needs a model), that an analytics tool returns what the skill expects, and
// that a metric is a good metric.

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { analyze, analyzeMetric, bootstrapInterval, meanInterval, minimumSample, normalCdf, normalQuantile, rateInterval, tCdf, tQuantile, verdict } from '../skills/product/real-measure/scripts/stats.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SKILL = path.join(ROOT, 'skills/product/real-measure');
const STATS = path.join(SKILL, 'scripts/stats.mjs');
const read = (...parts) => readFileSync(path.join(ROOT, ...parts), 'utf8');
const near = (actual, expected, tolerance, label = '') => assert.ok(Math.abs(actual - expected) <= tolerance, `${label} ${actual} is not within ${tolerance} of ${expected}`);

// Metric builders
const rate = (name, role, direction, before, after, extra = {}) => ({ name, role, kind: 'rate', direction, before: { num: before[0], den: before[1] }, after: { num: after[0], den: after[1] }, ...extra });
const primary = (before, after, extra) => rate('signup_rate', 'primary', 'up', before, after, extra);
const errors = (after, extra) => rate('error_rate', 'guardrail', 'down', [120, 20000], after, extra);

describe('distributions', () => {
  it('normal quantile and CDF match table values', () => {
    near(normalQuantile(0.975), 1.959964, 1e-6);
    near(normalQuantile(0.995), 2.575829, 1e-6);
    near(normalQuantile(0.5), 0, 1e-12);
    near(normalQuantile(0.001), -3.090232, 1e-6);
    near(normalCdf(1.96), 0.9750021, 1e-6);
    near(normalCdf(-1), 0.1586553, 1e-6);
    near(normalCdf(4), 0.9999683, 1e-6);
  });

  it('Student t quantile matches table values', () => {
    near(tQuantile(0.975, 5), 2.570582, 1e-5);
    near(tQuantile(0.975, 10), 2.228139, 1e-5);
    near(tQuantile(0.975, 30), 2.042272, 1e-5);
    near(tQuantile(0.975, 98), 1.984467, 1e-5);
    near(tQuantile(0.995, 5), 4.032143, 1e-5);
    near(tQuantile(0.025, 10), -2.228139, 1e-5);
  });

  it('t CDF is symmetric and agrees with the quantile', () => {
    near(tCdf(0, 7), 0.5, 1e-12);
    near(tCdf(1.3, 7) + tCdf(-1.3, 7), 1, 1e-12);
    near(tCdf(tQuantile(0.9, 12.5), 12.5), 0.9, 1e-9);
  });

  it('rejects a probability outside 0 and 1', () => {
    assert.throws(() => normalQuantile(0), /0 < p < 1/);
    assert.throws(() => tQuantile(1, 5), /0 < p < 1/);
    assert.throws(() => tQuantile(0.9, 0), /df > 0/);
  });
});

describe('intervals', () => {
  it('rate: 5.0% to 6.5% on 4000 each', () => {
    const r = rateInterval({ num: 200, den: 4000 }, { num: 260, den: 4000 });
    near(r.before, 0.05, 1e-12);
    near(r.after, 0.065, 1e-12);
    near(r.diff, 0.015, 1e-12);
    near(r.se, 0.0052027637, 1e-9);
    near(r.lo, 0.0048027706, 1e-8);
    near(r.hi, 0.0251972294, 1e-8);
    near(r.p, 0.003957, 1e-5);
  });

  it('rate: equal rates give a symmetric interval around zero and p of 1', () => {
    const r = rateInterval({ num: 500, den: 10000 }, { num: 500, den: 10000 });
    near(r.diff, 0, 1e-15);
    near(r.lo, -r.hi, 1e-12);
    near(r.p, 1, 1e-12);
  });

  it('rate: a narrower level gives a narrower interval', () => {
    const wide = rateInterval({ num: 200, den: 4000 }, { num: 260, den: 4000 }, 0.01);
    const narrow = rateInterval({ num: 200, den: 4000 }, { num: 260, den: 4000 }, 0.1);
    assert.ok(wide.hi - wide.lo > narrow.hi - narrow.lo);
  });

  it('mean: 10 to 11 with sd 2 on 50 each (Welch)', () => {
    const r = meanInterval({ n: 50, mean: 10, sd: 2 }, { n: 50, mean: 11, sd: 2 });
    near(r.diff, 1, 1e-12);
    near(r.se, 0.4, 1e-12);
    near(r.df, 98, 1e-9);
    near(r.lo, 0.2062130, 1e-6);
    near(r.hi, 1.7937870, 1e-6);
    near(r.p, 0.01408, 1e-5);
  });

  it('mean: unequal spread uses the Satterthwaite degrees of freedom', () => {
    const r = meanInterval({ n: 20, mean: 5, sd: 1 }, { n: 80, mean: 5.5, sd: 4 });
    near(r.df, (1 / 20 + 16 / 80) ** 2 / ((1 / 20) ** 2 / 19 + (16 / 80) ** 2 / 79), 1e-9);
    assert.ok(r.lo < 0.5 && r.hi > 0.5);
  });

  it('mean: zero spread gives a zero-width interval', () => {
    const r = meanInterval({ n: 40, mean: 3, sd: 0 }, { n: 40, mean: 4, sd: 0 });
    assert.equal(r.lo, 1);
    assert.equal(r.hi, 1);
  });

  const units = (count, offset = 0, seed = 7) => {
    let a = seed;
    return Array.from({ length: count }, () => {
      a = (a * 1103515245 + 12345) % 2147483648;
      return (a / 2147483648) * 10 + offset;
    });
  };

  it('bootstrap: the same seed gives the same interval', () => {
    const before = units(60);
    const after = units(60, 3, 11);
    const one = bootstrapInterval(before, after, { seed: 5 });
    const two = bootstrapInterval(before, after, { seed: 5 });
    assert.deepEqual(one, two);
  });

  it('bootstrap: a clear shift excludes zero and identical data includes zero', () => {
    const before = units(80);
    const shifted = bootstrapInterval(before, before.map((v) => v + 5));
    assert.ok(shifted.lo > 0, `lo ${shifted.lo}`);
    near(shifted.diff, 5, 1e-9);
    const same = bootstrapInterval(before, [...before]);
    assert.ok(same.lo < 0 && same.hi > 0);
  });

  it('bootstrap: the median is supported', () => {
    const r = bootstrapInterval([1, 2, 3, 4, 100], [2, 3, 4, 5, 200], { statistic: 'median' });
    assert.equal(r.diff, 1);
    assert.match(r.method, /median/);
  });
});

describe('minimum sample', () => {
  it('rate: 100 events and 100 non-events in each window pass', () => {
    assert.equal(minimumSample(primary([100, 200], [100, 200])).ok, true);
  });

  it('rate: 99 events in a window fail and name the shortfall', () => {
    const r = minimumSample(primary([99, 4000], [200, 4000]));
    assert.equal(r.ok, false);
    assert.deepEqual(r.shortfall, { before_events: 1 });
  });

  it('rate: too few non-events fail', () => {
    const r = minimumSample(primary([200, 250], [200, 4000]));
    assert.equal(r.ok, false);
    assert.deepEqual(r.shortfall, { before_non_events: 50 });
  });

  it('mean: 30 units pass and 29 fail', () => {
    const mean = (n) => ({ name: 'value', role: 'primary', kind: 'mean', direction: 'up', before: { n, mean: 1, sd: 1 }, after: { n: 30, mean: 1, sd: 1 } });
    assert.equal(minimumSample(mean(30)).ok, true);
    assert.deepEqual(minimumSample(mean(29)).shortfall, { before_units: 1 });
  });

  it('options set a higher minimum', () => {
    assert.equal(minimumSample(primary([150, 4000], [150, 4000]), { minEvents: 200 }).ok, false);
  });
});

describe('primary metric status', () => {
  const status = (metric) => analyzeMetric(metric).status;

  it('hit: the interval excludes zero and the estimate reaches the target', () => {
    const m = analyzeMetric(primary([200, 4000], [300, 4000], { target_abs: 0.01 }));
    assert.equal(m.status, 'hit');
    assert.ok(m.improvement.lo > 0 && m.improvement.d >= 0.01);
  });

  it('miss: the upper end of the interval is below the target', () => {
    assert.equal(status(primary([2000, 40000], [2010, 40000], { target_abs: 0.01 })), 'miss');
  });

  it('miss: the metric moved the wrong way and the interval excludes zero', () => {
    assert.equal(status(primary([2000, 40000], [1800, 40000])), 'miss');
  });

  it('inconclusive: the interval holds both zero and the target, with a rough size to settle it', () => {
    const m = analyzeMetric(primary([200, 4000], [230, 4000], { target_abs: 0.01 }));
    assert.equal(m.status, 'inconclusive');
    assert.ok(m.sample_factor_to_resolve > 10 && m.sample_factor_to_resolve < 25, `factor ${m.sample_factor_to_resolve}`);
  });

  it('inconclusive: a target-free metric that moved up but not significantly', () => {
    assert.equal(status(primary([200, 4000], [215, 4000])), 'inconclusive');
  });

  it('a sample under the minimum is small-sample, not a result', () => {
    const m = analyzeMetric(primary([40, 800], [80, 800], { target_abs: 0.01 }));
    assert.equal(m.status, 'small-sample');
    assert.equal(m.interval.lo < m.interval.hi, true);
  });

  it('an empty window is a data-health finding', () => {
    assert.equal(status(primary([0, 0], [260, 4000])), 'empty-window');
    assert.equal(status(primary([200, 4000], [0, 0])), 'empty-window');
  });

  it('direction down: a lower value is the improvement', () => {
    const m = analyzeMetric(rate('churn', 'primary', 'down', [800, 10000], [600, 10000], { target_abs: 0.01 }));
    assert.equal(m.status, 'hit');
    near(m.improvement.d, 0.02, 1e-12);
  });

  it('target_rel is a fraction of the before value', () => {
    const m = analyzeMetric(primary([200, 4000], [300, 4000], { target_rel: 0.1 }));
    near(m.target, 0.005, 1e-12);
  });

  it('mean: hit on a clear shift', () => {
    const m = analyzeMetric({ name: 'minutes', role: 'primary', kind: 'mean', direction: 'up', before: { n: 50, mean: 10, sd: 2 }, after: { n: 50, mean: 11, sd: 2 }, target_abs: 0.5 });
    assert.equal(m.status, 'hit');
  });

  it('mean: a sample of 29 units is small-sample', () => {
    const m = analyzeMetric({ name: 'minutes', role: 'primary', kind: 'mean', direction: 'up', before: { n: 29, mean: 10, sd: 2 }, after: { n: 50, mean: 12, sd: 2 } });
    assert.equal(m.status, 'small-sample');
  });
});

describe('guardrail status', () => {
  const status = (after, extra) => analyzeMetric(errors(after, extra)).status;

  it('ok: the change is inside the limit', () => {
    assert.equal(status([125, 20000], { limit_abs: 0.002 }), 'ok');
  });

  it('breached: the whole interval of the harm is past the limit', () => {
    assert.equal(status([300, 20000], { limit_abs: 0.002 }), 'breached');
  });

  it('possible-breach: the estimate is past the limit, the interval is not', () => {
    assert.equal(status([150, 20000], { limit_abs: 0.001 }), 'possible-breach');
  });

  it('unknown: the sample is under the minimum', () => {
    assert.equal(analyzeMetric(rate('error_rate', 'guardrail', 'down', [20, 2000], [30, 2000], { limit_abs: 0.001 })).status, 'unknown');
  });

  it('an improvement of a guardrail is ok', () => {
    assert.equal(analyzeMetric(rate('error_rate', 'guardrail', 'down', [2000, 40000], [1800, 40000], { limit_abs: 0.001 })).status, 'ok');
  });

  it('limit_rel is a fraction of the before value', () => {
    const m = analyzeMetric(errors([125, 20000], { limit_rel: 0.5 }));
    near(m.limit, 0.003, 1e-12);
  });

  it('a guardrail with a "up" direction breaches when the value falls', () => {
    const m = analyzeMetric(rate('checkout_rate', 'guardrail', 'up', [3000, 20000], [2000, 20000], { limit_abs: 0.01 }));
    assert.equal(m.status, 'breached');
  });
});

describe('verdict of the run', () => {
  const run = (metrics, flags = {}) => analyze({ ...flags, metrics });
  const hit = primary([200, 4000], [300, 4000], { target_abs: 0.01 });

  it('hit: primary hit, guardrails ok, data healthy', () => {
    const r = run([hit, errors([125, 20000], { limit_abs: 0.002 })]);
    assert.equal(r.verdict, 'hit');
    assert.equal(r.first, null);
  });

  it('miss: primary miss', () => {
    assert.equal(run([primary([2000, 40000], [2010, 40000], { target_abs: 0.01 })]).verdict, 'miss');
  });

  it('miss: a breached guardrail beats a primary hit and comes first', () => {
    const r = run([hit, errors([300, 20000], { limit_abs: 0.002 })]);
    assert.equal(r.verdict, 'miss');
    assert.equal(r.first, 'error_rate');
    assert.match(r.reasons[0], /guardrail breached: error_rate/);
  });

  it('inconclusive: a possible breach stops a hit', () => {
    const r = run([hit, errors([150, 20000], { limit_abs: 0.001 })]);
    assert.equal(r.verdict, 'inconclusive');
    assert.equal(r.first, 'error_rate');
  });

  it('inconclusive: a guardrail with a small sample stops a hit', () => {
    const r = run([hit, rate('error_rate', 'guardrail', 'down', [20, 2000], [30, 2000], { limit_abs: 0.001 })]);
    assert.equal(r.verdict, 'inconclusive');
  });

  it('inconclusive: a small primary sample', () => {
    const r = run([primary([40, 800], [80, 800], { target_abs: 0.01 })]);
    assert.equal(r.verdict, 'inconclusive');
    assert.ok(r.reasons.some((x) => /under the minimum/.test(x)));
  });

  it('inconclusive: an early look caps even a hit', () => {
    const r = run([hit], { early_look: true });
    assert.equal(r.verdict, 'inconclusive');
    assert.ok(r.reasons.some((x) => /early look/.test(x)));
  });

  it('inconclusive: an early look caps a breach too, and the guardrail is still first', () => {
    const r = run([hit, errors([300, 20000], { limit_abs: 0.002 })], { early_look: true });
    assert.equal(r.verdict, 'inconclusive');
    assert.equal(r.first, 'error_rate');
  });

  it('inconclusive: a data-health problem', () => {
    assert.equal(run([hit], { data_health_ok: false }).verdict, 'inconclusive');
  });

  it('inconclusive: an empty primary window', () => {
    assert.equal(run([primary([0, 0], [260, 4000])]).verdict, 'inconclusive');
  });

  it('a secondary metric never changes the verdict', () => {
    const r = run([hit, rate('exploratory', 'secondary', 'up', [100, 4000], [10, 4000])]);
    assert.equal(r.verdict, 'hit');
  });

  it('verdict() needs a primary metric', () => {
    assert.throws(() => verdict([]), /primary/);
  });

  it('the output has no person-level field', () => {
    const text = JSON.stringify(run([hit]));
    assert.ok(!/user_id|email|distinct_id/.test(text));
  });
});

describe('input checks', () => {
  const bad = (metrics, message, extra = {}) => assert.throws(() => analyze({ ...extra, metrics }), message);
  const ok = primary([200, 4000], [260, 4000]);

  it('rejects an empty list and a missing primary', () => {
    assert.throws(() => analyze({ metrics: [] }), /metrics/);
    assert.throws(() => analyze({}), /metrics/);
    bad([errors([125, 20000], { limit_abs: 0.002 })], /exactly one/);
  });

  it('rejects two primary metrics and a repeated name', () => {
    bad([ok, { ...ok, name: 'second' }], /exactly one/);
    bad([ok, { ...ok, role: 'secondary' }], /used twice/);
  });

  it('rejects a guardrail with no limit', () => {
    bad([ok, errors([125, 20000])], /limit_abs or limit_rel/);
  });

  it('rejects a target given twice and a negative target', () => {
    bad([primary([200, 4000], [260, 4000], { target_abs: 0.01, target_rel: 0.1 })], /not both/);
    bad([primary([200, 4000], [260, 4000], { target_abs: -0.01 })], /must not be negative/);
  });

  it('rejects counts that cannot be true', () => {
    bad([primary([5001, 5000], [260, 4000])], /larger than den/);
    bad([primary([1.5, 5000], [260, 4000])], /whole number/);
    bad([primary([-1, 5000], [260, 4000])], /whole number/);
  });

  it('rejects an unknown role, kind or direction and a bad level', () => {
    bad([{ ...ok, role: 'main' }], /role/);
    bad([{ ...ok, kind: 'ratio' }], /kind/);
    bad([{ ...ok, direction: 'sideways' }], /direction/);
    bad([ok], /alpha/, { alpha: 0.9 });
  });

  it('rejects a mean with one unit, a negative sd or a value that is not a number', () => {
    const mean = (before) => ({ name: 'm', role: 'primary', kind: 'mean', direction: 'up', before, after: { n: 40, mean: 1, sd: 1 } });
    bad([mean({ n: 1, mean: 1, sd: 1 })], /at least 2/);
    bad([mean({ n: 40, mean: 1, sd: -1 })], /negative/);
    bad([mean({ n: 40, mean: 'x', sd: 1 })], /finite number/);
    bad([{ name: 'b', role: 'primary', kind: 'bootstrap', direction: 'up', before: [1, NaN], after: [1, 2] }], /finite number/);
  });
});

describe('command line', () => {
  const run = (args, input) => spawnSync(process.execPath, [STATS, ...args], { input, encoding: 'utf8' });
  const input = { early_look: false, metrics: [primary([200, 4000], [300, 4000], { target_abs: 0.01 })] };

  it('reads a file and prints the verdict as JSON', () => {
    const dir = mkdtempSync(path.join(tmpdir(), 'real-measure-'));
    try {
      const file = path.join(dir, 'in.json');
      writeFileSync(file, JSON.stringify(input));
      const result = run([file]);
      assert.equal(result.status, 0, result.stderr);
      const out = JSON.parse(result.stdout);
      assert.equal(out.verdict, 'hit');
      assert.equal(out.metrics[0].status, 'hit');
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('reads standard input with a dash', () => {
    const result = run(['-'], JSON.stringify(input));
    assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).verdict, 'hit');
  });

  it('exits with 2 and a message on bad input', () => {
    const result = run(['-'], JSON.stringify({ metrics: [{ ...input.metrics[0], direction: 'x' }] }));
    assert.equal(result.status, 2);
    assert.match(result.stderr, /Invalid input: .*direction/);
    assert.equal(result.stdout, '');
  });

  it('exits with 2 on text that is not JSON, a missing file and no argument', () => {
    assert.equal(run(['-'], 'not json').status, 2);
    assert.equal(run(['/nonexistent/in.json']).status, 2);
    assert.equal(run([]).status, 2);
  });

  it('gives the same output on every run', () => {
    const boot = { metrics: [{ name: 'revenue', role: 'primary', kind: 'bootstrap', direction: 'up', before: Array.from({ length: 40 }, (_, i) => i), after: Array.from({ length: 40 }, (_, i) => i + 8) }] };
    assert.equal(run(['-'], JSON.stringify(boot)).stdout, run(['-'], JSON.stringify(boot)).stdout);
  });

  it('uses only the standard library and makes no network call', () => {
    const code = readFileSync(STATS, 'utf8');
    for (const [, from] of code.matchAll(/^import .* from '([^']+)'/gm)) assert.match(from, /^node:/, from);
    assert.ok(!/fetch\(|node:https?|node:net|XMLHttpRequest|process\.env/.test(code));
  });
});

describe('skill files and bundle', () => {
  const skill = read('skills/product/real-measure/SKILL.md');
  const metrics = read('skills/product/real-measure/references/metrics.md');
  const sources = read('skills/product/real-measure/references/sources.md');
  const body = skill.replace(/^---\n[\s\S]*?\n---\n/, '');

  it('the JSON example of metrics.md is a valid input', () => {
    const block = /```json\n([\s\S]*?)```/.exec(metrics)[1];
    const out = analyze(JSON.parse(block));
    assert.equal(out.verdict, 'hit');
    assert.equal(out.metrics.length, 2);
  });

  it('SKILL.md names its helper files and they exist', () => {
    assert.ok(body.includes('scripts/stats.mjs'));
    for (const ref of ['references/metrics.md', 'references/sources.md']) {
      assert.ok(body.includes(ref), `SKILL.md mentions ${ref}`);
      assert.ok(existsSync(path.join(SKILL, ref)), `${ref} exists`);
    }
    assert.ok(existsSync(path.join(SKILL, 'agents/openai.yaml')));
  });

  it('SKILL.md keeps the safety and honesty rules', () => {
    for (const rule of ['read-only', 'aggregates only', 'Never read `.env*` files', 'Never query an event that you guessed', '**Could not measure**', 'associated with', 'Execute no next action', 'Never ask for a write key', 'Never do the arithmetic yourself', 'early look']) {
      assert.ok(body.includes(rule) || (rule === 'aggregates only' && body.includes('Use aggregates only')) || (rule === 'early look' && body.includes('"early look"')), `SKILL.md has the rule: ${rule}`);
    }
  });

  it('SKILL.md names the three verdicts, the four next actions and the five-step guardrail rule', () => {
    for (const word of ['**Hit:**', '**Miss:**', '**Inconclusive:**', 'keep, iterate, roll back or back to brainstorm']) assert.ok(body.includes(word), word);
    assert.match(body, /A guardrail result that is breached or possible comes before everything else/);
  });

  it('the sources are the v1 sources and logs and store metrics come as export files', () => {
    assert.match(sources, /export file/);
    assert.match(sources, /In v1, the user gives them as an export file/);
    assert.match(sources, /Never read `\.env\*` files/);
    assert.match(sources, /Use at most 20 queries/);
  });

  it('real-plan has the Measure block, the handoff line and the advice line', () => {
    const plan = read('skills/product/real-plan/SKILL.md');
    const gate = read('skills/product/real-plan/references/feature-gate.md');
    assert.match(plan, /If the plan states an outcome goal, add a \*\*Measure\*\* block/);
    assert.match(plan, /A plan with no outcome goal needs no Measure block/);
    assert.match(plan, /Next, optional: after release, `\/real-measure <plan file>` on <date>\./);
    assert.match(plan, /only if `real-measure` is in the skill catalog/);
    assert.match(plan, /Never start `real-measure` yourself/);
    assert.match(gate, /#### Measure block/);
    const fields = [...gate.slice(gate.indexOf('Fields:'), gate.indexOf('Rules:')).matchAll(/^(\d+)\. /gm)].map((m) => Number(m[1]));
    assert.deepEqual(fields, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    assert.match(gate, /Advice line: .*holdout or a flag-based split.*not required/);
    assert.match(gate, /"associated with"/);
  });

  it('metrics.md has the same ten fields as the plan block', () => {
    const fields = [...metrics.slice(metrics.indexOf('## The Measure block'), metrics.indexOf('## Windows')).matchAll(/^(\d+)\. /gm)].length;
    assert.equal(fields, 10);
  });

  it('real-start has the Measure route, the precedence rule and the 7th step', () => {
    const start = read('skills/product/real-start/SKILL.md');
    assert.match(start, /- \*\*Measure\*\*: a change has shipped/);
    assert.match(start, /Start `real-measure`\./);
    assert.match(start, /"Did this change work\?" goes to Measure\. A request for what to improve stays in Audit\./);
    assert.match(start, /\n7\. After release, measure the result\./);
  });

  it('the bundle lists real-measure everywhere that lists skills', () => {
    const plugin = JSON.parse(read('.claude-plugin/plugin.json'));
    assert.ok(plugin.skills.includes('./skills/product/real-measure'));
    assert.match(read('.claude-plugin/marketplace.json'), /measure/);
    assert.match(read('scripts/install-local.sh'), /real-measure/);
    const readme = read('README.md');
    assert.match(readme, /^\| `\/real-measure` \|/m);
    assert.match(readme, /real-measure\*\* \(|`real-measure`, the eighth workflow/);
    assert.match(readme, /docs\/measure\//);
    assert.match(readme, /scripts\/test-real-measure\.mjs/);
    assert.match(read('docs/real-hardening-status.md'), /`real-measure`/);
  });

  it('install-local.sh rejects a bundle without stats.mjs before it links anything', () => {
    const base = mkdtempSync(path.join(tmpdir(), 'real-measure-install-'));
    try {
      mkdirSync(path.join(base, 'repo/scripts'), { recursive: true });
      cpSync(path.join(ROOT, 'skills'), path.join(base, 'repo/skills'), { recursive: true });
      cpSync(path.join(ROOT, 'scripts/install-local.sh'), path.join(base, 'repo/scripts/install-local.sh'));
      const dest = path.join(base, 'dest');
      const install = () => spawnSync('bash', [path.join(base, 'repo/scripts/install-local.sh'), dest], { encoding: 'utf8' });
      rmSync(path.join(base, 'repo/skills/product/real-measure/scripts/stats.mjs'));
      const result = install();
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, /Incomplete bundle: missing .*stats\.mjs/);
      assert.ok(!existsSync(dest), 'nothing is linked');
    } finally {
      rmSync(base, { recursive: true, force: true });
    }
  });
});
