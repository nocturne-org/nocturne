<#
.SYNOPSIS
    Initialisiert die 3-Ebenen Multi-Agenten-Hierarchie (CEO -> Untermanager -> Worker) fuer ein Projekt.
    Erzeugt die private Domain-Registry (project-domains.json) im privaten Scratch-Verzeichnis und spawnt
    auf Wunsch die Untermanager-GUI-Fenster ohne Code-Duplikate.

.DESCRIPTION
    Ausnahmslos Standard-ASCII-Minuszeichen (-) verwenden.
    Private Metadaten werden strikt ausserhalb des Repos in C:\Users\roger\.gemini\scratch\queue\<project>\ gespeichert.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceDir = "",

    [Parameter(Mandatory = $false)]
    [string]$Project = "",

    [Parameter(Mandatory = $false)]
    [string]$Context = "",

    [Parameter(Mandatory = $false)]
    [string[]]$Roles = @(),

    [Parameter(Mandatory = $false)]
    [string]$ParentManagerId = "0",

    [Parameter(Mandatory = $false)]
    [switch]$AutoSpawn,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# 1. Pfade & Projekt-Identifikation
$wsPath = if ($WorkspaceDir -ne "") { (Resolve-Path $WorkspaceDir).Path } else { (Get-Location).Path }
$projectSlug = if ($Project -ne "") { $Project } else { (Split-Path -Leaf $wsPath) }

$queueBase = "C:\Users\roger\.gemini\scratch\queue"
$projectQueueDir = Join-Path $queueBase $projectSlug
if (-not (Test-Path -Path $projectQueueDir)) {
    New-Item -ItemType Directory -Path $projectQueueDir -Force | Out-Null
}

$domainsFile = Join-Path $projectQueueDir "project-domains.json"

# 2. Bestehende Registrierung laden (Private Source of Truth)
$existingData = [PSCustomObject]@{
    project = $projectSlug
    workspace = $wsPath
    submanagers = @()
}

if (Test-Path -Path $domainsFile) {
    try {
        $raw = Get-Content -Path $domainsFile -Raw -Encoding UTF8
        $existingData = $raw | ConvertFrom-Json
    } catch {
        # Fallback falls Datei leer oder beschaedigt
        $existingData = [PSCustomObject]@{
            project = $projectSlug
            workspace = $wsPath
            submanagers = @()
        }
    }
}

# 3. Standard-Ressorts & orthogonale Zieldomaenen definieren
$canonicalPillars = @(
    [PSCustomObject]@{
        Role = "Security"
        Domain = "src/security/"
        Responsibilities = "- Authentifizierung, Autorisierung (RBAC), Secrets-Sanitization, API-Validierung, Krypto."
    },
    [PSCustomObject]@{
        Role = "IT Security"
        Domain = "infra/"
        Responsibilities = "- OS-Hardening, Least-Privilege, Host-Integritaet, Air-Gapping, Audit-Trails."
    },
    [PSCustomObject]@{
        Role = "DevOps"
        Domain = "scripts/ci/"
        Responsibilities = "- CI/CD-Pipelines, Test-Automatisierung, Linter, Build-Workflows, Docker."
    },
    [PSCustomObject]@{
        Role = "UI Frontend"
        Domain = "src/ui/"
        Responsibilities = "- Design-System, Barrierefreiheit (a11y), Komponenten-Hierarchie, User-Flows."
    }
)

# 4. Gewuenschte Rollen ermitteln
$targetPillars = @()
if ($Roles.Count -gt 0) {
    foreach ($r in $Roles) {
        $matched = $canonicalPillars | Where-Object { $_.Role.ToLower() -eq $r.Trim().ToLower() }
        if ($matched) {
            $targetPillars += $matched
        } else {
            # Individuelle Rolle dynamisch erzeugen
            $cleanName = $r.Trim()
            $slug = ($cleanName.ToLower() -replace '[^a-z0-9_\-]', '_')
            $targetPillars += [PSCustomObject]@{
                Role = $cleanName
                Domain = "src/$slug/"
                Responsibilities = "- Fachliche Zustaendigkeit fuer Domaene src/$slug/."
            }
        }
    }
} else {
    $targetPillars = $canonicalPillars
}

