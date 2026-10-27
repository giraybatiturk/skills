---
name: real-check
description: "Quick automated check of a public URL: site kontrol, siteyi tara, URL check, broken links, console errors, mobile overflow, prospect, client or competitor site report. Rule-based and read-only. Typically takes about 30 seconds. Needs no code or account access. Writes a one-page report for the site owner (HTML + PDF). On request, it also writes an outreach message draft and a tracking row. Never sends anything. For an in-depth review of your own product, use real-audit. For persistent Playwright tests of the user flows of your own app, use real-test. (v0.12.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.12.0
  source: https://github.com/giraybatiturk/skills
---

# Real check

A fast, deterministic look at one public URL. It is written for the owner of the site. The site is often the site of someone else: a client, a prospect, a competitor.
- The check reads the home page and its links, nothing else. The report says so.
- It typically takes about 30 seconds. A slow site with many links can take a few minutes.
- `<skill>` below means the directory that contains this `SKILL.md`. Resolve it from the skill catalog of the client.

This is not an audit. `real-check` is a rule-based scan of a public URL, with no code or account access. `real-audit` is expert judgment on your own product (repo, running app, screens), with prioritized findings, coverage and validation tasks. A clean `real-check` is not proof that the site works.

## Steps

1. **Parse `$ARGUMENTS`.** Required: a URL that starts with `http://` or `https://`. Otherwise stop and show the usage. Options:
   - `--lang tr|en`: report and message language. Default: the language of the conversation of the user (`tr` or `en`). If it is neither, ask once.
   - `--brand "Name <email>"`: optional signature for the report footer and the message. No brand by default.
   - `--outreach`: also write a message draft and a tracking row.
   - `--control`: do no check and write no report. Write only a tracking row and a neutral message draft for the comparison group of an A/B experiment. It implies `--outreach`.
   - `--out DIR`: output folder. Default `./real-check-reports`. If the user or project has an established outputs convention, use it.

   Done when the URL, language and flags are fixed.

2. **Set up once.** Skip this step for `--control`. If `<skill>/scripts/node_modules/playwright` is missing (Node 20+ is required), do these steps:
   1. Run `npm install --prefix <skill>/scripts`.
   2. Run `npx --prefix <skill>/scripts playwright install chromium`.

   If installation is not permitted (sandbox, no network, Claude app without a shell), say exactly that and stop. Do not fake results.

   Done when Playwright and Chromium are installed, or you have stated the blocker.

3. **Run the check.** `node <skill>/scripts/check.mjs <url> [flags]`. The last stdout line is JSON (exit 0, 3, 4 and 6). Exit 2 and 5 write to stderr only. Exit codes:
   - `0` report written (or control row written): continue.
   - `2` usage error: show the message and stop.
   - `3` no findings: say that the automated check found nothing worth reporting. Stop. Do not write a message.
   - `4` the site does not open: report the reason and stop.
     - If the reason says that the page submits a form or sends a write request as it loads, the site did open. The read-only check blocked that write and cannot continue. Say that. Do not say that the site is down.
     - With `--outreach`, its tracking row keeps status `does-not-open`. But the note starts `not checked:` and not `site does not open:`.
   - `5` the check could not run: show the tail of stderr and stop.
   - `6` the home page refused the automated visit (likely protection against automated visits): say so. Tell the user to verify in their own browser. Stop. Do not write a message.

   With `--outreach`, a run that ends in exit 3, 4 or 6 also writes a tracking row. The row has `group=report` and status `no-findings`, `does-not-open` or `blocked`. No report or message exists.

   Show every entry of `warnings[]` verbatim. A console finding can exist together with a network warning. Then ask the user to confirm it in their own browser. Do this before you use it in a message.

   When `real-audit` calls this skill, run without `--outreach` or `--control` and skip the preview server. Return these items to the caller:
   - the `findings.json` path (`json` in the JSON line; also written on exit 3)
   - the warnings
   - on exit 3, 4 or 6, the status and the reason

   The screenshots are embedded in the HTML report (`html`). They are not saved as separate files.

   Done when you handled the exit code, listed the findings one line each and showed every warning.

