#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Read the final HTML of a public or login-protected page with Playwright."""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path
from urllib.parse import urlparse


LOGIN_KEYWORDS = (
    "login",
    "signin",
    "sign-in",
    "auth",
    "sso",
    "oauth",
    "passport",
    "account/login",
    "user/login",
    "登录",
    "登陆",
    "登入",
)

BROWSER_CHOICES = (
    "auto",
    "msedge",
    "msedge-dev",
    "msedge-beta",
    "chrome",
    "chrome-dev",
    "chrome-beta",
    "chromium",
    "firefox",
)

WINDOWS_BROWSER_PATHS = {
    "msedge": (
        Path(os.environ.get("PROGRAMFILES", "")) / "Microsoft" / "Edge" / "Application" / "msedge.exe",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Microsoft" / "Edge" / "Application" / "msedge.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "Edge" / "Application" / "msedge.exe",
    ),
    "msedge-dev": (
        Path(os.environ.get("PROGRAMFILES", "")) / "Microsoft" / "Edge Dev" / "Application" / "msedge.exe",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Microsoft" / "Edge Dev" / "Application" / "msedge.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "Edge Dev" / "Application" / "msedge.exe",
    ),
    "msedge-beta": (
        Path(os.environ.get("PROGRAMFILES", "")) / "Microsoft" / "Edge Beta" / "Application" / "msedge.exe",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Microsoft" / "Edge Beta" / "Application" / "msedge.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "Edge Beta" / "Application" / "msedge.exe",
    ),
    "chrome": (
        Path(os.environ.get("PROGRAMFILES", "")) / "Google" / "Chrome" / "Application" / "chrome.exe",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Google" / "Chrome" / "Application" / "chrome.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Google" / "Chrome" / "Application" / "chrome.exe",
    ),
    "chrome-dev": (
        Path(os.environ.get("PROGRAMFILES", "")) / "Google" / "Chrome Dev" / "Application" / "chrome.exe",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Google" / "Chrome Dev" / "Application" / "chrome.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Google" / "Chrome Dev" / "Application" / "chrome.exe",
    ),
    "chrome-beta": (
        Path(os.environ.get("PROGRAMFILES", "")) / "Google" / "Chrome Beta" / "Application" / "chrome.exe",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Google" / "Chrome Beta" / "Application" / "chrome.exe",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Google" / "Chrome Beta" / "Application" / "chrome.exe",
    ),
}


class CliError(Exception):
    """Raised when command-line arguments are invalid."""


class DependencyError(Exception):
    """Raised when Python runtime dependencies are missing."""


class BrowserLaunchError(Exception):
    """Raised when the selected browser cannot be launched."""


class AuthTimeoutError(Exception):
    """Raised when manual authentication does not finish in time."""


def configure_stdio() -> None:
    """Force UTF-8 output where supported to avoid mojibake."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def eprint(message: str) -> None:
    """Write status and error messages to stderr."""
    print(message, file=sys.stderr, flush=True)


def build_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Read a page with Playwright and print the final HTML to stdout."
    )
    parser.add_argument(
        "--HTML_PAGE",
        dest="html_page",
        help="Target page URL. Must be an http or https URL.",
    )
    parser.add_argument(
        "--browser",
        default="auto",
        choices=BROWSER_CHOICES,
        help="Browser choice. Defaults to auto.",
    )
    parser.add_argument(
        "--auth-timeout",
        dest="auth_timeout",
        type=int,
        default=60,
        help="Seconds to wait for manual authentication. Defaults to 60.",
    )
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse and validate command-line arguments."""
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.html_page:
        raise CliError(
            '缺少必需参数 --HTML_PAGE，例如：py -3 deep_read.py --HTML_PAGE "https://example.com"'
        )

    parsed = urlparse(args.html_page)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise CliError("--HTML_PAGE 必须是合法的 http 或 https URL。")

    if args.auth_timeout <= 0:
        raise CliError("--auth-timeout 必须是大于 0 的整数。")

    return args


