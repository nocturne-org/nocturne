<#
.SYNOPSIS
    Kanonischer Queue-Manager fuer autonome Multi-Agenten-Workflows in Antigravity und OpenCode.
.DESCRIPTION
    Verwaltet die zentrale Aufgaben-Queue unter C:\Users\roger\.gemini\scratch\queue\tasks.json.
    Ermoeglicht atomares Ziehen (NextTask), Abschliessen (CompleteTask), Hinzufuegen (AddTask)
    und Statusabfragen (Status) fuer beliebig viele parallele Worker.
    Ausnahmslos Standard-ASCII-Minuszeichen (-) verwenden.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Init", "AddTask", "NextTask", "CompleteTask", "Status", "Reset")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [int]$WorkerId = 0,

    [Parameter(Mandatory = $false)]
    [string]$TaskId = "",

    [Parameter(Mandatory = $false)]
    [string]$Role = "",

    [Parameter(Mandatory = $false)]
    [string]$Domain = "",

    [Parameter(Mandatory = $false)]
    [string[]]$TargetFiles = @(),

    [Parameter(Mandatory = $false)]
    [string]$Title = "",

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [string]$TasksJson = "",

    [Parameter(Mandatory = $false)]
    [string]$Summary = "",

    [Parameter(Mandatory = $false)]
    [string]$GapSkill = "",

    [Parameter(Mandatory = $false)]
    [string]$GapReason = "",

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$QueueDir = "C:\Users\roger\.gemini\scratch\queue"
if (-not (Test-Path -Path $QueueDir)) {
    New-Item -ItemType Directory -Path $QueueDir -Force | Out-Null
}

$TasksFile = Join-Path $QueueDir "tasks.json"

function Load-Tasks {
    $retry = 0
    while ($retry -lt 10) {
        try {
            if (Test-Path -Path $TasksFile) {
                $raw = [System.IO.File]::ReadAllText($TasksFile, [System.Text.Encoding]::UTF8)
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $parsed = $raw | ConvertFrom-Json
                    return @($parsed)
                }
            }
            return @()
        } catch {
            $retry++
            Start-Sleep -Milliseconds (Get-Random -Minimum 40 -Maximum 120)
        }
    }
    return @()
}

