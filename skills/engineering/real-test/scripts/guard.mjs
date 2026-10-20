#!/usr/bin/env node
// real-test guard: a static check on generated Playwright tests. Node standard library only, no network.
//
//   node guard.mjs <tests-dir> [--baseline <dir>] [--require-tag @writes] [--plan <plan.md>] [--json <file>]
//
// Scans every code file (specs, the seed, helpers) and every data file (json, csv, txt, yaml, .env ...) under <tests-dir>,
// not node_modules, and
//   - renames a file that breaks a "reject" rule to <file>.rejected, so Playwright no longer finds it (nothing is deleted);
//   - lists "warn" findings and leaves the file in place.
// With --baseline, <dir> is a copy of the tests taken before the healer ran. Then
//   - a spec that lost an assertion or changed one (the matcher, its arguments, `.not`, soft/poll; the locator being
//     checked is not compared, the healer may repair it) is restored from the copy, as is a deleted spec;
//   - the seed, helper and data files must be unchanged, else they are restored;
//   - a file the heal made break a rule is set aside and the pre-heal copy put back (it still fails, and the report says so);
//   - an assertion whose locator text changed (getByText('Saved') -> locator('body')) is a "warn" finding, so the report can
//     list it: repairing a locator is allowed, pointing an assertion somewhere weaker is not, and only a reader can tell.
// With --require-tag, every test() in a spec must carry that tag (on the test or on its describe). With --plan, that
// requirement applies only to the specs the plan lists (older specs in the folder are left alone).
// <tests-dir>/real-test.fixtures.ts is skill-owned: it is accepted, and not scanned, only when it is byte-identical to
// ../assets/fixtures.ts; any other content is rejected as `fixtures-changed`. While it is present, a spec that does not import
// it gets the warning `fixtures-not-imported` (its flow then has no observations or screenshots).
// With --json, the findings and the summary are also written to that file.
//
// stdout: one JSON object per finding {file, line, rule, action, message}, then one summary object. Offending source lines
// are never printed, so a secret in a test never reaches the model. Exit 0: nothing rejected or restored. Exit 1: at least
// one file was rejected or restored. Exit 2: usage error.
//
// This is a heuristic pattern check, not a parser: it catches the usual ways a generated test hides a failure, bypasses
// the safety rules or carries a secret. It does not prove a test is good.

import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, realpathSync, renameSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const CODE_FILE = /\.[cm]?[jt]sx?$/;
const DATA_FILE = /\.(?:json|csv|tsv|txt|ya?ml|toml|ini|md|xml|html?)$|^\.env/i;
const SPEC = /\.(?:spec|test)\.[cm]?[jt]sx?$/;
const SEED = /^seed\.spec\.[cm]?[jt]sx?$/;

// The fixtures file the preflight copies from assets/fixtures.ts; the guard accepts it only unchanged.
const FIXTURES = 'real-test.fixtures.ts';
const FIXTURES_ASSET = path.join(path.dirname(fileURLToPath(import.meta.url)), '../assets/fixtures.ts');
const FIXTURES_IMPORT = /^\.\/real-test\.fixtures(?:\.[cm]?[jt]s)?$/;

// ---------------------------------------------------------------------------------------------------------------------
// Rules. `on: 'code'` runs on the source with comments, string contents and regex bodies blanked (a UI text such as
// "Use fetch() here" is not code); `on: 'text'` runs on the source with only comments blanked.
// ---------------------------------------------------------------------------------------------------------------------

const WORDS = {
  // Words that mark a credential field or value, in the languages the skill is asked in. `[sş][iıİI]fre`: Turkish "şifre",
  // any case. A PIN code is a postal code often enough that only a bare PIN counts; card security codes and one-time codes
  // are test data (see card numbers below), not secrets.
  credential: /pass(?:word|wd|code|phrase)|\bpass\b|\bpw\b|\bpwd\b|\bpin\b(?!\s*code)|secret|api[_-]?key|token|bearer|credential|[sş][iıİI]fre|parola|kennwort|passwort|contrase|senha|wachtwoord|mot de passe/i,
  // The same words as a variable or key name.
  credentialKey: '(?:(?<![A-Za-z0-9_$])[A-Za-z0-9_$]*(?:password|passwd|passcode|passphrase|secret|api[_-]?key|apikey|token|bearer|credential|[sş][iıİI]fre|parola|kennwort|passwort|contrase\\w*|senha|wachtwoord)[A-Za-z0-9_$]*|(?<![A-Za-z0-9$])(?:pass|pw|pwd|pin)(?![A-Za-z0-9$]))',
};
// A mail domain that cannot belong to a real person (RFC 2606 / 6761).
const RESERVED_DOMAIN = '(?:[A-Za-z0-9-]+\\.)*(?:example\\.(?:com|org|net)|example|test|invalid|localhost)';
const REAL_EMAIL = new RegExp(`^[^\\s@]+@(?!${RESERVED_DOMAIN}$)[^\\s@]+\\.[A-Za-z]{2,}$`);
const EMAIL_TOKEN = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+/g;
const MATCH_ALL = /^(?:\/(?:\.\*|\.\*\?|\(\?:\)|\[\\s\\S\]\*|\^\.\*\$|\^|\$)\/[a-z]*)$/;

