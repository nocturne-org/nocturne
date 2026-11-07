#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
spawn-agent.py
Spawnt neue native Antigravity GUI-Conversations via agentapi.bat.
Ermoeglicht:
1. Automatisches Erstellen von Worker-Fenstern mit Autonomie-Prompt und Rollennamen.
2. Automatisches Erstellen eines frischen Manager-Fensters bei Kontext-Reset.
3. Automatisches Erstellen eines normalen Folge-Chats mit praegnantem 3-Wort-Titel.

Ausnahmslos Standard-ASCII-Minuszeichen (-) verwenden.
"""

import sys
import os
import json
import argparse
import subprocess
import re
from datetime import datetime

DEFAULT_AGENTAPI = r"C:\Users\roger\.gemini\antigravity\bin\agentapi.bat"
DEFAULT_LANGUAGE_SERVER = r"C:\Users\roger\AppData\Local\Programs\antigravity\resources\bin\language_server.exe"
DEFAULT_QUEUE_BASE = r"C:\Users\roger\.gemini\scratch\queue"

STOP_WORDS = {
    "der", "die", "das", "ein", "eine", "einer", "und", "oder", "fuer", "von",
    "mit", "nach", "zu", "im", "in", "am", "an", "auf", "ueber", "unter", "den",
    "dem", "des", "the", "a", "an", "and", "or", "for", "of", "with", "to", "in", "on"
}


def normalize_path(p):
    if not p:
        return ""
    return os.path.abspath(p).replace("\\", "/").lower().rstrip("/")


def sanitize_three_word_title(raw_title, fallback="Fortsetzungs Chat"):
    if not raw_title:
        return fallback

    # Entferne Markdown, HTML, Sonderzeichen
    cleaned = re.sub(r"<[^>]+>", " ", raw_title)
    cleaned = re.sub(r"[^a-zA-Z0-9\u00C0-\u017F\s\-]", " ", cleaned)
    words = [w for w in cleaned.split() if w.strip()]

    if not words:
        return fallback

    # Falls mehr als 3 Woerter, Stop-Woerter filtern
    if len(words) > 3:
        meaningful = [w for w in words if w.lower() not in STOP_WORDS]
        if len(meaningful) >= 2:
            words = meaningful[:3]
        else:
            words = words[:3]

    return " ".join(words[:3]).title()


def run_agentapi_new_conversation(title, prompt, model="flash", agentapi_path=DEFAULT_AGENTAPI):
    # Direkter Aufruf von language_server.exe vermeidet Argument-Splitting bei Mehrzeilern in .bat
    if os.path.exists(DEFAULT_LANGUAGE_SERVER):
        cmd = [DEFAULT_LANGUAGE_SERVER, "agentapi", "new-conversation", f"--title={title}", prompt]
    elif os.path.exists(agentapi_path):
        cmd = [agentapi_path, "new-conversation", f"--title={title}", prompt]
    else:
        return {"success": False, "error": f"Weder language_server.exe noch agentapi.bat gefunden."}
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, shell=False, encoding="utf-8", errors="replace")
        stdout = proc.stdout.strip()
        if not stdout:
            return {"success": False, "error": f"agentapi lieferte leere Ausgabe. Stderr: {proc.stderr}"}

        data = json.loads(stdout)
        new_conv = data.get("response", {}).get("newConversation", {})
        cid = new_conv.get("conversationId", "")
        if cid:
            return {"success": True, "conversationId": cid, "title": title}
        return {"success": False, "error": f"Keine conversationId in Antwort: {stdout}"}
    except Exception as e:
        return {"success": False, "error": str(e)}


def spawn_worker(worker_id, role="Worker", domain="src/", parent_manager_id="", generation=1, workspace_dir="", project_slug="", queue_base=DEFAULT_QUEUE_BASE):
    ws_norm = normalize_path(workspace_dir or os.getcwd())
    p_slug = project_slug or os.path.basename(ws_norm) or "default"
    q_dir = os.path.join(queue_base, p_slug)
    os.makedirs(q_dir, exist_ok=True)

    # Rollenbasierter Name: z. B. 'Security Worker 1', 'DevOps Worker 2'
    clean_role = role.strip()
    if clean_role.lower().endswith("worker"):
        base_title = f"{clean_role} {worker_id}"
    else:
        base_title = f"{clean_role} Worker {worker_id}"

    title = f"{base_title} ({generation})" if generation > 1 else base_title

    # Template einlesen falls vorhanden
    tpl_path = os.path.join(ws_norm, "templates", "multi-agent", "master-prompt-worker.template")
    parent_id_str = parent_manager_id or "0"
    if os.path.isfile(tpl_path):
        with open(tpl_path, "r", encoding="utf-8") as f:
            prompt = f.read()
        prompt = prompt.replace("{{WORKER_ID}}", str(worker_id))
        prompt = prompt.replace("{{ROLE_NAME}}", clean_role)
        prompt = prompt.replace("{{ASSIGNED_DOMAIN}}", domain)
        prompt = prompt.replace("{{PARENT_MANAGER_ID}}", parent_id_str)
        prompt = prompt.replace("{{ASSIGNED_FILES}}", f"- {domain}*")
        prompt = prompt.replace("{{TASK_DESCRIPTION}}", "Warte auf erste Zuweisung ueber NextTask oder bearbeite die initiale Domaenen-Aufgabe.")
    else:
        prompt = f"""Du bist {title} ({clean_role}).