function Save-Tasks($tasksList) {
    $arr = @($tasksList)
    $json = $arr | ConvertTo-Json -Depth 10
    $tmpFile = "$TasksFile.tmp.$PID.$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    $retry = 0
    while ($retry -lt 10) {
        try {
            [System.IO.File]::WriteAllText($tmpFile, $json, [System.Text.Encoding]::UTF8)
            Move-Item -Path $tmpFile -Destination $TasksFile -Force
            return
        } catch {
            $retry++
            Start-Sleep -Milliseconds (Get-Random -Minimum 40 -Maximum 120)
        }
    }
    if (Test-Path -Path $tmpFile) {
        Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

switch ($Action) {
    "Init" {
        $initialTasks = @()
        if ($TasksJson -ne "" -and (Test-Path -Path $TasksJson)) {
            $raw = [System.IO.File]::ReadAllText($TasksJson, [System.Text.Encoding]::UTF8)
            $initialTasks = ($raw | ConvertFrom-Json)
        } elseif ($TasksJson -ne "") {
            $initialTasks = ($TasksJson | ConvertFrom-Json)
        }

        # Normalize schema
        $normalized = @()
        $idx = 1
        foreach ($t in $initialTasks) {
            $tId = if ($t.TaskId) { [string]$t.TaskId } elseif ($t.id) { [string]$t.id } else { "TASK-$idx" }
            $wId = if ($t.WorkerId) { [int]$t.WorkerId } else { 0 }
            $r = if ($t.Role) { [string]$t.Role } else { "Worker" }
            $d = if ($t.Domain) { [string]$t.Domain } else { "src/" }
            $f = if ($t.TargetFiles) { @($t.TargetFiles) } elseif ($t.files) { @($t.files) } else { @() }
            $tit = if ($t.Title) { [string]$t.Title } elseif ($t.title) { [string]$t.title } else { "Task $idx" }
            $desc = if ($t.Description) { [string]$t.Description } elseif ($t.description) { [string]$t.description } else { "" }
            $st = if ($t.Status) { [string]$t.Status } else { "pending" }

            $normalized += [PSCustomObject]@{
                TaskId = $tId
                WorkerId = $wId
                Role = $r
                Domain = $d
                TargetFiles = $f
                Title = $tit
                Description = $desc
                Status = $st
                AssignedAt = $null
                CompletedAt = $null
                Summary = ""
            }
            $idx++
        }

        Save-Tasks $normalized

        # Cleanup existing active markers
        Get-ChildItem -Path $QueueDir -Filter "worker_*_active.json" -File | Remove-Item -Force -ErrorAction SilentlyContinue

        $res = [PSCustomObject]@{
            Action = "Init"
            TaskCount = $normalized.Count
            Status = "OK"
            QueuePath = $TasksFile
        }
        if ($Json) { $res | ConvertTo-Json } else { Write-Host "[Queue-Init] $normalized.Count Aufgaben erfolgreich geladen in $TasksFile" -ForegroundColor Green }
    }

    "AddTask" {
        $tasks = @(Load-Tasks)
        $tId = if ($TaskId -ne "") { $TaskId } else { "TASK-$($tasks.Count + 1)" }

        $newTask = [PSCustomObject]@{
            TaskId = $tId
            WorkerId = $WorkerId
            Role = $Role
            Domain = $Domain
            TargetFiles = @($TargetFiles)
            Title = $Title
            Description = $Description
            Status = "pending"
            AssignedAt = $null
            CompletedAt = $null
            Summary = ""
        }

        $tasks += $newTask
        Save-Tasks $tasks

        $res = [PSCustomObject]@{
            Action = "AddTask"
            TaskId = $tId
            WorkerId = $WorkerId
            Title = $Title
            Status = "pending"
        }
        if ($Json) { $res | ConvertTo-Json } else { Write-Host "[Queue-AddTask] Aufgabe $tId fuer Worker $WorkerId hinzugefuegt: $Title" -ForegroundColor Green }
    }

    "NextTask" {
        if ($WorkerId -le 0) {
            throw "WorkerId muss groesser als 0 sein fuer NextTask."
        }

        $tasks = @(Load-Tasks)
        $foundTask = $null

        # 1. Pruefe ob bereits ein Task fuer diesen Worker in_progress ist
        foreach ($t in $tasks) {
            if ($t.WorkerId -eq $WorkerId -and $t.Status -eq "in_progress") {
                $foundTask = $t
                break
            }
        }

        # 2. Wenn keiner in_progress, suche naechsten pending Task fuer diesen Worker (oder unassigned WorkerId=0)
        if ($null -eq $foundTask) {
            foreach ($t in $tasks) {
                if (($t.WorkerId -eq $WorkerId -or $t.WorkerId -eq 0) -and $t.Status -eq "pending") {
                    $t.Status = "in_progress"
                    $t.WorkerId = $WorkerId
                    $t.AssignedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    $foundTask = $t
                    Save-Tasks $tasks
                    break
                }
            }
        }

        $activeFile = Join-Path $QueueDir "worker_${WorkerId}_active.json"
        $promptMdFile = Join-Path $QueueDir "worker_${WorkerId}.md"

        if ($foundTask) {
            # Aktive Datei schreiben
            $foundTask | ConvertTo-Json -Depth 5 | Set-Content -Path $activeFile -Encoding UTF8

            # Markdown-Prompt generieren fuer direkte Anzeige / Fallback
            $filesList = ($foundTask.TargetFiles | ForEach-Object { "- $_" }) -join "`r`n"
            $mdContent = @"
Du bist Worker ${WorkerId} ($($foundTask.Role)).
Deine Zieldomaene ist strikt: $($foundTask.Domain)
Zugewiesene Dateien:
$filesList

1. ARBEITSAUFTRAG: $($foundTask.TaskId) - $($foundTask.Title)
$($foundTask.Description)

2. SICHERHEITSREGELN:
- Datei-Isolation: Modifiziere AUSNAHMSLOS NUR Dateien in deiner Zieldomaene ($($foundTask.Domain)).
- Typografie-Pflicht: Verwende ausnahmslos Standard-ASCII-Minuszeichen (-). En-Dash und Em-Dash sind verboten.
- Anti-Slop: Klarer, substanzieller Code ohne unnoetige Fuelltexte.
- Syntax-Pruefung: Validiere deinen Code vor Fertigstellung.

3. ABSCHLUSS-BEFEHL (AUTONOM):
Fuehre nach Fertigstellung aus:
powershell -File .\scripts\multi-agent\manage-queue.ps1 -Action CompleteTask -WorkerId ${WorkerId} -TaskId "$($foundTask.TaskId)" -Summary "Erledigt"
Und rufe direkt danach NextTask auf, um die naechste Aufgabe ohne Pause zu bearbeiten!
"@
            [System.IO.File]::WriteAllText($promptMdFile, $mdContent, [System.Text.Encoding]::UTF8)

            $res = [PSCustomObject]@{
                Found = $true
                TaskId = $foundTask.TaskId
                WorkerId = $WorkerId
                Role = $foundTask.Role
                Domain = $foundTask.Domain
                TargetFiles = $foundTask.TargetFiles
                Title = $foundTask.Title
                Description = $foundTask.Description
                Status = "in_progress"
            }
            if ($Json) { $res | ConvertTo-Json } else { Write-Host "[Queue-Next] Worker $WorkerId uebernimmt: $($foundTask.TaskId) - $($foundTask.Title)" -ForegroundColor Green }
        } else {
            # Keine Aufgabe direkt verfuegbar. Pruefe ob noch andere Tasks pending/in_progress sind
            $anyPending = ($tasks | Where-Object { $_.Status -in @("pending", "in_progress") }).Count
            $statusMsg = if ($anyPending -gt 0) { "WAITING_FOR_DEPENDENCY" } else { "ALL_COMPLETED" }

            Remove-Item -Path $activeFile -Force -ErrorAction SilentlyContinue

            $res = [PSCustomObject]@{
                Found = $false
                WorkerId = $WorkerId
                Status = $statusMsg
                PendingTotal = $anyPending
            }
            if ($Json) { $res | ConvertTo-Json } else { Write-Host "[Queue-Next] Keine offene Aufgabe fuer Worker $WorkerId. Status: $statusMsg (Offen: $anyPending)" -ForegroundColor Yellow }
        }
    }

    "CompleteTask" {
        if ($WorkerId -le 0 -and [string]::IsNullOrWhiteSpace($TaskId)) {
            throw "WorkerId oder TaskId erforderlich fuer CompleteTask."
        }

        $tasks = @(Load-Tasks)
        $completedTask = $null

        foreach ($t in $tasks) {
            $match = $false
            if ($TaskId -ne "" -and $t.TaskId -eq $TaskId) { $match = $true }
            elseif ($TaskId -eq "" -and $t.WorkerId -eq $WorkerId -and $t.Status -eq "in_progress") { $match = $true }

            if ($match) {
                $t.Status = "completed"
                $t.CompletedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                if ($Summary -ne "") { $t.Summary = $Summary }
                $completedTask = $t
                break
            }
        }

        if ($completedTask) {
            Save-Tasks $tasks

            # Signal-Dateien schreiben
            $doneJsonFile = Join-Path $QueueDir "worker_${WorkerId}_done.json"
            $doneMdFile = Join-Path $QueueDir "worker_${WorkerId}_done.md"
            $activeFile = Join-Path $QueueDir "worker_${WorkerId}_active.json"

            $completedTask | ConvertTo-Json -Depth 5 | Set-Content -Path $doneJsonFile -Encoding UTF8

            $mdDone = @"
# Worker ${WorkerId}: Vollzugsmeldung
- Task-ID: $($completedTask.TaskId)
- Titel: $($completedTask.Title)
- Abgeschlossen am: $($completedTask.CompletedAt)
- Zusammenfassung: $($completedTask.Summary)
"@
            [System.IO.File]::WriteAllText($doneMdFile, $mdDone, [System.Text.Encoding]::UTF8)
            Remove-Item -Path $activeFile -Force -ErrorAction SilentlyContinue

            $res = [PSCustomObject]@{
                Success = $true
                TaskId = $completedTask.TaskId
                WorkerId = $WorkerId
                Status = "completed"
                CompletedAt = $completedTask.CompletedAt
            }
            if ($Json) { $res | ConvertTo-Json } else { Write-Host "[Queue-Done] Worker $WorkerId hat $($completedTask.TaskId) abgeschlossen." -ForegroundColor Green }
        } else {
            Write-Warning "Keine passende in_progress Aufgabe fuer Worker $WorkerId / Task $TaskId gefunden."
        }
    }

    "Status" {
        $tasks = @(Load-Tasks)
        [int]$total = $tasks.Count
        [int]$pending = @($tasks | Where-Object { $_.Status -eq "pending" }).Count
        [int]$inProgress = @($tasks | Where-Object { $_.Status -eq "in_progress" }).Count
        [int]$completed = @($tasks | Where-Object { $_.Status -eq "completed" }).Count
        [int]$failed = @($tasks | Where-Object { $_.Status -eq "failed" }).Count

        # Worker-Gruppierung
        $workerGroups = $tasks | Group-Object -Property WorkerId

        $workerStatusList = @()
        foreach ($wg in $workerGroups) {
            $wId = $wg.Name
            $wTasks = @($wg.Group)
            $activeTask = $wTasks | Where-Object { $_.Status -eq "in_progress" } | Select-Object -First 1
            [int]$wCompleted = @($wTasks | Where-Object { $_.Status -eq "completed" }).Count
            [int]$wPending = @($wTasks | Where-Object { $_.Status -eq "pending" }).Count

            $workerStatusList += [PSCustomObject]@{
                WorkerId = [int]$wId
                ActiveTask = if ($activeTask) { "$($activeTask.TaskId): $($activeTask.Title)" } else { "Keine (Wartend)" }
                CompletedCount = $wCompleted
                PendingCount = $wPending
                TotalCount = $wTasks.Count
            }
        }

        $res = [PSCustomObject]@{
            Total = $total
            Pending = $pending
            InProgress = $inProgress
            Completed = $completed
            Failed = $failed
            AllCompleted = ($total -gt 0 -and $completed -eq $total)
            Workers = $workerStatusList
        }

        if ($Json) {
            $res | ConvertTo-Json -Depth 5
        } else {
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host " QUEUE STATUS | Gesamt: $total | Offen: $pending | In Arbeit: $inProgress | Fertig: $completed" -ForegroundColor Yellow
            Write-Host "============================================================" -ForegroundColor Cyan
            foreach ($ws in $workerStatusList) {
                Write-Host " Worker $($ws.WorkerId): Aktuell -> $($ws.ActiveTask) | Fertig: $($ws.CompletedCount)/$($ws.TotalCount)" -ForegroundColor Gray
            }
            Write-Host "============================================================" -ForegroundColor Cyan
        }
    }

    "Reset" {
        if (Test-Path -Path $TasksFile) {
            $tasks = @(Load-Tasks)
            foreach ($t in $tasks) {
                $t.Status = "pending"
                $t.AssignedAt = $null
                $t.CompletedAt = $null
                $t.Summary = ""
            }
            Save-Tasks $tasks
        }
        Get-ChildItem -Path $QueueDir -Filter "worker_*_active.json" -File | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $QueueDir -Filter "worker_*_done.json" -File | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "[Queue-Reset] Alle Aufgaben auf 'pending' zurueckgesetzt." -ForegroundColor Green
    }
    "LogGap" {
        $gapFile = Join-Path $QueueDir "skill_gaps.json"
        $gaps = @()
        if (Test-Path -Path $gapFile) {
            try { $gaps = @(Get-Content -Path $gapFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $gaps = @() }
        }
        $newGap = [PSCustomObject]@{
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            WorkerId = $WorkerId
            TaskId = $TaskId
            GapSkill = $GapSkill
            GapReason = $GapReason
        }
        $gaps += $newGap
        $gaps | ConvertTo-Json -Depth 5 | Set-Content -Path $gapFile -Encoding UTF8
        Write-Host "[Queue-Gap] Skill-Luecke geloggt: Worker $WorkerId | Task $TaskId | Skill $GapSkill" -ForegroundColor Yellow
    }
}
