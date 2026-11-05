#!/usr/bin/env python3
"""setup_gemini_session.py - Einmaliger lokaler Login fuer Google Gemini Web (Argon).

Oeffnet Google Chrome zentriert in der Bildschirmmitte mit einem isolierten Profilordner,
damit Roger sich einmalig mit seinem Google-Konto einloggen kann.
Die Session bleibt danach dauerhaft lokal gespeichert und wird vom Hintergrund-CDP-Runner genutzt.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

CHROME_CANDIDATES = [
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
    Path(os.environ.get("LOCALAPPDATA", "")) / "Google/Chrome/Application/chrome.exe",
    Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
    Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
]

DEFAULT_PROFILE_DIR = Path(os.environ.get("USERPROFILE", "C:/Users/roger")) / ".gemini/config/gemini_profile"


def find_browser() -> Path:
    for candidate in CHROME_CANDIDATES:
        if candidate and candidate.is_file():
            return candidate
    for name in ("chrome", "chrome.exe", "msedge", "msedge.exe"):
        found = shutil.which(name)
        if found:
            return Path(found)
    raise SystemExit("Fehler: Kein Chrome oder Edge gefunden. Bitte Browser-Installation pruefen.")


def kill_existing_profile_instances() -> None:
    """Schliesst eventuell im Hintergrund laufende Chrome-Instanzen dieses Profils."""
    if sys.platform == "win32":
        try:
            cmd = "Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*gemini_profile*' -or $_.CommandLine -like '*9223*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
            subprocess.run(["powershell", "-Command", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)
        except Exception:
            pass


def get_screen_center_geometry(win_w: int = 1200, win_h: int = 850) -> tuple[int, int, int, int]:
    """Ermittelt Bildschirmaufloesung und berechnet zentrierte Fenster-Koordinaten."""
    sw = 1920
    sh = 1080
    if sys.platform == "win32":
        try:
            import ctypes
            user32 = ctypes.windll.user32
            sw = user32.GetSystemMetrics(0)
            sh = user32.GetSystemMetrics(1)
        except Exception:
            pass

    pos_x = max(0, (sw - win_w) // 2)
    pos_y = max(0, (sh - win_h) // 2)
    return pos_x, pos_y, sw, sh


def reset_window_placement_preferences(profile_dir: Path, pos_x: int, pos_y: int, win_w: int, win_h: int, sw: int, sh: int) -> None:
    """Bereinigt eventuelle Off-Screen-Koordinaten in den gespeicherten Chrome-Einstellungen."""
    pref_file = profile_dir / "Default" / "Preferences"
    if not pref_file.is_file():
        return

    try:
        data = json.loads(pref_file.read_text(encoding="utf-8"))
        if "browser" not in data or not isinstance(data["browser"], dict):
            data["browser"] = {}

        data["browser"]["window_placement"] = {
            "bottom": pos_y + win_h,
            "left": pos_x,
            "maximized": False,
            "right": pos_x + win_w,
            "top": pos_y,
            "work_area_bottom": sh,
            "work_area_left": 0,
            "work_area_right": sw,
            "work_area_top": 0,
        }
        pref_file.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass


def main() -> None:
    browser = find_browser()
    profile_dir = DEFAULT_PROFILE_DIR.resolve()
    profile_dir.mkdir(parents=True, exist_ok=True)
    target_url = "https://gemini.google.com"

    # Eventuelle alte Hintergrund-Prozesse beenden
    kill_existing_profile_instances()

    # Zentrierung berechnen (1200x850 Pixel, exakt mittig)
    win_w = 1200
    win_h = 850
    pos_x, pos_y, sw, sh = get_screen_center_geometry(win_w, win_h)

    # Gespeicherte Fensterposition bereinigen
    reset_window_placement_preferences(profile_dir, pos_x, pos_y, win_w, win_h, sw, sh)

    print("=" * 64)
    print("  Google Gemini Web (Argon) - Einmaliger Session-Login")
    print("=" * 64)
    print()
    print(f"Browser-Pfad: {browser}")
    print(f"Profil-Pfad : {profile_dir}")
    print(f"Fenster     : {win_w}x{win_h} zentriert bei X={pos_x}, Y={pos_y}")
    print(f"Ziel-URL    : {target_url}")
    print()
    print("Starte Browser mittig auf deinem Bildschirm...")

    args = [
        str(browser),
        f"--user-data-dir={profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
        "--remote-allow-origins=*",
        f"--window-size={win_w},{win_h}",
        f"--window-position={pos_x},{pos_y}",
        target_url,
    ]

    proc = subprocess.Popen(args)

    print()
    print(">> Das Browserfenster ist jetzt mittig geoeffnet.")
    print(">> Bitte logge dich ganz normal mit deinem Google-Konto ein.")
    print(">> Sobald du auf https://gemini.google.com bist und das Chatfeld siehst:")
    try:
        input(">> Druecke hier im Terminal [ENTER], um die Session abzuschliessen...")
    except (KeyboardInterrupt, EOFError):
        print("\nAbbruch durch Benutzer.")
        sys.exit(1)

    marker_file = profile_dir / "session_ready.txt"
    with open(marker_file, "w", encoding="utf-8") as f:
        f.write(f"Session initialisiert am: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    print()
    print("[OK] Session wurde erfolgreich gespeichert.")
    print(f"[OK] Profilpfad: {profile_dir}")
    print("Kuenftig kann der Hintergrund-Runner (gemini_cdp_runner.py) ohne Unterbrechung zugreifen.")
    print()


if __name__ == "__main__":
    main()