// Card numbers that payment providers publish for testing. Any other Luhn-valid card number may be a real card.
const TEST_CARDS = new Set(
  '4242424242424242 4000056655665556 5555555555554444 2223003122003222 5200828282828210 5105105105105100 378282246310005 371449635398431 6011111111111117 6011000990139424 3056930009020004 36227206271667 3566002020360505 6200000000000005 4000000000000002 4000000000009995 4000002500003155 4111111111111111 4012888888881881 5424000000000015 370000000000002 6011000000000012 3088000000000017 38000000000006 4007000000027 4222222222222 5528790000000008 4543590000000006 4157920000000002 4766620000000001 4603450000000000 5400010000000004 5890040000000016 5311570000000005'.split(' '),
);

const luhn = (digits) => {
  let sum = 0;
  for (let i = 0; i < digits.length; i++) {
    let d = Number(digits[digits.length - 1 - i]);
    if (i % 2 === 1 && (d *= 2) > 9) d -= 9;
    sum += d;
  }
  return sum % 10 === 0;
};
/** True for a number that passes the card checksum and is not a published test card. */
export function realLookingCard(value) {
  const digits = value.replace(/[\s-]/g, '');
  return /^[2-6]\d{12,18}$/.test(digits) && luhn(digits) && !TEST_CARDS.has(digits);
}

export const RULE_INFO = {
  // Safety: the test must not mock the network, call the backend directly, write behind the UI or run foreign code.
  'network-intercept': ['reject', 'mocks or intercepts the network'],
  'new-context': ['reject', 'creates its own browser or browser context'],
  'direct-request': ['reject', 'calls the backend directly instead of driving the UI'],
  'write-call': ['reject', 'sends a write request outside the UI'],
  'in-page-network': ['reject', 'sends requests from page code'],
  'form-submit': ['reject', 'submits a form from script'],
  'foreign-code': ['reject', 'loads or runs code other than @playwright/test and files in the tests folder'],
  'page-scripting': ['reject', 'injects scripts into the page'],
  'session-injection': ['reject', 'injects, copies or overrides a session or credentials by hand (the session comes from storageState)'],
  'absolute-url': ['reject', 'hard-codes an absolute URL in goto (use a path relative to baseURL)'],
  // Weakened tests: they pass without proving anything.
  'trivial-assertion': ['reject', 'asserts a constant'],
  'always-true-matcher': ['reject', 'matcher that is true for almost any value'],
  'vacuous-matcher': ['reject', 'matcher with an argument that matches anything'],
  'match-all-regex': ['reject', 'regular expression that matches anything'],
  'matcherless-expect': ['reject', 'expect() without a matcher asserts nothing'],
  'unawaited-assertion': ['reject', 'asynchronous assertion that is not awaited cannot fail the test'],
  'conditional-assertion': ['reject', 'assertion inside a condition, loop, switch or callback may never run'],
  'early-return': ['reject', 'returns before the last assertion, so later assertions may never run'],
  'try-catch': ['reject', 'try/catch can hide a failure'],
  'swallowed-error': ['reject', 'swallows an error'],
  'force-action': ['reject', 'forces an action past the actionability checks'],
  'fixed-wait': ['reject', 'fixed wait or networkidle (flaky)'],
  'skip-or-only': ['reject', 'skips tests or runs only some (use test.fixme with a reason)'],
  'expected-failure': ['reject', 'marks a test as expected to fail (use test.fixme with a reason)'],
  'timeout-or-retry': ['reject', 'changes timeouts or retries for a test'],
  'fixme-without-reason': ['reject', 'test.fixme without a reason'],
  'no-assertion': ['reject', 'contains no expect() call'],
  'missing-write-tag': ['reject', 'a test is missing the required tag'],
  // Secrets and personal data.
  'credential-typed': ['reject', 'types a literal into a password, token or other secret field'],
  'secret-literal': ['reject', 'hard-coded secret or token'],
  'url-secret': ['reject', 'a URL carries a secret (token, key, password or credentials)'],
  'real-email': ['reject', 'an email address that may be real (use name@example.com)'],
  'real-card': ['reject', 'a card number that is not a published test card'],
  // The skill-owned fixtures file.
  'fixtures-changed': ['reject', "real-test.fixtures.ts differs from the skill's assets/fixtures.ts (skill-owned; copy it again)"],
  // Raised only against a baseline.
  'assertion-changed': ['restored', 'assertions of the pre-heal test are gone or changed; restored'],
  'file-deleted': ['restored', 'the heal deleted this file; restored'],
  'protected-file-changed': ['restored', 'the heal edited the seed, a helper or a data file; restored'],
  'rejected-after-heal': ['restored', 'the heal broke a rule; the pre-heal test is back and still fails'],
  'assertion-target-changed': ['warn', 'assertions now look at different locator text (getByText, role name, label, selector); read the diff'],
  'fixtures-not-imported': ['warn', 'the spec does not import ./real-test.fixtures, so its flow has no observations or screenshots'],
};

