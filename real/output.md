# Output

## Links
- Make every link open on click, without exception.
- Web link: `[text](https://...)`.
- Local file or folder: `[name](file:///absolute/path)`.
- Do not use `~`, a relative path or a path without a scheme. Write spaces as `%20`.
- Do not use a plain-text URL, a bare path or a standalone `file:line`.
- If you need a line number, put it in the link text: `[index.html:1433](file:///.../index.html)`.
- Use the same format for paths from an agent report.
<!-- Why: Links in other formats did not open when the user clicked them. -->
- `file://` alone is not enough for HTML or image preview.
- Serve the folder of the file in the background: `python3 -m http.server <port> --bind 127.0.0.1`.
- Do not fix the port. Ask the operating system for a free one. Other sessions can hold ports like 8765.
- Verify with `curl` that the `<title>` of the page belongs to the expected file. A 200 alone is not enough.
- Give the link as `[name](http://127.0.0.1:<port>/file.html)`.
<!-- Why: A 200 can come from the server of another session on the same port. -->

## Open on request
- To open or show a file, a folder or a URL for the user, run `real-show.sh --open <target>`.
- On macOS the helper opens a file or a folder in the background. The app does not take focus.
- For a web page, the helper prints the link only. Give that link to the user. Do not open the page.
- If `real-show.sh` is not available, run `open -g <path>` for a file or a folder. Give a link for a web page.
- If the user says that a link did not open, check the scheme and the page title. Then give the link again.
- Do not open a page, a file or a window during a test, a screenshot or a build. Use the own headless browser.
- Do not run `open`, `xdg-open` or a browser command for any other reason. A hook can deny these commands.
<!-- Why: A test showed that `open -g` still makes a new tab the active tab. Without `-g`, the app also takes focus. A page that opens by itself interrupts the user. One helper keeps the link, the title check and the open rule in one place. -->

## Generated documents and artifacts
- Give every generated HTML document or print source a fixed white background.
- Use `:root{color-scheme:light only}` and `html,body{background:#fff}`. In-chat widgets are the exception.
- If you published an Artifact in the session, publish it again to the same path when the work visibly changes. Do not ask.
- In a live UI audit, wait for the render (CDP plus about 2.5 s) before you report a visual finding.
- Verify an "empty or missing image" finding with a second clean render.
<!-- Why: Dark themes and unfinished renders made documents look broken. -->

## Where output goes
- Put finished output in the documents folder that the local overlay names, under `<project>/<topic>/`.
- Finished output is an image, video, PDF or mockup that is sent, uploaded or shared.
- Name files `<topic>-<what>.<ext>`: lowercase, hyphens, no spaces, no non-ASCII characters.
- `<project>` is a short name.
- Keep source (templates, scripts, the HTML that makes the output) in the project's repo.
- Intermediate versions and tool folders are not permanent. Examples: build-output folders, `.playwright-cli/`, scratchpads.
- When the job ends, move the final file to the documents folder. Give the user the link from there.
- Keep the concrete folder layout in the private overlay.
<!-- Why: Output left in a scratch folder was lost. -->

## Text to paste elsewhere
- Text that the user will paste elsewhere is, for example, a message, an email, a prompt or a reply.
- Put that text alone in one fenced block. Put your explanation outside the block.
- If the text is longer than 40 lines, write it to a `.txt` file. Give the link to the file.
- Do not add bullet markers, hard line breaks inside a paragraph or indents in the block.
- If the text contains a fence, use a longer fence around it.
<!-- Why: A bullet list or a wrapped paragraph copies with extra characters. -->

## End of a long turn
- End a turn that took more than one minute with one last line.
- The line is `STATE: done`, `STATE: blocked - <what you need from the user>` or `STATE: failed - <what failed>`.
- Write the text after the hyphen in the language of the user.
- Do not add this line to short answers.
<!-- Why: A tool can read this line to send a notification. The user sees the state at once. -->
