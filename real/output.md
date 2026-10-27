# Output

## Links
- Every link opens on click, no exceptions.
- Web link: `[text](https://...)`.
- Local file or folder: `[name](file:///absolute/path)`.
- No `~`, no relative path, no path without a scheme. Spaces become `%20`.
- No plain-text URL, no bare path, no standalone `file:line`.
- Need a line number? Put it in the link text: `[index.html:1433](file:///.../index.html)`.
- Paths from an agent report get the same format.
<!-- Why: Links in other formats did not open when clicked, and the user had to ask again and again. -->
- `file://` alone is not enough for HTML or image preview.
- Serve the file's folder in the background: `python3 -m http.server <port> --bind 127.0.0.1`.
- Do not fix the port. Ask the operating system for a free one. Other sessions may hold ports like 8765.
- Verify with `curl` that the page's `<title>` belongs to the expected file. A 200 alone is not enough.
- Give the link as `[name](http://127.0.0.1:<port>/file.html)`.
<!-- Why: A 200 can come from another session's server on the same port. -->
- If the user says "open", or says a link did not open, also open it with `open`.
- Otherwise do not open generated PDFs or files with `open`. Give a link and let the user open it.

## Generated documents and artifacts
- Every generated HTML document or print source has a fixed white background.
- Use `:root{color-scheme:light only}` and `html,body{background:#fff}`. In-chat widgets are the exception.
- If an Artifact was published in the session, republish it to the same path whenever the work visibly changes. Do not ask.
- In a live UI audit, wait for the render (CDP plus about 2.5 s) before claiming a visual finding.
- Verify an "empty or missing image" finding with a second clean render.
<!-- Why: Dark themes and unfinished renders made documents look broken when they were not. -->

## Where output goes
- Finished output goes to the documents folder named in the local overlay, under `<project>/<topic>/`.
- Finished output means an image, video, PDF or mockup that is sent, uploaded or shared.
- Name files `<topic>-<what>.<ext>`: lowercase, hyphens, no spaces, no non-ASCII characters.
- `<project>` is a short name.
- Source (templates, scripts, the HTML that produces the output) stays in the project's repo.
- Intermediate versions and tool folders (build-output folders, `.playwright-cli/`, scratchpads) are not permanent.
- When the job ends, move the final file to the documents folder. Give the user the link from there.
- The concrete folder layout is kept in the private overlay.
<!-- Why: Output left in a scratch or ignored folder was lost and found only by luck. -->
