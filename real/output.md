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
- If the user says "open", or says that a link did not open, also open it with `open`.
- In all other cases, do not open generated PDFs or files with `open`. Give a link. The user opens it.

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
