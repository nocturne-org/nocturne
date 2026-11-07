<#
.SYNOPSIS
    Startet ein OpenCode Multi-Agent Grid in sichtbaren Terminal-Fenstern auf dem Windows Desktop.
.DESCRIPTION
    Teilt Aufgaben autonom in Master-Prompts auf, startet parallele Worker in Terminal-Fenstern,
    ueberwacht PIDs mit einem 30s-Watchdog und schliesst Kacheln nach 10 Minuten Inaktivitaet.
.PARAMETER TasksJson
    Pfad zu einer JSON-Datei mit Aufgabendefinitionen.
.PARAMETER AutoCloseMinutes
    Minuten bis zum automatischen Schliessen nach Aufgabenabschluss (Standard: 10).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TasksJson = "",

    [Parameter(Mandatory = $false)]
    [int]$AutoCloseMinutes = 10,

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceRoot = "",

    [Parameter(Mandatory = $false)]
    [switch]$SkipPreflight,

    [Parameter(Mandatory = $false)]
    [switch]$LocalOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $WorkspaceRoot = (Get-Location).Path
}

# 1. Verzeichnisse & Scratch initialisieren
$ScratchDir = "C:\Users\roger\.gemini\scratch\agent-grid"
if (-not (Test-Path -Path $ScratchDir)) {
    New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
}

$TemplatePath = Join-Path $WorkspaceRoot "templates\multi-agent\master-prompt-worker.template"
if (-not (Test-Path -Path $TemplatePath)) {
    throw "Template nicht gefunden: $TemplatePath"
}