const simple = (id, on, re) => ({ id, on, re });
const RULES = [
  simple('network-intercept', 'code', /\.(?:route|unroute\w*|routeFromHAR|routeWebSocket)\s*\(/g),
  simple('new-context', 'code', /\.newContext\s*\(|\bbrowser\.newPage\s*\(|\.launch(?:Persistent\w*)?\s*\(|\b(?:chromium|firefox|webkit)\s*\./g),
  simple('direct-request', 'code', /\b(?:page|context)\.request\b|\brequest\s*\.\s*(?:get|post|put|patch|delete|head|fetch|dispose|storageState)\s*\(|\bAPIRequestContext\b/g),
  simple('write-call', 'code', /\.(?:post|put|patch|fetch)\s*\(|\b(?:request|api|http|client|axios)\w*\s*\.\s*delete\s*\(/g),
  simple('write-call', 'text', /\[\s*(['"])(?:post|put|patch|delete|fetch)\1\s*\]|\bmethod\s*:\s*['"`](?:POST|PUT|PATCH|DELETE)\b/gi),
  simple('in-page-network', 'code', /\bfetch\s*\(|\bXMLHttpRequest\b|\bsendBeacon\s*\(|\bWebSocket\s*\(|\bEventSource\s*\(/g),
  simple('form-submit', 'code', /\.(?:submit|requestSubmit)\s*\(/g),
  simple('form-submit', 'text', /\.dispatchEvent\s*\(\s*['"]submit['"]/g),
  simple('foreign-code', 'code', /\brequire\s*\(|\bimport\s*\(|(?<![\w$.])eval\s*\(|\bnew\s+Function\s*\(|child_process|\bimport\s+['"]/g),
  simple('page-scripting', 'code', /\.(?:addInitScript|addScriptTag|exposeFunction|exposeBinding)\s*\(/g),
  simple('session-injection', 'code', /\.addCookies\s*\(|\.setExtraHTTPHeaders\s*\(|\bdocument\s*\.\s*cookie\s*=|\.storageState\s*\(/g),
  simple('session-injection', 'text', /\b(?:local|session)Storage\.setItem\s*\(\s*['"][^'"]*(?:token|auth|session|jwt|sid)|\buse\s*\(\s*\{[^}]*\b(?:storageState|extraHTTPHeaders|httpCredentials|baseURL)\b/gi),
  simple('absolute-url', 'text', /\.goto\s*\(\s*['"`]\s*(?:https?:)?\/\//gi),
  simple('always-true-matcher', 'code', /\.toBeTruthy\s*\(|\.toBeDefined\s*\(|\bexpect\.anything\s*\(|\.toBeGreaterThanOrEqual\s*\(\s*0\s*\)|\.toBeGreaterThan\s*\(\s*-1\s*\)|\.not\.toBeNull\s*\(|\.not\.toBeUndefined\s*\(/g),
  simple('match-all-regex', 'text', /\/(?:\.\*|\(\?:\)|\[\\s\\S\]\*|\^\.\*\$)\/[a-z]*/g),
  simple('try-catch', 'code', /\btry\s*\{/g),
  simple('swallowed-error', 'code', /\.catch\s*\(|\bcatch\s*(?:\([^)]*\))?\s*\{\s*\}/g),
  simple('force-action', 'code', /\bforce\s*:\s*true\b/g),
  simple('fixed-wait', 'code', /\.waitForTimeout\s*\(/g),
  simple('fixed-wait', 'text', /['"`]networkidle['"`]/g),
  simple('skip-or-only', 'code', /\b(?:test|describe)(?:\s*\.\s*[A-Za-z]+)*\s*\.\s*(?:skip|only)\b/g),
  simple('expected-failure', 'code', /\btest(?:\s*\.\s*[A-Za-z]+)*\s*\.\s*fail\s*\(|\bexpectedStatus\s*=(?!=)/g),
  simple('expected-failure', 'text', /\bannotations\s*\.\s*push\s*\(\s*\{\s*type\s*:\s*['"](?:fail|skip|fixme)['"]/g),
  simple('timeout-or-retry', 'code', /\btest\s*\.\s*(?:slow|setTimeout)\s*\(/g),
  simple('timeout-or-retry', 'text', /\.configure\s*\(\s*\{[^}]*\b(?:retries|timeout)\b|\buse\s*\(\s*\{[^}]*\b(?:actionTimeout|navigationTimeout|timeout)\b/g),
  simple('fixme-without-reason', 'text', /\btest\.fixme\s*\(\s*(?:!?\w+\s*)?(?:,\s*(?:''|""|``|'\s+'|"\s+")\s*)?\)/g),
  simple('secret-literal', 'text', secretLiteral()),
  simple('url-secret', 'text', /[?&#;](?:(?:access|api|auth|refresh|id|session|csrf|client)[_-])?(?:token|key|secret|password|passwd|pwd|sig|signature|jwt|sid|sessionid|apikey|auth|code)=[^&'"`\s]{6,}|\bhttps?:\/\/[^\/\s'"`@:]+:[^\/\s'"`@]+@/gi),
];

function secretLiteral() {
  return new RegExp(
    [
      `${WORDS.credentialKey}['"]?\\s*[:=]\\s*['"\`][^'"\`\\s]{4,}['"\`]`,
      "\\bAuthorization['\"]?\\s*:\\s*['\"`]",
      '\\bBearer\\s+[A-Za-z0-9._~+/-]{10,}',
      '\\beyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.',
      '\\b[sp]k_(?:live|test)_[A-Za-z0-9]{8,}',
      '\\bsk-[A-Za-z0-9_-]{20,}',
      '\\bAKIA[0-9A-Z]{16}\\b',
      '\\bgh[pousr]_[A-Za-z0-9]{20,}',
      '\\bxox[abprs]-[A-Za-z0-9-]{10,}',
      '-----BEGIN [A-Z ]*PRIVATE KEY-----',
    ].join('|'),
    'gi',
  );
}

// ---------------------------------------------------------------------------------------------------------------------
// Source preparation: blank comments, string contents and regex bodies without moving a single character.
// ---------------------------------------------------------------------------------------------------------------------

const REGEX_AFTER = /(?:^|[(,=:[!&|?{};+\-*%<>~^]|\b(?:return|typeof|case|of|in|void|throw|delete))\s*$/;
const blank = (text) => text.replace(/[^\n\r]/g, ' ');

/**
 * { code, masked, bodies }. `code`: comments blanked. `masked`: also string contents and regex bodies blanked. `bodies`: the
 * [from, to) ranges of those contents (the literal text of every string, template and regex). Same length as source.
 */
export function prepare(source) {
  const n = source.length;
  const stack = []; // open template literals and `${ }` expressions
  const bodies = [];
  let code = '';
  let masked = '';
  let run = null; // start of the current run of template text
  let i = 0;
  const endRun = () => {
    if (run !== null && code.length > run) bodies.push([run, code.length]);
    run = null;
  };
  while (i < n) {
    const c = source[i];
    const d = source[i + 1];
    const top = stack.at(-1);
    if (top?.template) {
      if (c === '`') {
        endRun();
        stack.pop();
        code += c;
        masked += c;
        i++;
      } else if (c === '$' && d === '{') {
        endRun();
        stack.push({ template: false, depth: 0 });
        code += '${';
        masked += '${';
        i += 2;
      } else {
        run ??= code.length;
        const text = c === '\\' ? source.slice(i, i + 2) : c;
        code += text;
        masked += blank(text);
        i += text.length;
      }
      continue;
    }
    if (c === '/' && (d === '/' || d === '*')) {
      let end;
      if (d === '/') {
        end = source.indexOf('\n', i);
        if (end === -1) end = n;
      } else {
        end = source.indexOf('*/', i + 2);
        end = end === -1 ? n : end + 2;
      }
      const text = source.slice(i, end);
      code += blank(text);
      masked += blank(text);
      i = end;
      continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < n && source[j] !== c && source[j] !== '\n') j += source[j] === '\\' ? 2 : 1;
      j = Math.min(j, n);
      const closed = source[j] === c;
      bodies.push([code.length + 1, code.length + 1 + (j - i - 1)]);
      code += source.slice(i, closed ? j + 1 : j);
      masked += c + blank(source.slice(i + 1, j)) + (closed ? c : '');
      i = closed ? j + 1 : j;
      continue;
    }
    if (c === '`') {
      stack.push({ template: true });
      code += c;
      masked += c;
      i++;
      continue;
    }
    if (c === '/' && REGEX_AFTER.test(code.slice(-30))) {
      let j = i + 1;
      let inClass = false;
      while (j < n && source[j] !== '\n') {
        const ch = source[j];
        if (ch === '\\') j += 2;
        else if (!inClass && ch === '/') break;
        else {
          if (ch === '[') inClass = true;
          else if (ch === ']') inClass = false;
          j++;
        }
      }
      if (source[j] === '/') {
        let k = j + 1;
        while (k < n && /[a-z]/i.test(source[k])) k++;
        bodies.push([code.length + 1, code.length + 1 + (j - i - 1)]);
        code += source.slice(i, k);
        masked += '/' + blank(source.slice(i + 1, j)) + source.slice(j, k);
        i = k;
        continue;
      }
    }
    if (top) {
      if (c === '{') top.depth++;
      else if (c === '}') {
        if (top.depth === 0) stack.pop();
        else top.depth--;
      }
    }
    code += c;
    masked += c;
    i++;
  }
  endRun();
  return { code, masked, bodies };
}

/** Back-compat name: the source with comments blanked. */
export const stripComments = (source) => prepare(source).code;

const lineOf = (text, index) => text.slice(0, index).split('\n').length;

/** Index of the bracket that closes the one at `open`, in text where strings are already blanked; -1 if none. */
function closing(masked, open) {
  const pair = { '(': ')', '{': '}', '[': ']' }[masked[open]];
  let depth = 0;
  for (let i = open; i < masked.length; i++) {
    const c = masked[i];
    if (c === masked[open]) depth++;
    else if (c === pair && --depth === 0) return i;
  }
  return -1;
}

/**
 * [start, end) ranges of statements, split at `;`, after `=> {` and at a line break before a statement keyword or `}`. A
 * piece that ends with `[`, `(` or `,` continues in the next one (`await Promise.all([` and its elements are one statement).
 */
function statements(masked) {
  const pieces = [];
  let start = 0;
  for (const m of masked.matchAll(/;|(?<==>\s*\{)|\r?\n(?=\s*(?:await|const|let|var|expect|test|if|for|while|return|import|export|throw|\}))/g)) {
    pieces.push([start, m.index]);
    start = m.index + m[0].length;
  }
  pieces.push([start, masked.length]);
  const out = [];
  for (const piece of pieces) {
    if (out.length && /[[(,]\s*$/.test(masked.slice(...out.at(-1)))) out.at(-1)[1] = piece[1];
    else out.push([...piece]);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------------------------------------------------

// Matchers on locators, pages and responses: asynchronous, so the assertion has to be awaited.
const ASYNC_MATCHERS = new Set(
  'toBeAttached toBeChecked toBeDisabled toBeEditable toBeEmpty toBeEnabled toBeFocused toBeHidden toBeInViewport toBeVisible toContainText toHaveAccessibleDescription toHaveAccessibleName toHaveAttribute toHaveClass toHaveCount toHaveCSS toHaveId toHaveJSProperty toHaveText toHaveValue toHaveValues toHaveScreenshot toMatchAriaSnapshot toHaveTitle toHaveURL toBeOK toMatchSnapshot'.split(' '),
);
const EMPTY_MATCHES_ALL = new Set(['toContainText', 'toContain', 'toMatch']); // an empty string is always contained
const TEXT_MATCHERS = new Set(['toHaveText', 'toContainText', 'toHaveValue', 'toHaveURL', 'toHaveTitle', 'toHaveAttribute', 'toHaveClass', 'toHaveId', 'toHaveCSS', 'toHaveAccessibleName', 'toHaveAccessibleDescription', 'toHaveValues', 'toContain', 'toMatch']);

/** Every expect() statement: { index, end, kind, receiver, targets, not, matcher, args (array of source texts) }. */
function findAssertions({ code, masked, bodies }) {
  const found = [];
  for (const m of masked.matchAll(/\bexpect(?:\s*\.\s*(soft|poll))?\s*\(/g)) {
    const open = m.index + m[0].length - 1;
    const close = closing(masked, open);
    if (close === -1) continue;
    let p = close + 1;
    let not = false;
    let matcher = null;
    let args = [];
    for (;;) {
      const access = /^\s*\??\.\s*([A-Za-z_$][\w$]*)/.exec(masked.slice(p, p + 120));
      if (!access) break;
      p += access[0].length;
      const call = /^\s*\(/.exec(masked.slice(p, p + 40));
      if (!call) {
        if (access[1] === 'not') not = !not;
        continue;
      }
      const argsOpen = p + call[0].length - 1;
      const argsClose = closing(masked, argsOpen);
      if (argsClose === -1) break;
      matcher = access[1];
      args = splitArguments(code, masked, argsOpen + 1, argsClose);
      p = argsClose + 1;
      break;
    }
    const targets = bodies.filter(([from, to]) => from >= open && to <= close).map(([from, to]) => code.slice(from, to));
    found.push({ index: m.index, end: p, kind: m[1] ?? '', receiver: code.slice(open + 1, close), targets, not, matcher, args });
  }
  return found;
}

/** The top-level arguments between two offsets, as source text. */
function splitArguments(code, masked, from, to) {
  const args = [];
  let depth = 0;
  let start = from;
  for (let i = from; i < to; i++) {
    const c = masked[i];
    if ('([{'.includes(c)) depth++;
    else if (')]}'.includes(c)) depth--;
    else if (c === ',' && depth === 0) {
      args.push(code.slice(start, i));
      start = i + 1;
    }
  }
  args.push(code.slice(start, to));
  return args.map((a) => a.trim()).filter((a, i, all) => a !== '' || i < all.length - 1);
}

/** What an assertion claims, without the locator it looks at: soft/poll, `.not`, matcher, normalised arguments. */
function signature(a) {
  const args = a.args
    .map((arg) => arg.replace(/\s+/g, ' ').replace(/"((?:[^"\\\n]|\\.)*)"/g, "'$1'"))
    .filter((arg) => !/^\{\s*timeout\s*:\s*[\d_.]+\s*\}$/.test(arg))
    .map((arg) => arg.replace(/,?\s*timeout\s*:\s*[\d_.]+\s*,?/g, ' ').replace(/\{\s*,?\s*\}/g, '{}'));
  return `${a.kind}|${a.not ? 'not' : ''}|${a.matcher}|${args.join(',')}`;
}

const assertionsOf = (source) => findAssertions(prepare(source));
export const countExpects = (source) => assertionsOf(source).length;

const counted = (items) => {
  const map = new Map();
  for (const item of items) map.set(item, (map.get(item) ?? 0) + 1);
  return map;
};
const missing = (before, after) => {
  const have = counted(after);
  const lost = [];
  for (const item of before) {
    const left = have.get(item) ?? 0;
    if (left > 0) have.set(item, left - 1);
    else lost.push(item);
  }
  return lost;
};

/** How many assertions of `before` are missing from `after` (as a multiset of signatures). */
export const missingAssertions = (before, after) => missing(assertionsOf(before).map(signature), assertionsOf(after).map(signature)).length;

/** Assertions of `after` whose locator text (strings and regexes inside expect(...)) differs from every `before` one; { count, line }. */
export function assertionTargetChanges(before, after) {
  const key = (a) => `${signature(a)}\u0002${a.targets.join('\u0001')}`;
  const was = assertionsOf(before);
  const now = assertionsOf(after);
  const lost = new Set(missing(was.map(key), now.map(key)));
  if (lost.size === 0) return { count: 0, line: 1 };
  const prepared = prepare(after);
  const fresh = missing(now.map(key), was.map(key));
  const first = now.find((a) => key(a) === fresh[0]);
  return { count: fresh.length, line: first ? lineOf(prepared.code, first.index) : 1 };
}

const isConstant = (receiver) => {
  const rest = receiver
    .replace(/'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"|`[^`$]*`|\b\d[\d._]*\b/g, ' ')
    .replace(/\b(?:true|false|null|undefined|NaN|Infinity)\b/g, ' ');
  return !/[A-Za-z_$]/.test(rest);
};

/** Ranges [from, to) of code that runs only under a condition, in a loop, per case or per element. */
function conditionalRanges(masked) {
  const ranges = [];
  const afterHead = (p) => {
    const bodyStart = p + /^\s*/.exec(masked.slice(p))[0].length;
    if (masked[bodyStart] === '{') {
      const end = closing(masked, bodyStart);
      if (end !== -1) ranges.push([bodyStart, end]);
    } else {
      const end = masked.slice(bodyStart).search(/;|\n/);
      ranges.push([bodyStart, end === -1 ? masked.length : bodyStart + end]);
    }
  };
  for (const m of masked.matchAll(/\b(?:if|for|while|switch)\s*\(|\belse\b/g)) {
    let p = m.index + m[0].length;
    if (m[0] !== 'else') {
      const close = closing(masked, p - 1);
      if (close === -1) continue;
      p = close + 1;
    }
    afterHead(p);
  }
  for (const m of masked.matchAll(/\.(?:forEach|map|flatMap|filter|some|every|reduce)\s*\(/g)) {
    const open = m.index + m[0].length - 1;
    const close = closing(masked, open);
    if (close !== -1) ranges.push([open, close]);
  }
  return ranges;
}

/** How many test() calls lack the tag: on the test itself or on an enclosing describe. */
function untaggedTests(code, masked, tag) {
  const escaped = tag.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const tagged = new RegExp(`\\btag\\s*:\\s*(?:\\[[^\\]]*)?['"]${escaped}['"]`);
  const callArguments = (m) => {
    const open = m.index + m[0].length - 1;
    const close = closing(masked, open);
    return close === -1 ? null : { open, close, args: splitArguments(code, masked, open + 1, close) };
  };
  const describes = [];
  for (const m of masked.matchAll(/\btest\s*\.\s*describe(?:\s*\.\s*\w+)*\s*\(/g)) {
    const call = callArguments(m);
    if (call && call.args.slice(0, -1).some((a) => tagged.test(a))) describes.push([call.open, call.close]);
  }
  let count = 0;
  for (const m of masked.matchAll(/\btest\s*\(/g)) {
    const call = callArguments(m);
    if (!call) continue;
    if (!call.args.slice(0, -1).some((a) => tagged.test(a)) && !describes.some(([from, to]) => call.open > from && call.open < to)) count++;
  }
  return count;
}

// ---------------------------------------------------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------------------------------------------------

const TYPE_TWO = /\.(?:fill|type)\s*\(\s*(['"`])((?:\\.|(?!\1)[^\\\n])*)\1\s*,\s*(['"`])((?:\\.|(?!\3)[^\\\n])*)\3/g;
const TYPE_ONE = /\.(?:fill|type|pressSequentially)\s*\(\s*(['"`])((?:\\.|(?!\1)[^\\\n])*)\1/g;

/** Literal values typed into fields in one statement: both `locator.fill('v')` and `page.fill('#sel', 'v')`. */
function typedValues(statement) {
  const values = [];
  const seen = new Set();
  for (const m of statement.matchAll(TYPE_TWO)) {
    seen.add(m.index);
    values.push(m[4]);
  }
  for (const m of statement.matchAll(TYPE_ONE)) if (!seen.has(m.index)) values.push(m[2]);
  return values.filter((v) => v.trim() !== '');
}

const IMPORT = /(\bfrom|\bimport|\brequire\s*\()\s*(['"])([^'"\n]*)\2/g;
const insideRoot = (root, target) => {
  const rel = path.relative(root, target);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
};

/** Findings for one code file's source: [{ line, rule, action, message }]. ctx: { spec = true, file, root, requireTag, fixtures }. */
export function scan(source, ctx = {}) {
  const { spec = true, file, root, requireTag, fixtures } = ctx;
  const prepared = prepare(source);
  const { code, masked } = prepared;
  const findings = [];
  const add = (index, id) => findings.push({ line: lineOf(code, index), rule: id, action: RULE_INFO[id][0], message: RULE_INFO[id][1] });

  for (const rule of RULES) {
    for (const m of (rule.on === 'text' ? code : masked).matchAll(rule.re)) add(m.index, rule.id);
  }

  // Code handed to the page as a string (page.evaluate('fetch(...)')).
  for (const m of code.matchAll(/\.(?:evaluate|evaluateHandle|\$eval|\$\$eval|waitForFunction)\s*\(\s*(['"`])((?:\\.|(?!\1)[^\\])*)\1/g)) {
    if (/\bfetch\s*\(|\bXMLHttpRequest\b|\bsendBeacon\s*\(|\bWebSocket\s*\(/.test(m[2])) add(m.index, 'in-page-network');
  }

  // Imports: only @playwright/test and files inside the tests folder.
  let importsFixtures = false;
  for (const m of code.matchAll(IMPORT)) {
    if (masked.slice(m.index, m.index + m[1].length) !== m[1]) continue; // the words sit inside a string
    const specifier = m[3];
    if (FIXTURES_IMPORT.test(specifier)) importsFixtures = true;
    if (specifier === '@playwright/test') continue;
    const relative = specifier.startsWith('.');
    const outside = relative && (file && root ? !insideRoot(root, path.resolve(path.dirname(file), specifier)) : specifier.startsWith('..'));
    if (!relative || outside) add(m.index, 'foreign-code');
  }
  if (spec && fixtures && !importsFixtures) findings.push({ line: 1, rule: 'fixtures-not-imported', action: 'warn', message: RULE_INFO['fixtures-not-imported'][1] });

  const statementRanges = statements(masked);
  const statementAt = (index) => statementRanges.find(([from, to]) => index >= from && index <= to) ?? [0, masked.length];

  // Secrets and personal data typed into fields or held in variables.
  for (const [from, to] of statementRanges) {
    const text = code.slice(from, to);
    const values = typedValues(text);
    const at = from + Math.max(0, text.search(/\S/));
    if (values.length && WORDS.credential.test(text)) add(at, 'credential-typed');
    if (values.some((v) => REAL_EMAIL.test(v.trim()))) add(at, 'real-email');
    if (values.some(realLookingCard)) add(at, 'real-card');
  }
  for (const m of code.matchAll(/(?<![A-Za-z0-9_$])[A-Za-z0-9_$]*(?:email|mail|user|login|account|owner|contact)[A-Za-z0-9_$]*['"]?\s*[:=]\s*(['"`])([^'"`\s]+)\1/gi)) {
    if (REAL_EMAIL.test(m[2])) add(m.index, 'real-email');
  }

  // Assertions.
  const assertions = findAssertions(prepared);
  const conditions = conditionalRanges(masked);
  for (const a of assertions) {
    const [stmtFrom] = statementAt(a.index);
    const prefix = masked.slice(stmtFrom, a.index);
    if (a.matcher === null) add(a.index, 'matcherless-expect');
    if (isConstant(a.receiver)) add(a.index, 'trivial-assertion');
    if (a.kind === 'poll' || ASYNC_MATCHERS.has(a.matcher)) {
      if (!/\b(?:await|return)\b/.test(prefix)) add(a.index, 'unawaited-assertion');
    }
    if (TEXT_MATCHERS.has(a.matcher)) {
      const vacuous = a.args.some((arg) => MATCH_ALL.test(arg) || (EMPTY_MATCHES_ALL.has(a.matcher) && /^(?:''|""|``)$/.test(arg)));
      if (vacuous) add(a.index, 'vacuous-matcher');
    }
    if (conditions.some(([from, to]) => a.index >= from && a.index <= to) || /&&|\|\||\?(?![.?])/.test(prefix)) add(a.index, 'conditional-assertion');
  }
  const lastAssertion = Math.max(-1, ...assertions.map((a) => a.index));
  for (const m of masked.matchAll(/\breturn\s*(?:;|\}|\n)/g)) if (m.index < lastAssertion) add(m.index, 'early-return');
  if (spec && assertions.length === 0) findings.push({ line: 1, rule: 'no-assertion', action: 'reject', message: RULE_INFO['no-assertion'][1] });
  if (spec && requireTag && untaggedTests(code, masked, requireTag) > 0) {
    findings.push({ line: 1, rule: 'missing-write-tag', action: 'reject', message: `a test is missing the required tag ${requireTag}` });
  }

  return dedupe(findings);
}

/** Findings for a data file (json, csv, txt, yaml, .env ...): secrets, URLs with secrets, real emails and real card numbers. */
export function scanData(source) {
  const findings = [];
  const add = (index, id) => findings.push({ line: lineOf(source, index), rule: id, action: RULE_INFO[id][0], message: RULE_INFO[id][1] });
  for (const rule of RULES) {
    if (rule.id !== 'secret-literal' && rule.id !== 'url-secret') continue;
    for (const m of source.matchAll(rule.re)) add(m.index, rule.id);
  }
  for (const m of source.matchAll(new RegExp(`${WORDS.credentialKey}["']?[ \\t]*[:=,][ \\t]*["']?[^\\s"',}]{4,}`, 'gi'))) add(m.index, 'secret-literal');
  // A table whose header names a credential column: any filled cell in that column is a secret.
  const [header, ...table] = source.split(/\r?\n/);
  const cell = (text) => text.trim().replace(/^["']|["']$/g, '');
  const columns = header.split(/[,;\t]/).map(cell);
  const secret = columns.flatMap((name, i) => (columns.length > 1 && WORDS.credential.test(name) ? [i] : []));
  table.forEach((row, n) => {
    const cells = row.split(/[,;\t]/);
    if (secret.some((i) => cell(cells[i] ?? '').length >= 4)) findings.push({ line: n + 2, rule: 'secret-literal', action: 'reject', message: RULE_INFO['secret-literal'][1] });
  });
  for (const m of source.matchAll(EMAIL_TOKEN)) if (REAL_EMAIL.test(m[0])) add(m.index, 'real-email');
  for (const m of source.matchAll(/(?<![\d])(?:\d[ -]?){13,19}(?![\d])/g)) if (realLookingCard(m[0].trim())) add(m.index, 'real-card');
  return dedupe(findings);
}

function dedupe(findings) {
  const seen = new Set();
  return findings.sort((a, b) => a.line - b.line).filter((f) => !seen.has(`${f.rule}:${f.line}`) && seen.add(`${f.rule}:${f.line}`));
}

// ---------------------------------------------------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------------------------------------------------

function files(dir) {
  const out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules' || entry.name.endsWith('.rejected')) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...files(full));
    else if (CODE_FILE.test(entry.name) || (DATA_FILE.test(entry.name) && statSync(full).size <= 1_000_000)) out.push(full);
  }
  return out.sort();
}

const isCode = (file) => CODE_FILE.test(file);
const isSpec = (file) => SPEC.test(path.basename(file)) && !SEED.test(path.basename(file));

/** The test files a plan lists (its `**File:**` lines), as absolute paths. */
export const plannedPaths = (planText) => new Set([...planText.matchAll(/^\*\*File:\*\*\s*`([^`]+)`/gm)].map((m) => path.resolve(m[1])));

/** Run the guard. Returns { findings, rejected, restored, checked }; moves and copies files as described above. */
export function guard(dir, options = {}) {
  const { baselineDir, requireTag, plan } = options;
  const findings = [];
  const restored = new Set();
  const rejected = [];
  const rel = (file) => path.relative(dir, file).split(path.sep).join('/');
  const restore = (from, target, rule, name) => {
    mkdirSync(path.dirname(target), { recursive: true });
    copyFileSync(from, target);
    restored.add(name);
    findings.push({ file: name, line: 1, rule, action: 'restored', message: RULE_INFO[rule][1] });
  };
  const tagFor = (file) => (requireTag && (!plan || plan.has(path.resolve(file))) ? requireTag : undefined);
  const analyze = (file, root, tag, fixtures = false) => {
    if (path.relative(root, file) === FIXTURES) {
      return readFileSync(file).equals(readFileSync(FIXTURES_ASSET)) ? [] : [{ line: 1, rule: 'fixtures-changed', action: 'reject', message: RULE_INFO['fixtures-changed'][1] }];
    }
    const source = readFileSync(file, 'utf8');
    return isCode(file) ? scan(source, { spec: isSpec(file), file, root, requireTag: tag, fixtures }) : scanData(source);
  };

  if (baselineDir) {
    for (const before of files(baselineDir)) {
      const target = path.join(dir, path.relative(baselineDir, before));
      const name = rel(target);
      const was = readFileSync(before, 'utf8');
      if (!existsSync(target)) restore(before, target, 'file-deleted', name);
      else if (isSpec(before)) {
        const now = readFileSync(target, 'utf8');
        if (missingAssertions(was, now) > 0) restore(before, target, 'assertion-changed', name);
        else {
          const { count, line } = assertionTargetChanges(was, now);
          if (count > 0) findings.push({ file: name, line, rule: 'assertion-target-changed', action: 'warn', message: `${count} ${RULE_INFO['assertion-target-changed'][1]}` });
        }
      } else if (readFileSync(target, 'utf8') !== was) restore(before, target, 'protected-file-changed', name);
    }
  }

  const withFixtures = existsSync(path.join(dir, FIXTURES));
  const all = files(dir);
  for (const file of all) {
    const name = rel(file);
    const own = analyze(file, dir, tagFor(file), withFixtures && (!plan || plan.has(path.resolve(file)))).map((f) => ({ file: name, ...f }));
    findings.push(...own);
    if (!own.some((f) => f.action === 'reject')) continue;
    renameSync(file, `${file}.rejected`);
    const before = baselineDir && path.join(baselineDir, path.relative(dir, file));
    const clean = before && existsSync(before) && !analyze(before, baselineDir, tagFor(file)).some((f) => f.action === 'reject');
    if (clean) restore(before, file, 'rejected-after-heal', name);
    else rejected.push(name);
  }
  return { findings, rejected, restored: [...restored].sort(), checked: all.length };
}

const USAGE = 'Usage: node guard.mjs <tests-dir> [--baseline <dir>] [--require-tag @tag] [--plan <plan.md>] [--json <file>]';

function main(argv) {
  const args = [...argv];
  const take = (flag) => {
    const at = args.indexOf(flag);
    return at === -1 ? undefined : (args.splice(at, 2)[1] ?? null);
  };
  const baseline = take('--baseline');
  const requireTag = take('--require-tag');
  const planFile = take('--plan');
  const jsonFile = take('--json');
  const [dir, ...extra] = args;
  if (!dir || extra.length || [baseline, requireTag, planFile, jsonFile].includes(null) || (requireTag !== undefined && !/^@[\w-]+$/.test(requireTag))) {
    console.error(USAGE);
    return 2;
  }
  for (const d of [dir, baseline].filter(Boolean)) {
    if (!existsSync(d) || !statSync(d).isDirectory()) {
      console.error(`Not a directory: ${d}\n${USAGE}`);
      return 2;
    }
  }
  let plan;
  if (planFile) {
    try {
      plan = plannedPaths(readFileSync(planFile, 'utf8'));
    } catch (error) {
      console.error(`Cannot read ${planFile}: ${error.message}`);
      return 2;
    }
  }
  const result = guard(dir, { baselineDir: baseline, requireTag, plan });
  const warnings = result.findings.filter((finding) => finding.action === 'warn').length;
  const summary = { checked: result.checked, rejected: result.rejected, restored: result.restored, warnings };
  for (const finding of result.findings) console.log(JSON.stringify(finding));
  console.log(JSON.stringify(summary));
  if (jsonFile) {
    mkdirSync(path.dirname(path.resolve(jsonFile)), { recursive: true });
    writeFileSync(jsonFile, JSON.stringify({ findings: result.findings, summary }, null, 2) + '\n');
  }
  return result.rejected.length || result.restored.length ? 1 : 0;
}

// Run only as a script, not when a test imports the helpers. The skill is installed as a symlink: process.argv[1] is the
// path as typed and import.meta.url the resolved one, so compare real paths.
const isEntry = (() => {
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
})();
if (isEntry) process.exitCode = main(process.argv.slice(2));
