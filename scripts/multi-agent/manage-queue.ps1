<#
.SYNOPSIS
    Kanonischer Queue-Manager fuer autonome Multi-Agenten-Workflows in Antigravity und OpenCode.
.DESCRIPTION
    Verwaltet die zentrale Aufgaben-Queue unter C:\Users\roger\.gemini\scratch\queue\tasks.json.
    Ermoeglicht atomares Ziehen (NextTask), Abschliessen (CompleteTask), Hinzufuegen (AddTask),
    Skill-Luecken-Logging (LogGap), Session-Registrierung (RegisterWorker), direktes GUI-Wecken
    (WakeWorker via agentapi und Signal-Datei) und Massen-Wecken (WakeAll).
    Ausnahmslos Standard-ASCII-Minuszeichen (-) verwenden.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Init", "AddTask", "NextTask", "CompleteTask", "Status", "Reset", "LogGap", "WakeWorker", "WaitForWake", "RegisterWorker", "WakeAll", "Reconcile", "SpawnWorker", "SpawnWorkers", "SpawnSubManager", "SpawnManager", "SpawnGeneral", "CheckHealth", "AutoCompact", "AutoRespawn", "SendMessage", "CleanScratch")]
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
    [string]$Responsibilities = "",

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
    [string]$ConversationId = "",

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceDir = "",

    [Parameter(Mandatory = $false)]
    [string]$Project = "",

    [Parameter(Mandatory = $false)]
    [string]$ManagerConvId = "",

    [Parameter(Mandatory = $false)]
    [int]$MaxWorkers = 10,

    [Parameter(Mandatory = $false)]
    [int]$Count = 2,

    [Parameter(Mandatory = $false)]
    [int]$Generation = 1,

    [Parameter(Mandatory = $false)]
    [string]$To = "",

    [Parameter(Mandatory = $false)]
    [string]$From = "",

    [Parameter(Mandatory = $false)]
    [string]$Message = "",

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# Dynamische Namespace-Isolierung pro Projekt (fuer parallele Manager ueber mehrere Repos)
$wsPath = if ($WorkspaceDir -ne "") { $WorkspaceDir } else { (Get-Location).Path }
$projectSlug = if ($Project -ne "") { $Project } else { (Split-Path -Leaf $wsPath) }
if ([string]::IsNullOrWhiteSpace($projectSlug)) { $projectSlug = "default" }

$BaseQueueDir = "C:\Users\roger\.gemini\scratch\queue"
$QueueDir = Join-Path $BaseQueueDir $projectSlug
if (-not (Test-Path -Path $QueueDir)) {
    New-Item -ItemType Directory -Path $QueueDir -Force | Out-Null
}

$TasksFile = Join-Path $QueueDir "tasks.json"
$GapsFile = Join-Path $QueueDir "skill_gaps.json"