# 2. Alte Grid-Instanzen aufraeumen (Fenster- & Prozesshygiene)
$ActiveGridFile = Join-Path $ScratchDir "active_grid.json"
if (Test-Path -Path $ActiveGridFile) {
    Write-Host "[Grid-Setup] Raeume vorherige Grid-Session auf..." -ForegroundColor Cyan
    try {
        $PrevGrid = Get-Content -Path $ActiveGridFile -Raw | ConvertFrom-Json
        if ($PrevGrid.Pids) {
            foreach ($oldPid in $PrevGrid.Pids) {
                $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Host "  Beende alten Prozess: $oldPid ($($proc.ProcessName))" -ForegroundColor Gray
                    Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {
        Write-Warning "Konnte alte Grid-PIDs nicht vollstaendig beenden: $_"
    }
    Remove-Item -Path $ActiveGridFile -Force -ErrorAction SilentlyContinue
}

# 3. Reversibilitaet sichern (Git-Checkpoint)
Write-Host "[Grid-Setup] Sichere Git-Status (Reversibilitaet)..." -ForegroundColor Cyan
Push-Location $WorkspaceRoot
try {
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        git add -A
        git commit -m "checkpoint(pre-grid): snapshot before multi-agent grid ($timestamp)" | Out-Null
        Write-Host "  Arbeitsverzeichnis gesichert via Git-Commit: checkpoint(pre-grid)-$timestamp." -ForegroundColor Green
    } else {
        Write-Host "  Git-Working-Tree ist sauber. Kein Commit erforderlich." -ForegroundColor Green
    }
} finally {
    Pop-Location
}

# 4. Aufgaben laden oder Default-Szenario aufsetzen
$TasksList = @()
$ManageQueueScript = Join-Path $WorkspaceRoot "scripts\multi-agent\manage-queue.ps1"

if ($TasksJson -ne "" -and (Test-Path -Path $TasksJson)) {
    $TasksList = Get-Content -Path $TasksJson -Raw | ConvertFrom-Json
    if (Test-Path -Path $ManageQueueScript) {
        Write-Host "[Grid-Setup] Initialisiere Aufgaben-Queue via manage-queue.ps1..." -ForegroundColor Cyan
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ManageQueueScript" -Action Init -TasksJson "$TasksJson" | Out-Null
    }
} else {
    # Default Dual-Worker Konfiguration: Core-Logik + Tests
    $TasksList = @(
        [PSCustomObject]@{
            WorkerId = 1
            Role = "Core-Developer"
            Domain = "src/"
            Model = if ($LocalOnly) { "ollama/qwen-coder-unhinged:7b" } else { "groq/llama-3.3-70b-versatile" }
            FallbackModel = "opencode/beam-free#low"
            TargetFiles = @("src/example_module.py")
            TaskDescription = "Erstelle ein sauberes Python-Modul mit Typhinweisen und Docstrings. Verwende strikt ASCII-Minus."
        },
        [PSCustomObject]@{
            WorkerId = 2
            Role = "Test-Engineer"
            Domain = "tests/"
            Model = if ($LocalOnly) { "ollama/qwen-coder-unhinged:7b" } else { "opencode/beam-free#low" }
            FallbackModel = "sambanova/Meta-Llama-3.3-70B-Instruct"
            TargetFiles = @("tests/test_example_module.py")
            TaskDescription = "Schreibe passende Pytest-Unit-Tests fuer das Modul in src/. Verwende strikt ASCII-Minus."
        }
    )
}

# Worker-Pool ableiten (Eindeutige Worker-IDs)
$WorkerPool = @()
$groupedWorkers = $TasksList | Group-Object -Property WorkerId
foreach ($grp in $groupedWorkers) {
    $firstTask = $grp.Group[0]
    $WorkerPool += [PSCustomObject]@{
        WorkerId = [int]$grp.Name
        Role = if ($firstTask.Role) { $firstTask.Role } else { "Worker $($grp.Name)" }
        Domain = if ($firstTask.Domain) { $firstTask.Domain } else { "src/" }
        Model = if ($firstTask.Model) { $firstTask.Model } elseif ($LocalOnly) { "ollama/qwen-coder-unhinged:7b" } else { "groq/llama-3.3-70b-versatile" }
        FallbackModel = if ($firstTask.FallbackModel) { $firstTask.FallbackModel } else { "opencode/beam-free#low" }
        TargetFiles = if ($firstTask.TargetFiles) { $firstTask.TargetFiles } else { @() }
        TaskDescription = if ($firstTask.TaskDescription) { $firstTask.TaskDescription } elseif ($firstTask.Description) { $firstTask.Description } else { "Aufgabe bearbeiten" }
        TasksCount = $grp.Count
    }
}

# 5. Pre-Flight Health-Check (API-Erreichbarkeit)
if (-not $SkipPreflight -and -not $LocalOnly) {
    Write-Host "[Pre-Flight] Pruefe Erreichbarkeit der Free-Tier Endpunkte..." -ForegroundColor Cyan
    foreach ($worker in $WorkerPool) {
        Write-Host "  Teste Provider fuer Worker $($worker.WorkerId) ($($worker.Model))..." -ForegroundColor Gray
        $pingOutput = ""
        $pingSuccess = $false
        try {
            $testCmd = "opencode run -m $($worker.Model) 'Antworte nur mit OK.' < NUL 2>&1"
            $pingOutput = cmd.exe /c $testCmd
            if ($LASTEXITCODE -eq 0 -and $pingOutput -notmatch "Rate limit|error|exceeded") {
                $pingSuccess = $true
            }
        } catch {
            $pingSuccess = $false
        }

        if (-not $pingSuccess) {
            Write-Warning "  Worker $($worker.WorkerId) ($($worker.Model)) meldet Fehler. Schalte auf Fallback: $($worker.FallbackModel)"
            $worker.Model = $worker.FallbackModel
        } else {
            Write-Host "  Worker $($worker.WorkerId) Endpunkt bereit." -ForegroundColor Green
        }
    }
}

# 6. Master-Prompts & Runner-Skripte pro Worker generieren
$RunnerPaths = @()
$TemplateContent = Get-Content -Path $TemplatePath -Raw

foreach ($worker in $WorkerPool) {
    $wId = $worker.WorkerId
    $promptFile = Join-Path $ScratchDir "worker_${wId}_prompt.txt"
    $runnerFile = Join-Path $ScratchDir "worker_${wId}_runner.ps1"
    $pidFile = Join-Path $ScratchDir "worker_${wId}.pid"
    $heartbeatFile = Join-Path $ScratchDir "heartbeat_${wId}.txt"
    $statusFile = Join-Path $ScratchDir "status_${wId}.json"

    # Alte Status-/PID-Dateien entfernen
    Remove-Item -Path $pidFile, $heartbeatFile, $statusFile -Force -ErrorAction SilentlyContinue

    # Files-Liste als Aufzaehlung
    $filesText = ($worker.TargetFiles | ForEach-Object { "- $_" }) -join "`r`n"

    # Template fuellen
    $masterPrompt = $TemplateContent
    $masterPrompt = $masterPrompt.Replace("{{WORKER_ID}}", [string]$wId)
    $masterPrompt = $masterPrompt.Replace("{{ROLE_NAME}}", [string]$worker.Role)
    $masterPrompt = $masterPrompt.Replace("{{ASSIGNED_DOMAIN}}", [string]$worker.Domain)
    $masterPrompt = $masterPrompt.Replace("{{ASSIGNED_FILES}}", $filesText)
    $masterPrompt = $masterPrompt.Replace("{{TASK_DESCRIPTION}}", [string]$worker.TaskDescription)

    # Prompt speichern
    [System.IO.File]::WriteAllText($promptFile, $masterPrompt, [System.Text.Encoding]::UTF8)

    # Runner-Skript generieren mit autonomer Queue-Schleife
    $AutoCloseSeconds = $AutoCloseMinutes * 60
    $runnerScript = @"
`$ErrorActionPreference = "Continue"
`$Host.UI.RawUI.WindowTitle = "OpenCode Grid | Worker ${wId} - $($worker.Role) ($($worker.Model))"

# PID & Start-Signal sofort schreiben
[System.IO.File]::WriteAllText("$pidFile", `$PID.ToString(), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$heartbeatFile", (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), [System.Text.Encoding]::UTF8)

# Heartbeat-Hintergrund-Timer starten
`$HeartbeatTimer = New-Object System.Timers.Timer
`$HeartbeatTimer.Interval = 5000
Register-ObjectEvent -InputObject `$HeartbeatTimer -EventName Elapsed -SourceIdentifier "Heartbeat_${wId}" -Action {
    try {
        [System.IO.File]::WriteAllText("$heartbeatFile", (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), [System.Text.Encoding]::UTF8)
    } catch {}
} | Out-Null
`$HeartbeatTimer.Start()

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " OPENCODE WORKER $wId : $($worker.Role)" -ForegroundColor Yellow
Write-Host " Modell: $($worker.Model)" -ForegroundColor White
Write-Host " Domaene: $($worker.Domain)" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

`$startTime = Get-Date
`$overallExitCode = 0
`$tasksProcessed = 0

`$QueueScript = "$ManageQueueScript"
`$QueueDir = "C:\Users\roger\.gemini\scratch\queue"

if (Test-Path -Path `$QueueScript) {
    Write-Host "[Queue-Modus] Starte autonome Aufgaben-Schleife fuer Worker ${wId}..." -ForegroundColor Cyan
    while (`$true) {
        `$rawNext = powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$QueueScript" -Action NextTask -WorkerId ${wId} -Json 2>&1
        `$taskObj = `$null
        try {
            `$taskObj = `$rawNext | ConvertFrom-Json
        } catch {}

        if (`$taskObj -and `$taskObj.Found -eq `$true) {
            Write-Host ""
            Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
            Write-Host " [AUFGABE] `$($taskObj.TaskId) : `$($taskObj.Title)" -ForegroundColor Yellow
            Write-Host " Domaene: `$($taskObj.Domain)" -ForegroundColor Gray
            Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

            `$pMdFile = Join-Path `$QueueDir "worker_${wId}.md"
            `$taskPrompt = if (Test-Path -Path `$pMdFile) { Get-Content -Path `$pMdFile -Raw } else { "`$($taskObj.Title): `$($taskObj.Description)" }

            `$tStart = Get-Date
            cmd.exe /c "opencode run --auto -m $($worker.Model) `"`$taskPrompt`" < NUL 2>&1"
            `$tExit = `$LASTEXITCODE
            `$tDur = [Math]::Round(((Get-Date) - `$tStart).TotalSeconds, 1)

            if (`$tExit -eq 0) {
                Write-Host " [STATUS] Aufgabe `$($taskObj.TaskId) erfolgreich in `$tDur s." -ForegroundColor Green
                powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$QueueScript" -Action CompleteTask -WorkerId ${wId} -TaskId "`$($taskObj.TaskId)" -Summary "Erfolgreich in `$tDur s" | Out-Null
            } else {
                Write-Warning " [FEHLER] Aufgabe `$($taskObj.TaskId) beendet mit ExitCode `$tExit."
                `$overallExitCode = `$tExit
            }
            `$tasksProcessed++
            continue
        }

        if (`$taskObj -and `$taskObj.Status -eq "ALL_COMPLETED") {
            Write-Host "`n[FERTIG] Alle Aufgaben in der Queue wurden erfolgreich abgeschlossen!" -ForegroundColor Green
            break
        }

        # Falls noch Tasks fuer andere Worker laufen oder pending sind
        Write-Host -NoNewline "`r[Wartend] Keine offene Aufgabe fuer Worker ${wId}. Warte 5s...  "
        Start-Sleep -Seconds 5

        # Abbrechen wenn global nichts mehr offen ist
        `$qStatusRaw = powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$QueueScript" -Action Status -Json 2>&1
        try {
            `$qStatus = `$qStatusRaw | ConvertFrom-Json
            if (`$qStatus.Pending -eq 0 -and `$qStatus.InProgress -eq 0) {
                Write-Host "`n[FERTIG] Keine offenen Aufgaben mehr in der Queue." -ForegroundColor Green
                break
            }
        } catch {}
    }
} else {
    # Fallback Einzellauf
    `$promptContent = Get-Content -Path "$promptFile" -Raw
    cmd.exe /c "opencode run --auto -m $($worker.Model) `"`$promptContent`" < NUL 2>&1"
    `$overallExitCode = `$LASTEXITCODE
    `$tasksProcessed = 1
}

`$HeartbeatTimer.Stop()
Unregister-Event -SourceIdentifier "Heartbeat_${wId}" -ErrorAction SilentlyContinue

`$totalDuration = [Math]::Round(((Get-Date) - `$startTime).TotalSeconds, 1)