4. **Outreach (only with `--outreach` or `--control`, and only after exit 0).** The script writes the tracking row. You write the message. Runs that ended in exit 3, 4 or 6 have a row but get no message.
   - Write `<slug>-message.md` into the run folder (`slug` and `dir` in the JSON line; the same folder as the report).
   - Write this warning on the top line. Use these words: "Before sending: check consent rules for unsolicited commercial messages in the recipient's jurisdiction (for example GDPR/ePrivacy in the EU, ETK/İYS in Türkiye). Not verified by this skill."
   - Then write two drafts in the report language:
     - **LinkedIn:** at most 600 characters.
     - **Email:** subject line and at most 120 words.

   Rules for both:
   - Use at most 3 findings. Write one plain sentence for each. Take them only from the `title` fields in `findings.json`, in the same order.
   - Use no jargon (console, scrollWidth, Playwright, DOM). Use no price, discount or urgency.
   - Write the greeting with the placeholder `[Name]`. Never invent a name.
   - Write one closing question: would they like the one-page report sent to them? The LinkedIn draft does not mention an attachment. The email says "I can send the one-page report".
   - Take the signature from `--brand` if given. Otherwise use `[Your name]`.
   - **Control group (`--control`):** use an identical opening and closing. Write no site-specific finding. Use only a generic line such as "I had a look at your site and a few things stood out".
   - Never send, post, upload or share anything. The user sends.

   Done when `<slug>-message.md` exists, both drafts meet their limits and every finding sentence maps to a `title`.

5. **Preview and hand over.** With a report (exit 0, not `--control`):
   1. Serve the run folder on a free, OS-assigned port bound to `127.0.0.1`. For example, run `python3 -m http.server 0 --bind 127.0.0.1` in the background.
   2. Verify with `curl` that the served `<title>` is the title of the report.
   3. Tell the user how to stop the server.
   4. Give clickable links: the HTML report from the preview server. Give the PDF, the message and `outreach.csv` as absolute `file://` URLs.

   With `--control` there is no report. Skip the preview. Link only the message and the CSV.

   Report each finding on one line. Then report any warnings. The CSV row has `status=draft`. The user updates it after sending.

   Add one line when all of these are true:
   - The checked site is the site of the user. It is never a client, prospect or competitor site.
   - You reported findings.
   - `real-test` is in the skill catalog of the client.

   The line is: "Next, optional: `real-test` can keep persistent tests of your app's user flows." Otherwise skip it silently.

   Done when every link opens and you listed the findings and warnings.

## Boundaries

- Check the home page and the same-site links on it only (first 50, GET). Follow redirects by hand, and only within the site. Do not submit a form. Do not start a checkout or a login.
  - Abort every HTTP request other than GET, HEAD and OPTIONS. Close every WebSocket.
  - Do not count the console errors that follow a blocked request as findings. These are:
    - a "Failed to load resource" line for the blocked URL, within about 2 seconds of a blocked request
    - a generic network error such as "Failed to fetch", within about 2 seconds of a blocked request
    - WebSocket errors after a closed WebSocket, with no time window
  - Report them as "possibly caused" in a warning. Keep them in `findings.json`.
  - A form that the checked page submits as it loads is blocked too. The page then shows a browser error page. The check stops with exit 4 and a reason that names the blocked write.
