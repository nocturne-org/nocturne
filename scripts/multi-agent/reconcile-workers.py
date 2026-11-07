#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
reconcile-workers.py
Kanonischer Auto-Discovery und Reconcile-Service fuer Multi-Agenten-Sessions.
Liest conversation_summaries.db (SQLite) im Read-Only-Modus aus, filtert nach
dem aktiven Workspace, schliesst Manager-Sessions aus und mappt aktive GUI-Tabs
automatisch auf Worker 1, Worker 2 etc.

Ausnahmslos Standard-ASCII-Minuszeichen (-) verwenden.
"""

import sys
import os
import re
import json
import sqlite3
import argparse
import urllib.parse
from datetime import datetime

DEFAULT_DB_PATH = r"C:\Users\roger\.gemini\antigravity\conversation_summaries.db"
DEFAULT_QUEUE_DIR = r"C:\Users\roger\.gemini\scratch\queue"

def normalize_path(p):
    if not p:
        return ""
    p = os.path.abspath(p).replace("\\", "/").lower().rstrip("/")
    return p

def parse_workspace_uris(ws_json):
    if not ws_json:
        return []
    try:
        uris = json.loads(ws_json)
        paths = []
        for u in uris:
            unquoted = urllib.parse.unquote(u)
            if unquoted.startswith("file:///"):
                paths.append(normalize_path(unquoted[8:]))
            else:
                paths.append(normalize_path(unquoted))
        return paths
    except Exception:
        return []

def reconcile(workspace_dir, manager_id="", max_workers=10, db_path=DEFAULT_DB_PATH, queue_dir=""):
    norm_target = normalize_path(workspace_dir)
    if not os.path.exists(db_path):
        return {"success": False, "error": f"Database not found: {db_path}", "workers": []}

    project_slug = os.path.basename(norm_target) or "default"
    effective_queue_dir = queue_dir if (queue_dir and queue_dir.strip()) else os.path.join(DEFAULT_QUEUE_DIR, project_slug)

    # SQLite read-only URI mode (nie DB sperren)
    uri_db = f"file:{os.path.abspath(db_path)}?mode=ro"
    conn = sqlite3.connect(uri_db, uri=True)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT conversation_id, title, workspace_uris, last_modified_time, killed
        FROM conversation_summaries
        WHERE killed = 0
    """)
    rows = cursor.fetchall()
    conn.close()

    candidates = []
    for cid, title, ws_json, lmt, killed in rows:
        paths = parse_workspace_uris(ws_json)
        if norm_target in paths:
            candidates.append({
                "cid": str(cid),
                "title": str(title or "").strip(),
                "lmt": str(lmt or "")
            })

    # Manager filtern
    norm_mgr = manager_id.strip().lower() if manager_id else ""
    worker_pool = []
    for c in candidates:
        if norm_mgr and c["cid"].lower() == norm_mgr:
            continue
        if not norm_mgr and "manager" in c["title"].lower():
            continue
        worker_pool.append(c)

    # Nach letzter Aktivitaet sortieren (neueste zuerst)
    worker_pool.sort(key=lambda x: x["lmt"], reverse=True)

    assigned = {}
    unassigned = []

    # Stufe 1: Expliziter Title-Match (z. B. "Worker 1", "worker 2", "Arbeiter-1")
    for c in worker_pool:
        m = re.search(r"(?:worker|arbeiter)[\s\-_]*(\d+)", c["title"], re.IGNORECASE)
        if m:
            wid = int(m.group(1))
            if wid not in assigned and wid <= max_workers:
                assigned[wid] = {
                    "WorkerId": wid,
                    "ConversationId": c["cid"],
                    "Title": c["title"],
                    "LastModified": c["lmt"],
                    "MatchedBy": "title"
                }
            else:
                unassigned.append(c)
        else:
            unassigned.append(c)

    # Stufe 2: Sequenzielle Zuweisung nach Recency fuer verbleibende aktive Chats
    next_wid = 1
    for c in unassigned:
        while next_wid in assigned:
            next_wid += 1
        if next_wid > max_workers:
            break
        assigned[next_wid] = {
            "WorkerId": next_wid,
            "ConversationId": c["cid"],
            "Title": c["title"],
            "LastModified": c["lmt"],
            "MatchedBy": "recency"
        }
        next_wid += 1

    os.makedirs(effective_queue_dir, exist_ok=True)
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Session-Dateien fuer erkannte Worker schreiben
    active_worker_ids = set()
    result_workers = []
    for wid in sorted(assigned.keys()):
        w_data = assigned[wid]
        active_worker_ids.add(wid)
        session_file = os.path.join(effective_queue_dir, f"worker_{wid}_session.json")
        session_obj = {
            "WorkerId": wid,
            "ConversationId": w_data["ConversationId"],
            "Title": w_data["Title"],
            "Workspace": norm_target,
            "LastModified": w_data["LastModified"],
            "MatchedBy": w_data["MatchedBy"],
            "RegisteredAt": now_str,
            "AutoDiscovered": True
        }
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(session_obj, f, indent=2)
        result_workers.append(session_obj)

    # Veraltete Session-Dateien aufraeumen
    stale_removed = []
    for fname in os.listdir(effective_queue_dir):
        m = re.match(r"^worker_(\d+)_session\.json$", fname)
        if m:
            check_id = int(m.group(1))
            if check_id not in active_worker_ids:
                full_path = os.path.join(effective_queue_dir, fname)
                try:
                    os.remove(full_path)
                    stale_removed.append(check_id)
                except Exception:
                    pass

    return {
        "success": True,
        "workspace": norm_target,
        "queueDir": effective_queue_dir,
        "reconciledCount": len(result_workers),
        "workers": result_workers,
        "staleRemoved": stale_removed,
        "timestamp": now_str
    }

def main():
    parser = argparse.ArgumentParser(description="Auto-Reconcile active GUI worker conversations.")
    parser.add_argument("--workspace", default=os.getcwd(), help="Target workspace path")
    parser.add_argument("--manager-id", default="", help="Conversation ID of the manager agent")
    parser.add_argument("--max-workers", type=int, default=10, help="Max workers to register")
    parser.add_argument("--db-path", default=DEFAULT_DB_PATH, help="Path to conversation_summaries.db")
    parser.add_argument("--queue-dir", default="", help="Path to queue directory (defaults to queue/<project_slug>)")
    parser.add_argument("--json", action="store_true", help="Output pure JSON")

    args = parser.parse_args()
    res = reconcile(
        workspace_dir=args.workspace,
        manager_id=args.manager_id,
        max_workers=args.max_workers,
        db_path=args.db_path,
        queue_dir=args.queue_dir
    )

    if args.json:
        print(json.dumps(res, indent=2))
    else:
        print(f"[Auto-Reconcile] Workspace: {res.get('workspace')}")
        print(f"[Auto-Reconcile] {res.get('reconciledCount')} aktive Worker zugeordnet:")
        for w in res.get("workers", []):
            print(f"  - Worker {w['WorkerId']}: {w['ConversationId']} ('{w['Title']}') via {w['MatchedBy']}")
        if res.get("staleRemoved"):
            print(f"[Auto-Reconcile] Veraltete Worker-Sessions bereinigt: {res.get('staleRemoved')}")

if __name__ == "__main__":
    main()
