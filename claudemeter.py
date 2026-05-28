#!/usr/bin/env python3
"""Claudemeter — Claude Code quota monitor.

Polls Anthropic API rate-limit headers using the OAuth token from
Claude Code credentials and displays utilization.

Modes:
  --headless   Cross-platform poller daemon (writes cache file, no GUI)
  (default)    macOS menu bar app (also writes cache file)
"""

from __future__ import annotations

import getpass
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

import httpx

# --- Constants ----------------------------------------------------------------

KEYCHAIN_SERVICE = "Claude Code-credentials"
CREDENTIALS_PATH = Path.home() / ".claude" / ".credentials.json"
CACHE_PATH = Path.home() / ".claude" / ".claudemeter-quota"

API_URL = "https://api.anthropic.com/v1/messages"
API_HEADERS_TEMPLATE = {
    "anthropic-version": "2023-06-01",
    "anthropic-beta": "oauth-2025-04-20",
    "Content-Type": "application/json",
    "User-Agent": "claude-code/2.1.5",
}
API_BODY = {
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 1,
    "messages": [{"role": "user", "content": "hi"}],
}

POLL_INTERVAL = 60  # seconds


# --- Token resolution ---------------------------------------------------------

def _extract_access_token(blob: str) -> str | None:
    blob = blob.strip()
    if not blob:
        return None
    try:
        data = json.loads(blob)
    except json.JSONDecodeError:
        data = None
    if isinstance(data, dict):
        if isinstance(data.get("accessToken"), str):
            return data["accessToken"]
        for v in data.values():
            if isinstance(v, dict) and isinstance(v.get("accessToken"), str):
                return v["accessToken"]
    m = re.search(r'"accessToken"\s*:\s*"([^"]+)"', blob)
    if m:
        return m.group(1)
    if re.fullmatch(r"[A-Za-z0-9_\-.~+/=]{20,}", blob):
        return blob
    return None


