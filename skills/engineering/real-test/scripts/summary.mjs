#!/usr/bin/env node
// real-test summary: turns a Playwright JSON report into the numbers and rows the markdown report is written from.
// Node standard library only, no network.
//
//   node summary.mjs <results.json> [--first <first-run.json>] [--plan <specs/real-test-plan.md>] [--guard <guard.json>]...
//
// stdout: one JSON object {totals, flowTotals, flows, tests, blocked, extra, guard, runErrors}. Statuses: passed, failed,
// fixme, skipped, flaky, and for flows also blocked.
//   totals      counts of runs (one flow in one project), seed.spec.* excluded
//   flowTotals  counts of flows by status (a flow is a spec file); this is what the report's table and counts use
//   flows       one row per spec file: its status over all projects (failed > flaky > fixme > skipped > passed) and per project
//   tests       one row per test and project: reason (the test.fixme text), first error line, screenshot and trace paths
//   blocked     with --plan: every planned test file that has no run, with the reason (no test file, rejected by the guard,
//               not run); these flows are `blocked` in flows and flowTotals
//   extra       with --plan: flows that ran but are not in the plan (older specs in the folder); not counted above
//   guard       with --guard (guard.mjs --json files, repeatable): all findings, and `targetChanges`, the ones where an
//               assertion now looks at different locator text after the heal; the report lists them
//   runErrors   errors Playwright reported outside any test (a config or load error); a run with errors is not a green run
// A test marked test.fail() is never `passed` (it is reported `failed` with that as the reason), so it is never `healed`.
// With --first, the report of the run before the heal: every row also gets `first` ({status, error, screenshots, traces}
// of that run, or null), and a flow that failed then and passes now gets `healed: true`. A test that was failing and is
// now fixme keeps its evidence there: the final run does not execute it.
// Exit 0: summary written. Exit 2: usage error or unreadable report.

