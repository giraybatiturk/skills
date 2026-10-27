# Output

## Links
- Every link opens on click, no exceptions. Web: `[text](https://...)`. Local file or folder: `[name](file:///absolute/path)`; no `~`, no relative path, no path without a scheme; spaces become `%20`.
- No plain-text URL, no bare path, no standalone `file:line`. If a line number is needed, put it in the link text: `[index.html:1433](file:///.../index.html)`.
- Paths that come from an agent report are given to the user in this format too.
- For HTML and image preview, `file://` is not enough. Serve the file's folder in the background with `python3 -m http.server <port> --bind 127.0.0.1`. Do not fix the port; ask the operating system for a free one (servers of other sessions may hold ports like 8765). Verify with `curl` that the page's `<title>` belongs to the expected file (a 200 alone is not enough). Give the link as `[name](http://127.0.0.1:<port>/file.html)`.
- If the user says "open", or says a link did not open, also open it with `open`. Otherwise do not open generated PDFs or files with `open`; give a link in the reply and the user opens it if wanted.

## Generated documents and artifacts
- Every generated HTML document or print source has a fixed white background: `:root{color-scheme:light only}` and `html,body{background:#fff}` (in-chat widgets excepted).
- If an Artifact was published in the session, republish it to the same path, without asking, whenever the work visibly changes.
- In a live UI audit, wait for the render (CDP plus about 2.5 s) before claiming a visual finding. Verify an "empty or missing image" finding with a second clean render.

## Where output goes
- Finished output (an image, video, PDF or mockup that is sent, uploaded or shared) goes to the documents folder named in the local overlay, under `<project>/<topic>/`. Name it `<topic>-<what>.<ext>`: lowercase, hyphens, no spaces, no non-ASCII characters. `<project>` is a short name.
- Source (templates, scripts, the HTML that produces the output) stays in the project's repo.
- Intermediate versions and tool folders (build-output folders, `.playwright-cli/`, scratchpads) are not permanent. When the job ends, move the final file to the documents folder and give the user the link from there.
- The concrete folder layout (per-project packages, design and test folders, dated naming) is kept in the private overlay.