# Status schreiben
`$statusObj = [PSCustomObject]@{
    WorkerId = $wId
    ExitCode = `$overallExitCode
    TasksProcessed = `$tasksProcessed
    DurationSeconds = `$totalDuration
    CompletedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}
`$statusObj | ConvertTo-Json | Set-Content -Path "$statusFile" -Force

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
if (`$overallExitCode -eq 0) {
    Write-Host " [STATUS] Worker $wId abgeschlossen (`$tasksProcessed Aufgaben) in `$totalDuration s." -ForegroundColor Green
} else {
    Write-Host " [STATUS] Worker $wId beendet mit Fehlern (ExitCode `$overallExitCode) in `$totalDuration s." -ForegroundColor Red
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 10-Minuten Auto-Close Countdown
Write-Host "Dieses Fenster schliesst automatisch in $AutoCloseMinutes Minuten ($AutoCloseSeconds s)." -ForegroundColor Gray
Write-Host "Druecke eine beliebige Taste, um das Fenster dauerhaft offen zu halten..." -ForegroundColor Yellow
Write-Host ""

`$remaining = $AutoCloseSeconds
while (`$remaining -gt 0) {
    if ([Console]::KeyAvailable) {
        `$null = [Console]::ReadKey(`$true)
        Write-Host "`nAuto-Close abgebrochen. Fenster bleibt geoeffnet. Druecke Enter zum Beenden." -ForegroundColor Green
        `$null = Read-Host
        exit `$overallExitCode
    }
    `$mins = [Math]::Floor(`$remaining / 60)
    `$secs = `$remaining % 60
    Write-Host -NoNewline "`rAuto-Close in: {0:D2}:{1:D2}  " -f `$mins, `$secs
    Start-Sleep -Seconds 1
    `$remaining--
}

Write-Host "`nTimeout erreicht. Fenster schliesst automatisch." -ForegroundColor Gray
exit `$overallExitCode
"@

    [System.IO.File]::WriteAllText($runnerFile, $runnerScript, [System.Text.Encoding]::UTF8)
    $RunnerPaths += $runnerFile
}

# 7. Launcher-Batch generieren & Fenster auf dem Desktop oeffnen
Write-Host "[Grid-Launch] Starte $($WorkerPool.Count) Worker-Fenster fuer $($TasksList.Count) Aufgaben auf dem Desktop..." -ForegroundColor Cyan

$BatchLauncher = Join-Path $ScratchDir "launch_grid.cmd"
$BatchLines = @("@echo off")
foreach ($rPath in $RunnerPaths) {
    $BatchLines += "start `"OpenCode Worker`" powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$rPath`""
}
[System.IO.File]::WriteAllLines($BatchLauncher, $BatchLines, [System.Text.Encoding]::UTF8)

# Batch asynchron ausfuehren
Start-Process "cmd.exe" -ArgumentList "/c", "`"$BatchLauncher`""