- Never request links that look like an action. Do not follow a redirect to one.
  - First decode and fold the path and the query (case, diacritics, Turkish dotless `ı`).
  - These keywords match anywhere in that address text, with no word boundary. The non-English ones are mostly stems, so nouns and imperatives match too (`abmeld` covers `abmelden` and `abmeldung`):
    - English: log out, log off, sign out, sign off, opt out, unsubscribe, delete, remove, cancel, deactivate, add to cart.
    - Turkish: `cikis` (`çıkış`, `ÇIKIŞ`), `oturum kapat`, `oturumu kapat`, `sepete ekle`.
    - German: `abmeld`, `ausloggen`, `lösch`, `storn`, `abbestell`, `austragen`, `entfernen`, `in den Warenkorb` (`ö` and `ü` also as `oe` and `ue`).
    - French: `déconnex`, `déconnect`, `suppr`, `désabonn`, `désinscri`, `résili` (not `résilience`), `effac`, `fermer (la) session`, `désactiv`, `ajouter au panier`.
    - Spanish: `cerrar (la) sesión`, `finalizar sesión`, `desconect`, `desconex`, `borrar`, `dar de baja` (also `darse`, `darme`), `desuscrib`, `agregar al carrito`, `añadir al carrito`.
    - Italian: `disconnett`, `disconness`, `disiscri`, `rimuovi`, `rimozion`, `disdett`, `disdici`, `disattiv`, `aggiungi al carrello`.
    - Portuguese: `terminar`, `encerrar` or `fechar (a) sessão`, `deslog`, `deletar`, `excluir`, `exclusão`, `apagar`, `descadastr`, `desinscrev`, `adicionar ao carrinho`.
    - Dutch: `uitlog`, `afmeld`, `verwijder`, `uitschrijv`, `opzeg`.
    - Add to cart as an address in other languages: `panier`, `carrito`, `carrello`, `carrinho`, `winkelwagen` or `warenkorb`, then `/` and an add word (`/carrito/agregar`, `/winkelwagen/toevoegen`). There is no query-string form outside English.
    - Only at the start of a word (no letter directly before):
      - `elimina` (`eliminar`)
      - `annul` (`annuler`, `annulla`, `annuleren`; not `annulment` or `annular`)
      - `anul` (`anular`; not `granular`)
      - `log uit`
      - `kündig` (also `kuendig`; not `verpleegkundige` or `ankündigung`)
    - Only as a whole word (no letter before or after): `salir`, `sair`, `esci`, `baja`, `uscita`.

  - The two-part words can have `-`, `_`, a space or nothing between the parts (`logout`, `add_to_cart`, `oturumu%20kapat`, `cerrar-sesion`).
  - `log/out` and `sign/out` also match, but only at the start of a word. So `/blog/outdoor` is checked.
  - `cart` followed by `/` and add, remove, update, clear or empty matches too.
  - An address with `cart` before the `?` and add, update, clear or empty anywhere in the query matches too (`/cart?add=1`, `/cart?action=add`). `/cart/address` and `/cart?address=` do not match.
  - Separately, the check skips a link when a query parameter KEY is `confirm` or ends in `token` (`token`, `access_token`, `csrfToken`). `token` text in the path or inside a parameter value does not count.
  - Keywords match anywhere. So an ordinary page whose address contains one is also left unchecked. Examples: `/blog/how-to-remove-404`, `/cancellation-policy`, `/deleted`.
  - The narrowing above is not a guarantee.
    - Whole-word matching still skips everyday uses of those words (`/donde-salir`, `/onde-sair-em-lisboa`, `/baja-california`).
    - The check also skips other-language stems inside everyday words (`/feuerlöscher`, `/planta-baja`, `/noise-suppression`, `/tattoo-entfernen`, `/kfz-abmelden`, `/asbest-verwijderen`, `/conditions-d-annulation`, `/elimination-diet`).
  - The opposite miss also exists.
    - A stem that needs a leading boundary does not match when it is glued to a letter. So the check requests glued foreign forms (`/cuentaeliminar`, `/commandeannuler`, `/vertragskuendigung`).
    - Outside English, cart actions other than add are not covered. The check requests `/panier/vider` and `/warenkorb/leeren`.
    - The check checks `/pesci`, `/preliminary-results`, `/annulment`, `/granular` and `/resilience-planning`.
  - The check reports skipped links as not checked in one warning. It lists them in `findings.json`. So a real broken page behind such an address is not checked either.
  - This is a keyword heuristic that errs towards skipping.
    - The non-English words come from general knowledge of those languages. They do not come from measured sites.
    - Other languages are not covered.
    - A site that changes state on a GET under another name is not protected.
- Abort the requests that the page sends straight to loopback, private and link-local addresses. Count them in a warning, unless the checked URL is itself local. Use literal addresses only. Do no DNS lookup.
  - A redirect hop to such an address cannot be stopped before the browser follows it. So the check only detects it.
  - If the checked page itself redirects or navigates there, or ends on a browser error page, the check stops with exit 4. A blocked navigation of a popup is only counted in the warning.
  - On the phone-width visit the same event is only a warning. The check does not check the phone layout.
  - The late-navigation check runs once, after the settle wait of about 2 s of the desktop visit. So the check does not detect a later navigation. Measured: 1.5 s after load gave exit 4. 2.6 s gave exit 3 with no mention.
- The check is rule-based. It is not a quality score.
  - A failed load of a third-party resource (network error or HTTP error) is a warning, not a finding.
  - A link that answers 401, 403, 429 or 503 is a warning, not a finding.
  - The same-site test compares the last two host labels. So under suffixes like `.com.tr` or `.co.uk`, unrelated sites count as the same site.
- The browser identifies itself as automated (`real-check/0.12` in the user agent).
  - The check does not read `robots.txt`.
  - It loads the home page twice (desktop and phone width). It requests up to 50 links. Each follows up to 5 same-site redirects.
  - When more than 50 links qualify, a warning says how many qualified. It also says that the check checked only the first 50.

## Experiment

When the user runs an outreach A/B, read `outreach.csv`.
- Count only rows whose `status` is `draft` or a later status. Rows with `no-findings`, `does-not-open` or `blocked` never had a report or message.
- If the report and control groups differ in size by 2 or more, say so in one line.
- The decision rule belongs to the user. Do not set one.