def import_playwright():
    """Import Playwright lazily so basic CLI validation works without it."""
    try:
        from playwright.sync_api import Error as playwright_error
        from playwright.sync_api import TimeoutError as playwright_timeout_error
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise DependencyError(
            "未检测到 Python 包 playwright。请先执行：py -3 -m pip install playwright"
        ) from exc

    return sync_playwright, playwright_error, playwright_timeout_error


def normalize_host(url: str) -> str:
    """Normalize host names for loose comparisons."""
    host = (urlparse(url).hostname or "").lower()
    if host.startswith("www."):
        return host[4:]
    return host


def contains_login_keyword(value: str) -> bool:
    """Return True when the text contains a login-related keyword."""
    lowered = (value or "").lower()
    return any(keyword in lowered for keyword in LOGIN_KEYWORDS)


def is_http_url(url: str) -> bool:
    """Return True when the URL uses http or https."""
    return (url or "").startswith(("http://", "https://"))


def hosts_share_scope(left_host: str, right_host: str) -> bool:
    """Return True when two hosts are the same or have a parent/subdomain relationship."""
    left = (left_host or "").strip().lower()
    right = (right_host or "").strip().lower()
    if not left or not right:
        return False
    return left == right or left.endswith(f".{right}") or right.endswith(f".{left}")


def find_browser_executable(browser_name: str) -> str | None:
    """Return the first matching branded browser path when present."""
    for candidate in WINDOWS_BROWSER_PATHS.get(browser_name, ()):
        if candidate.is_file():
            return str(candidate)
    return None


def resolve_browser_strategy(browser_name: str) -> list[dict[str, str]]:
    """Resolve the browser launch order for the requested browser."""
    if browser_name == "auto":
        strategies = []
        edge_path = find_browser_executable("msedge")
        if edge_path:
            strategies.append({"engine": "chromium", "browser_name": "msedge", "executable_path": edge_path})

        chrome_path = find_browser_executable("chrome")
        if chrome_path:
            strategies.append({"engine": "chromium", "browser_name": "chrome", "executable_path": chrome_path})

        strategies.append({"engine": "chromium", "browser_name": "chromium"})
        return strategies

    if browser_name == "firefox":
        return [{"engine": "firefox", "browser_name": "firefox"}]

    executable_path = find_browser_executable(browser_name)
    if executable_path:
        return [{"engine": "chromium", "browser_name": browser_name, "executable_path": executable_path}]

    if browser_name in WINDOWS_BROWSER_PATHS:
        raise BrowserLaunchError(
            f"未检测到浏览器 {browser_name}。请先安装该浏览器，或改用 --browser chromium。"
        )

    return [{"engine": "chromium", "browser_name": browser_name}]


def runtime_root() -> Path:
    """Return the runtime directory next to the skill root."""
    skill_root = Path(__file__).resolve().parent.parent
    root = skill_root / ".runtime"
    root.mkdir(parents=True, exist_ok=True)
    return root


def browser_profile_dir(browser_name: str) -> Path:
    """Return the persistent user-data directory for the selected browser."""
    profile_dir = runtime_root() / f"profile-{browser_name}"
    profile_dir.mkdir(parents=True, exist_ok=True)
    return profile_dir


def safe_close_context(context) -> None:
    """Close a browser context without masking the original error."""
    if context is None:
        return
    try:
        context.close()
    except Exception:
        pass


def launch_persistent_context(playwright, strategy: dict[str, str], headless: bool):
    """Launch a persistent browser context using the resolved strategy."""
    browser_type = getattr(playwright, strategy["engine"])
    user_data_dir = browser_profile_dir(strategy["browser_name"])
    launch_options = {
        "headless": headless,
    }

    if strategy["engine"] == "chromium":
        launch_options["args"] = ["--disable-blink-features=AutomationControlled"]

    executable_path = strategy.get("executable_path")
    if executable_path:
        launch_options["executable_path"] = executable_path

    try:
        return browser_type.launch_persistent_context(str(user_data_dir), **launch_options)
    except Exception as exc:
        browser_name = strategy["browser_name"]
        if browser_name == "chromium":
            raise BrowserLaunchError(
                "无法启动 Playwright 自带 Chromium。请执行：py -3 -m playwright install chromium"
            ) from exc
        if browser_name == "firefox":
            raise BrowserLaunchError(
                "无法启动 Playwright Firefox。请执行：py -3 -m playwright install firefox"
            ) from exc
        raise BrowserLaunchError(
            f"无法启动浏览器 {browser_name}。请确认该浏览器已正确安装。"
        ) from exc