# 8. 30-Sekunden Leichtgewichtiger Watchdog
Write-Host "[Watchdog] Warte 30 Sekunden auf Prozess-Initialisierung & Heartbeat..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

$AllPids = @()
$HealthyCount = 0

foreach ($worker in $WorkerPool) {
    $wId = $worker.WorkerId
    $pidFile = Join-Path $ScratchDir "worker_${wId}.pid"
    $heartbeatFile = Join-Path $ScratchDir "heartbeat_${wId}.txt"

    if (Test-Path -Path $pidFile) {
        $workerPid = (Get-Content -Path $pidFile -Raw).Trim()
        $proc = Get-Process -Id $workerPid -ErrorAction SilentlyContinue
        if ($proc) {
            $AllPids += [int]$workerPid
            $lastBeat = ""
            if (Test-Path -Path $heartbeatFile) {
                $lastBeat = (Get-Content -Path $heartbeatFile -Raw).Trim()
            }
            Write-Host "  [OK] Worker $wId (PID $workerPid, Modell $($worker.Model)): laeuft aktiv. Heartbeat: $lastBeat" -ForegroundColor Green
            $HealthyCount++
        } else {
            Write-Warning "  [FAIL] Worker $wId (PID $workerPid): Prozess nicht mehr aktiv!"
        }
    } else {
        Write-Warning "  [WARN] Worker ${wId}: Kein PID-File gefunden."
    }
}

# Grid-Zustand persistieren
$GridState = [PSCustomObject]@{
    StartedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Pids = $AllPids
    Workers = $WorkerPool
}
$GridState | ConvertTo-Json | Set-Content -Path $ActiveGridFile -Force

Write-Host ""
Write-Host "[Grid-Status] $HealthyCount von $($WorkerPool.Count) Worker-Fenstern laufen stabil." -ForegroundColor Green
Write-Host "Session gesichert. Kacheln schliessen nach Fertigstellung und 10 Minuten Inaktivitaet automatisch." -ForegroundColor Gray
