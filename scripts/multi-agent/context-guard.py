#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
context-guard.py
Ueberwacht den Kontext-Zustand aktiver Antigravity-Conversations anhand der transcript.jsonl.
Ermittelt, wann ein Chat gestaucht (/compact) oder durch ein Nachfolge-Fenster (Respawn)
ersetzt werden muss, differenziert nach Worker, Manager und normalem Benutzer-Chat.

Ausnahmslos Standard-ASCII-Minuszeichen (-) verwenden.
"""

import sys
import os
import json
import argparse
import subprocess
import re
from datetime import datetime

DEFAULT_BRAIN_DIR = r"C:\Users\roger\.gemini\antigravity\brain"
DEFAULT_AGENTAPI = r"C:\Users\roger\.gemini\antigravity\bin\agentapi.bat"
DEFAULT_QUEUE_BASE = r"C:\Users\roger\.gemini\scratch\queue"

# Schwellenwerte
THRESHOLDS = {
    "worker": {
        "compact_steps": 60,
        "compact_bytes": 1200000,    # ~1.2 MB
        "spawn_steps": 120,
        "spawn_bytes": 2500000       # ~2.5 MB
    },
    "manager": {
        "compact_steps": 40,
        "compact_bytes": 1000000,    # ~1.0 MB
        "spawn_steps": 80,
        "spawn_bytes": 2000000       # ~2.0 MB
    },
    "general": {
        "compact_turns": 25,
        "compact_bytes": 1500000,
        "spawn_turns": 40,
        "spawn_bytes": 3000000
    }
}

STOP_WORDS = {
    "der", "die", "das", "ein", "eine", "einer", "und", "oder", "fuer", "von",
    "mit", "nach", "zu", "im", "in", "am", "an", "auf", "ueber", "unter", "den",
    "dem", "des", "the", "a", "an", "and", "or", "for", "of", "with", "to", "in", "on"
}


def find_transcript_file(conversation_id=None, brain_dir=DEFAULT_BRAIN_DIR):
    if conversation_id:
        cid_str = str(conversation_id).strip()
        if re.match(r"^[A-Za-z0-9_-]{1,64}$", cid_str):
            p = os.path.join(brain_dir, cid_str, ".system_generated", "logs", "transcript.jsonl")
            if os.path.isfile(p):
                return p

    if os.path.isdir(brain_dir):
        newest_mtime = -1.0
        newest_path = None
        try:
            with os.scandir(brain_dir) as it:
                for entry in it:
                    try:
                        if entry.is_dir() and not entry.name.startswith("."):
                            t_file = os.path.join(entry.path, ".system_generated", "logs", "transcript.jsonl")
                            if os.path.isfile(t_file):
                                mtime = os.path.getmtime(t_file)
                                if mtime > newest_mtime:
                                    newest_mtime = mtime
                                    newest_path = t_file
                    except OSError:
                        continue
        except OSError:
            pass
        return newest_path

    return None


def analyze_transcript(transcript_path):
    if not transcript_path or not os.path.isfile(transcript_path):
        return {
            "exists": False,
            "user_turns": 0,
            "total_steps": 0,
            "tool_calls": 0,
            "file_size_bytes": 0,
            "last_prompt": ""
        }

    user_turns = 0
    total_steps = 0
    tool_calls = 0
    last_prompt = ""
    try:
        file_size = os.path.getsize(transcript_path)
    except OSError:
        file_size = 0

    try:
        with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    if not isinstance(obj, dict):
                        continue
                    total_steps += 1
                    step_type = obj.get("type", "")
                    if step_type == "USER_INPUT":
                        user_turns += 1
                        content = obj.get("content", "")
                        # Letzten Prompt festhalten (immer als String)
                        if content not in (None, ""):
                            if isinstance(content, str):
                                last_prompt = content
                            else:
                                last_prompt = str(content)
                    tc = obj.get("tool_calls", None)
                    if isinstance(tc, (list, tuple)):
                        tool_calls += len(tc)
                except (json.JSONDecodeError, ValueError):
                    continue
                except Exception:
                    continue
    except (OSError, IOError):
        pass

    return {
        "exists": True,
        "transcript_path": transcript_path,
        "user_turns": user_turns,
        "total_steps": total_steps,
        "tool_calls": tool_calls,
        "file_size_bytes": file_size,
        "last_prompt": last_prompt
    }


def evaluate_health(role, stats):
    cfg = THRESHOLDS.get(role, THRESHOLDS["general"])
    try:
        user_turns = int(stats.get("user_turns", 0) or 0)
    except (TypeError, ValueError):
        user_turns = 0
    try:
        total_steps = int(stats.get("total_steps", 0) or 0)
    except (TypeError, ValueError):
        total_steps = 0
    try:
        file_bytes = int(stats.get("file_size_bytes", 0) or 0)
    except (TypeError, ValueError):
        file_bytes = 0

    if role == "general":
        if user_turns >= cfg["spawn_turns"] or file_bytes >= cfg["spawn_bytes"]:
            return {
                "level": "spawn_recommended",
                "action": "spawn",
                "reason": f"User-Turns ({user_turns}) oder Byte-Groesse ({file_bytes} B) haben Obergrenze erreicht."
            }
        elif user_turns >= cfg["compact_turns"] or file_bytes >= cfg["compact_bytes"]:
            return {
                "level": "compact_recommended",
                "action": "compact",
                "reason": f"User-Turns ({user_turns}) haben Stufe 1 fuer Kompaktierung erreicht."
            }
    else:
        # Fuer Worker und Manager gilt die Step- & Byte-Heuristik
        if total_steps >= cfg["spawn_steps"] or file_bytes >= cfg["spawn_bytes"]:
            return {
                "level": "spawn_recommended",
                "action": "spawn",
                "reason": f"Gesamtschritte ({total_steps}) oder Byte-Groesse ({file_bytes} B) haben Obergrenze erreicht."
            }
        elif total_steps >= cfg["compact_steps"] or file_bytes >= cfg["compact_bytes"]:
            return {
                "level": "compact_recommended",
                "action": "compact",
                "reason": f"Gesamtschritte ({total_steps}) haben Stufe 1 fuer Kompaktierung erreicht."
            }

    return {
        "level": "ok",
        "action": "none",
        "reason": "Kontext im gruenen Bereich."
    }


def send_compact_command(conversation_id, agentapi_path=DEFAULT_AGENTAPI):
    if not conversation_id:
        return {"success": False, "error": "Keine ConversationId angegeben."}
    cid = str(conversation_id).strip()
    if not re.match(r"^[A-Za-z0-9_-]{1,64}$", cid):
        return {"success": False, "error": f"Ungueltige ConversationId: {conversation_id}"}
    if not os.path.exists(agentapi_path):
        return {"success": False, "error": f"agentapi nicht gefunden: {agentapi_path}"}

    cmd = [agentapi_path, "send-message", cid, "/compact"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, shell=False, encoding="utf-8", errors="replace")
        if proc.returncode == 0:
            return {"success": True, "message": f"/compact an {cid} gesendet."}
        return {"success": False, "error": proc.stderr or proc.stdout}
    except Exception as e:
        return {"success": False, "error": str(e)}


def generate_concise_title(text, max_words=3):
    if not text:
        return "Fortsetzungs-Chat"
    if not isinstance(text, str):
        text = str(text)
    if not isinstance(max_words, int) or max_words <= 0:
        max_words = 3

    # Saeubern
    cleaned = re.sub(r"<[^>]+>", " ", text)
    cleaned = re.sub(r"[\r\n\t]+", " ", cleaned)
    cleaned = re.sub(r"[^a-zA-Z0-9\u00C0-\u017F\s\-]", " ", cleaned)

    tokens = [w for w in cleaned.split() if len(w) > 2 and w.lower() not in STOP_WORDS]
    if not tokens:
        tokens = [w for w in cleaned.split() if w.strip()]

    selected = tokens[:max_words]
    title = " ".join(selected).title()
    return title if title else "Fortsetzungs-Chat"


def get_footer_banner(user_turns=40):
    return f"""> [!WARNING]