# 5. Deduplizierung: Pruefen welche Untermanager neu sind
$toSpawn = @()
$alreadyRegistered = @()

$registeredRoles = @($existingData.submanagers | ForEach-Object { [string]$_.role.ToLower() })

foreach ($p in $targetPillars) {
    if ($registeredRoles -contains $p.Role.ToLower()) {
        $alreadyRegistered += $p
    } else {
        $toSpawn += $p
    }
}

# 6. DryRun oder JSON Ausgabe
if ($DryRun) {
    $report = [PSCustomObject]@{
        Project = $projectSlug
        Workspace = $wsPath
        TotalTarget = $targetPillars.Count
        Existing = $alreadyRegistered
        ToSpawn = $toSpawn
        DomainsFile = $domainsFile
    }
    if ($Json) {
        $report | ConvertTo-Json -Depth 5
    } else {
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " PROJECT-INIT HIERARCHY PLAN [DRY-RUN] | $projectSlug" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "Private Registry: $domainsFile"
        Write-Host "`n[BEREITS REGISTRIERT (Keine Dubletten)]: $($alreadyRegistered.Count)" -ForegroundColor Yellow
        foreach ($ar in $alreadyRegistered) {
            Write-Host "  - $($ar.Role) -> Domaene: $($ar.Domain)" -ForegroundColor Gray
        }
        Write-Host "`n[NEU ZU SPAWNEN]: $($toSpawn.Count)" -ForegroundColor Green
        foreach ($ts in $toSpawn) {
            Write-Host "  - $($ts.Role) -> Domaene: $($ts.Domain)" -ForegroundColor Green
        }
        Write-Host "============================================================" -ForegroundColor Cyan
    }
    exit 0
}

# 7. Untermanager spawnen (falls AutoSpawn aktiv)
$spawnScript = Join-Path $PSScriptRoot "spawn-agent.py"
$spawnedList = @()
$subIdCounter = $existingData.submanagers.Count + 1

if ($AutoSpawn -and $toSpawn.Count -gt 0) {
    Write-Host "[Project-Init] Spawne $($toSpawn.Count) Untermanager fuer $projectSlug..." -ForegroundColor Cyan
    foreach ($ts in $toSpawn) {
        $argsList = @(
            "`"$spawnScript`"",
            "--type", "submanager",
            "--submanager-id", "$subIdCounter",
            "--role", "`"$($ts.Role)`"",
            "--domain", "`"$($ts.Domain)`"",
            "--responsibilities", "`"$($ts.Responsibilities)`"",
            "--parent-manager-id", "`"$ParentManagerId`"",
            "--workspace", "`"$wsPath`"",
            "--project", "`"$projectSlug`"",
            "--json"
        )

        try {
            $rawOut = & python $argsList
            $res = $rawOut | ConvertFrom-Json
            if ($res.success) {
                Write-Host "  [OK] Untermanager '$($ts.Role)' erstellt (CID: $($res.conversationId))" -ForegroundColor Green
                $spawnedList += $res
                $subIdCounter++
            } else {
                Write-Host "  [FEHLER] Untermanager '$($ts.Role)': $($res.error)" -ForegroundColor Red
            }
        } catch {
            Write-Host "  [EXCEPTION] Fehler beim Aufruf von spawn-agent.py: $_" -ForegroundColor Red
        }
    }
} elseif (-not $AutoSpawn) {
    Write-Host "[Project-Init] Planung abgeschlossen. AutoSpawn war nicht aktiv (Nutze -AutoSpawn zum Erstellen)." -ForegroundColor Yellow
}

# 8. Finale Ausgabe
if ($Json) {
    [PSCustomObject]@{
        Success = $true
        Project = $projectSlug
        Existing = $alreadyRegistered
        Spawned = $spawnedList
        DomainsFile = $domainsFile
    } | ConvertTo-Json -Depth 5
} else {
    Write-Host "`n[ERGEBNIS] Hierarchy-Init abgeschlossen." -ForegroundColor Green
    Write-Host "Registry gespeichert unter: $domainsFile" -ForegroundColor Gray
}
