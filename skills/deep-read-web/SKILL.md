---
name: deep-read-web
description: Read the full HTML of a public or login-protected web page with Playwright. Use this when the user wants page HTML, wants to inspect content behind a manual login flow, or asks you to analyze a page that may require authentication.
---

# Deep Read Web

## When to use

Use this skill when:

- the user provides an `http` or `https` URL and wants the page HTML
- the page may require manual login before it becomes readable
- the user wants you to analyze the final rendered page content after authentication

## How to run

On Windows, prefer:

```bash
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>"
```

If `py -3` is unavailable, fall back to:

```bash
python skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>"
```

Optional browser override:

```bash
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>" --browser firefox
```

## Expected behavior

1. The script first tries a headless read.
2. If the page looks readable, it returns the full HTML without opening a window.
3. If the page looks like a login or authentication flow, it opens a visible browser window and waits for the user to log in.
4. After authentication succeeds, it prints the final page HTML to standard output.
5. If authentication does not complete within the timeout, it exits with an error.

## Dependency handling

If Python is missing, explain that the first version currently requires Python and point the user to the repository README for setup.

If Playwright is missing, suggest:

```bash
py -3 -m pip install playwright
py -3 -m playwright install chromium firefox
```

## Output handling

- Treat standard output as the final page HTML.
- Treat standard error as user-facing status or failure information.
- Do not ask the user to paste passwords, tokens, cookies, or session secrets into chat.
