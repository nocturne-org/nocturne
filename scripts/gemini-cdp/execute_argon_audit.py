import asyncio
import json
import os
import shutil
import subprocess
import time
import urllib.request
import websockets

CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PROFILE_DIR = os.path.expanduser(r"~\.gemini\config\gemini_profile")
PORT = 9223

def ensure_chrome():
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/version", timeout=1) as resp:
            print("[ARGON] Chrome laeuft bereits auf Port 9223.")
            return None
    except Exception:
        pass

    print(f"[ARGON] Starte Chrome (Port {PORT}, Profil: {PROFILE_DIR})...")
    cmd = [
        CHROME_PATH,
        f"--remote-debugging-port={PORT}",
        f"--user-data-dir={PROFILE_DIR}",
        "--no-first-run",
        "--no-default-browser-check",
        "--window-position=-2400,-2400",
        "--window-size=1280,900",
        "https://gemini.google.com/app"
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3.0)
    return proc

async def get_gemini_ws():
    for _ in range(15):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json", timeout=2) as resp:
                pages = json.loads(resp.read().decode())
            for p in pages:
                if "gemini.google.com" in p.get("url", ""):
                    return p["webSocketDebuggerUrl"]
        except Exception:
            pass
        await asyncio.sleep(1.0)
    raise RuntimeError("Gemini Tab nicht erreichbar.")

async def eval_js(ws, expr):
    msg = {"id": 1, "method": "Runtime.evaluate", "params": {"expression": expr, "returnByValue": True}}
    await ws.send(json.dumps(msg))
    res = json.loads(await ws.recv())
    return res.get("result", {}).get("result", {}).get("value")

async def run():
    chrome_proc = ensure_chrome()
    try:
        ws_url = await get_gemini_ws()
        print(f"[ARGON] Verbinde mit WebSocket: {ws_url[:45]}...")

        async with websockets.connect(ws_url, max_size=50 * 1024 * 1024) as ws:
            # 1. Warten bis Editor bereit ist
            for _ in range(20):
                ready = await eval_js(ws, "document.querySelector('rich-textarea div[contenteditable=\"true\"]') !== null")
                if ready:
                    break
                await asyncio.sleep(1.0)
            print("[ARGON] Editor bereit.")

            # 2. Modus pruefen
            mode = await eval_js(ws, """(() => {
                const btn = document.querySelector('button[aria-label*="Modusauswahl"]');
                return btn ? btn.innerText.replace('\\n', ' ') : 'unbekannt';
            })()""")
            print(f"[ARGON] Aktiver Modus: {mode}")

            # 3. Prompt laden
            prompt_file = r"C:\Users\roger\.gemini\scratch\prompts\argon_nocturne_audit.md"
            with open(prompt_file, "r", encoding="utf-8") as f:
                prompt_text = f.read()

            # 4. Text einsetzen
            await eval_js(ws, """(() => {
                const ed = document.querySelector('rich-textarea div[contenteditable="true"]');
                ed.focus();
                ed.textContent = '';
            })()""")
            await ws.send(json.dumps({"id": 2, "method": "Input.insertText", "params": {"text": prompt_text}}))
            await ws.recv()
            await asyncio.sleep(0.5)

            await eval_js(ws, """(() => {
                const ed = document.querySelector('rich-textarea div[contenteditable="true"]');
                ed.dispatchEvent(new Event('input', { bubbles: true }));
                ed.dispatchEvent(new Event('change', { bubbles: true }));
            })()""")
            await asyncio.sleep(0.8)

            # 5. Senden klicken
            send_info = await eval_js(ws, """(() => {
                const btn = document.querySelector('button[aria-label*="Nachricht senden" i]');
                if (btn) {
                    btn.click();
                    return { ok: true, aria: btn.getAttribute('aria-label') };
                }
                return { ok: false };
            })()""")
            print(f"[ARGON] Senden geklickt: {send_info}")

        # 6. Nach Senden kann Gemini die URL aendern -> Neue Verbindung aufbauen
        await asyncio.sleep(3.0)
        ws_url = await get_gemini_ws()
        print(f"[ARGON] Reconnect zu: {ws_url[:45]}...")

        async with websockets.connect(ws_url, max_size=50 * 1024 * 1024) as ws:
            print("[ARGON] Warte auf Generierung von Argon Hoch...")
            deadline = time.time() + 240.0
            last_len = -1
            stable_cycles = 0
            final_text = ""

            while time.time() < deadline:
                data = await eval_js(ws, r"""(() => {
                    const responses = document.querySelectorAll('model-response, [data-test-id*="model-response"]');
                    const buttons = Array.from(document.querySelectorAll('button'));
                    const isGen = buttons.some(b => {
                        const t = ((b.getAttribute('aria-label') || '') + ' ' + (b.innerText || '')).toLowerCase();
                        return t.includes('stopp') || t.includes('stop') || t.includes('anhalten');
                    });

                    let text = '';
                    if (responses.length > 0) {
                        const last = responses[responses.length - 1];
                        const content = last.querySelector('message-content, .markdown, .model-response-text');
                        text = content ? (content.innerText || content.textContent || '') : (last.innerText || last.textContent || '');
                        text = text.replace(/^gemini\s+hat\s+gesagt[:\s]*/i, '').replace(/^gemini\s+said[:\s]*/i, '').trim();
                    }

                    return {
                        count: responses.length,
                        isGen: isGen,
                        len: text.length,
                        hasClosingTag: text.includes('</argon_payload>'),
                        text: text
                    };
                })()""")

                if isinstance(data, dict):
                    cur_len = data.get("len", 0)
                    is_gen = data.get("isGen", False)
                    has_closing = data.get("hasClosingTag", False)

                    if cur_len > 50:
                        if (not is_gen and cur_len == last_len) or has_closing:
                            stable_cycles += 1
                            if stable_cycles >= 2 or (has_closing and not is_gen):
                                print(f"\n[ARGON] Fertig generiert! ({cur_len} Zeichen)")
                                final_text = data.get("text", "")
                                break
                        else:
                            stable_cycles = 0

                        last_len = cur_len
                        print(f"\r[ARGON] Generiere... {cur_len} Zeichen (isGenerating: {is_gen})", end="", flush=True)

                await asyncio.sleep(2.0)

            if not final_text and isinstance(data, dict):
                final_text = data.get("text", "")

            # In Datei speichern
            os.makedirs(r"c:\prvt\audiobook-app\docs\reports", exist_ok=True)
            out_file = r"c:\prvt\audiobook-app\docs\reports\ARGON_AUDIT_VERDICT.md"
            with open(out_file, "w", encoding="utf-8") as f:
                f.write(final_text)
            print(f"\n[ARGON] Audit-Ergebnis erfolgreich gespeichert: {out_file}")

    finally:
        if chrome_proc:
            chrome_proc.terminate()

asyncio.run(run())