Deine primaere Zieldomaene ist strikt: {domain}
Uebergeordneter Untermanager ID: {parent_id_str}
Projekt: {p_slug}
Generation: {generation}

DEIN MODUS: AUTONOMER QUEUE-WORKER (Endlos-Schleife bis alle Aufgaben abgeschlossen sind).
Du musst NICHT auf neuen Input im Chat warten! Du arbeitest alle Aufgaben vollautonom ab.

## DEIN SCHLEIFEN-PROTOKOLL:
1. AUFGABE ZIEHEN:
   powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action NextTask -WorkerId {worker_id} -Role "{clean_role}" -Json

2. WENN EINE AUFGABE VORLIEGT (Found == true):
   a) Lies TaskId, Title, TargetFiles und Description.
   b) SKILL-MATCHING:
      Gleiche die Aufgabe mit docs/architecture/skill-routing-matrix.md ab (z. B. /offload-worker fuer Bulk-Code, /modern-web-guidance fuer Frontend, /tdd fuer Logik/Tests).
   c) FUEHRE DIE AUFGABE AUS (Code schreiben, validieren).
   d) Sicherheitsregeln:
      - Datei-Isolation: AUSNAHMSLOS Dateien in deiner Zieldomaene ({domain}).
      - Typografie: Ausnahmslos Standard-ASCII-Minus (-). En-Dash und Em-Dash sind verboten.
      - Anti-Slop: Klarer, funktionaler Code ohne unnoetige Kommentare.
   e) Aufgabe als erledigt markieren:
      powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action CompleteTask -WorkerId {worker_id} -TaskId "<TASK_ID>" -Summary "Erledigt"
      powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action SendMessage -To {parent_id_str} -From "{title}" -Message "Task <TASK_ID> erledigt."
   f) Gehe SOFORT und OHNE Pause zurueck zu SCHRITT 1, um die naechste Aufgabe zu bearbeiten!

3. WENN KEINE AUFGABE BEREITSTEHT (Found == false):
   - Falls Status == 'WAITING_FOR_DEPENDENCY':
     powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action WaitForWake -WorkerId {worker_id}
   - Falls Status == 'ALL_COMPLETED':
     Melde im Chat 'Alle Aufgaben in Domaene {domain} erledigt.' und beende die Schleife.
