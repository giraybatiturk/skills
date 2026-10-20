// real-test fixtures. Skill-owned: the preflight copies this file to <out>/real-test.fixtures.ts on every run and the guard
// rejects any other content. Specs import { test, expect } from './real-test.fixtures'.
//
// One auto fixture per test records what the page did (console errors, page errors, responses with status >= 400, failed
// requests) and, after the test body, attaches a full-page screenshot (real-test-screen), an axe-core run for WCAG 2.0/2.1
// A and AA (real-test-a11y) and the record (real-test-observations). It only observes: it never fails a test or changes
// its result; an error inside it goes into the observations attachment.
import { AxeBuilder } from '@axe-core/playwright';
import { expect, test as base } from '@playwright/test';

type Entry = Record<string, unknown>;

// Query strings and fragments can carry tokens: keep origin and path only.
const clean = (url: string) => {
  try {
    const parsed = new URL(url);
    return (parsed.origin === 'null' ? parsed.protocol : parsed.origin + parsed.pathname).slice(0, 200);
  } catch {
    return url.slice(0, 200);
  }
};

// A step that hangs must not hold the test: stop waiting for it after `ms`.
const within = <T>(work: Promise<T>, ms: number) =>
  new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`timed out after ${ms} ms`)), ms);
    work.then(resolve, reject).finally(() => clearTimeout(timer));
  });

export const test = base.extend<{ realTestObservations: void }>({
  realTestObservations: [
    async ({ page, baseURL }, use, testInfo) => {
      const origin = (() => {
        try {
          return new URL(baseURL ?? '').origin;
        } catch {
          return '';
        }
      })();
      const party = (url: string) => {
        if (!url) return 'unknown';
        try {
          return new URL(url).origin === origin ? 'same-origin' : 'third-party';
        } catch {
          return 'third-party';
        }
      };
      const seen = { console: [] as Entry[], pageErrors: [] as Entry[], badResponses: [] as Entry[], failedRequests: [] as Entry[], errors: [] as string[] };

      page.on('console', (message) => {
        if (message.type() !== 'error') return;
        const { url } = message.location();
        seen.console.push({ text: message.text().slice(0, 300), url: clean(url), party: party(url) });
      });
      page.on('pageerror', (error) => seen.pageErrors.push({ message: String(error.message ?? error).slice(0, 300) }));
      page.on('response', (response) => {
        if (response.status() >= 400) seen.badResponses.push({ url: clean(response.url()), status: response.status(), method: response.request().method(), party: party(response.url()) });
      });
      page.on('requestfailed', (request) => seen.failedRequests.push({ url: clean(request.url()), method: request.method(), error: request.failure()?.errorText, party: party(request.url()) }));

      await use();

      const record = async (step: string, work: () => Promise<void>) => {
        try {
          await work();
        } catch (error) {
          seen.errors.push(`${step}: ${String(error).slice(0, 300)}`);
        }
      };
      if (!page.isClosed()) {
        await record('screenshot', async () => {
          const body = await page.screenshot({ fullPage: true, animations: 'disabled', caret: 'hide', timeout: 10_000 });
          await testInfo.attach('real-test-screen', { body, contentType: 'image/png' });
        });
        await record('axe', async () => {
          const { violations } = await within(new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze(), 20_000);
          const list = violations.map((v) => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.length }));
          await testInfo.attach('real-test-a11y', { body: JSON.stringify({ violations: list }), contentType: 'application/json' });
        });
      }
      await testInfo.attach('real-test-observations', { body: JSON.stringify(seen), contentType: 'application/json' });
    },
    // Own budget for setup and teardown, so a slow screenshot or axe run never fails the test on its timeout.
    { auto: true, timeout: 60_000 },
  ],
});

export { expect };