def open_context(playwright, browser_name: str, headless: bool):
    """Open a context by trying each resolved strategy in order."""
    strategies = resolve_browser_strategy(browser_name)
    last_error: Exception | None = None

    for strategy in strategies:
        try:
            return launch_persistent_context(playwright, strategy, headless)
        except BrowserLaunchError as exc:
            last_error = exc
            continue

    if last_error is not None:
        raise last_error

    raise BrowserLaunchError("未找到可用浏览器。")


def get_first_page(context):
    """Return the first page in the context, creating one if needed."""
    if context.pages:
        return context.pages[0]
    return context.new_page()


def configure_page_timeouts(context, timeout_ms: int = 3000) -> None:
    """Keep page-level waits short while polling login state."""

    def on_page(new_page):
        new_page.set_default_timeout(timeout_ms)

    context.on("page", on_page)
    for page in list(context.pages):
        try:
            if not page.is_closed():
                page.set_default_timeout(timeout_ms)
        except Exception:
            continue


def iter_open_pages(context):
    """Iterate over a stable snapshot of open pages."""
    for page in list(context.pages):
        try:
            if page.is_closed():
                continue
        except Exception:
            continue
        yield page


def safe_locator_count(page, selector: str) -> int:
    """Count a locator safely across navigation changes."""
    try:
        return page.locator(selector).count()
    except Exception:
        return 0


def safe_title(page) -> str:
    """Return the current page title when available."""
    try:
        return page.title()
    except Exception:
        return ""


def is_login_page(page, target_url: str) -> bool:
    """Heuristically determine whether a page is still a login flow."""
    current_url = page.url or ""
    current_host = normalize_host(current_url)
    target_host = normalize_host(target_url)
    title = safe_title(page)

    if safe_locator_count(page, "input[type='password']") > 0:
        return True

    url_has_keyword = contains_login_keyword(current_url)
    title_has_keyword = contains_login_keyword(title)
    host_left_target_scope = bool(
        current_host and target_host and not hosts_share_scope(current_host, target_host)
    )

    if host_left_target_scope and url_has_keyword:
        return True

    input_count = safe_locator_count(page, "input")
    if (url_has_keyword or title_has_keyword) and input_count > 0:
        return True

    account_selector = (
        "input[name*='user' i], input[name*='email' i], input[name*='login' i], "
        "input[name*='account' i], input[name*='phone' i], input[id*='user' i], "
        "input[id*='email' i], input[id*='login' i], input[id*='account' i], "
        "input[id*='phone' i]"
    )
    if (
        url_has_keyword or title_has_keyword or host_left_target_scope
    ) and safe_locator_count(page, account_selector) > 0:
        return True

    return False


def is_allowed_result_page(page, target_url: str) -> bool:
    """Return True when a page looks like the target site's final readable page."""
    page_url = page.url or ""
    if not is_http_url(page_url):
        return False

    page_host = normalize_host(page_url)
    target_host = normalize_host(target_url)
    if not hosts_share_scope(page_host, target_host):
        return False

    return not is_login_page(page, target_url)


def ready_page_sort_key(page, target_url: str) -> tuple[int, int, int, int]:
    """Score readable pages so we pick the most likely content page."""
    page_url = page.url or ""
    if not is_http_url(page_url):
        return (3, 3, 3, 3)

    target_host = normalize_host(target_url)
    page_host = normalize_host(page_url)
    host_scope_match = hosts_share_scope(target_host, page_host)
    same_host = target_host == page_host

    target_url_trimmed = target_url.rstrip("/")
    page_url_trimmed = page_url.rstrip("/")
    exact_match = target_url_trimmed == page_url_trimmed

    target_path = urlparse(target_url).path or "/"
    page_path = urlparse(page_url).path or "/"
    path_prefix = page_path.startswith(target_path) if len(target_path) > 1 else True

    return (
        0 if host_scope_match else 1,
        0 if same_host else 1,
        0 if exact_match else 1,
        0 if path_prefix else 1,
    )