> **Chat-Kontext ist ausgereizt** ({user_turns} Turns erreicht).
> Um Qualitaetsverlust zu vermeiden, wird ein frischer Chat empfohlen.
> Fuehre `/context-guard` aus, um direkt in ein neues Fenster mit Handoff zu wechseln, oder nutze `/compact`."""


def main():
    parser = argparse.ArgumentParser(description="Context Guard - Kontextueberwachung und Auto-Evolution.")
    parser.add_argument("command", choices=["check", "compact", "banner", "title"], help="Auszufuehrender Befehl")
    parser.add_argument("--cid", default="", help="Conversation UUID")
    parser.add_argument("--transcript", default="", help="Pfad zu transcript.jsonl")
    parser.add_argument("--role", choices=["worker", "manager", "general"], default="general", help="Rolle des Chats")
    parser.add_argument("--text", default="", help="Text fuer Titel-Generierung")
    parser.add_argument("--max-words", type=int, default=3, help="Maximale Wortanzahl fuer Titel")
    parser.add_argument("--json", action="store_true", help="JSON-Ausgabe")

    args = parser.parse_args()

    if args.command == "title":
        title = generate_concise_title(args.text, max_words=args.max_words)
        if args.json:
            print(json.dumps({"title": title}, indent=2))
        else:
            print(title)
        return

    # Transcript lokalisieren
    t_path = args.transcript or find_transcript_file(args.cid)

    if args.command == "check":
        stats = analyze_transcript(t_path)
        health = evaluate_health(args.role, stats)
        result = {
            "conversationId": args.cid,
            "transcriptPath": t_path,
            "role": args.role,
            "userTurns": stats.get("user_turns", 0),
            "totalSteps": stats.get("total_steps", 0),
            "toolCalls": stats.get("tool_calls", 0),
            "fileSizeBytes": stats.get("file_size_bytes", 0),
            "level": health["level"],
            "action": health["action"],
            "reason": health["reason"]
        }
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"[Context-Guard] Rolle: {args.role} | Status: {health['level'].upper()}")
            print(f"  Turns: {result['userTurns']} | Steps: {result['totalSteps']} | Groesse: {result['fileSizeBytes']} Bytes")
            print(f"  Aktion: {health['action']} ({health['reason']})")
        return

    if args.command == "compact":
        cid = args.cid
        if not cid and t_path:
            # Versuche UUID aus Pfad zu extrahieren
            parts = t_path.replace("\\", "/").split("/")
            if "brain" in parts:
                idx = parts.index("brain")
                if idx + 1 < len(parts):
                    cid = parts[idx + 1]
        res = send_compact_command(cid)
        if args.json:
            print(json.dumps(res, indent=2))
        else:
            if res.get("success"):
                print(f"[Context-Guard] {res.get('message')}")
            else:
                print(f"[Context-Guard-Error] {res.get('error')}")
        return

    if args.command == "banner":
        stats = analyze_transcript(t_path)
        health = evaluate_health(args.role, stats)
        if health["level"] == "spawn_recommended":
            banner = get_footer_banner(stats.get("user_turns", 40))
            print(banner)
        return


if __name__ == "__main__":
    main()
