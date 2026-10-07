// Local test for the real-test skill and for the bundle's version stamps and skill lists. Run from the repository root:
//
//   node scripts/test-real-test.mjs
//
// Node standard library only. No browser, no network, no model: it reads the repository files and runs guard.mjs and
// summary.mjs on temporary folders. It is not part of the skill, so scripts/build-zips.sh does not ship it.
//
// Covered: every SKILL.md has valid frontmatter whose name, version and trailing "(vX.Y.Z)" stamp agree; the plugin
// version is the highest skill version; every skill is listed in plugin.json, marketplace.json, install-local.sh, the
// installer test's expected count, the README (count word, table, Codex list, changelog), real-start and
// docs/real-hardening-status.md; every skill has agents/openai.yaml; what SKILL.md and the README claim about safety and
// data; the rules, the baseline comparison and the CLI of guard.mjs; summary.mjs. The guard cases that start with
// "review:" are the exact inputs two independent reviews showed to slip through an earlier guard.
//
// NOT covered: that the agents follow SKILL.md (needs a model), the Playwright agents themselves, natural-language
// routing, and the guard's reach beyond the patterns in its table (it is a pattern check, not a parser, and it cannot tell
// that a healed assertion now looks at a weaker element). The end-to-end runs against a real app were done by hand; see
// docs/real-hardening-status.md.

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { RULE_INFO, assertionTargetChanges, countExpects, missingAssertions, realLookingCard, scan, scanData, stripComments } from '../skills/engineering/real-test/scripts/guard.mjs';
import { planned, summarize } from '../skills/engineering/real-test/scripts/summary.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SKILL = path.join(ROOT, 'skills/engineering/real-test');
const GUARD = path.join(SKILL, 'scripts/guard.mjs');
const SUMMARY = path.join(SKILL, 'scripts/summary.mjs');
const read = (...parts) => readFileSync(path.join(ROOT, ...parts), 'utf8');
const COUNT_WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve'];
const capitalized = (word) => word[0].toUpperCase() + word.slice(1);

// ---------------------------------------------------------------------------------------------------------------------
// Bundle: frontmatter, versions, lists
// ---------------------------------------------------------------------------------------------------------------------

/** Every skill: { name, rel (as in plugin.json), dir, text, front }. */
function skills() {
  const found = [];
  for (const group of readdirSync(path.join(ROOT, 'skills'))) {
    const groupDir = path.join(ROOT, 'skills', group);
    for (const name of readdirSync(groupDir)) {
      if (existsSync(path.join(groupDir, name, 'SKILL.md'))) found.push({ name, rel: `./skills/${group}/${name}`, dir: path.join(groupDir, name) });
    }
  }
  return found.sort((a, b) => a.name.localeCompare(b.name)).map((s) => ({ ...s, text: readFileSync(path.join(s.dir, 'SKILL.md'), 'utf8') })).map((s) => ({ ...s, front: frontmatter(s.text) }));
}

/** The small YAML subset the skills use: top-level scalars and one `metadata:` block of scalars. */
function frontmatter(text) {
  const match = /^---\n([\s\S]*?)\n---\n/.exec(text);
  assert.ok(match, 'SKILL.md starts with a --- frontmatter block');
  const front = { metadata: {} };
  let inMetadata = false;
  for (const line of match[1].split('\n')) {
    const nested = /^ {2}(\w+):\s*(.*)$/.exec(line);
    if (inMetadata && nested) {
      front.metadata[nested[1]] = nested[2];
      continue;
    }
    const top = /^(\w+):\s*(.*)$/.exec(line);
    assert.ok(top, `frontmatter line is key: value: ${line}`);
    inMetadata = top[1] === 'metadata';
    if (!inMetadata) front[top[1]] = top[2].replace(/^"(.*)"$/s, '$1');
  }
  return front;
}

const semver = (version) => version.split('.').map(Number);
const compare = (a, b) => semver(a).reduce((diff, part, i) => diff || part - semver(b)[i], 0);

describe('bundle', () => {
  const all = skills();
  const plugin = JSON.parse(read('.claude-plugin/plugin.json'));
  const marketplace = JSON.parse(read('.claude-plugin/marketplace.json'));
  const countWord = COUNT_WORDS[all.length];
  const shortNames = all.map((s) => s.name.replace(/^real-/, ''));

  it('finds the skills on disk, real-test among them', () => {
    assert.ok(all.some((s) => s.name === 'real-test'));
    assert.ok(countWord, `count word for ${all.length} skills`);
  });

  for (const skill of all) {
    it(`${skill.name}: frontmatter is valid and the version stamp agrees`, () => {
      const { front } = skill;
      assert.equal(front.name, skill.name, 'name matches the folder');
      assert.equal(front.license, 'MIT');
      assert.match(front.metadata.version, /^\d+\.\d+\.\d+$/);
      assert.equal(front.metadata.source, 'https://github.com/giraybatiturk/skills');
      assert.ok(front.metadata.author);
      assert.ok(front.description.length > 0 && front.description.length <= 1024, `description length ${front.description.length}`);
      assert.ok(front.description.endsWith(`(v${front.metadata.version})`), 'description ends with the version stamp');
    });

    it(`${skill.name}: has agents/openai.yaml that invokes it`, () => {
      const yaml = readFileSync(path.join(skill.dir, 'agents/openai.yaml'), 'utf8');
      assert.match(yaml, /display_name: ".+"/);
      assert.match(yaml, new RegExp(`default_prompt: "[^"]*\\$${skill.name}\\b`));
      assert.match(yaml, /allow_implicit_invocation: true/);
    });
  }

  it('plugin.json: version is the highest skill version and real-test carries it', () => {
    const versions = all.map((s) => s.front.metadata.version);
    assert.equal(plugin.version, versions.sort(compare).at(-1));
    assert.equal(all.find((s) => s.name === 'real-test').front.metadata.version, plugin.version);
  });

  it('plugin.json: lists exactly the skills on disk and counts them', () => {
    assert.deepEqual([...plugin.skills].sort(), all.map((s) => s.rel).sort());
    assert.ok(plugin.description.startsWith(`${capitalized(countWord)} connected workflows`), plugin.description);
    assert.ok(plugin.keywords.includes('testing'));
  });

  it('marketplace.json: counts and names every workflow', () => {
    const { description } = marketplace.plugins[0];
    assert.ok(description.startsWith(`${capitalized(countWord)} connected product workflows`), description);
    for (const name of shortNames) assert.ok(description.includes(name), `marketplace description mentions ${name}`);
  });

  it('install-local.sh: installs every skill from its folder and counts them', () => {
    const script = read('scripts/install-local.sh');
    const names = /^names=\((.*)\)$/m.exec(script)[1].split(' ');
    const sources = /^sources=\((.*)\)$/m.exec(script)[1].split(' ');
    assert.deepEqual([...names].sort(), all.map((s) => s.name).sort());
    assert.deepEqual([...sources].sort(), all.map((s) => s.rel.replace('./skills/', '')).sort());
    for (const [i, name] of names.entries()) assert.equal(path.basename(sources[i]), name, `names and sources line up at ${name}`);
    assert.match(script, new RegExp(`all ${countWord} workflows`));
    assert.match(script, /real-test\/scripts\/\$file/);
    for (const file of ['guard.mjs', 'summary.mjs']) assert.match(script, new RegExp(file.replace('.', '\\.')));
  });

  it('build-zips.sh: takes the skill list from plugin.json, no list of its own', () => {
    const script = read('scripts/build-zips.sh');
    assert.match(script, /plugin\.json/);
    for (const skill of all) assert.ok(!script.includes(skill.name), `build-zips.sh does not hard-code ${skill.name}`);
  });

  it('installer test: expects one link per skill', () => {
    const python = read('scripts/test-audit-regressions.py');
    assert.match(python, new RegExp(`len\\(list\\(self\\.dest\\.iterdir\\(\\)\\)\\), ${all.length}\\)`));
  });

  it('README: counts, lists and documents every workflow and the release', () => {
    const readme = read('README.md');
    assert.ok(readme.includes(`${capitalized(countWord)} connected workflows`));
    assert.ok(readme.includes(`## The ${countWord} workflows`));
    assert.ok(readme.includes(`Download the ${countWord} zips`) && readme.includes(`Upload all ${countWord};`));
    assert.ok(readme.includes(`complete ${countWord}-skill bundle`));
    for (const skill of all) assert.match(readme, new RegExp(`^\\| \`/${skill.name}\` \\|`, 'm'), `README table row for ${skill.name}`);
    const codexList = /public list should contain exactly (.*)\./.exec(readme)[1];
    for (const skill of all) assert.ok(codexList.includes(`\`${skill.name}\``), `Codex list names ${skill.name}`);
    assert.ok(readme.includes(`- **${plugin.version}** (`), `changelog entry for ${plugin.version}`);
    assert.ok(readme.includes('scripts/test-real-test.mjs'));
  });

  it('real-start: routes to every other skill', () => {
    const start = all.find((s) => s.name === 'real-start').text;
    for (const skill of all.filter((s) => s.name !== 'real-start')) assert.ok(start.includes(`\`${skill.name}\``), `real-start routes to ${skill.name}`);
  });

  it('real-check and real-audit descriptions point at real-test', () => {
    for (const name of ['real-check', 'real-audit']) assert.ok(all.find((s) => s.name === name).front.description.includes('real-test'), name);
  });

  it('docs/real-hardening-status.md: counts the workflows', () => {
    assert.ok(read('docs/real-hardening-status.md').includes(`${capitalized(countWord)} workflows are retained`));
  });
});