"""

    res = run_agentapi_new_conversation(title=title, prompt=prompt)
    if res.get("success"):
        cid = res["conversationId"]
        session_file = os.path.join(q_dir, f"worker_{worker_id}_session.json")
        sess_data = {
            "WorkerId": worker_id,
            "ConversationId": cid,
            "Title": title,
            "Workspace": ws_norm,
            "Project": p_slug,
            "Role": clean_role,
            "Domain": domain,
            "ParentManagerId": parent_id_str,
            "Generation": generation,
            "RegisteredAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "AutoSpawned": True
        }
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(sess_data, f, indent=2)
        res["sessionFile"] = session_file
        res["workerId"] = worker_id
        res["project"] = p_slug
        res["generation"] = generation

    return res


def spawn_submanager(role, domain="src/", parent_manager_id="0", responsibilities="", generation=1, submanager_id=1, workspace_dir="", project_slug="", queue_base=DEFAULT_QUEUE_BASE):
    ws_norm = normalize_path(workspace_dir or os.getcwd())
    p_slug = project_slug or os.path.basename(ws_norm) or "default"
    q_dir = os.path.join(queue_base, p_slug)
    os.makedirs(q_dir, exist_ok=True)

    clean_role = role.strip()
    if clean_role.lower().endswith("manager"):
        base_title = clean_role
    else:
        base_title = f"{clean_role} Manager"

    title = f"{base_title} ({generation})" if generation > 1 else base_title

    tpl_path = os.path.join(ws_norm, "templates", "multi-agent", "master-prompt-submanager.template")
    resp_text = responsibilities.strip() if responsibilities else f"- Fachliche Gesamtverantwortung fuer Domaene {domain}\n- Qualitaetssicherung, DeepSeek-Sparring und Worker-Steuerung"

    if os.path.isfile(tpl_path):
        with open(tpl_path, "r", encoding="utf-8") as f:
            prompt = f.read()
        prompt = prompt.replace("{{PROJECT_SLUG}}", p_slug)
        prompt = prompt.replace("{{WORKSPACE_PATH}}", ws_norm)
        prompt = prompt.replace("{{ROLE_NAME}}", clean_role)
        prompt = prompt.replace("{{ASSIGNED_DOMAIN}}", domain)
        prompt = prompt.replace("{{RESPONSIBILITIES}}", resp_text)
        prompt = prompt.replace("{{PARENT_MANAGER_ID}}", str(parent_manager_id or "0"))
        prompt = prompt.replace("{{SUBMANAGER_ID}}", str(submanager_id))
        prompt = prompt.replace("{{WORKER_TARGET_ID}}", str(submanager_id))
        prompt = prompt.replace("{{GENERATION}}", str(generation))
        prompt = prompt.replace("{{NEXT_GENERATION}}", str(generation + 1))
    else:
        prompt = f"""Du bist der {title} fuer {p_slug} ({ws_norm}).
Zieldomaene: {domain}
Uebergeordneter CEO: {parent_manager_id}

DEIN MODUS: RESSORT-LEITER (Fachliche Fuehrung, Dekomposition, Worker-Steuerung).
Arbeite den operativen 6-Schritte-Kreislauf ab:
1. Registrierung: powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action RegisterWorker -WorkerId {submanager_id} -Role "{clean_role}"
2. Aufgaben abholen: powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action NextTask -Role "{clean_role}" -Json
3. DeepSeek-Sparring fuer Risiko- und Schnittstellen-Check.
4. Dekomposition und Worker-Dispatching (GUI-Worker oder OpenCode Grid).
5. Ueberwachung & Blockaden-Beseitigung.
6. Vollzugsmeldung an den CEO per CLI.
"""

    res = run_agentapi_new_conversation(title=title, prompt=prompt)
    if res.get("success"):
        cid = res["conversationId"]
        safe_role_slug = re.sub(r"[^a-zA-Z0-9_\-]", "_", clean_role.lower())
        session_file = os.path.join(q_dir, f"submanager_{safe_role_slug}_session.json")
        sess_data = {
            "SubManagerId": submanager_id,
            "ConversationId": cid,
            "Title": title,
            "Workspace": ws_norm,
            "Project": p_slug,
            "Role": clean_role,
            "Domain": domain,
            "ParentManagerId": str(parent_manager_id or "0"),
            "Generation": generation,
            "RegisteredAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "AutoSpawned": True
        }
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(sess_data, f, indent=2)

        # In private project-domains.json registrieren (ausserhalb des Repos)
        domains_file = os.path.join(q_dir, "project-domains.json")
        domains_data = {"project": p_slug, "workspace": ws_norm, "submanagers": []}
        if os.path.isfile(domains_file):
            try:
                with open(domains_file, "r", encoding="utf-8") as df:
                    domains_data = json.load(df)
            except Exception:
                pass

        # Update oder Append
        existing = [sm for sm in domains_data.get("submanagers", []) if sm.get("role", "").lower() != clean_role.lower()]
        existing.append({
            "role": clean_role,
            "domain": domain,
            "submanager_id": submanager_id,
            "conversation_id": cid,
            "parent_manager_id": str(parent_manager_id or "0"),
            "generation": generation,
            "last_registered": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        domains_data["submanagers"] = existing
        with open(domains_file, "w", encoding="utf-8") as df:
            json.dump(domains_data, df, indent=2)

        res["sessionFile"] = session_file
        res["role"] = clean_role
        res["domain"] = domain
        res["submanagerId"] = submanager_id
        res["project"] = p_slug

    return res


def spawn_manager(workspace_dir="", project_slug="", generation=1, summary="", queue_base=DEFAULT_QUEUE_BASE):
    ws_norm = normalize_path(workspace_dir or os.getcwd())
    p_slug = project_slug or os.path.basename(ws_norm) or "default"
    q_dir = os.path.join(queue_base, p_slug)
    os.makedirs(q_dir, exist_ok=True)

    summary_text = summary.strip() if summary else "Der bisherige Manager hat ein frisches Fenster initiiert, um den Kontext zu resetten."

    tpl_path = os.path.join(ws_norm, "templates", "multi-agent", "master-prompt-manager.template")
    if os.path.isfile(tpl_path):
        with open(tpl_path, "r", encoding="utf-8") as f:
            template_content = f.read()
        prompt = f"""{template_content}

