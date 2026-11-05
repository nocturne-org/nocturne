<#
.SYNOPSIS
    Liest einen Gemini 4 Argon XML-Payload aus der Windows-Zwischenablage,
    erstellt einen Git-Checkpoint und wendet alle Dateioperationen an.
.PARAMETER DryRun
    Simuliert den Durchlauf und zeigt betroffene Dateien an, ohne das Dateisystem zu veraendern.
.PARAMETER ExecuteSteps
    Fuehrt nach dem Schreiben der Dateien automatisch die Befehle aus <execution_order> und <verification> aus.
#>
[CmdletBinding()]
param(
    [string]$FilePath,
    [switch]$DryRun,
    [switch]$ExecuteSteps
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Status {
    param([string]$Prefix, [string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Cyan)
    Write-Host "[$Prefix] " -ForegroundColor $Color -NoNewline
    Write-Host $Message
}

# 1. Zwischenablage oder Datei auslesen und validieren
if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
    if (-not (Test-Path -Path $FilePath)) {
        Throw "Die angegebene Datei existiert nicht: $FilePath"
    }
    $rawInput = Get-Content -Path $FilePath -Raw -Encoding UTF8
} else {
    $rawInput = Get-Clipboard -Raw
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        Throw "Die Windows-Zwischenablage ist leer. Bitte kopiere den <argon_payload> Block oder uebergib -FilePath."
    }
}

# Extrahiere den exakten <argon_payload>...</argon_payload> Block (ignoriert Markdown-Fences)
$pattern = '(?s)(<argon_payload\b.*?</argon_payload>)'
$match = [regex]::Match($rawInput, $pattern)

if (-not $match.Success) {
    Throw "Kein gueltiger <argon_payload>-Block in der Eingabe gefunden."
}

$xmlContent = $match.Groups[1].Value

try {
    [xml]$payload = $xmlContent
} catch {
    Throw "XML-Parsing fehlgeschlagen: $($_.Exception.Message)"
}

$summary = $payload.argon_payload.blueprint.summary
Write-Status "BLUEPRINT" ($summary -replace '\s+', ' ').Trim() ([ConsoleColor]::Yellow)

# 2. Git-Checkpointing (100% Reversibilitaet)
if (-not $DryRun) {
    $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $isGitRepo -ne "true") {
        Write-Status "GIT" "Verzeichnis ist noch kein Git-Repo. Initialisiere lokales Git-Repository fuer Reversibilitaet..." ([ConsoleColor]::Yellow)
        git init | Out-Null
        git add -A | Out-Null
        git commit --allow-empty -m "CHECKPOINT: Initial commit vor Argon-Blueprint" | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $checkpointMsg = "CHECKPOINT: Pre-Argon Blueprint ($timestamp)"

    Write-Status "GIT" "Erstelle Sicherheits-Checkpoint aller getrackten und ungetrackten Dateien..." ([ConsoleColor]::Magenta)
    git add -A | Out-Null
    git commit --allow-empty -m $checkpointMsg | Out-Null
    
    $checkpointHash = (git rev-parse --short HEAD).Trim()
    Write-Status "GIT" "Checkpoint erstellt (Commit $checkpointHash). Rollback jederzeit mit einem Befehl moeglich." ([ConsoleColor]::Green)
}

# 3. Dateien verarbeiten
$fileNodes = $payload.argon_payload.files.file
if (-not $fileNodes) {
    Write-Status "WARN" "Keine <file>-Eintraege im XML-Payload vorhanden." ([ConsoleColor]::DarkYellow)
    exit 0
}

$stats = @{ Created = 0; Updated = 0; Deleted = 0 }
$changedPaths = New-Object System.Collections.Generic.List[string]
$repoRoot = (Get-Location).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($node in $fileNodes) {
    $relPath = $node.GetAttribute("path")
    $action  = $node.GetAttribute("action")
    if ([string]::IsNullOrWhiteSpace($action)) { $action = "write" }

    if ([string]::IsNullOrWhiteSpace($relPath)) {
        Throw "Ein <file>-Tag enthaelt kein 'path'-Attribut."
    }

    # Pfad-Normalisierung und Schutz vor Directory Traversal
    $normalizedRel = $relPath -replace '/', '\'
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $normalizedRel))
    
    if (-not $fullPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Throw "Sicherheitsabbruch: Pfad '$relPath' verlaesst das Projektverzeichnis."
    }

    if ($action -eq "delete") {
        if (Test-Path -LiteralPath $fullPath) {
            if (-not $DryRun) {
                Remove-Item -LiteralPath $fullPath -Force
            }
            $stats.Deleted++
            $changedPaths.Add("[DELETE] $relPath")
        }
        continue
    }

    # Dateiinhalt aus CDATA oder InnerText extrahieren
    $code = $node.InnerText
    # Fuehrenden und abschliessenden Zeilenumbruch aus CDATA-Block entfernen, falls vorhanden
    $code = $code -replace '^\r?\n', '' -replace '\r?\n$', ''

    $existed = Test-Path -LiteralPath $fullPath
    $parentDir = Split-Path -Path $fullPath -Parent

    if (-not $DryRun) {
        if (-not (Test-Path -LiteralPath $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($fullPath, $code, $utf8NoBom)
    }

    if ($existed) {
        $stats.Updated++
        $changedPaths.Add("[UPDATE] $relPath")
    } else {
        $stats.Created++
        $changedPaths.Add("[CREATE] $relPath")
    }
}

# 4. Zusammenfassung ausgeben
Write-Host ""
Write-Status "SUMMARY" "Erstellt: $($stats.Created) | Aktualisiert: $($stats.Updated) | Geloescht: $($stats.Deleted)" ([ConsoleColor]::Green)
foreach ($entry in $changedPaths) {
    Write-Host "  $entry"
}

# 5. Ausfuehrungs- und Verifikationsschritte anzeigen oder ausfuehren
$execSteps = $payload.argon_payload.execution_order.step
$verifyCmds = $payload.argon_payload.verification.test_command

if ($execSteps) {
    Write-Host ""
    Write-Status "EXECUTION ORDER" "Geplante Build-/Setup-Schritte:" ([ConsoleColor]::Cyan)
    foreach ($step in $execSteps) {
        $idx = $step.GetAttribute("index")
        $desc = $step.GetAttribute("description")
        $cmd = ($step.InnerText).Trim()
        Write-Host "  $idx. [$desc] -> $cmd"
        if ($ExecuteSteps -and (-not $DryRun)) {
            Invoke-Expression $cmd
            if ($LASTEXITCODE -ne 0) { Throw "Befehl fehlgeschlagen: $cmd" }
        }
    }
}

if ($verifyCmds) {
    Write-Host ""
    Write-Status "VERIFICATION" "Validierungsbefehle:" ([ConsoleColor]::Cyan)
    foreach ($v in $verifyCmds) {
        $desc = $v.GetAttribute("description")
        $cmd = ($v.InnerText).Trim()
        Write-Host "  [TEST: $desc] -> $cmd"
        if ($ExecuteSteps -and (-not $DryRun)) {
            Invoke-Expression $cmd
            if ($LASTEXITCODE -ne 0) { Throw "Validierung fehlgeschlagen: $cmd" }
        }
    }
}

Write-Host ""
Write-Status "ROLLBACK" "Ein-Befehl-Wiederherstellung bei Fehlern:" ([ConsoleColor]::DarkYellow)
Write-Host "  git reset --hard HEAD; git clean -fd; git reset --mixed HEAD~1" -ForegroundColor White
