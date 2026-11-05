#!/usr/bin/env python3
"""gemini_cdp_runner.py - Vollautomatischer Hintergrund-Runner fuer Google Gemini Web (Argon).

Steuert Google Chrome ueber das Chrome DevTools Protocol (CDP) per WebSocket,
genau nach dem Vorbild des browser-to-pdf Skills.

Eigenschaften:
- Laeuft vollstaendig im Hintergrund (ausserhalb des sichtbaren Bildschirms).
- Blockiert weder Mauszeiger noch Tastatur.
- Nutzt die gespeicherte lokale Login-Session aus gemini_profile.
- Injiziert den Prompt per DOM-Events, wartet auf die vollstaendige Generierung
  und extrahiert die Antwort (inkl. <argon_payload> Blueprint).
- 100% reversibel und strikt Standard-ASCII-Minuszeichen.
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import websockets

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

CHROME_CANDIDATES = [
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
    Path(os.environ.get("LOCALAPPDATA", "")) / "Google/Chrome/Application/chrome.exe",
    Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
    Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
]

DEFAULT_PROFILE_DIR = Path(os.environ.get("USERPROFILE", "C:/Users/roger")) / ".gemini/config/gemini_profile"
DEFAULT_PORT = 9223


def log(msg: str) -> None:
    print(f"[gemini-cdp] {msg}", flush=True)


def find_browser() -> Path:
    for candidate in CHROME_CANDIDATES:
        if candidate and candidate.is_file():
            return candidate
    for name in ("chrome", "chrome.exe", "msedge", "msedge.exe"):
        found = shutil.which(name)
        if found:
            return Path(found)
    raise SystemExit("Fehler: Kein Chrome oder Edge gefunden.")


class CDPClient:
    """Minimaler, robuster CDP-Client ueber WebSockets."""

    def __init__(self, ws_url: str) -> None:
        self.ws_url = ws_url
        self._ws: websockets.WebSocketClientProtocol | None = None
        self._id = 0

    async def __aenter__(self) -> "CDPClient":
        self._ws = await websockets.connect(
            self.ws_url,
            max_size=None,
            ping_interval=None,
            ping_timeout=None,
        )
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._ws is not None:
            with contextlib.suppress(Exception):
                await self._ws.close()
            self._ws = None

    async def send(self, method: str, params: dict | None = None, timeout: float = 60.0) -> dict:
        self._id += 1
        msg_id = self._id
        payload = json.dumps({"id": msg_id, "method": method, "params": params or {}})
        await self._ws.send(payload)

        deadline = time.time() + timeout
        while time.time() < deadline:
            raw = await asyncio.wait_for(self._ws.recv(), timeout=max(0.1, deadline - time.time()))
            msg = json.loads(raw)
            if msg.get("id") == msg_id:
                if "error" in msg:
                    raise RuntimeError(f"CDP-Fehler bei {method}: {msg['error']}")
                return msg.get("result", {})
        raise TimeoutError(f"CDP-Timeout bei {method}")

    async def eval_js(self, expression: str, timeout: float = 30.0) -> any:
        res = await self.send(
            "Runtime.evaluate",
            {
                "expression": expression,
                "returnByValue": True,
                "awaitPromise": True,
            },
            timeout=timeout,
        )
        result_obj = res.get("result", {})
        if "value" in result_obj:
            return result_obj["value"]
        if result_obj.get("type") == "undefined":
            return None
        return result_obj


def is_port_open(port: int) -> bool:
    endpoint = f"http://127.0.0.1:{port}/json/version"
    try:
        with urllib.request.urlopen(endpoint, timeout=1.5) as resp:
            return resp.status == 200
    except Exception:
        return False


def get_cdp_targets(port: int) -> list[dict]:
    endpoint = f"http://127.0.0.1:{port}/json"
    with urllib.request.urlopen(endpoint, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


def ensure_chrome_running(browser: Path, profile_dir: Path, port: int, visible: bool = False) -> subprocess.Popen | None:
    if is_port_open(port):
        log(f"Bestehende Chrome-Instanz auf Port {port} erkannt.")
        return None

    log(f"Starte Chrome im Hintergrund (Port {port}, Profil: {profile_dir})...")
    args = [
        str(browser),
        f"--user-data-dir={profile_dir}",
        f"--remote-debugging-port={port}",
        "--remote-allow-origins=*",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-features=Translate,MediaRouter",
        "https://gemini.google.com",
    ]

    if not visible:
        # Off-Screen Position verhindert jegliche Interaktion mit dem aktiven Desktop
        args.extend(["--window-position=-32000,-32000", "--window-size=1280,900"])
    else:
        args.append("--window-size=1280,900")

    creation_flags = 0
    if sys.platform == "win32":
        creation_flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP

    proc = subprocess.Popen(args, creationflags=creation_flags)

    deadline = time.time() + 25.0
    while time.time() < deadline:
        if is_port_open(port):
            log("CDP-Port erfolgreich bereitgestellt.")
            return proc
        time.sleep(0.5)

    raise SystemExit("Fehler: Chrome konnte nicht innerhalb von 25 Sekunden mit CDP gestartet werden.")


async def get_or_create_gemini_page(port: int) -> dict:
    targets = get_cdp_targets(port)
    pages = [t for t in targets if t.get("type") == "page"]

    # 1. Bevorzuge bereits offene Gemini-Tabs
    for p in pages:
        url = p.get("url", "")
        if "gemini.google.com" in url:
            return p

    # 2. Wenn leere Tabs da sind, navigiere den ersten
    if pages:
        first = pages[0]
        ws_url = first.get("webSocketDebuggerUrl")
        if ws_url:
            async with CDPClient(ws_url) as cdp:
                await cdp.send("Page.navigate", {"url": "https://gemini.google.com"})
                await asyncio.sleep(2.0)
            return first

    # 3. Sonst erstelle neuen Tab ueber CDP-HTTP-API
    new_url = f"http://127.0.0.1:{port}/json/new?https://gemini.google.com"
    with urllib.request.urlopen(new_url, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


async def wait_until_ready(cdp: CDPClient, timeout: float = 40.0) -> None:
    log("Warte auf Bereitstellung der Gemini Web-Oberflaeche...")
    js_check = """(() => {
        // 1. Cookie-Banner automatisch bestaetigen falls vorhanden
        const buttons = Array.from(document.querySelectorAll('button'));
        const acceptBtn = buttons.find(b => {
            const txt = ((b.innerText || '') + ' ' + (b.getAttribute('aria-label') || '')).toLowerCase();
            return txt.includes('alle annehmen') || txt.includes('accept all') || txt.includes('zustimmen');
        });
        if (acceptBtn) {
            acceptBtn.click();
        }

        const url = window.location.href;
        if (url.includes('accounts.google.com')) {
            return { status: 'need_login', url };
        }

        // 2. Pruefen ob Login noetig ist (Anmelde-Button sichtbar ohne Benutzer-Avatar)
        const hasSignInPrompt = buttons.some(b => {
            const txt = ((b.innerText || '') + ' ' + (b.getAttribute('aria-label') || '')).toLowerCase();
            return txt.includes('anmelden') || txt.includes('sign in');
        });
        const hasAvatar = document.querySelector('img[alt*="Google-Konto"], [aria-label*="Google-Konto"], [aria-label*="Google Account"]') !== null;

        const editor = document.querySelector('rich-textarea div[contenteditable="true"], div[contenteditable="true"]');
        if (hasSignInPrompt && !hasAvatar && !editor) {
            return { status: 'need_login', url };
        }

        return {
            status: editor ? 'ready' : 'loading',
            readyState: document.readyState,
            url
        };
    })()"""

    deadline = time.time() + timeout
    while time.time() < deadline:
        res = await cdp.eval_js(js_check)
        if isinstance(res, dict):
            status = res.get("status")
            if status == "ready":
                log("Gemini Eingabefeld erfolgreich erkannt.")
                return
            if status == "need_login":
                raise SystemExit(
                    "Fehler: Nicht eingeloggt. Bitte starte einmalig scripts\\gemini-cdp\\setup_gemini_session.bat, "
                    "um dich bei Google anzumelden."
                )
        await asyncio.sleep(1.0)

    raise TimeoutError("Zeitueberschreitung beim Laden von Gemini. Bitte Verbindung pruefen.")


async def send_prompt_to_gemini(cdp: CDPClient, prompt: str) -> int:
    log(f"Fuege Prompt ein ({len(prompt)} Zeichen)...")

    # 1. Editor fokussieren und leeren (TrustedHTML-sicher via textContent)
    js_focus_and_clear = """(() => {
        const editor = document.querySelector('rich-textarea div[contenteditable="true"], div[contenteditable="true"]');
        if (!editor) return { ok: false, error: 'Kein Editor gefunden' };
        editor.focus();
        editor.textContent = '';
        return { ok: true };
    })()"""

    focus_res = await cdp.eval_js(js_focus_and_clear)
    if not isinstance(focus_res, dict) or not focus_res.get("ok"):
        raise RuntimeError(f"Editor konnte nicht fokussiert werden: {focus_res}")

    # 2. Text nativ per CDP Input.insertText einfuegen (umgeht alle DOM/TrustedHTML-Einschraenkungen)
    await cdp.send("Input.insertText", {"text": prompt})

    # 3. Input-Event dispatchen fuer Angular/UI-Reaktivitaet
    js_trigger_events = """(() => {
        const editor = document.querySelector('rich-textarea div[contenteditable="true"], div[contenteditable="true"]');
        if (editor) {
            editor.dispatchEvent(new Event('input', { bubbles: true }));
            editor.dispatchEvent(new Event('change', { bubbles: true }));
            return { ok: true, length: editor.innerText.length };
        }
        return { ok: false };
    })()"""
    await cdp.eval_js(js_trigger_events)

    # Kurze Pause fuer Framework-Reaktivitaet
    await asyncio.sleep(0.8)

    # Antworten vor dem Senden zaehlen
    count_before = await cdp.eval_js("document.querySelectorAll('model-response').length")
    initial_count = int(count_before or 0)

    # Sende-Button klicken
    js_send = """(() => {
        const btn = document.querySelector('button[aria-label*="Send" i], button[aria-label*="Senden" i], button.send-button, [data-test-id*="send" i], button.send-button-container');
        if (btn) {
            btn.removeAttribute('disabled');
            btn.setAttribute('aria-disabled', 'false');
            btn.click();
            return { ok: true, method: 'click' };
        }
        return { ok: false, error: 'Kein Sende-Button gefunden' };
    })()"""

    send_res = await cdp.eval_js(js_send)
    method = send_res.get('method') if isinstance(send_res, dict) else 'none'

    # Zusaetzlich native CDP Enter-Taste senden fuer vollstaendige Kompatibilitaet
    await cdp.send("Input.dispatchKeyEvent", {
        "type": "rawKeyDown",
        "windowsVirtualKeyCode": 13,
        "key": "Enter",
        "code": "Enter",
        "unmodifiedText": "\r",
        "text": "\r"
    })
    await asyncio.sleep(0.05)
    await cdp.send("Input.dispatchKeyEvent", {
        "type": "keyUp",
        "windowsVirtualKeyCode": 13,
        "key": "Enter",
        "code": "Enter"
    })

    log(f"Prompt erfolgreich gesendet (Methode: {method} + native CDP Enter). Warte auf Generierung...")
    return initial_count


async def wait_for_response(cdp: CDPClient, initial_count: int, timeout: float = 300.0) -> str:
    js_poll = r"""(() => {
        const responses = document.querySelectorAll('model-response, [data-test-id*="model-response"], message-content, .model-response');
        const buttons = Array.from(document.querySelectorAll('button'));
        const stopBtn = buttons.find(b => {
            const txt = ((b.getAttribute('aria-label') || '') + ' ' + (b.innerText || '')).toLowerCase();
            return txt.includes('stopp') || txt.includes('stop') || txt.includes('anhalten');
        });

        const count = responses.length;
        let cleanText = '';
        if (count > 0) {
            const latest = responses[count - 1];
            const contentNode = latest.querySelector('message-content, .markdown, .model-response-text, [data-test-id="content"]');
            const raw = contentNode ? (contentNode.innerText || contentNode.textContent || '') : (latest.innerText || latest.textContent || '');
            cleanText = raw.replace(/^gemini\s+hat\s+gesagt[:\s]*/i, '').replace(/^gemini\s+said[:\s]*/i, '').trim();
        }

        return {
            count: count,
            isGenerating: stopBtn !== undefined,
            cleanLength: cleanText.length,
            hasClosingTag: cleanText.includes('</argon_payload>'),
            snippet: cleanText.slice(-60)
        };
    })()"""

    deadline = time.time() + timeout
    last_len = -1
    stable_cycles = 0
    has_seen_generating = False

    while time.time() < deadline:
        res = await cdp.eval_js(js_poll)
        if isinstance(res, dict):
            count = res.get("count", 0)
            is_generating = res.get("isGenerating", False)
            clean_len = res.get("cleanLength", 0)
            has_closing = res.get("hasClosingTag", False)

            if is_generating:
                has_seen_generating = True

            # Antwort-Container erkannt
            if count > initial_count:
                if clean_len > 0:
                    # Stabilitaet erst bewerten, wenn Generierung lief oder Text substanziell ist
                    if not is_generating and (has_seen_generating or clean_len > 10):
                        if clean_len == last_len:
                            stable_cycles += 1
                            if stable_cycles >= 2:
                                log(f"Generierung abgeschlossen ({clean_len} Zeichen).")
                                break
                        else:
                            stable_cycles = 0

                    if has_closing and not is_generating:
                        log("Vollstaendiger <argon_payload> Blueprint erkannt.")
                        break

                last_len = clean_len

        await asyncio.sleep(1.5)
    else:
        log("Warnung: Maximaler Timeout erreicht. Lese aktuellen Textstand aus...")

    # Text der neuesten Antwort extrahieren und Ansage-Label entfernen
    js_extract = r"""(() => {
        const responses = document.querySelectorAll('model-response');
        if (responses.length === 0) return '';
        const latest = responses[responses.length - 1];
        const contentNode = latest.querySelector('message-content, .markdown, .model-response-text');
        let text = contentNode ? (contentNode.innerText || contentNode.textContent || '') : (latest.innerText || latest.textContent || '');
        return text.replace(/^gemini\s+hat\s+gesagt[:\s]*/i, '').replace(/^gemini\s+said[:\s]*/i, '').trim();
    })()"""

    final_text = await cdp.eval_js(js_extract)
    if isinstance(final_text, str):
        final_text = final_text.replace("\u2013", "-").replace("\u2014", "-")
    return final_text or ""


def extract_argon_payload(text: str) -> str | None:
    match = re.search(r"(<argon_payload>[\s\S]*?</argon_payload>)", text)
    if match:
        return match.group(1).strip()
    return None


async def run_pipeline(args: argparse.Namespace) -> None:
    # 1. Prompt bestimmen
    if args.prompt_file:
        prompt_path = Path(args.prompt_file)
        if not prompt_path.is_file():
            raise SystemExit(f"Fehler: Prompt-Datei nicht gefunden: {prompt_path}")
        prompt_text = prompt_path.read_text(encoding="utf-8")
    elif args.stdin:
        prompt_text = sys.stdin.read()
    elif args.prompt:
        prompt_text = args.prompt
    else:
        raise SystemExit("Fehler: Kein Prompt angegeben (--prompt, --prompt-file oder --stdin).")

    prompt_text = prompt_text.strip()
    if not prompt_text:
        raise SystemExit("Fehler: Prompt ist leer.")

    browser = find_browser()
    profile_dir = Path(args.profile_dir).resolve()
    port = int(args.port)

    # 2. Browser starten / verbinden
    ensure_chrome_running(browser, profile_dir, port, visible=args.visible)
    target = await get_or_create_gemini_page(port)
    ws_url = target.get("webSocketDebuggerUrl")
    if not ws_url:
        raise SystemExit("Fehler: Konnte WebSocket-Debugger-URL fuer Gemini-Tab nicht ermitteln.")

    # 3. Interaktion via CDP
    async with CDPClient(ws_url) as cdp:
        await cdp.send("Page.enable")
        await cdp.send("Runtime.enable")
        await wait_until_ready(cdp, timeout=args.timeout)

        initial_count = await send_prompt_to_gemini(cdp, prompt_text)
        result_text = await wait_for_response(cdp, initial_count, timeout=args.timeout)

    # 4. Blueprint oder Volltext extrahieren
    output_text = result_text
    if args.extract_blueprint:
        blueprint = extract_argon_payload(result_text)
        if blueprint:
            output_text = blueprint
            log("Blueprint erfolgreich isoliert.")
        else:
            log("Hinweis: Kein <argon_payload> Tag gefunden; gebe Gesamtext aus.")

    # 5. Speichern oder Ausgeben
    if args.output:
        out_path = Path(args.output).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output_text, encoding="utf-8")
        log(f"Ergebnis gespeichert unter: {out_path} ({len(output_text)} Zeichen)")
    else:
        print("\n" + "=" * 64)
        print("ANTWORT VON GEMINI WEB:")
        print("=" * 64)
        print(output_text)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Google Gemini Web Hintergrund-Runner via Chrome CDP")
    parser.add_argument("-p", "--prompt", help="Prompt-Text direkt uebergeben")
    parser.add_argument("-f", "--prompt-file", help="Pfad zu einer Textdatei mit dem Prompt")
    parser.add_argument("--stdin", action="store_true", help="Prompt von stdin einlesen")
    parser.add_argument("-o", "--output", help="Ausgabedatei fuer die Antwort")
    parser.add_argument("--port", default=DEFAULT_PORT, type=int, help=f"CDP-Port (Standard: {DEFAULT_PORT})")
    parser.add_argument("--profile-dir", default=str(DEFAULT_PROFILE_DIR), help="Profilordner fuer Gemini")
    parser.add_argument("--timeout", default=300.0, type=float, help="Timeout in Sekunden (Standard: 300)")
    parser.add_argument("--extract-blueprint", action="store_true", help="Extrahiert isoliert den <argon_payload> Block")
    parser.add_argument("--visible", action="store_true", help="Chrome sichtbar anzeigen (Standard: unsichtbar im Hintergrund)")
    return parser.parse_args()


if __name__ == "__main__":
    asyncio.run(run_pipeline(parse_args()))