---

## 6. Uebergabe-Status von Generation {generation - 1 if generation > 1 else 1} (Handoff)
- Generation: {generation}
- Uebergabe-Stand:
{summary_text}

Fuehre sofort Schritt 0 (Initialer System-Check) aus und setze die Steuerung fort.
"""
    else:
        prompt = f"""Du bist der Manager fuer das Projekt {p_slug} im Workspace {ws_norm}.
Dieser Chat wurde frisch erstellt, um den Kontext-Ballast des vorherigen Managers auf 0 zu resetten.
Generation: {generation}

UEBERGABE-STAND:
{summary_text}

DEINE NAECHSTEN SCHRITTE:
1. Pruefe sofort den aktuellen Status der Aufgaben-Queue:
   powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action Status
2. Falls Worker aufgeweckt werden muessen:
   powershell -File .\\scripts\\multi-agent\\manage-queue.ps1 -Action WakeAll
3. Fuehre den Zwei-Takt-Ueberwachungszyklus (30s Pruefung / 5-Minuten-Dashboard) gemaess /subagent-manager fort.
"""

    base_title = f"Manager ({p_slug})"
    title = f"{base_title} ({generation})" if generation > 1 else base_title

    res = run_agentapi_new_conversation(title=title, prompt=prompt)
    if res.get("success"):
        res["project"] = p_slug
        res["summary"] = summary_text
        res["generation"] = generation
        manager_file = os.path.join(q_dir, "manager_session.json")
        mgr_data = {
            "ConversationId": res["conversationId"],
            "Title": title,
            "Workspace": ws_norm,
            "Project": p_slug,
            "Generation": generation,
            "RegisteredAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        with open(manager_file, "w", encoding="utf-8") as f:
            json.dump(mgr_data, f, indent=2)

    return res


def spawn_general(title="", prompt="", workspace_dir="", project_slug="", summary=""):
    ws_norm = normalize_path(workspace_dir or os.getcwd())
    p_slug = project_slug or os.path.basename(ws_norm) or "default"

    # Titel strikt auf maximal 3 Woerter kuerzen / normalisieren
    final_title = sanitize_three_word_title(title or summary or "Fortsetzungs Chat")

    content_prompt = prompt.strip()
    if not content_prompt:
        summary_body = summary.strip() if summary else "Dieser Chat setzt die vorherige Session mit frischem 0-Token-Kontext fort."
        content_prompt = f"""Du bist der fortsetzende KI-Assistent fuer Roger im Projekt {p_slug} (Workspace: {ws_norm}).
Dieser Chat wurde frisch erstellt, um den ausgereizten Kontext der vorherigen Unterhaltung freizumachen.

UEBERGABE-STAND & KONTEXT:
{summary_body}