# Abwaertskompatibilitaet: Falls Legacy-Queue im Root existiert, aber noch nicht im Projekt-Ordner, migrieren
if (-not (Test-Path -Path $TasksFile) -and (Test-Path -Path (Join-Path $BaseQueueDir "tasks.json"))) {
    Copy-Item -Path (Join-Path $BaseQueueDir "tasks.json") -Destination $TasksFile -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $BaseQueueDir -Filter "worker_*_session.json" -File | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $QueueDir -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path (Join-Path $BaseQueueDir "skill_gaps.json")) {
        Copy-Item -Path (Join-Path $BaseQueueDir "skill_gaps.json") -Destination $GapsFile -Force -ErrorAction SilentlyContinue
    }
}

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

        # Cleanup existing active markers & wake signals
        Get-ChildItem -Path $QueueDir -Filter "worker_*_active.json" -File | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $QueueDir -Filter "worker_*.wake" -File | Remove-Item -Force -ErrorAction SilentlyContinue

        $res = [PSCustomObject]@{
            Action = "Init"
            TaskCount = $normalized.Count
            Status = "OK"
            QueuePath = $TasksFile
        }
        if ($Json) { $res | ConvertTo-Json } else { Write-Host "[Queue-Init] $normalized.Count Aufgaben erfolgreich geladen in $TasksFile" -ForegroundColor Green }
    }

    "RegisterWorker" {
        if ($WorkerId -le 0 -or [string]::IsNullOrWhiteSpace($ConversationId)) {
            throw "WorkerId und ConversationId erforderlich fuer RegisterWorker."
        }
        $sessionFile = Join-Path $QueueDir "worker_${WorkerId}_session.json"
        $sessObj = [PSCustomObject]@{
            WorkerId = $WorkerId
            Role = $Role
            ConversationId = $ConversationId
            ParentManagerId = $ManagerConvId
            RegisteredAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        $jsonSess = $sessObj | ConvertTo-Json
        [System.IO.File]::WriteAllText($sessionFile, $jsonSess, [System.Text.Encoding]::UTF8)

        # Falls es sich um einen Untermanager handelt (Role gesetzt und keine Worker-Endung):
        if ($Role -ne "" -and $Role -notmatch "worker") {
            $safeRole = ($Role.ToLower() -replace '[^a-z0-9_\-]', '_')
            $smFile = Join-Path $QueueDir "submanager_${safeRole}_session.json"
            [System.IO.File]::WriteAllText($smFile, $jsonSess, [System.Text.Encoding]::UTF8)
        }
        if ($Json) { $sessObj | ConvertTo-Json } else { Write-Host "[Queue-Session] $Role (ID $WorkerId) registriert mit ConversationId: $ConversationId" -ForegroundColor Green }
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

        # Weck-Signal automatisch an Worker senden
        if ($WorkerId -gt 0) {
            $wakeScript = $PSCommandPath
            if (Test-Path -Path $wakeScript) {
                powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$wakeScript" -Action WakeWorker -WorkerId $WorkerId | Out-Null
            }
        }

        $res = [PSCustomObject]@{
            Action = "AddTask"
            TaskId = $tId
            WorkerId = $WorkerId
            Title = $Title
            Status = "pending"
        }
        if ($Json) { $res | ConvertTo-Json } else { Write-Host "[Queue-AddTask] Aufgabe $tId fuer Worker $WorkerId hinzugefuegt: $Title (Weckruf ausgeloest)" -ForegroundColor Green }
    }

    "WakeWorker" {
        if ($WorkerId -le 0) { throw "WorkerId erforderlich fuer WakeWorker." }

        # Direktes Wecken via agentapi send-message (fuer native GUI-Fenster)
        $sessionFile = Join-Path $QueueDir "worker_${WorkerId}_session.json"
        $apiSuccess = $false
        $targetConvId = ""
        if (Test-Path -Path $sessionFile) {
            try {
                $sess = Get-Content -Path $sessionFile -Raw | ConvertFrom-Json
                $targetConvId = $sess.ConversationId
                $agentApi = "C:\Users\roger\.gemini\antigravity\bin\agentapi.bat"
                if (Test-Path -Path $agentApi) {
                    $msgText = "[$projectSlug] Weckruf vom Manager: Neue Aufgaben in der Queue bereit. Bitte manage-queue.ps1 -Action NextTask ausfuehren."
                    $null = cmd.exe /c "`"$agentApi`" send-message --title=`"[$projectSlug] Weckruf vom Manager`" `"$targetConvId`" `"$msgText`" 2>&1"
                    if ($LASTEXITCODE -eq 0) {
                        $apiSuccess = $true
                    }
                }
            } catch {
                Write-Warning "[Queue-Wake] agentapi send-message Fehler: $_"
            }
        }

        $res = [PSCustomObject]@{
            Success = $true
            WorkerId = $WorkerId
            Action = "WakeWorker"
            Project = $projectSlug
            ConversationId = $targetConvId
            AgentApiDelivered = $apiSuccess
        }
        if ($Json) { $res | ConvertTo-Json }
        else {
            if ($apiSuccess) {
                Write-Host "[Queue-Wake] [$projectSlug] Worker $WorkerId via agentapi direkt im GUI-Fenster aufgeweckt ($targetConvId)." -ForegroundColor Green
            } else {
                Write-Host "[Queue-Wake] [$projectSlug] Signal-Datei fuer Worker $WorkerId gesetzt ($wakeFile)." -ForegroundColor Yellow
            }
        }
    }

    "Reconcile" {
        $reconcileScript = Join-Path $PSScriptRoot "reconcile-workers.py"
        if (-not (Test-Path -Path $reconcileScript)) {
            throw "reconcile-workers.py nicht gefunden unter: $reconcileScript"
        }
        $ws = if ($WorkspaceDir -ne "") { $WorkspaceDir } else { (Get-Location).Path }
        $cmdArgs = @("`"$reconcileScript`"", "--workspace", "`"$ws`"", "--queue-dir", "`"$QueueDir`"", "--max-workers", "$MaxWorkers")
        if ($ManagerConvId -ne "") {
            $cmdArgs += @("--manager-id", "`"$ManagerConvId`"")
        }
        if ($Json) {
            $cmdArgs += "--json"
            $output = & python $cmdArgs
            $output
        } else {
            & python $cmdArgs
        }
    }

    "SpawnWorker" {
        $spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
        if (-not (Test-Path -Path $spawnScript)) {
            throw "spawn-agent.py nicht gefunden unter: $spawnScript"
        }
        $wId = if ($WorkerId -gt 0) { $WorkerId } else { 1 }
        $r = if ($Role -ne "") { $Role } else { "Worker" }
        $d = if ($Domain -ne "") { $Domain } else { "src/" }
        $parent = if ($ManagerConvId -ne "") { $ManagerConvId } else { "0" }
        $argsList = @("`"$spawnScript`"", "--type", "worker", "--worker-id", "$wId", "--role", "`"$r`"", "--domain", "`"$d`"", "--parent-manager-id", "`"$parent`"", "--generation", "$Generation", "--workspace", "`"$wsPath`"", "--project", "`"$projectSlug`"")
        if ($Json) { $argsList += "--json" }
        & python $argsList
    }

    "SpawnWorkers" {
        $spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
        if (-not (Test-Path -Path $spawnScript)) {
            throw "spawn-agent.py nicht gefunden unter: $spawnScript"
        }
        $c = if ($Count -gt 0) { $Count } elseif ($MaxWorkers -gt 0) { $MaxWorkers } else { 2 }
        $d = if ($Domain -ne "") { $Domain } else { "src/" }
        $parent = if ($ManagerConvId -ne "") { $ManagerConvId } else { "0" }
        $argsList = @("`"$spawnScript`"", "--type", "workers", "--count", "$c", "--domain", "`"$d`"", "--parent-manager-id", "`"$parent`"", "--workspace", "`"$wsPath`"", "--project", "`"$projectSlug`"")
        if ($Json) { $argsList += "--json" }
        & python $argsList
    }

    "SpawnSubManager" {
        $spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
        if (-not (Test-Path -Path $spawnScript)) {
            throw "spawn-agent.py nicht gefunden unter: $spawnScript"
        }
        $smId = if ($WorkerId -gt 0) { $WorkerId } else { 1 }
        $r = if ($Role -ne "") { $Role } else { "Security" }
        $d = if ($Domain -ne "") { $Domain } else { "src/" }
        $parent = if ($ManagerConvId -ne "") { $ManagerConvId } else { "0" }
        $argsList = @("`"$spawnScript`"", "--type", "submanager", "--submanager-id", "$smId", "--role", "`"$r`"", "--domain", "`"$d`"", "--parent-manager-id", "`"$parent`"", "--generation", "$Generation", "--workspace", "`"$wsPath`"", "--project", "`"$projectSlug`"")
        if ($Responsibilities -ne "") { $argsList += @("--responsibilities", "`"$Responsibilities`"") }
        if ($Json) { $argsList += "--json" }
        & python $argsList
    }

    "SpawnManager" {
        $spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
        if (-not (Test-Path -Path $spawnScript)) {
            throw "spawn-agent.py nicht gefunden unter: $spawnScript"
        }
        $argsList = @("`"$spawnScript`"", "--type", "manager", "--workspace", "`"$wsPath`"", "--project", "`"$projectSlug`"", "--generation", "$Generation")
        if ($Summary -ne "") { $argsList += @("--summary", "`"$Summary`"") }
        if ($Json) { $argsList += "--json" }
        & python $argsList
    }

    "SpawnGeneral" {
        $spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
        if (-not (Test-Path -Path $spawnScript)) {
            throw "spawn-agent.py nicht gefunden unter: $spawnScript"
        }
        $argsList = @("`"$spawnScript`"", "--type", "general", "--workspace", "`"$wsPath`"", "--project", "`"$projectSlug`"")
        if ($Title -ne "") { $argsList += @("--title", "`"$Title`"") }
        if ($Summary -ne "") { $argsList += @("--summary", "`"$Summary`"") }
        if ($Description -ne "") { $argsList += @("--prompt", "`"$Description`"") }
        if ($Json) { $argsList += "--json" }
        & python $argsList
    }

    "CheckHealth" {
        $guardScript = Join-Path $PSScriptRoot "context-guard.py"
        if (-not (Test-Path -Path $guardScript)) {
            throw "context-guard.py nicht gefunden unter: $guardScript"
        }
        $targetRole = if ($Role -ne "") { $Role } elseif ($WorkerId -gt 0) { "worker" } else { "general" }
        $argsList = @("`"$guardScript`"", "check", "--role", "$targetRole")
        if ($ConversationId -ne "") { $argsList += @("--cid", "`"$ConversationId`"") }
        if ($Json) { $argsList += "--json" }
        & python $argsList
    }

    "AutoCompact" {
        $guardScript = Join-Path $PSScriptRoot "context-guard.py"
        if (-not (Test-Path -Path $guardScript)) {
            throw "context-guard.py nicht gefunden unter: $guardScript"
        }
        $cid = $ConversationId
        if ($cid -eq "" -and $WorkerId -gt 0) {
            $sf = Join-Path $QueueDir "worker_${WorkerId}_session.json"
            if (Test-Path -Path $sf) {
                $sess = Get-Content -Path $sf -Raw | ConvertFrom-Json
                $cid = $sess.ConversationId
            }
        }
        $argsList = @("`"$guardScript`"", "compact", "--cid", "`"$cid`"")
        if ($Json) { $argsList += "--json" }
        & python $argsList
    }

    "AutoRespawn" {
        $spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
        if (-not (Test-Path -Path $spawnScript)) {
            throw "spawn-agent.py nicht gefunden unter: $spawnScript"
        }
        if ($WorkerId -gt 0) {
            $sf = Join-Path $QueueDir "worker_${WorkerId}_session.json"
            $wRole = if ($Role -ne "") { $Role } else { "Worker" }
            $wDom = if ($Domain -ne "") { $Domain } else { "src/" }
            $nextGen = $Generation + 1
            if (Test-Path -Path $sf) {
                $sess = Get-Content -Path $sf -Raw | ConvertFrom-Json
                if ($sess.Role) { $wRole = $sess.Role }
                if ($sess.Domain) { $wDom = $sess.Domain }
                if ($sess.Generation) { $nextGen = [int]$sess.Generation + 1 }
            }
            $argsList = @("`"$spawnScript`"", "--type", "worker", "--worker-id", "$WorkerId", "--role", "`"$wRole`"", "--domain", "`"$wDom`"", "--generation", "$nextGen", "--workspace", "`"$wsPath`"", "--project", "`"$projectSlug`"")
            if ($Json) { $argsList += "--json" }
            & python $argsList
        } else {
            $argsList = @("`"$spawnScript`"", "--type", "manager", "--workspace", "`"$wsPath`"", "--project", "`"$projectSlug`"", "--generation", "$($Generation + 1)")
            if ($Summary -ne "") { $argsList += @("--summary", "`"$Summary`"") }
            if ($Json) { $argsList += "--json" }
            & python $argsList
        }
    }

    "SendMessage" {
        if ([string]::IsNullOrWhiteSpace($Message)) {
            throw "Message Parameter darf nicht leer sein fuer SendMessage."
        }
        $targetTo = if ($To -ne "") { $To } elseif ($WorkerId -gt 0) { "$WorkerId" } else { "Manager" }
        $sender = if ($From -ne "") { $From } else { "Agent" }
        $agentApi = "C:\Users\roger\.gemini\antigravity\bin\agentapi.bat"
        if (-not (Test-Path -Path $agentApi)) {
            throw "agentapi.bat nicht gefunden unter: $agentApi"
        }

        $targetCids = @()

        if ($targetTo -match "^(?i)manager|ceo|lead$") {
            # Manager-Session suchen
            $mgrFile = Join-Path $QueueDir "manager_session.json"
            if (Test-Path -Path $mgrFile) {
                try {
                    $sess = Get-Content -Path $mgrFile -Raw | ConvertFrom-Json
                    if ($sess.ConversationId) { $targetCids += $sess.ConversationId }
                } catch {}
            }
            if ($targetCids.Count -eq 0 -and $ManagerConvId -ne "") {
                $targetCids += $ManagerConvId
            }
        }
        elseif ($targetTo -match "^(?i)all|broadcast|workers$") {
            # Alle Worker-Sessions suchen
            $sFiles = Get-ChildItem -Path $QueueDir -Filter "worker_*_session.json" -File
            foreach ($sf in $sFiles) {
                try {
                    $sess = Get-Content -Path $sf.FullName -Raw | ConvertFrom-Json
                    if ($sess.ConversationId) { $targetCids += $sess.ConversationId }
                } catch {}
            }
        }
        elseif ($targetTo -match "^[0-9]+$") {
            # Worker ID
            $wId = [int]$targetTo
            $wFile = Join-Path $QueueDir "worker_${wId}_session.json"
            if (Test-Path -Path $wFile) {
                try {
                    $sess = Get-Content -Path $wFile -Raw | ConvertFrom-Json
                    if ($sess.ConversationId) { $targetCids += $sess.ConversationId }
                } catch {}
            }
        }
        elseif ($targetTo -match "^[A-Za-z0-9_-]{1,64}$") {
            # Direkt gegebene ConversationId
            $targetCids += $targetTo
        }

        if ($targetCids.Count -eq 0) {
            $errRes = [PSCustomObject]@{
                Success = $false
                Action = "SendMessage"
                To = $targetTo
                Error = "Keine ConversationId fuer Ziel '$targetTo' gefunden."
            }
            if ($Json) { $errRes | ConvertTo-Json; exit 0 }
            else { throw "Keine ConversationId fuer Ziel '$targetTo' in $QueueDir gefunden." }
        }

        $sentCount = 0
        $deliveredTo = @()
        $msgPayload = "[$projectSlug] Nachricht von $($sender): $Message"
        foreach ($cid in $targetCids) {
            $null = cmd.exe /c "`"$agentApi`" send-message --title=`"[$projectSlug] $sender`" `"$cid`" `"$msgPayload`" 2>&1"
            if ($LASTEXITCODE -eq 0) {
                $sentCount++
                $deliveredTo += $cid
            }
        }

        $res = [PSCustomObject]@{
            Success = ($sentCount -gt 0)
            Action = "SendMessage"
            Project = $projectSlug
            From = $sender
            To = $targetTo
            DeliveredCount = $sentCount
            Recipients = $deliveredTo
        }
        if ($Json) { $res | ConvertTo-Json }
        else {
            Write-Host "[Queue-Message] Nachricht von '$sender' an '$targetTo' erfolgreich zugestellt ($sentCount Empfaenger)." -ForegroundColor Green
        }
    }

    "CleanScratch" {
        $legacyPatterns = @("*.wake", "*.md", "*_done.json", "*_active.json")
        $deletedFiles = @()
        foreach ($pattern in $legacyPatterns) {
            $found = Get-ChildItem -Path $QueueDir -Filter $pattern -File -ErrorAction SilentlyContinue
            foreach ($f in $found) {
                Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
                $deletedFiles += $f.Name
            }
        }
        $res = [PSCustomObject]@{
            Action = "CleanScratch"
            Project = $projectSlug
            QueueDir = $QueueDir
            DeletedCount = $deletedFiles.Count
            DeletedFiles = $deletedFiles
        }
        if ($Json) { $res | ConvertTo-Json }
        else {
            Write-Host "[Queue-Clean] $QueueDir bereinigt: $($deletedFiles.Count) temporaere Dateien entfernt." -ForegroundColor Green
        }
    }

    "WakeAll" {
        # 1. Vor dem Wecken automatisch aktive Worker im Workspace abgleichen (Auto-Discovery)
        $reconcileScript = Join-Path $PSScriptRoot "reconcile-workers.py"
        if (Test-Path -Path $reconcileScript) {
            $ws = if ($WorkspaceDir -ne "") { $WorkspaceDir } else { (Get-Location).Path }
            $recArgs = @("`"$reconcileScript`"", "--workspace", "`"$ws`"", "--queue-dir", "`"$QueueDir`"", "--max-workers", "$MaxWorkers")
            if ($ManagerConvId -ne "") { $recArgs += @("--manager-id", "`"$ManagerConvId`"") }
            try {
                $null = & python $recArgs
            } catch {}
        }

        # 2. Alle aktuell zugeordneten Worker wecken
        $sessionFiles = Get-ChildItem -Path $QueueDir -Filter "worker_*_session.json" -File
        $wokenCount = 0
        $agentApi = "C:\Users\roger\.gemini\antigravity\bin\agentapi.bat"
        foreach ($sf in $sessionFiles) {
            try {
                $sess = Get-Content -Path $sf.FullName -Raw | ConvertFrom-Json
                $wId = [int]$sess.WorkerId
                $convId = [string]$sess.ConversationId
                $wTitle = if ($sess.Title) { $sess.Title } else { "Worker $wId" }
                if ($wId -gt 0) {
                    # agentapi Nachricht direkt ins GUI-Fenster
                    if ($convId -ne "" -and (Test-Path -Path $agentApi)) {
                        $msgText = "[$projectSlug] Weckruf vom Manager: Weiterarbeiten! Bitte manage-queue.ps1 -Action NextTask ausfuehren."
                        $null = cmd.exe /c "`"$agentApi`" send-message --title=`"[$projectSlug] Weckruf vom Manager`" `"$convId`" `"$msgText`" 2>&1"
                    }
                    $wokenCount++
                }
            } catch {}
        }
        if ($Json) { @{ Action = "WakeAll"; Project = $projectSlug; WorkersWoken = $wokenCount } | ConvertTo-Json }
        else { Write-Host "[Queue-Wake] [$projectSlug] Alle $wokenCount zugeordneten Worker wurden erfolgreich aufgeweckt." -ForegroundColor Green }
    }

    "WaitForWake" {
        if ($WorkerId -le 0) { throw "WorkerId erforderlich fuer WaitForWake." }
        $res = [PSCustomObject]@{
            Action = "WaitForWake"
            WorkerId = $WorkerId
            Project = $projectSlug
            Status = "WAITING"
            Message = "Worker wartet auf CLI-Weckruf des Managers via agentapi."
        }
        if ($Json) { $res | ConvertTo-Json }
        else { Write-Host "[Queue-Wait] Worker $WorkerId pausiert (Wartet auf CLI-Weckruf des Managers via agentapi)." -ForegroundColor Cyan }
    }

    "NextTask" {
        if ($WorkerId -le 0) {
            throw "WorkerId muss groesser als 0 sein fuer NextTask."
        }

        # Context-Guard Health Check fuer Worker
        $guardScript = Join-Path $PSScriptRoot "context-guard.py"
        $sessionFile = Join-Path $QueueDir "worker_${WorkerId}_session.json"
        if ((Test-Path -Path $guardScript) -and (Test-Path -Path $sessionFile)) {
            try {
                $sess = Get-Content -Path $sessionFile -Raw | ConvertFrom-Json
                $cid = [string]$sess.ConversationId
                $gen = if ($sess.Generation) { [int]$sess.Generation } else { 1 }
                $wRole = if ($sess.Role) { [string]$sess.Role } else { "Worker" }
                $wDom = if ($sess.Domain) { [string]$sess.Domain } else { "src/" }

                if ($cid -ne "") {
                    $healthRaw = & python "`"$guardScript`"" check --cid "$cid" --role worker --json 2>$null
                    if ($healthRaw) {
                        $health = $healthRaw | ConvertFrom-Json
                        if ($health.level -eq "spawn_recommended") {
                            # Stufe 2 erreicht: Auto-Respawn der naechsten Generation
                            $nextGen = $gen + 1
                            $spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
                            Write-Host "[Context-Guard] Worker $WorkerId hat Kontext-Limit erreicht (Steps: $($health.totalSteps)). Spawne Generation $nextGen..." -ForegroundColor Magenta
                            $spawnRes = & python "`"$spawnScript`"" --type worker --worker-id $WorkerId --role "$wRole" --domain "$wDom" --generation $nextGen --workspace "$wsPath" --project "$projectSlug" --json 2>$null

                            $res = [PSCustomObject]@{
                                Found = $false
                                WorkerId = $WorkerId
                                Status = "RESPAWNED_NEW_GENERATION"
                                Generation = $nextGen
                                Message = "Generation $nextGen erfolgreich gespawnt. Dieser alte Worker-Chat beendet sich nun."
                            }
                            if ($Json) { $res | ConvertTo-Json; exit 0 }
                            else {
                                Write-Host "[Context-Guard] Generation $nextGen gespawnt. Dieser Worker-Chat beendet sich nun." -ForegroundColor Yellow
                                exit 0
                            }
                        }
                        elseif ($health.level -eq "compact_recommended") {
                            # Stufe 1 erreicht: Einmalig /compact anfordern
                            Write-Host "[Context-Guard] Worker $WorkerId hat Stufe 1 erreicht. Sende /compact und pausiere 10s..." -ForegroundColor Cyan
                            $null = & python "`"$guardScript`"" compact --cid "$cid"
                            Start-Sleep -Seconds 10
                        }
                    }
                }
            } catch {
                # Bei Fehlern im Guard-Check nicht abbrechen, normal weiterarbeiten
            }
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

        if ($foundTask) {
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

            $activeFile = Join-Path $QueueDir "worker_${WorkerId}_active.json"
            if (Test-Path -Path $activeFile) {
                $activeFile = Join-Path $QueueDir "worker_${WorkerId}_active.json"
            if (Test-Path -Path $activeFile) {
                $activeFile = Join-Path $QueueDir "worker_${WorkerId}_active.json"
            if (Test-Path -Path $activeFile) {
                Remove-Item -Path $activeFile -Force -ErrorAction SilentlyContinue
            }
            }
            }

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

    "LogGap" {
        $gaps = @()
        if (Test-Path -Path $GapsFile) {
            try {
                $raw = [System.IO.File]::ReadAllText($GapsFile, [System.Text.Encoding]::UTF8)
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $gaps = @($raw | ConvertFrom-Json)
                }
            } catch {}
        }
        $newGap = [PSCustomObject]@{
            WorkerId = $WorkerId
            TaskId = $TaskId
            SuggestedSkill = if ($GapSkill -ne "") { $GapSkill } else { "Unbenannter Skill" }
            Reason = $GapReason
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        $gaps += $newGap
        $jsonGaps = $gaps | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($GapsFile, $jsonGaps, [System.Text.Encoding]::UTF8)
        if ($Json) { $newGap | ConvertTo-Json } else { Write-Host "[Skill-Gap] Vorschlag fuer '$($newGap.SuggestedSkill)' protokolliert: $GapReason" -ForegroundColor Cyan }
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

        # Skill-Gaps laden
        $gapsList = @()
        if (Test-Path -Path $GapsFile) {
            try {
                $rawGaps = [System.IO.File]::ReadAllText($GapsFile, [System.Text.Encoding]::UTF8)
                if (-not [string]::IsNullOrWhiteSpace($rawGaps)) {
                    $gapsList = @($rawGaps | ConvertFrom-Json)
                }
            } catch {}
        }

        # Registrierte Sessions laden
        $sessionFiles = Get-ChildItem -Path $QueueDir -Filter "worker_*_session.json" -File
        $sessions = @()
        foreach ($sf in $sessionFiles) {
            try {
                $sessions += (Get-Content -Path $sf.FullName -Raw | ConvertFrom-Json)
            } catch {}
        }

        $res = [PSCustomObject]@{
            Project = $projectSlug
            QueueDir = $QueueDir
            Total = $total
            Pending = $pending
            InProgress = $inProgress
            Completed = $completed
            Failed = $failed
            AllCompleted = ($total -gt 0 -and $completed -eq $total)
            Workers = $workerStatusList
            SkillGaps = $gapsList
            RegisteredSessions = $sessions
        }

        if ($Json) {
            $res | ConvertTo-Json -Depth 5
        } else {
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host " QUEUE STATUS [$projectSlug] | Gesamt: $total | Offen: $pending | In Arbeit: $inProgress | Fertig: $completed" -ForegroundColor Yellow
            Write-Host "============================================================" -ForegroundColor Cyan
            foreach ($ws in $workerStatusList) {
                Write-Host " Worker $($ws.WorkerId): Aktuell -> $($ws.ActiveTask) | Fertig: $($ws.CompletedCount)/$($ws.TotalCount)" -ForegroundColor Gray
            }
            if ($sessions.Count -gt 0) {
                Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
                Write-Host " [SESSIONS] $($sessions.Count) GUI-Worker aktiv (auto-reconciled & persistent):" -ForegroundColor Green
                foreach ($s in $sessions) {
                    $matched = if ($s.MatchedBy) { "via $($s.MatchedBy)" } else { "manuell" }
                    $tit = if ($s.Title) { "'$($s.Title)' " } else { "" }
                    Write-Host "  - Worker $($s.WorkerId): $tit($($s.ConversationId)) [$matched]" -ForegroundColor Gray
                }
            }
            if ($gapsList.Count -gt 0) {
                Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
                Write-Host " [SKILL-GAPS] $($gapsList.Count) Optimierungsvorschlaege erfasst:" -ForegroundColor Magenta
                foreach ($g in $gapsList | Select-Object -Last 3) {
                    Write-Host "  - $($g.SuggestedSkill): $($g.Reason)" -ForegroundColor Gray
                }
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
        Get-ChildItem -Path $QueueDir -Filter "worker_*.wake" -File | Remove-Item -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $GapsFile -Force -ErrorAction SilentlyContinue
        Write-Host "[Queue-Reset] Alle Aufgaben auf 'pending' zurueckgesetzt, Weck-Signale und Gaps bereinigt." -ForegroundColor Green
    }
}