def _read_token_keychain() -> str | None:
    try:
        out = subprocess.run(
            [
                "security", "find-generic-password",
                "-s", KEYCHAIN_SERVICE,
                "-a", getpass.getuser(),
                "-w",
            ],
            check=True, capture_output=True, text=True, timeout=10,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return None
    return _extract_access_token(out.stdout)


def _read_token_file() -> str | None:
    try:
        return _extract_access_token(CREDENTIALS_PATH.read_text())
    except OSError:
        return None


def read_token() -> str | None:
    return _read_token_keychain() or _read_token_file()


# --- API polling --------------------------------------------------------------

def poll_api(token: str) -> dict | None:
    headers = dict(API_HEADERS_TEMPLATE)
    headers["Authorization"] = f"Bearer {token}"
    try:
        resp = httpx.post(API_URL, headers=headers, json=API_BODY, timeout=20.0)
    except httpx.HTTPError as e:
        return {"ok": False, "error": str(e)}

    # Extract rate-limit headers even from 429 responses — Anthropic sends
    # utilization data regardless of status code.
    if resp.status_code >= 400 and resp.status_code != 429:
        return {"ok": False, "error": f"HTTP {resp.status_code}"}

    now = time.time()

    def pct(util: str) -> int:
        try:
            return int(round(float(util) * 100))
        except (ValueError, TypeError):
            return 0

    def reset_minutes(ts: str) -> int:
        try:
            r = float(ts)
        except (ValueError, TypeError):
            return 0
        m = (r - now) / 60.0
        return int(round(m)) if m > 0 else 0

    h = resp.headers
    return {
        "ok": True,
        "s": pct(h.get("anthropic-ratelimit-unified-5h-utilization", "0")),
        "sr": reset_minutes(h.get("anthropic-ratelimit-unified-5h-reset", "0")),
        "w": pct(h.get("anthropic-ratelimit-unified-7d-utilization", "0")),
        "wr": reset_minutes(h.get("anthropic-ratelimit-unified-7d-reset", "0")),
        "st": h.get("anthropic-ratelimit-unified-5h-status", "unknown"),
    }


# --- Cache file ---------------------------------------------------------------

def write_cache(result: dict) -> None:
    """Atomically write poll result to cache file."""
    data = {
        "s": result["s"],
        "w": result["w"],
        "sr": result["sr"],
        "wr": result["wr"],
        "st": result["st"],
        "ts": int(time.time()),
    }
    cache_dir = CACHE_PATH.parent
    cache_dir.mkdir(parents=True, exist_ok=True)
    try:
        fd, tmp = tempfile.mkstemp(dir=cache_dir, prefix=".claudemeter-quota-")
        with os.fdopen(fd, "w") as f:
            json.dump(data, f)
        os.replace(tmp, CACHE_PATH)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass


# --- Formatting ---------------------------------------------------------------

def fmt_reset(mins: int) -> str:
    if mins <= 0:
        return "—"
    if mins < 60:
        return f"{mins}m"
    h, m = divmod(mins, 60)
    if h < 24:
        return f"{h}h{m:02d}m"
    d, h = divmod(h, 24)
    return f"{d}d{h:02d}h"


# --- Headless poller ----------------------------------------------------------

def run_headless() -> None:
    """Cross-platform headless poller. Writes cache file every cycle."""
    stop = threading.Event()

    def handle_signal(sig, frame):
        stop.set()

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    token: str | None = read_token()

    while not stop.is_set():
        if not token:
            token = read_token()
        if not token:
            stop.wait(timeout=POLL_INTERVAL)
            continue

        result = poll_api(token)
        if result and not result.get("ok") and "401" in result.get("error", ""):
            token = read_token()
        if result and result.get("ok"):
            write_cache(result)

        stop.wait(timeout=POLL_INTERVAL)


# --- macOS menu bar app -------------------------------------------------------

CLAUDE_ORANGE = (0xD9 / 255.0, 0x77 / 255.0, 0x57 / 255.0)


def run_menubar() -> None:
    """macOS menu bar app. Requires rumps + pyobjc."""
    import rumps

    try:
        from AppKit import (
            NSAttributedString,
            NSColor,
            NSFont,
            NSFontAttributeName,
            NSForegroundColorAttributeName,
        )
        _APPKIT_OK = True
    except ImportError:
        _APPKIT_OK = False

    class ClaudemeterApp(rumps.App):
        def __init__(self) -> None:
            super().__init__("Claude", title="◌ —", quit_button="Quit")
            import AppKit
            AppKit.NSApplication.sharedApplication().setActivationPolicy_(
                AppKit.NSApplicationActivationPolicyAccessory
            )
            self.item_status = rumps.MenuItem("Status: starting…")
            self.item_5h = rumps.MenuItem("5h: —")
            self.item_5h_reset = rumps.MenuItem("  resets in —")
            self.item_7d = rumps.MenuItem("7d: —")
            self.item_7d_reset = rumps.MenuItem("  resets in —")
            self.item_refresh = rumps.MenuItem("Refresh now", callback=self.on_refresh)
            self.menu = [
                self.item_status,
                None,
                self.item_5h,
                self.item_5h_reset,
                self.item_7d,
                self.item_7d_reset,
                None,
                self.item_refresh,
            ]
            self._lock = threading.Lock()
            self._stop = threading.Event()
            self._wake = threading.Event()
            self._token: str | None = read_token()
            t = threading.Thread(target=self._poll_loop, daemon=True)
            t.start()

        def on_refresh(self, _sender) -> None:
            self._wake.set()

        def _poll_loop(self) -> None:
            while not self._stop.is_set():
                self._tick()
                self._wake.wait(timeout=POLL_INTERVAL)
                self._wake.clear()

        def _tick(self) -> None:
            if not self._token:
                self._token = read_token()
            if not self._token:
                self._apply({"ok": False, "error": "no token"})
                return
            result = poll_api(self._token)
            if result and not result.get("ok") and "401" in result.get("error", ""):
                self._token = read_token()
            self._apply(result or {"ok": False, "error": "no response"})

        def _apply(self, r: dict) -> None:
            with self._lock:
                if not r.get("ok"):
                    self.title = "⚠ —"
                    self._set_colored_title("⚠ —", error=True)
                    self.item_status.title = f"Status: {r.get('error', 'error')}"
                    return
                # Write cache on successful poll
                write_cache(r)
                s = r["s"]
                w = r["w"]
                glyph = "◔" if s < 50 else "◑" if s < 75 else "◕" if s < 95 else "●"
                text = f"{glyph} 5h {s}% · 7d {w}%"
                self.title = text
                self._set_colored_title(text, error=False)
                self.item_status.title = f"Status: {r.get('st', 'ok')}"
                self.item_5h.title = f"5h: {s}%"
                self.item_5h_reset.title = f"  resets in {fmt_reset(r['sr'])}"
                self.item_7d.title = f"7d: {w}%"
                self.item_7d_reset.title = f"  resets in {fmt_reset(r['wr'])}"

        def _set_colored_title(self, text: str, error: bool) -> None:
            if not _APPKIT_OK:
                return
            try:
                item = getattr(self._nsapp, "nsstatusitem", None)
                if item is None:
                    return
                button = item.button() if hasattr(item, "button") else None
                if button is None:
                    return
                if error:
                    color = NSColor.systemRedColor()
                else:
                    color = NSColor.colorWithCalibratedRed_green_blue_alpha_(
                        CLAUDE_ORANGE[0], CLAUDE_ORANGE[1], CLAUDE_ORANGE[2], 1.0
                    )
                attrs = {
                    NSForegroundColorAttributeName: color,
                    NSFontAttributeName: NSFont.menuBarFontOfSize_(0),
                }
                attr_str = NSAttributedString.alloc().initWithString_attributes_(text, attrs)
                button.setAttributedTitle_(attr_str)
            except Exception as e:
                print(f"colorize failed: {e}", flush=True)

    ClaudemeterApp().run()


# --- Entry point --------------------------------------------------------------

if __name__ == "__main__":
    if "--headless" in sys.argv:
        run_headless()
    else:
        run_menubar()