FUEHRE DIE ARBEIT NAHTLOS FORT:
1. Ueberpruefe den aktuellen Git-Status mit git status.
2. Nimm den naechsten offenen Schritt aus dem Uebergabestand direkt auf.
"""

    res = run_agentapi_new_conversation(title=final_title, prompt=content_prompt)
    if res.get("success"):
        res["project"] = p_slug
        res["title"] = final_title

    return res


def main():
    parser = argparse.ArgumentParser(description="Spawn worker, submanager, manager or general conversations via agentapi.")
    parser.add_argument("--type", choices=["worker", "manager", "submanager", "workers", "general"], required=True, help="Type of conversation")
    parser.add_argument("--worker-id", type=int, default=1, help="Worker ID")
    parser.add_argument("--submanager-id", type=int, default=1, help="SubManager ID")
    parser.add_argument("--count", type=int, default=2, help="Worker count for workers type")
    parser.add_argument("--role", default="Worker", help="Worker/SubManager role name (e.g. Security, DevOps, UI)")
    parser.add_argument("--domain", default="src/", help="Worker/SubManager domain")
    parser.add_argument("--parent-manager-id", default="0", help="Parent Manager / SubManager Conversation ID")
    parser.add_argument("--responsibilities", default="", help="SubManager responsibilities description")
    parser.add_argument("--generation", type=int, default=1, help="Generation number (n+1)")
    parser.add_argument("--workspace", default=os.getcwd(), help="Workspace path")
    parser.add_argument("--project", default="", help="Project slug")
    parser.add_argument("--title", default="", help="Title for general chat (max 3 words)")
    parser.add_argument("--summary", default="", help="Summary text for handoff")
    parser.add_argument("--prompt", default="", help="Custom prompt text")
    parser.add_argument("--json", action="store_true", help="Output pure JSON")

    args = parser.parse_args()

    if args.type == "worker":
        res = spawn_worker(
            worker_id=args.worker_id,
            role=args.role,
            domain=args.domain,
            parent_manager_id=args.parent_manager_id,
            generation=args.generation,
            workspace_dir=args.workspace,
            project_slug=args.project
        )
        if args.json:
            print(json.dumps(res, indent=2))
        else:
            if res.get("success"):
                print(f"[Spawn] Worker {args.worker_id} ({res.get('title')}) erfolgreich erstellt! ID: {res.get('conversationId')}")
            else:
                print(f"[Spawn-Error] Worker-Erstellung fehlgeschlagen: {res.get('error')}")

    elif args.type == "submanager":
        res = spawn_submanager(
            role=args.role,
            domain=args.domain,
            parent_manager_id=args.parent_manager_id,
            responsibilities=args.responsibilities,
            generation=args.generation,
            submanager_id=args.submanager_id,
            workspace_dir=args.workspace,
            project_slug=args.project
        )
        if args.json:
            print(json.dumps(res, indent=2))
        else:
            if res.get("success"):
                print(f"[Spawn] Untermanager '{res.get('role')}' ({res.get('title')}) erfolgreich erstellt! ID: {res.get('conversationId')}")
            else:
                print(f"[Spawn-Error] Untermanager-Erstellung fehlgeschlagen: {res.get('error')}")

    elif args.type == "workers":
        results = []
        for wid in range(1, args.count + 1):
            r = spawn_worker(
                worker_id=wid,
                role=args.role if args.role != "Worker" else f"Worker-{wid}",
                domain=args.domain,
                generation=args.generation,
                workspace_dir=args.workspace,
                project_slug=args.project
            )
            results.append(r)
        if args.json:
            print(json.dumps(results, indent=2))
        else:
            for r in results:
                if r.get("success"):
                    print(f"[Spawn] Worker {r.get('workerId')} ({r.get('title')}) erstellt! ID: {r.get('conversationId')}")
                else:
                    print(f"[Spawn-Error] Worker {r.get('workerId', '?')} Fehler: {r.get('error')}")

    elif args.type == "manager":
        res = spawn_manager(
            workspace_dir=args.workspace,
            project_slug=args.project,
            generation=args.generation,
            summary=args.summary
        )
        if args.json:
            print(json.dumps(res, indent=2))
        else:
            if res.get("success"):
                print(f"[Spawn] Manager-Fenster ({res.get('title')}) erfolgreich erstellt! ID: {res.get('conversationId')}")
            else:
                print(f"[Spawn-Error] Manager-Erstellung fehlgeschlagen: {res.get('error')}")

    elif args.type == "general":
        res = spawn_general(
            title=args.title,
            prompt=args.prompt,
            workspace_dir=args.workspace,
            project_slug=args.project,
            summary=args.summary
        )
        if args.json:
            print(json.dumps(res, indent=2))
        else:
            if res.get("success"):
                print(f"[Spawn] Neuer Chat '{res.get('title')}' erfolgreich erstellt! ID: {res.get('conversationId')}")
            else:
                print(f"[Spawn-Error] Chat-Erstellung fehlgeschlagen: {res.get('error')}")


if __name__ == "__main__":
    main()