describe('real-test SKILL.md and README claims', () => {
  const text = read('skills/engineering/real-test/SKILL.md');
  const body = text.replace(/^---\n[\s\S]*?\n---\n/, '');
  const description = frontmatter(text).description;
  const readme = read('README.md');
  const changelog = readme.slice(readme.indexOf('- **0.12.0**'), readme.indexOf('- **0.11.0**'));

  it('names its flags, its helper scripts and its siblings', () => {
    for (const word of ['--flows', '--out', '--lang', '--allow-writes', 'init-agents', 'CHECKPOINT', 'test.fixme', '.auth/', 'storageState', '`real-check`', '`real-audit`']) {
      assert.ok(body.includes(word), `SKILL.md mentions ${word}`);
    }
    for (const script of ['guard.mjs', 'summary.mjs']) {
      assert.ok(body.includes(`scripts/${script}`), `SKILL.md calls ${script}`);
      assert.ok(existsSync(path.join(SKILL, 'scripts', script)), `${script} exists`);
    }
  });

  it('has the seven steps in order and the safety section', () => {
    const steps = [...body.matchAll(/^(\d+)\. \*\*([^*]+)\*\*/gm)].map((m) => `${m[1]} ${m[2]}`);
    assert.deepEqual(steps, ['1 Parse `$ARGUMENTS`.', '2 Preflight.', '3 Auth.', '4 Plan.', '5 Generate.', '6 Run and heal.', '7 Report.']);
    assert.match(body, /^## Safety$/m);
  });

  it('mentions neither a brand nor a cloud service', () => {
    assert.doesNotMatch(text, /tasarim\.io|modal\.com|paddle|anthropic sdk/i);
  });

  it('review: does not promise more than it enforces', () => {
    for (const [name, claim] of [['description', description], ['SKILL.md', body], ['README', readme], ['changelog', changelog]]) {
      assert.doesNotMatch(claim, /never submits irreversible/i, `${name}: irreversible submits happen with --allow-writes`);
      assert.doesNotMatch(claim, /never a weakened assertion|never write a weakened/i, `${name}: the guard checks matchers and arguments, not intent`);
      assert.doesNotMatch(claim, /sends nothing anywhere except|Nothing leaves it except/i, `${name}: data also goes to the app under test and to setup downloads`);
    }
    assert.match(body, /Besides the app under test and the one-time downloads of setup/);
    assert.match(readme, /Credentials go only to the app under test: you log in yourself once/);
    assert.match(readme, /Test data, page content, snapshots and test code go to the app under test and pass through your agent's model provider/);
    assert.doesNotMatch(readme, /Test data and credentials go only to/, 'credentials must not read as going to the model provider');
    assert.match(body, /Credentials do not: the user logs in themselves/);
    assert.match(readme, /npm and Chromium downloads/);
    assert.doesNotMatch(readme, /installs both into your project as a dev dependency/);
    assert.match(description, /Stops before any final submit/);
  });

  it('review: asks about production for every host, drops query and fragment, uses a dedicated folder', () => {
    assert.match(body, /Ask once, for every host/);
    assert.match(body, /only make "non-production" the suggested answer/);
    assert.doesNotMatch(body, /are non-production; for anything else/);
    assert.match(body, /never its query or fragment/);
    assert.match(body, /path of the target URL, no query or fragment/);
    assert.match(body, /Only this skill writes there/);
    assert.match(body, /IPv6 literals are not supported/);
  });

  it('review: backs up .mcp.json, hardens whenever the agents exist, says browser_evaluate stays', () => {
    assert.match(body, /copy any existing `\.mcp\.json` aside/);
    assert.match(body, /Harden, every time the agents exist/);
    assert.match(body, /The agents keep `browser_evaluate`/);
  });

  it('review: write tests are tagged, skipped for another origin, and the guard enforces the tag', () => {
    assert.match(body, /`grepInvert`/);
    assert.match(body, /@writes/);
    assert.match(body, /--require-tag @writes/);
    assert.match(body, /relative to `baseURL`/);
  });

  it('review: counts blocked flows and names the confirm run', () => {
    assert.match(body, /--plan specs\/real-test-plan\.md/);
    assert.match(body, /`flowTotals`/);
    assert.match(body, /`<run>` = `confirm`/);
    assert.match(body, /Run the command again \(`<run>` = `final`\)/);
  });

  it('review: the tested origin is pinned and checked, not assumed (R3)', () => {
    assert.match(body, /Write `<out>\/seed\.spec\.ts` on every run/);
    assert.match(body, /"env": \{ "BASE_URL": "<origin>" \}/);
    assert.match(body, /mcp_servers\.playwright-test\.env/);
    assert.match(body, /echo "\$\{BASE_URL-\}"/);
    assert.match(body, /BASE_URL=<origin> PLAYWRIGHT_HTML_OPEN=never/);
    assert.match(body, /read their default `baseURL` origin and their `grepInvert` origin/);
    assert.match(body, /earlier target's origin must never stay behind/);
    assert.equal((body.match(/WRONG_ORIGIN/g) ?? []).length >= 2, true, 'planner and generator briefs name WRONG_ORIGIN');
  });

  it('review: the guard output reaches the report mechanically, and the plan scopes the counts (R2, R6)', () => {
    assert.match(body, /--json <report>\/guard-generate\.json/);
    assert.match(body, /--json <report>\/guard-heal\.json/);
    assert.match(body, /--guard <report>\/guard-generate\.json \[--guard <report>\/guard-heal\.json\]/);
    assert.match(body, /`assertion-target-changed`/);
    assert.match(body, /every entry of `guard\.targetChanges`/);
    assert.match(body, /`extra` lists specs in the folder that ran but are not in the plan/);
    assert.match(body, /the tag is required of the planned specs only/);
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// guard.mjs: rules
// ---------------------------------------------------------------------------------------------------------------------

const wrap = (body) => `import { test, expect } from '@playwright/test';\n\ntest.describe('Suite', () => {\n  test('Case', async ({ page }) => {\n${body}\n  });\n});\n`;
const OK_LINE = '    await expect(page).toHaveTitle(/x/);';
/** Rule ids that fire on one statement inside an otherwise sound test. */
const fires = (sample, ctx) => new Set(scan(wrap(`    ${sample}\n${OK_LINE}`), ctx).map((f) => f.rule));
const CLEAN = wrap(`    // 1. Enter the password and check the delete button text; fetch is only a word here
    await page.goto('/todomvc/#/');
    const input = page.getByRole('textbox', { name: 'What needs to be done?' });
    await input.fill('Buy milk');
    await input.press('Enter');
    await expect(page.getByTestId('todo-title')).toHaveText(['Buy milk']);
    await page.getByLabel('Email').fill('test.user@example.com');
    await page.getByLabel('Password').fill(process.env.E2E_PASSWORD ?? '');
    await expect(page).toHaveURL(/#\\/$/);
    expect(await page.$$eval('li', (items) => items.length)).toBe(1);
    expect(await page.$eval('h1', (h) => h.textContent)).toContain('todos');`);

describe('guard.mjs rules', () => {
  // Every sample must fire the rule it is filed under. The "review:" ones are inputs the reviews showed to slip through.
  const MUST_REJECT = {
    'network-intercept': ["await page.route('**/api/**', (r) => r.fulfill({ body: '{}' }));", 'await context.unroute("**/*");', "await page.routeFromHAR('x.har');"],
    'new-context': ['const ctx = await browser.newContext();', 'const p = await browser.newPage();', "const c = await chromium.launchPersistentContext('/tmp/x');"],
    'direct-request': ["await request.get('/api/users');", "await page.request.get('/api/admin/export');", "await context.request.post('/x');"],
    'write-call': ["await page.request.post('/api/todos', { data: {} });", "await request.delete('/api/todos/1');", "await apiContext.delete('/x');", "await page.evaluate(() => 1, { method: 'POST' });"],
    'in-page-network': ["await page.evaluate(() => fetch('/api/x'));", 'navigator.sendBeacon("/x");', "await page.evaluate(\"fetch('/api/x', { method: 'POST' })\");"],
    'form-submit': [
      'await page.evaluate(() => document.forms[0].submit());',
      "await page.evaluate(() => document.querySelector('form').requestSubmit());",
      "await page.locator('form').dispatchEvent('submit');",
    ],
    'foreign-code': ["const fs = require('fs');", "const m = await import('./x.js');", "import { x } from 'lodash';", "import 'dotenv/config';", "eval('1 + 1');", "import fs from 'node:fs';"],
    'page-scripting': ["await page.addInitScript(() => { localStorage.setItem('sid', 'abc'); });", "await page.addScriptTag({ content: 'x' });"],
    'session-injection': [
      "await context.addCookies([{ name: 'sid', value: '1', url: 'https://x.test' }]);",
      "document.cookie = 'a=b';",
      "localStorage.setItem('authToken', 'x');",
      "await page.context().storageState({ path: 'leak.json' });",
      "test.use({ storageState: 'other.json' });",
      "test.use({ baseURL: 'https://prod.example.com' });",
    ],
    'absolute-url': ["await page.goto('https://staging.example.com/app');", "await page.goto('//staging.example.com/app');"],
    'trivial-assertion': ['expect(true).toBe(true);', "expect('a').toBe('a');", 'expect(1 === 1).toBe(true);', 'expect([]).toEqual([]);', 'expect(1).toBeGreaterThan(0);'],
    'always-true-matcher': ["expect(page.getByText('x')).toBeTruthy();", 'expect(n).toBeDefined();', 'expect(count).toBeGreaterThanOrEqual(0);', 'expect(count).toBeGreaterThan(-1);'],
    'vacuous-matcher': ["await expect(page.getByRole('status')).toHaveText(/.*/);", "await expect(page.getByRole('status')).toContainText('');", "await expect(page).toHaveURL(/(?:)/);"],
    'match-all-regex': ["await expect(page.getByText(/.*/)).toBeVisible();", "await page.getByRole('button', { name: /[\\s\\S]*/ }).click();"],
    'matcherless-expect': ["expect(page.getByText('x'));", "await expect(page.getByText('x'));"],
    'unawaited-assertion': ["expect(page.getByText('x')).toBeVisible();", 'expect.poll(() => page.title()).toBe("x");', "expect(page).toHaveURL(/x/);"],
    'conditional-assertion': [
      "if (await page.getByText('x').isVisible()) { await expect(page.getByText('x')).toHaveText('y'); }",
      "await page.getByText('x').isVisible() && await expect(page).toHaveURL(/x/);",
      "for (const el of await page.getByText('Saved').all()) await expect(el).toBeVisible();",
      "for (const el of await page.getByText('Saved').all()) {\n      await expect(el).toBeVisible();\n    }",
      "(await page.getByText('Saved').all()).forEach(async (el) => { await expect(el).toBeVisible(); });",
      "await Promise.all(names.map(async (n) => { await expect(page.getByText(n)).toBeVisible(); }));",
      "switch (kind) {\n      case 'a':\n        await expect(page).toHaveURL(/x/);\n        break;\n    }",
      "while (retry) { await expect(page).toHaveURL(/x/); retry = false; }",
    ],
    'early-return': ['if (isMobile) return;', 'if (isMobile) {\n      return;\n    }', 'if (isMobile) return\n    await page.goto("/x");'],
    'try-catch': ['try { await expect(page).toHaveURL(/x/); } catch (e) { console.log(e); }'],
    'swallowed-error': ["await page.getByText('x').click().catch(() => {});", "await page.getByText('x').click().catch(noop);", "await page.getByText('x').click().catch(console.log);", 'try { await a(); } catch {}'],
    'force-action': ["await page.getByRole('button').click({ force: true });"],
    'fixed-wait': ['await page.waitForTimeout(2000);', "await page.waitForLoadState('networkidle');"],
    'skip-or-only': [
      "test.skip('x', async () => {});",
      "test.only('x', async () => {});",
      "test.describe.skip('x', () => {});",
      "await test.step.skip('x', async () => {});",
      "test.describe.serial.only('x', () => {});",
    ],
    'expected-failure': ['test.fail();', "test.fail(true, 'known');", "test.info().expectedStatus = 'failed';", "test.info().annotations.push({ type: 'fail' });"],
    'timeout-or-retry': ['test.describe.configure({ retries: 5 });', 'test.slow();', 'test.setTimeout(600000);', 'test.use({ actionTimeout: 120000 });'],
    'fixme-without-reason': ['test.fixme();', 'test.fixme(true);', 'test.fixme(isMobile);', "test.fixme(true, '');"],
    'credential-typed': [
      "await page.getByLabel('Password').fill('hunter2');",
      "await page.locator('input[type=password]').fill(\"s3cret\");",
      "await page.getByRole('textbox', { name: 'API token' }).pressSequentially('abc123');",
      "await page.fill('#password', 'hunter2hunter2');",
      "await page.type('input[name=password]', 'hunter2hunter2');",
      "await page.getByLabel('Şifre').fill('abc123');",
      "await page.getByLabel('ŞİFRE').fill('abc123');",
      "await page.getByLabel('Parola').fill('abc123');",
      "await page.getByLabel('PIN').fill('482913');",
      "await page.locator('#pwd').fill('abc123');",
      "await page.getByLabel('Passwort').fill('abc123');",
      "await page.getByLabel('Contraseña').fill('abc123');",
    ],
    'secret-literal': [
      "const password = 'hunter2hunter2';",
      "const pw = 'hunter2hunter2';",
      "const creds = { pass: 'hunter2hunter2' };",
      "const şifre = 'hunter2hunter2';",
      "headers: { Authorization: 'Basic abc' }",
      'const t = "Bearer abcdefghijklmnop";',
      "const k = 'AKIAABCDEFGHIJKLMNOP';",
      "const jwt = 'eyJhbGciOiJI.eyJzdWIiOiIx.sig';",
      'const k = "sk_live_abcdefgh12345678";',
    ],
    'url-secret': ["await page.goto('/x?token=abcdef123456');", "await page.goto('/x?a=1&api_key=abcdef123456');", "const u = 'https://user:hunter2@staging.example.com/';"],
    'real-card': [
      "await page.getByLabel('Card number').fill('4532 0151 1283 0366');",
      "await page.fill('#card', '6011514433546201');",
    ],
    'real-email': [
      "await page.getByLabel('Email').fill('jane.doe@gmail.com');",
      "await page.getByLabel('Email').type('someone@company.io');",
      "await page.fill('#email', 'giray@gmail.com');",
      "const email = 'giray@gmail.com';",
    ],
  };

  for (const [rule, samples] of Object.entries(MUST_REJECT)) {
    it(`rejects ${rule} (${samples.length} samples)`, () => {
      assert.ok(RULE_INFO[rule], `${rule} is a known rule`);
      for (const sample of samples) assert.ok(fires(sample).has(rule), `${rule} should catch: ${sample}; got ${[...fires(sample)]}`);
    });
  }

  it('the table above covers every rule that rejects (nothing is untested)', () => {
    const special = new Set(['no-assertion', 'missing-write-tag']); // separate tests below
    for (const [rule, [action]] of Object.entries(RULE_INFO)) if (action === 'reject' && !special.has(rule)) assert.ok(rule in MUST_REJECT, `test table covers ${rule}`);
  });

  it('review: rejects a relative import that leaves the tests folder, allows one inside it', () => {
    const ctx = { file: '/project/tests/real-test/a.spec.ts', root: '/project/tests/real-test' };
    assert.ok(fires("import { evil } from '../../../elsewhere/evil';", ctx).has('foreign-code'));
    assert.ok(fires("import { evil } from '/etc/passwd';", ctx).has('foreign-code'));
    assert.ok(!fires("import { login } from './helpers';", ctx).has('foreign-code'));
    assert.ok(!fires("import { login } from '../real-test/helpers';", ctx).has('foreign-code'));
    assert.ok(fires("import { evil } from '../elsewhere/evil';").has('foreign-code'), 'without a folder, any parent import counts as outside');
  });

  it('rejects a test without any assertion, also one whose only expect( sits in a string', () => {
    assert.deepEqual(scan(wrap("    await page.goto('/');")).map((h) => h.rule), ['no-assertion']);
    assert.deepEqual(scan(wrap("    const s = 'expect(x)';")).map((h) => h.rule), ['no-assertion']);
  });

  it('the seed and helpers are not asked for assertions', () => {
    assert.deepEqual(scan("import { test } from '@playwright/test';\ntest('seed', async ({ page }) => { await page.goto('/'); });\n", { spec: false }), []);
  });

  it('passes an ordinary generated test, step comments, env-based input and page.$eval included', () => {
    assert.deepEqual(scan(CLEAN), []);
  });

  it('review: does not reject ordinary code (false positives)', () => {
    for (const sample of [
      'await expect(page.getByText("Use fetch() here")).toBeVisible();',
      "await expect(page.getByText('fetch(')).toBeVisible();",
      "const seen = new Map(); seen.delete('a');",
      "const u = new URL('http://x.test/?q=1'); u.searchParams.delete('q');",
      "await expect(page.getByRole('status')).toHaveText('');",
      "await page.getByLabel('Password').fill('');",
      "await page.getByLabel('Forgot password?').click();\n    await page.getByLabel('Email').fill('user@example.com');",
      "await Promise.all([expect(page.getByText('a')).toBeVisible(), expect(page.getByText('b')).toBeVisible()]);",
      "expect(await page.title()).toContain('x');",
      "if (isMobile) { await page.getByRole('button', { name: 'Menu' }).click(); }",
      "await page.getByRole('link', { name: 'Docs' }).click();\n    await expect(page).toHaveURL(/docs\\/#intro$/);",
      "await expect(page.getByRole('heading', { name: 'todos' })).toBeVisible({ timeout: 10_000 });",
      "const passed = ['a'];\n    const compass = 'north-by-north-west';",
      "await Promise.all([\n      expect(page.getByText('a')).toBeVisible(),\n      expect(page.getByText('b')).toBeVisible(),\n    ]);",
      "await expect(\n      page.getByRole('heading', { name: 'todos' }),\n    ).toBeVisible();",
      "await page.getByLabel('Card number').fill('4242 4242 4242 4242');\n    await page.getByLabel('Expiry').fill('12 / 34');\n    await page.getByLabel('CVC').fill('123');",
      "await page.getByLabel('OTP').fill('000000');",
      "await page.getByLabel('PIN code').fill('560001');",
      "await page.getByLabel('Order number').fill('1234567812345678');",
      "await page.getByLabel('Card number').fill('5555555555554444');",
      "await page.getByLabel('Card number').fill('378282246310005');",
      "const checks = [1, 2];\n    for (const n of checks) { await page.getByRole('button', { name: `Add ${n}` }).click(); }",
      "await expect(async () => {\n      await expect(page.getByText('x')).toBeVisible();\n    }).toPass();",
      "await expect.poll(async () => (await page.title()), { timeout: 5000 }).toBe('x');",
      "await page.getByLabel('Country').selectOption('TR');\n    await page.getByLabel('I agree').check();\n    await page.getByLabel('Upload').setInputFiles('tests/fixtures/sample.pdf');",
      "page.once('dialog', (dialog) => { void dialog.accept(); });\n    await page.getByRole('button', { name: 'Delete draft' }).click();",
      "const id = 3;\n    await page.goto(`/items/${id}`);",
      "const total = 10; const half = total / 2;\n    await expect(page.getByText(String(half))).toBeVisible();",
      "await expect(page.getByText(\"Sepet'e eklendi\")).toBeVisible();",
      "await test.step('open menu', async () => {\n      await page.getByRole('button', { name: 'Menu' }).click();\n      await expect(page.getByRole('navigation')).toBeVisible();\n    });",
      "await page.getByLabel('Username').fill('test-user');\n    await page.getByLabel('Full name').fill('Test User');\n    await page.getByLabel('Coupon').fill('SUMMER10');\n    await page.getByLabel('Passport number').fill('U1234567');",
      "await page.getByLabel('Card number').fill('4242 4242 4242 4242');\n    await page.getByLabel('Expiry').fill('12 / 34');\n    await page.getByLabel('CVC').fill('123');\n    await page.getByLabel('ZIP').fill('94107');",
      "await page.getByRole('button', { name: 'Forgot password?' }).click()\n    await page.getByLabel('Email').fill('user@example.com')",
      "await expect(page.getByRole('status')).toHaveText(/saved|gespeichert|kaydedildi/i);",
      "const rows = page.getByRole('row');\n    const n = await rows.count();\n    expect(n).toBeGreaterThan(0);",
      "const [popup] = await Promise.all([page.waitForEvent('popup'), page.getByRole('link', { name: 'Docs' }).click()]);\n    await expect(popup).toHaveURL(/docs/);",
      "test.fixme(isMobile, 'The phone layout hides the toggle; the plan expects it visible.');",
    ]) {
      const hits = scan(wrap(`    ${sample}\n${OK_LINE}`));
      assert.deepEqual(hits.map((h) => `${h.rule}:${h.line}`), [], `should pass: ${sample}`);
    }
  });

  it('allows reserved mail domains and empty input', () => {
    for (const address of ['a@example.com', 'a@mail.example.org', 'a@host.test', 'a@x.invalid', 'a@localhost']) {
      assert.deepEqual([...fires(`await page.getByLabel('Email').fill('${address}');`)], [], address);
      assert.deepEqual([...fires(`await page.fill('#email', '${address}');`)], [], address);
    }
  });

  it('does not glue a test title to the first line of its body', () => {
    const text = "import { test, expect } from '@playwright/test';\ntest('Reset password', async ({ page }) => {\n  await page.getByLabel('Email').fill('a@example.com');\n  await expect(page).toHaveURL(/x/);\n});\n";
    assert.deepEqual(scan(text), []);
    const bare = "import { test, expect } from '@playwright/test';\ntest('Reset password', async ({ page }) => { page.getByLabel('Email').fill('a@example.com'); await expect(page).toHaveURL(/x/); });\n";
    assert.deepEqual(scan(bare), [], 'a body that starts with page. on the same line as the title');
  });

  it('review: a regex literal with an apostrophe does not hide a comment or confuse the counts', () => {
    const text = wrap("    await expect(page.getByText(/don't/i)).toBeVisible();\n    // await page.route('**/*', () => {}); expect(page)\n    await expect(page).toHaveURL(/x/);");
    assert.deepEqual(scan(text), []);
    assert.equal(countExpects(text), 2);
  });

  it('ignores comments, keeps line numbers and still sees code after a URL string', () => {
    const text = wrap("    // await page.route('**/*', () => {});\n    /* force: true */\n    await page.goto('/a'); await page.waitForTimeout(10);\n    await expect(page).toHaveURL(/x/);");
    assert.deepEqual(scan(text).map((h) => [h.rule, h.line]), [['fixed-wait', 7]]);
    assert.equal(stripComments(text).split('\n').length, text.split('\n').length);
    assert.equal(stripComments(text).length, text.length);
  });

  it('treats test.fixme with a reason as fine', () => {
    for (const call of ["test.fixme(true, 'The app shows nothing.');", "test.fixme(isMobile, 'Overflows at 375 px.');"]) assert.ok(!fires(call).has('fixme-without-reason'), call);
  });

  it('counts expect calls and compares assertions by matcher and arguments, not by locator', () => {
    assert.equal(countExpects("// expect(a)\nawait expect(b).toBe(1); await expect.soft(c).toBe(2); await expect.poll(d).toBe(3);"), 3);
    const before = wrap("    await expect(page.getByText('a')).toHaveText('Payment declined');\n    await expect(page.getByText('b')).not.toBeChecked();");
    assert.equal(missingAssertions(before, before), 0);
    assert.equal(missingAssertions(before, before.replace("getByText('a')", "getByRole('alert')").replace('toBeChecked()', 'toBeChecked({ timeout: 9000 })')), 0, 'locator and timeout changes are fine');
    assert.equal(missingAssertions(before, before.replace("toHaveText('Payment declined')", 'toBeVisible()')), 1, 'matcher swapped, count unchanged');
    assert.equal(missingAssertions(before, before.replace('not.toBeChecked', 'toBeChecked')), 1, '.not dropped');
    assert.equal(missingAssertions(before, before.replace("'Payment declined'", '/.*/')), 1, 'argument loosened');
    assert.equal(missingAssertions(before, before + '\nawait expect(x).toBe(1);'), 0, 'more assertions are fine');
  });

  it('review: the require-tag rule', () => {
    const tagged = "import { test, expect } from '@playwright/test';\ntest('a', { tag: '@writes' }, async ({ page }) => { await expect(page).toHaveURL(/x/); });\ntest('b', { tag: ['@x', '@writes'] }, async ({ page }) => { await expect(page).toHaveURL(/x/); });\n";
    assert.deepEqual(scan(tagged, { requireTag: '@writes' }), []);
    const one = tagged.replace("{ tag: ['@x', '@writes'] }, ", '');
    assert.deepEqual(scan(one, { requireTag: '@writes' }).map((h) => h.rule), ['missing-write-tag']);
    assert.deepEqual(scan(one), []);
  });

  it('review: a tag on the describe covers its tests; a describe without the tag does not', () => {
    const body = "  test('a', async ({ page }) => { await expect(page).toHaveURL(/x/); });\n  test('b', async ({ page }) => { await expect(page).toHaveURL(/x/); });\n";
    const head = "import { test, expect } from '@playwright/test';\n";
    assert.deepEqual(scan(`${head}test.describe('Flow', { tag: '@writes' }, () => {\n${body}});\n`, { requireTag: '@writes' }), []);
    assert.deepEqual(scan(`${head}test.describe('Flow', { tag: ['@a', '@writes'] }, () => {\n${body}});\n`, { requireTag: '@writes' }), []);
    assert.deepEqual(scan(`${head}test.describe('Flow', () => {\n${body}});\n`, { requireTag: '@writes' }).map((h) => h.rule), ['missing-write-tag']);
    assert.deepEqual(scan(`${head}test.describe('Flow', { tag: '@other' }, () => {\n${body}});\n`, { requireTag: '@writes' }).map((h) => h.rule), ['missing-write-tag']);
    const mixed = `${head}test.describe('Flow', { tag: '@writes' }, () => {\n${body}});\ntest('outside', async ({ page }) => { await expect(page).toHaveURL(/x/); });\n`;
    assert.deepEqual(scan(mixed, { requireTag: '@writes' }).map((h) => h.rule), ['missing-write-tag']);
  });

  it('review: card numbers: published test cards pass, a Luhn-valid other number is a real-looking card', () => {
    for (const card of ['4242 4242 4242 4242', '5555555555554444', '378282246310005', '4000-0566-5566-5556']) assert.equal(realLookingCard(card), false, card);
    for (const card of ['4532015112830366', '4532 0151 1283 0366', '6011514433546201']) assert.equal(realLookingCard(card), true, card);
    for (const notCard of ['1234567812345678', '123', '1700000000000', '']) assert.equal(realLookingCard(notCard), false, notCard);
  });

  it('review: data files (json, csv, .env) are scanned for secrets, real emails and card numbers (R4)', () => {
    const rules = (text) => scanData(text).map((f) => f.rule).sort();
    assert.deepEqual(rules('{\n  "password": "hunter2hunter2",\n  "email": "giray@gmail.com"\n}\n'), ['real-email', 'secret-literal']);
    assert.deepEqual(rules('name,password\nA,hunter2hunter2\n'), ['secret-literal']);
    assert.deepEqual(rules('API_TOKEN=abcdefgh12345\n'), ['secret-literal']);
    assert.deepEqual(rules('user,card\nTest User,4532 0151 1283 0366\n'), ['real-card']);
    assert.deepEqual(rules('{ "url": "https://x.test/?token=abcdef123456" }'), ['secret-literal', 'url-secret']);
    assert.deepEqual(rules('{\n  "name": "Test User",\n  "email": "test.user@example.com",\n  "card": "4242 4242 4242 4242",\n  "created": 1700000000000\n}\n'), []);
  });

  it('review: a changed locator text inside an assertion is reported, a repaired constant is not (R2)', () => {
    const before = wrap("    await expect(page.getByText('Saved')).toBeVisible();\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeEnabled();");
    assert.deepEqual(assertionTargetChanges(before, before), { count: 0, line: 1 });
    const weaker = before.replace("page.getByText('Saved')", "page.locator('body')");
    const changes = assertionTargetChanges(before, weaker);
    assert.equal(changes.count, 1);
    assert.equal(changes.line, 5);
    assert.equal(missingAssertions(before, weaker), 0, 'the matcher is unchanged, so only the target warning catches it');
    assert.equal(assertionTargetChanges(before, before.replace("name: 'Retry'", "name: 'Try again'")).count, 1);
    const viaConst = (name) => wrap(`    const retry = page.getByRole('button', { name: '${name}' });\n    await expect(retry).toBeEnabled();`);
    assert.equal(assertionTargetChanges(viaConst('Retry'), viaConst('Try again')).count, 0, 'a locator held in a variable is the healer\'s to repair');
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// guard.mjs: command line, baseline
// ---------------------------------------------------------------------------------------------------------------------

describe('guard.mjs command line', () => {
  const run = (...args) => spawnSync(process.execPath, [GUARD, ...args], { encoding: 'utf8' });
  const lines = (result) => result.stdout.trim().split('\n').map((line) => JSON.parse(line));
  const summaryOf = (result) => lines(result).at(-1);
  const findingsOf = (result) => lines(result).slice(0, -1);
  const temp = () => {
    const dir = mkdtempSync(path.join(tmpdir(), 'real-test-guard-'));
    return { dir, done: () => rmSync(dir, { recursive: true, force: true }) };
  };
  const SEED = "import { test } from '@playwright/test';\n\ntest('seed', async ({ page }) => {\n  await page.goto('/todomvc');\n});\n";

  it('sets aside a bad file, leaves good files and a clean seed alone, and never prints source lines', () => {
    const { dir, done } = temp();
    try {
      writeFileSync(path.join(dir, 'good.spec.ts'), CLEAN);
      writeFileSync(path.join(dir, 'bad.spec.ts'), wrap("    await page.getByLabel('Password').fill('hunter2-secret');\n    await expect(page).toHaveURL(/x/);"));
      writeFileSync(path.join(dir, 'seed.spec.ts'), SEED);
      const result = run(dir);
      assert.equal(result.status, 1);
      assert.ok(!result.stdout.includes('hunter2-secret'));
      assert.deepEqual(summaryOf(result), { checked: 3, rejected: ['bad.spec.ts'], restored: [], warnings: 0 });
      assert.deepEqual(findingsOf(result).map((f) => [f.file, f.rule, f.action]), [['bad.spec.ts', 'credential-typed', 'reject']]);
      assert.deepEqual(readdirSync(dir).sort(), ['bad.spec.ts.rejected', 'good.spec.ts', 'seed.spec.ts']);
    } finally {
      done();
    }
  });

  it('exits 0 and touches nothing when every file is clean', () => {
    const { dir, done } = temp();
    try {
      writeFileSync(path.join(dir, 'good.spec.ts'), CLEAN);
      writeFileSync(path.join(dir, 'seed.spec.ts'), SEED);
      const result = run(dir);
      assert.equal(result.status, 0);
      assert.deepEqual(lines(result), [{ checked: 2, rejected: [], restored: [], warnings: 0 }]);
    } finally {
      done();
    }
  });

  it('review: scans the seed and helper files too', () => {
    const { dir, done } = temp();
    try {
      writeFileSync(path.join(dir, 'good.spec.ts'), CLEAN.replace("import { test, expect } from '@playwright/test';", "import { test, expect } from '@playwright/test';\nimport { open } from './helpers';"));
      writeFileSync(path.join(dir, 'helpers.ts'), "export async function open(page) { await page.route('**/*', (r) => r.abort()); }\n");
      writeFileSync(path.join(dir, 'seed.spec.ts'), SEED.replace("'/todomvc'", "'/todomvc?token=abcdef123456'"));
      const result = run(dir);
      assert.equal(result.status, 1);
      assert.deepEqual(summaryOf(result).rejected, ['helpers.ts', 'seed.spec.ts']);
      assert.deepEqual(findingsOf(result).map((f) => [f.file, f.rule]), [['helpers.ts', 'network-intercept'], ['seed.spec.ts', 'url-secret']]);
      assert.ok(existsSync(path.join(dir, 'seed.spec.ts.rejected')));
    } finally {
      done();
    }
  });

  it('finds specs in subfolders and ignores node_modules', () => {
    const { dir, done } = temp();
    try {
      mkdirSync(path.join(dir, 'a'));
      mkdirSync(path.join(dir, 'node_modules'));
      writeFileSync(path.join(dir, 'a/deep.spec.ts'), wrap("    await page.route('**/*', () => {});\n    await expect(page).toHaveURL(/x/);"));
      writeFileSync(path.join(dir, 'node_modules/dep.spec.ts'), 'route(');
      const result = run(dir);
      assert.equal(result.status, 1);
      assert.deepEqual(summaryOf(result).rejected, ['a/deep.spec.ts']);
      assert.ok(existsSync(path.join(dir, 'node_modules/dep.spec.ts')));
    } finally {
      done();
    }
  });

  it('--require-tag rejects a spec with an untagged test and leaves a fully tagged one', () => {
    const { dir, done } = temp();
    try {
      const tagged = "import { test, expect } from '@playwright/test';\ntest('a', { tag: '@writes' }, async ({ page }) => { await expect(page).toHaveURL(/x/); });\n";
      writeFileSync(path.join(dir, 'tagged.spec.ts'), tagged);
      writeFileSync(path.join(dir, 'untagged.spec.ts'), tagged.replace("{ tag: '@writes' }, ", ''));
      writeFileSync(path.join(dir, 'seed.spec.ts'), SEED);
      const result = run(dir, '--require-tag', '@writes');
      assert.equal(result.status, 1);
      assert.deepEqual(summaryOf(result).rejected, ['untagged.spec.ts']);
      assert.deepEqual(findingsOf(result).map((f) => f.rule), ['missing-write-tag']);
    } finally {
      done();
    }
  });

  it('exits 2 on usage errors', () => {
    assert.equal(run().status, 2);
    assert.equal(run('/nonexistent-real-test-dir').status, 2);
    const { dir, done } = temp();
    try {
      assert.equal(run(dir, '--baseline').status, 2);
      assert.equal(run(dir, '--baseline', path.join(dir, 'missing')).status, 2);
      assert.equal(run(dir, '--require-tag').status, 2);
      assert.equal(run(dir, '--require-tag', 'writes').status, 2);
      assert.equal(run(dir, 'extra').status, 2);
    } finally {
      done();
    }
  });

  it('runs through a symlink, the way the installer links the skill', () => {
    const { dir, done } = temp();
    try {
      const link = path.join(dir, 'real-test');
      symlinkSync(SKILL, link);
      const tests = path.join(dir, 'tests');
      mkdirSync(tests);
      writeFileSync(path.join(tests, 'good.spec.ts'), CLEAN);
      const result = spawnSync(process.execPath, [path.join(link, 'scripts/guard.mjs'), tests], { encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(summaryOf(result).checked, 1);
    } finally {
      done();
    }
  });

  // The heal. `before` is the copy taken before the healer ran, `after` what the healer left.
  const FLOW = (assertions) => wrap(`    await page.goto('/pay');\n${assertions}`);
  const STRONG = FLOW("    await expect(page.getByRole('alert')).toHaveText('Payment declined');\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();");
  const heal = ({ before = STRONG, after, extraBefore = {}, extraAfter = {} }) => {
    const { dir, done } = temp();
    const b = path.join(dir, 'before');
    const a = path.join(dir, 'after');
    mkdirSync(b);
    mkdirSync(a);
    writeFileSync(path.join(b, 'seed.spec.ts'), SEED);
    writeFileSync(path.join(a, 'seed.spec.ts'), SEED);
    writeFileSync(path.join(b, 't.spec.ts'), before);
    if (after !== null) writeFileSync(path.join(a, 't.spec.ts'), after);
    for (const [name, content] of Object.entries(extraBefore)) writeFileSync(path.join(b, name), content);
    for (const [name, content] of Object.entries(extraAfter)) writeFileSync(path.join(a, name), content);
    const result = run(a, '--baseline', b);
    const out = { result, summary: summaryOf(result), findings: findingsOf(result), file: (name) => (existsSync(path.join(a, name)) ? readFileSync(path.join(a, name), 'utf8') : null), names: () => readdirSync(a).sort() };
    return { ...out, done };
  };

  const MUST_RESTORE = {
    'review: matcher swapped, same number of expects (Codex 4)': [FLOW("    await expect(page.getByRole('alert')).toBeVisible();\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();"), 'assertion-changed'],
    'review: .not inversion': [FLOW("    await expect(page.getByRole('alert')).toHaveText('Payment declined');\n    await expect(page.getByRole('button', { name: 'Retry' })).not.toBeVisible();"), 'assertion-changed'],
    'review: argument widened to match anything': [FLOW("    await expect(page.getByRole('alert')).toHaveText(/.*/);\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();"), 'assertion-changed'],
    'review: argument changed to another text': [FLOW("    await expect(page.getByRole('alert')).toHaveText('Payment');\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();"), 'assertion-changed'],
    'an assertion removed and an unrelated one added': [FLOW("    await expect(page.getByRole('alert')).toHaveText('Payment declined');\n    await expect(page).toHaveURL(/pay/);"), 'assertion-changed'],
    'an assertion removed': [FLOW("    await expect(page.getByRole('alert')).toHaveText('Payment declined');"), 'assertion-changed'],
    'review: a bare expect with no matcher added, count went up': [FLOW("    await expect(page.getByRole('alert')).toBeVisible();\n    await expect(page.getByRole('button', { name: 'Retry' }));\n    await expect(page.getByRole('alert'));"), 'assertion-changed'],
  };
  for (const [name, [after, rule]] of Object.entries(MUST_RESTORE)) {
    it(`restores the pre-heal test: ${name}`, () => {
      const h = heal({ after });
      try {
        assert.equal(h.result.status, 1);
        assert.deepEqual(h.summary.restored, ['t.spec.ts']);
        assert.deepEqual(h.summary.rejected, []);
        assert.ok(h.findings.some((f) => f.file === 't.spec.ts' && f.rule === rule && f.action === 'restored'), JSON.stringify(h.findings));
        assert.equal(h.file('t.spec.ts'), STRONG);
      } finally {
        h.done();
      }
    });
  }

  it('review: restores the pre-heal test when the heal adds test.fail(), and keeps the healed one aside (S1)', () => {
    const h = heal({ after: STRONG.replace("    await page.goto('/pay');", "    test.fail();\n    await page.goto('/pay');") });
    try {
      assert.equal(h.result.status, 1);
      assert.deepEqual(h.summary, { checked: 2, rejected: [], restored: ['t.spec.ts'], warnings: 0 });
      assert.deepEqual(h.findings.map((f) => [f.rule, f.action]), [['expected-failure', 'reject'], ['rejected-after-heal', 'restored']]);
      assert.equal(h.file('t.spec.ts'), STRONG);
      assert.ok(h.names().includes('t.spec.ts.rejected'));
    } finally {
      h.done();
    }
  });

  it('review: a heal that breaks a rule while keeping every assertion is reverted, not dropped from the run (S1)', () => {
    const h = heal({ after: STRONG.replace("    await page.goto('/pay');", "    await page.goto('/pay');\n    await page.waitForTimeout(500);") });
    try {
      assert.deepEqual(h.summary.rejected, []);
      assert.deepEqual(h.summary.restored, ['t.spec.ts']);
      assert.equal(h.file('t.spec.ts'), STRONG);
    } finally {
      h.done();
    }
  });

  it('review: a heal that adds .toBeTruthy() in place of an assertion is restored', () => {
    const h = heal({ after: FLOW("    await expect(page.getByRole('alert')).toHaveText('Payment declined');\n    expect(await page.getByRole('button', { name: 'Retry' }).isVisible()).toBeTruthy();") });
    try {
      assert.deepEqual(h.summary, { checked: 2, rejected: [], restored: ['t.spec.ts'], warnings: 0 });
      assert.equal(h.file('t.spec.ts'), STRONG);
    } finally {
      h.done();
    }
  });

  it('restores a test the heal deleted', () => {
    const h = heal({ after: null });
    try {
      assert.deepEqual(h.summary.restored, ['t.spec.ts']);
      assert.ok(h.findings.some((f) => f.rule === 'file-deleted'));
      assert.equal(h.file('t.spec.ts'), STRONG);
    } finally {
      h.done();
    }
  });

  it('review: restores a seed or helper the heal edited (N8)', () => {
    const { dir, done } = temp();
    try {
      const b = path.join(dir, 'before');
      const a = path.join(dir, 'after');
      mkdirSync(b);
      mkdirSync(a);
      for (const d of [b, a]) writeFileSync(path.join(d, 't.spec.ts'), STRONG);
      writeFileSync(path.join(b, 'seed.spec.ts'), SEED);
      writeFileSync(path.join(a, 'seed.spec.ts'), SEED.replace("'/todomvc'", "'/other'"));
      writeFileSync(path.join(b, 'helpers.ts'), 'export const x = 1;\n');
      writeFileSync(path.join(a, 'helpers.ts'), 'export const x = 2;\n');
      const result = run(a, '--baseline', b);
      assert.equal(result.status, 1);
      assert.deepEqual(summaryOf(result).restored, ['helpers.ts', 'seed.spec.ts']);
      assert.deepEqual(findingsOf(result).map((f) => f.rule), ['protected-file-changed', 'protected-file-changed']);
      assert.equal(readFileSync(path.join(a, 'seed.spec.ts'), 'utf8'), SEED);
    } finally {
      done();
    }
  });

  it('keeps a heal that repairs a locator held in a variable, bumps a timeout or adds an assertion, with no finding', () => {
    const named = (name) => FLOW(`    const retry = page.getByRole('button', { name: '${name}' });\n    await expect(page.getByRole('alert')).toHaveText('Payment declined', { timeout: 15000 });\n    await expect(retry).toBeVisible();${name === 'Retry' ? '' : '\n    await expect(page).toHaveURL(/pay/);'}`);
    const h = heal({ before: named('Retry'), after: named('Try again') });
    try {
      assert.equal(h.result.status, 0, JSON.stringify(h.findings));
      assert.deepEqual(h.summary, { checked: 2, rejected: [], restored: [], warnings: 0 });
      assert.equal(h.file('t.spec.ts'), named('Try again'));
    } finally {
      h.done();
    }
  });

  // A heal that keeps every assertion's matcher and arguments but wraps, skips or ends the test early: reverted.
  const MUST_REVERT = {
    'review: early return before unchanged assertions (R1)': [STRONG.replace("    await page.goto('/pay');", "    await page.goto('/pay');\n    if (isMobile) return;"), 'early-return'],
    'review: assertion in a for loop over .all() (R1)': [FLOW("    for (const el of await page.getByRole('alert').all()) await expect(el).toHaveText('Payment declined');\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();"), 'conditional-assertion'],
    'review: assertions in forEach (R1)': [FLOW("    (await page.getByRole('alert').all()).forEach(async (el) => { await expect(el).toHaveText('Payment declined'); });\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();"), 'conditional-assertion'],
    'review: assertion in a switch case (R1)': [FLOW("    switch (mode) {\n      case 'a':\n        await expect(page.getByRole('alert')).toHaveText('Payment declined');\n        break;\n    }\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();"), 'conditional-assertion'],
    'review: expectedStatus assigned (R1)': [STRONG.replace("    await page.goto('/pay');", "    await page.goto('/pay');\n    test.info().expectedStatus = 'failed';"), 'expected-failure'],
    'review: assertion behind an if (R1)': [FLOW("    if (await page.getByRole('alert').isVisible()) {\n      await expect(page.getByRole('alert')).toHaveText('Payment declined');\n    }\n    await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();"), 'conditional-assertion'],
  };
  for (const [name, [after, rule]] of Object.entries(MUST_REVERT)) {
    it(`reverts to the pre-heal test: ${name}`, () => {
      const h = heal({ after });
      try {
        assert.equal(h.result.status, 1);
        assert.deepEqual(h.summary.rejected, []);
        assert.deepEqual(h.summary.restored, ['t.spec.ts']);
        assert.ok(h.findings.some((f) => f.rule === rule && f.action === 'reject'), JSON.stringify(h.findings));
        assert.ok(h.findings.some((f) => f.rule === 'rejected-after-heal'));
        assert.equal(h.file('t.spec.ts'), STRONG);
      } finally {
        h.done();
      }
    });
  }

  it('review: an assertion pointed at another element is a warning that the report must list, not a restore (R2)', () => {
    const { dir, done } = temp();
    try {
      const b = path.join(dir, 'before');
      const a = path.join(dir, 'after');
      mkdirSync(b);
      mkdirSync(a);
      const saved = (target) => wrap(`    await page.goto('/pay');\n    await expect(${target}).toBeVisible();`);
      writeFileSync(path.join(b, 't.spec.ts'), saved("page.getByText('Saved')"));
      writeFileSync(path.join(a, 't.spec.ts'), saved("page.locator('body')"));
      const json = path.join(dir, 'report/guard-heal.json');
      const result = run(a, '--baseline', b, '--json', json);
      assert.equal(result.status, 0, 'a warning does not block');
      assert.deepEqual(summaryOf(result), { checked: 1, rejected: [], restored: [], warnings: 1 });
      const [finding] = findingsOf(result);
      assert.deepEqual([finding.file, finding.rule, finding.action, finding.line], ['t.spec.ts', 'assertion-target-changed', 'warn', 6]);
      assert.equal(readFileSync(path.join(a, 't.spec.ts'), 'utf8'), saved("page.locator('body')"), 'the healed file stays');
      const written = JSON.parse(readFileSync(json, 'utf8'));
      assert.deepEqual(written.summary, summaryOf(result));
      assert.equal(written.findings[0].rule, 'assertion-target-changed');
      // The summary carries it into the report data.
      const results = path.join(dir, 'results.json');
      writeFileSync(results, JSON.stringify(FINAL));
      const summary = spawnSync(process.execPath, [SUMMARY, results, '--guard', json], { encoding: 'utf8' });
      assert.equal(summary.status, 0, summary.stderr);
      const parsed = JSON.parse(summary.stdout);
      assert.deepEqual(parsed.guard.targetChanges.map((f) => [f.source, f.file, f.rule]), [['guard-heal.json', 't.spec.ts', 'assertion-target-changed']]);
    } finally {
      done();
    }
  });

  it('review: data files under the tests folder are scanned and a bad one is set aside (R4)', () => {
    const { dir, done } = temp();
    try {
      writeFileSync(path.join(dir, 'login.spec.ts'), wrap("    await page.getByLabel('Email').fill(users.email);\n    await page.getByLabel('Label').fill(users.password);\n    await expect(page).toHaveURL(/x/);").replace("import { test, expect } from '@playwright/test';", "import { test, expect } from '@playwright/test';\nimport users from './users.json';"));
      writeFileSync(path.join(dir, 'users.json'), '{"password":"hunter2hunter2","email":"giray@gmail.com"}');
      writeFileSync(path.join(dir, 'clean.json'), '{"name":"Test User","email":"test.user@example.com"}');
      writeFileSync(path.join(dir, 'seed.spec.ts'), SEED);
      const result = run(dir);
      assert.equal(result.status, 1);
      assert.ok(!result.stdout.includes('hunter2hunter2') && !result.stdout.includes('gmail'));
      assert.deepEqual(summaryOf(result).rejected, ['users.json']);
      assert.deepEqual(findingsOf(result).map((f) => `${f.file}:${f.rule}`).sort(), ['users.json:real-email', 'users.json:secret-literal']);
      assert.deepEqual(readdirSync(dir).sort(), ['clean.json', 'login.spec.ts', 'seed.spec.ts', 'users.json.rejected']);
    } finally {
      done();
    }
  });

  it('review: a data file the heal edited is restored (R4)', () => {
    const { dir, done } = temp();
    try {
      const b = path.join(dir, 'before');
      const a = path.join(dir, 'after');
      mkdirSync(b);
      mkdirSync(a);
      for (const d of [b, a]) writeFileSync(path.join(d, 't.spec.ts'), STRONG);
      writeFileSync(path.join(b, 'users.json'), '{"name":"Test User"}');
      writeFileSync(path.join(a, 'users.json'), '{"name":"Someone Else"}');
      const result = run(a, '--baseline', b);
      assert.equal(result.status, 1);
      assert.deepEqual(summaryOf(result).restored, ['users.json']);
      assert.equal(readFileSync(path.join(a, 'users.json'), 'utf8'), '{"name":"Test User"}');
    } finally {
      done();
    }
  });

  it('review: --require-tag with --plan checks only the planned specs; older specs in the folder are left alone (R6)', () => {
    const { dir, done } = temp();
    try {
      const plan = path.join(dir, 'plan.md');
      const tagged = "import { test, expect } from '@playwright/test';\ntest('a', { tag: '@writes' }, async ({ page }) => { await expect(page).toHaveURL(/x/); });\n";
      const untagged = tagged.replace("{ tag: '@writes' }, ", '');
      const tests = path.join(dir, 'tests');
      mkdirSync(tests);
      writeFileSync(path.join(tests, 'planned.spec.ts'), tagged);
      writeFileSync(path.join(tests, 'old-flow.spec.ts'), untagged);
      writeFileSync(plan, `#### 1.1. Planned\n\n**File:** \`${path.relative(process.cwd(), path.join(tests, 'planned.spec.ts'))}\`\n`);
      const result = run(tests, '--require-tag', '@writes', '--plan', plan);
      assert.equal(result.status, 0, JSON.stringify(findingsOf(result)));
      assert.deepEqual(readdirSync(tests).sort(), ['old-flow.spec.ts', 'planned.spec.ts']);
      writeFileSync(path.join(tests, 'planned.spec.ts'), untagged);
      const second = run(tests, '--require-tag', '@writes', '--plan', plan);
      assert.equal(second.status, 1);
      assert.deepEqual(summaryOf(second).rejected, ['planned.spec.ts']);
      assert.ok(existsSync(path.join(tests, 'old-flow.spec.ts')), 'the older spec is not touched');
      assert.equal(run(tests, '--require-tag', '@writes').status, 1, 'without a plan every spec is checked (old-flow.spec.ts)');
      assert.equal(run(tests, '--plan', path.join(dir, 'missing.md')).status, 2);
    } finally {
      done();
    }
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// summary.mjs
// ---------------------------------------------------------------------------------------------------------------------

const result = (status, extra = {}) => ({ status, errors: [], attachments: [], ...extra });
const testRow = (projectName, status, results, annotations = []) => ({ projectName, status, annotations, results });
const spec = (title, file, tests) => ({ title, file, tests });
const fileSuite = (file, describe, specs) => ({ title: file, file, specs: [], suites: [{ title: describe, file, specs }] });

const ANSI_ERROR = '\u001b[31mError:\u001b[39m expect(locator).toBeVisible() failed\n\nLocator: getByText("x")';
const FINAL = {
  config: { rootDir: path.join(process.cwd(), 'tests/real-test') },
  errors: [],
  suites: [
    fileSuite('a.spec.ts', 'Flow A', [spec('Adds', 'a.spec.ts', [testRow('real-test-desktop', 'expected', [result('passed')]), testRow('real-test-mobile', 'expected', [result('passed')])])]),
    fileSuite('b.spec.ts', 'Flow B', [
      spec('Fails on phone', 'b.spec.ts', [
        testRow('real-test-desktop', 'expected', [result('passed')]),
        testRow('real-test-mobile', 'unexpected', [result('failed', { errors: [{ message: ANSI_ERROR }], attachments: [{ name: 'screenshot', contentType: 'image/png', path: path.join(process.cwd(), 'out/shot.png') }, { name: 'trace', contentType: 'application/zip', path: path.join(process.cwd(), 'out/trace.zip') }] })]),
      ]),
    ]),
    fileSuite('c.spec.ts', 'Flow C', [
      spec('Known defect', 'c.spec.ts', [testRow('real-test-desktop', 'skipped', [result('skipped')], [{ type: 'fixme', description: 'No error message is shown.' }])]),
      spec('Skipped without a reason', 'c.spec.ts', [testRow('real-test-desktop', 'skipped', [result('skipped')])]),
    ]),
    fileSuite('d.spec.ts', 'Flow D', [spec('Flaky one', 'd.spec.ts', [testRow('real-test-desktop', 'flaky', [result('failed'), result('passed')])])]),
    fileSuite('seed.spec.ts', 'Seed', [spec('seed', 'seed.spec.ts', [testRow('real-test-desktop', 'expected', [result('passed')])])]),
  ],
};

describe('summary.mjs', () => {
  it('counts statuses, groups flows, excludes the seed and keeps evidence', () => {
    const summary = summarize(FINAL);
    assert.deepEqual(summary.totals, { failed: 1, flaky: 1, fixme: 1, skipped: 1, passed: 3 });
    assert.deepEqual(summary.flowTotals, { failed: 1, flaky: 1, fixme: 1, skipped: 0, passed: 1, blocked: 0 });
    assert.deepEqual(summary.flows.map((f) => [f.file, f.status]), [
      ['tests/real-test/a.spec.ts', 'passed'],
      ['tests/real-test/b.spec.ts', 'failed'],
      ['tests/real-test/c.spec.ts', 'fixme'],
      ['tests/real-test/d.spec.ts', 'flaky'],
    ]);
    assert.deepEqual(summary.flows[1].projects, { 'real-test-desktop': 'passed', 'real-test-mobile': 'failed' });
    const failed = summary.tests.find((t) => t.status === 'failed');
    assert.equal(failed.title, 'Flow B > Fails on phone');
    assert.equal(failed.error, 'Error: expect(locator).toBeVisible() failed');
    assert.deepEqual(failed.screenshots, ['out/shot.png']);
    assert.deepEqual(failed.traces, ['out/trace.zip']);
    assert.equal(summary.tests.find((t) => t.status === 'fixme').reason, 'No error message is shown.');
    assert.deepEqual(summary.runErrors, []);
    assert.deepEqual(summary.blocked, []);
  });

  it('review: a test marked test.fail() is never passed and never healed (Codex 3)', () => {
    const marked = structuredClone(FINAL);
    marked.suites[0].suites[0].specs[0].tests[0].annotations = [{ type: 'fail' }];
    const first = structuredClone(FINAL);
    first.suites[0].suites[0].specs[0].tests[0] = testRow('real-test-desktop', 'unexpected', [result('failed')]);
    const summary = summarize(marked, first);
    const row = summary.tests.find((t) => t.file.endsWith('a.spec.ts') && t.project === 'real-test-desktop');
    assert.equal(row.status, 'failed');
    assert.match(row.reason, /test\.fail/);
    const flow = summary.flows.find((f) => f.file.endsWith('a.spec.ts'));
    assert.deepEqual([flow.status, flow.healed], ['failed', false]);
    assert.equal(summary.totals.passed, 2);
  });

  it('review: planned flows without a run are blocked and counted (Codex 8, S10)', () => {
    const plan = [
      '## Test Scenarios', '### 1. Flows', '',
      '#### 1.1. Adds', '', '**File:** `tests/real-test/a.spec.ts`', '',
      '#### 1.2. Was rejected', '', '**File:** `tests/real-test/e.spec.ts`', '',
      '#### 1.3. Never generated', '', '**File:** `tests/real-test/f.spec.ts`', '',
    ].join('\n');
    assert.deepEqual(planned(plan), [
      { title: 'Adds', file: 'tests/real-test/a.spec.ts' },
      { title: 'Was rejected', file: 'tests/real-test/e.spec.ts' },
      { title: 'Never generated', file: 'tests/real-test/f.spec.ts' },
    ]);
    const summary = summarize(FINAL, undefined, plan, (file) => file === 'tests/real-test/e.spec.ts.rejected');
    assert.deepEqual(summary.blocked, [
      { file: 'tests/real-test/e.spec.ts', title: 'Was rejected', reason: 'rejected by the guard' },
      { file: 'tests/real-test/f.spec.ts', title: 'Never generated', reason: 'no test file' },
    ]);
    assert.deepEqual(summary.flowTotals, { failed: 0, flaky: 0, fixme: 0, skipped: 0, passed: 1, blocked: 2 });
    assert.equal(summary.flows.filter((f) => f.status === 'blocked').length, 2);
    assert.equal(Object.values(summary.flowTotals).reduce((sum, n) => sum + n, 0), 3, 'flowTotals add up to the 3 scenarios of the plan');
    assert.equal(summarize(FINAL, undefined, plan, (file) => !file.endsWith('.rejected')).blocked[0].reason, 'not run', 'a planned file that exists but did not run (filtered out) is blocked as not run');
  });

  it('review: flows that ran but are not in the plan are listed apart and not counted (R6)', () => {
    const plan = '#### 1.1. Adds\n\n**File:** `tests/real-test/a.spec.ts`\n\n#### 1.2. Fails on phone\n\n**File:** `tests/real-test/b.spec.ts`\n';
    const summary = summarize(FINAL, undefined, plan);
    assert.deepEqual(summary.flows.map((f) => f.file), ['tests/real-test/a.spec.ts', 'tests/real-test/b.spec.ts']);
    assert.deepEqual(summary.extra.map((f) => [f.file, f.status]), [['tests/real-test/c.spec.ts', 'fixme'], ['tests/real-test/d.spec.ts', 'flaky']]);
    assert.equal(Object.values(summary.flowTotals).reduce((sum, n) => sum + n, 0), 2, 'two scenarios in the plan, two flows counted');
    assert.deepEqual(summary.totals, { failed: 1, flaky: 0, fixme: 0, skipped: 0, passed: 3 });
    assert.equal(summarize(FINAL).extra.length, 0, 'without a plan every flow is counted');
    assert.equal(summarize(FINAL, undefined, plan).tests.every((t) => /\/(?:a|b)\.spec\.ts$/.test(t.file)), true);
  });

  it('reports run errors so that an empty run is not green', () => {
    const summary = summarize({ config: {}, suites: [], errors: [{ message: '\u001b[31mError: No tests found\u001b[39m\nmore' }] });
    assert.deepEqual(summary.totals, { failed: 0, flaky: 0, fixme: 0, skipped: 0, passed: 0 });
    assert.deepEqual(summary.runErrors, ['Error: No tests found']);
  });

  it('merges the first run: healed flows, and evidence for a failure that became a fixme', () => {
    const first = structuredClone(FINAL);
    first.suites[0].suites[0].specs[0].tests[0] = testRow('real-test-desktop', 'unexpected', [result('failed', { errors: [{ message: 'locator not found' }] })]);
    first.suites[2].suites[0].specs[0].tests[0] = testRow('real-test-desktop', 'unexpected', [result('failed', { errors: [{ message: 'no message' }], attachments: [{ name: 'screenshot', contentType: 'image/png', path: path.join(process.cwd(), 'first/s.png') }] })]);
    const summary = summarize(FINAL, first);
    const a = summary.flows.find((f) => f.file.endsWith('a.spec.ts'));
    assert.deepEqual([a.first, a.healed], ['failed', true]);
    const c = summary.flows.find((f) => f.file.endsWith('c.spec.ts'));
    assert.deepEqual([c.status, c.first, c.healed], ['fixme', 'failed', false]);
    const defect = summary.tests.find((t) => t.status === 'fixme');
    assert.deepEqual(defect.first, { status: 'failed', error: 'no message', screenshots: ['first/s.png'], traces: [] });
  });

  it('command line: reads a file and a plan, rejects bad input, works through a symlink', () => {
    const dir = mkdtempSync(path.join(tmpdir(), 'real-test-summary-'));
    try {
      const file = path.join(dir, 'results.json');
      writeFileSync(file, JSON.stringify(FINAL));
      const plan = path.join(dir, 'plan.md');
      writeFileSync(plan, '#### 1.1. Gone\n\n**File:** `tests/real-test/gone.spec.ts`\n');
      const ok = spawnSync(process.execPath, [SUMMARY, file, '--plan', plan], { encoding: 'utf8' });
      assert.equal(ok.status, 0, ok.stderr);
      assert.equal(JSON.parse(ok.stdout).totals.failed, 0, 'with a plan only the planned flows count');
      assert.equal(JSON.parse(ok.stdout).extra.length, 4);
      assert.equal(JSON.parse(ok.stdout).flowTotals.blocked, 1);
      const noPlan = spawnSync(process.execPath, [SUMMARY, file], { encoding: 'utf8' });
      assert.equal(JSON.parse(noPlan.stdout).totals.failed, 1);
      assert.equal(spawnSync(process.execPath, [SUMMARY, file, '--guard'], { encoding: 'utf8' }).status, 2);
      assert.equal(spawnSync(process.execPath, [SUMMARY, file, '--guard', path.join(dir, 'missing.json')], { encoding: 'utf8' }).status, 2);
      assert.equal(spawnSync(process.execPath, [SUMMARY], { encoding: 'utf8' }).status, 2);
      assert.equal(spawnSync(process.execPath, [SUMMARY, path.join(dir, 'missing.json')], { encoding: 'utf8' }).status, 2);
      writeFileSync(path.join(dir, 'bad.json'), '{');
      assert.equal(spawnSync(process.execPath, [SUMMARY, path.join(dir, 'bad.json')], { encoding: 'utf8' }).status, 2);
      assert.equal(spawnSync(process.execPath, [SUMMARY, file, '--first'], { encoding: 'utf8' }).status, 2);
      assert.equal(spawnSync(process.execPath, [SUMMARY, file, '--plan'], { encoding: 'utf8' }).status, 2);
      assert.equal(spawnSync(process.execPath, [SUMMARY, file, '--plan', path.join(dir, 'no-plan.md')], { encoding: 'utf8' }).status, 2);
      symlinkSync(SKILL, path.join(dir, 'real-test'));
      const linked = spawnSync(process.execPath, [path.join(dir, 'real-test/scripts/summary.mjs'), file, '--first', file], { encoding: 'utf8' });
      assert.equal(linked.status, 0, linked.stderr);
      assert.equal(JSON.parse(linked.stdout).flows.length, 4);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