def pick_ready_page(context, target_url: str):
    """Return the best non-login page currently available in the context."""
    candidates = []
    for page in iter_open_pages(context):
        if is_allowed_result_page(page, target_url):
            candidates.append(page)

    if not candidates:
        return None

    return min(candidates, key=lambda page: ready_page_sort_key(page, target_url))


def tick_pages_domcontentloaded(context, playwright_timeout_error) -> None:
    """Advance each page so popup-based login flows become visible to polling."""
    for page in iter_open_pages(context):
        try:
            page.wait_for_load_state("domcontentloaded", timeout=1000)
        except playwright_timeout_error:
            continue
        except Exception:
            continue


def navigate_and_wait(page, url: str, playwright_timeout_error) -> None:
    """Navigate to a page and tolerate long-lived network activity."""
    page.goto(url, wait_until="domcontentloaded", timeout=60000)
    try:
        page.wait_for_load_state("networkidle", timeout=10000)
    except playwright_timeout_error:
        return


def read_html_without_login(playwright, browser_name: str, url: str, playwright_timeout_error):
    """Try a headless read first and return whether a visible login step is needed."""
    context = open_context(playwright, browser_name, headless=True)
    try:
        configure_page_timeouts(context)
        page = get_first_page(context)
        navigate_and_wait(page, url, playwright_timeout_error)

        ready_page = pick_ready_page(context, url)
        if ready_page is not None:
            return False, ready_page.content()

        if is_login_page(page, url):
            return True, None

        return False, page.content()
    finally:
        safe_close_context(context)


def read_html_after_manual_login(
    playwright,
    browser_name: str,
    url: str,
    auth_timeout: int,
    playwright_timeout_error,
):
    """Open a visible browser and wait for the user to complete authentication."""
    eprint(
        f"检测到页面可能需要登录，已打开浏览器窗口。请在 {auth_timeout} 秒内完成登录鉴权。"
    )
    context = open_context(playwright, browser_name, headless=False)
    try:
        configure_page_timeouts(context)
        page = get_first_page(context)
        navigate_and_wait(page, url, playwright_timeout_error)

        deadline = time.monotonic() + auth_timeout
        while time.monotonic() < deadline:
            tick_pages_domcontentloaded(context, playwright_timeout_error)
            ready_page = pick_ready_page(context, url)
            if ready_page is not None:
                try:
                    ready_page.wait_for_load_state("networkidle", timeout=5000)
                except playwright_timeout_error:
                    pass
                return ready_page.content()

            time.sleep(1)

        raise AuthTimeoutError(
            f"登录鉴权超时：超过 {auth_timeout} 秒仍未检测到已回到目标站点的内容页。"
        )
    finally:
        safe_close_context(context)


def run(args: argparse.Namespace) -> str:
    """Execute the requested page read and return the resulting HTML."""
    sync_playwright, _, playwright_timeout_error = import_playwright()

    with sync_playwright() as playwright:
        need_login, html = read_html_without_login(
            playwright,
            args.browser,
            args.html_page,
            playwright_timeout_error,
        )
        if need_login:
            html = read_html_after_manual_login(
                playwright,
                args.browser,
                args.html_page,
                args.auth_timeout,
                playwright_timeout_error,
            )

    return html or ""


def main(argv: list[str] | None = None) -> int:
    """Run the CLI entry point."""
    configure_stdio()

    try:
        args = parse_args(argv)
        html = run(args)
        sys.stdout.write(html)
        sys.stdout.flush()
        return 0
    except CliError as exc:
        eprint(f"错误：{exc}")
        return 2
    except DependencyError as exc:
        eprint(f"错误：{exc}")
        return 1
    except AuthTimeoutError as exc:
        eprint(f"错误：{exc}")
        return 1
    except BrowserLaunchError as exc:
        eprint(f"错误：{exc}")
        return 1
    except KeyboardInterrupt:
        eprint("错误：用户已中断执行。")
        return 130
    except Exception as exc:
        eprint(f"错误：执行失败，无法读取页面 HTML。详情：{exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