import { existsSync, readFileSync, realpathSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ANSI = /\u001b\[[0-9;]*m/g;
const SEED = /(?:^|[\\/])seed\.spec\.[cm]?[jt]sx?$/;
const ORDER = ['failed', 'flaky', 'fixme', 'skipped', 'passed'];

const relative = (file) => {
  const rel = path.relative(process.cwd(), file);
  return rel.startsWith('..') || path.isAbsolute(rel) ? file : rel.split(path.sep).join('/');
};

function status(test) {
  if (test.annotations.some((a) => a.type === 'fail')) return 'failed'; // expected failure: never a pass
  if (test.status === 'expected') return 'passed';
  if (test.status === 'flaky') return 'flaky';
  if (test.status === 'skipped') return test.annotations.some((a) => a.type === 'fixme') ? 'fixme' : 'skipped';
  return 'failed';
}

/** One row per test and project in a Playwright JSON report, seed excluded. */
export function rows(report) {
  const rootDir = report.config?.rootDir ?? process.cwd();
  const out = [];

  const visit = (suite, titles) => {
    for (const spec of suite.specs ?? []) {
      const file = relative(path.resolve(rootDir, spec.file));
      if (SEED.test(file)) continue;
      for (const test of spec.tests) {
        const last = test.results.at(-1);
        const attachments = (last?.attachments ?? []).filter((a) => a.path);
        const expectedFail = test.annotations.some((a) => a.type === 'fail');
        out.push({
          project: test.projectName,
          file,
          title: [...titles, spec.title].join(' > '),
          status: status(test),
          reason: expectedFail ? 'marked test.fail(): an expected failure is not a pass' : (test.annotations.find((a) => a.type === 'fixme')?.description ?? ''),
          error: (last?.errors?.[0]?.message ?? last?.error?.message ?? '').replace(ANSI, '').split('\n').find((line) => line.trim()) ?? '',
          screenshots: attachments.filter((a) => a.contentType?.startsWith('image/')).map((a) => relative(a.path)),
          traces: attachments.filter((a) => a.name === 'trace').map((a) => relative(a.path)),
        });
      }
    }
    for (const child of suite.suites ?? []) visit(child, [...titles, child.title]);
  };
  // Top-level suites are spec files; their titles are file names, not part of a test's name.
  for (const suite of report.suites ?? []) visit(suite, []);
  return out;
}

/** The planned tests of a Playwright plan file: [{ title, file }] from its `#### i.j. Title` and `**File:**` lines. */
export function planned(planText) {
  const out = [];
  let title = '';
  for (const line of planText.split('\n')) {
    const heading = /^####\s+\d+\.\d+\.?\s+(.+?)\s*$/.exec(line);
    if (heading) title = heading[1];
    const file = /^\*\*File:\*\*\s*`([^`]+)`/.exec(line);
    if (file) out.push({ title, file: path.normalize(file[1]).split(path.sep).join('/') });
  }
  return out;
}

const worst = (statuses) => ORDER.find((name) => statuses.includes(name));

/**
 * The summary of a report. `firstReport`: the run before the heal. `plan`: the plan's text; with it, only the planned flows
 * are counted and the others are listed apart as `extra`. `exists`: file check, for tests. `guardRuns`: [{ source, findings }]
 * of guard.mjs --json files.
 */
export function summarize(report, firstReport, plan, exists = existsSync, guardRuns = []) {
  const all = rows(report);
  if (firstReport) {
    const before = new Map(rows(firstReport).map((t) => [`${t.project}|${t.file}|${t.title}`, t]));
    for (const t of all) {
      const b = before.get(`${t.project}|${t.file}|${t.title}`);
      t.first = b ? { status: b.status, error: b.error, screenshots: b.screenshots, traces: b.traces } : null;
    }
  }
  const plannedFiles = plan ? new Set(planned(plan).map((p) => p.file)) : null;
  const tests = plannedFiles ? all.filter((t) => plannedFiles.has(t.file)) : all;
  const unplanned = plannedFiles ? all.filter((t) => !plannedFiles.has(t.file)) : [];

  const flowsOf = (items) => {
    const byFile = new Map();
    for (const t of items) byFile.set(t.file, [...(byFile.get(t.file) ?? []), t]);
    return [...byFile].map(([file, group]) => {
      const flow = {
        file,
        title: group[0].title,
        status: worst(group.map((t) => t.status)),
        projects: Object.fromEntries(group.map((t) => [t.project, t.status])),
      };
      if (firstReport) {
        flow.first = worst(group.map((t) => t.first?.status).filter(Boolean)) ?? null;
        flow.healed = flow.first === 'failed' && flow.status === 'passed';
      }
      return flow;
    });
  };
  const flows = flowsOf(tests);
  const extra = flowsOf(unplanned);

  const blocked = [];
  for (const { title, file } of plan ? planned(plan) : []) {
    if (flows.some((f) => f.file === file)) continue;
    const reason = exists(`${file}.rejected`) ? 'rejected by the guard' : exists(file) ? 'not run' : 'no test file';
    blocked.push({ file, title, reason });
    flows.push({ file, title, status: 'blocked', projects: {}, reason });
  }

  const findings = guardRuns.flatMap(({ source, findings: list }) => list.map((f) => ({ source, ...f })));
  const count = (items, name) => items.filter((item) => item.status === name).length;
  return {
    totals: Object.fromEntries(ORDER.map((name) => [name, count(tests, name)])),
    flowTotals: Object.fromEntries([...ORDER, 'blocked'].map((name) => [name, count(flows, name)])),
    flows,
    tests,
    blocked,
    extra,
    guard: { findings, targetChanges: findings.filter((f) => f.rule === 'assertion-target-changed') },
    runErrors: (report.errors ?? []).map((e) => (e.message ?? '').replace(ANSI, '').split('\n')[0]),
  };
}

const USAGE = 'Usage: node summary.mjs <results.json> [--first <first-run.json>] [--plan <plan.md>] [--guard <guard.json>]...';

function readText(file) {
  try {
    return readFileSync(file, 'utf8');
  } catch (error) {
    console.error(`Cannot read ${file}: ${error.message}`);
    return undefined;
  }
}

function readJson(file) {
  const text = readText(file);
  if (text === undefined) return undefined;
  try {
    return JSON.parse(text);
  } catch (error) {
    console.error(`Cannot parse ${file}: ${error.message}`);
    return undefined;
  }
}

function main(argv) {
  const args = [...argv];
  const take = (flag) => {
    const at = args.indexOf(flag);
    return at === -1 ? undefined : (args.splice(at, 2)[1] ?? null);
  };
  const firstFile = take('--first');
  const planFile = take('--plan');
  const guardFiles = [];
  for (let next = take('--guard'); next !== undefined; next = take('--guard')) guardFiles.push(next);
  const [file, ...extra] = args;
  if (!file || extra.length || firstFile === null || planFile === null || guardFiles.includes(null)) {
    console.error(USAGE);
    return 2;
  }
  const report = readJson(file);
  const first = firstFile ? readJson(firstFile) : undefined;
  const plan = planFile ? readText(planFile) : undefined;
  const guardRuns = guardFiles.map((guardFile) => ({ source: path.basename(guardFile), findings: readJson(guardFile)?.findings }));
  if (!report || (firstFile && !first) || (planFile && plan === undefined) || guardRuns.some((run) => !run.findings)) return 2;
  console.log(JSON.stringify(summarize(report, first, plan, existsSync, guardRuns), null, 2));
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
