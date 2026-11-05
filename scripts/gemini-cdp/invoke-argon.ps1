<#
.SYNOPSIS
    Vollautomatischer Aufruf von Google Gemini Web (Argon) per Chrome CDP im Hintergrund
    mit optionaler direkter Anwendung des Blueprints.
.PARAMETER Prompt
    Der Prompt-Text als String.
.PARAMETER PromptFile
    Pfad zu einer Textdatei mit dem Prompt.
.PARAMETER Apply
    Wendet den empfangenen <argon_payload> Blueprint nach Erhalt automatisch ueber apply-argon-blueprint.ps1 an.
.PARAMETER ExecuteSteps
    Fuehrt bei -Apply auch die <execution_order> und <verification> Schritte aus.
.PARAMETER DryRun
    Simuliert bei -Apply die Dateiaenderungen, ohne sie auf die Festplatte zu schreiben.
.PARAMETER Visible
    Startet Chrome sichtbar (Standard: unsichtbar im Hintergrund).
#>
[CmdletBinding()]
param(
    [string]$Prompt,
    [string]$PromptFile,
    [switch]$Apply,
    [switch]$ExecuteSteps,
    [switch]$DryRun,
    [switch]$Visible,
    [int]$Port = 9223,
    [string]$OutputFile
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path "$scriptDir\..\..").Path
$runnerPy = Join-Path $scriptDir "gemini_cdp_runner.py"

if (-not (Test-Path $runnerPy)) {
    Throw "CDP Runner Skript nicht gefunden: $runnerPy"
}

# Temporaere Ausgabedatei festlegen, falls nicht explizit uebergeben
if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $tempDir = Join-Path $repoRoot ".tmp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }
    $OutputFile = Join-Path $tempDir "argon_last_response.xml"
}

# Python-Argumente vorbereiten
$pyArgs = @(
    "`"$runnerPy`"",
    "--port", "$Port",
    "--extract-blueprint",
    "-o", "`"$OutputFile`""
)

if (-not [string]::IsNullOrWhiteSpace($PromptFile)) {
    if (-not (Test-Path $PromptFile)) {
        Throw "Prompt-Datei nicht gefunden: $PromptFile"
    }
    $pyArgs += @("-f", "`"$PromptFile`"")
} elseif (-not [string]::IsNullOrWhiteSpace($Prompt)) {
    $pyArgs += @("-p", "`"$Prompt`"")
} else {
    Throw "Bitte gib entweder -Prompt oder -PromptFile an."
}

if ($Visible) {
    $pyArgs += "--visible"
}

Write-Host "[ARGON-CDP] Sende Prompt an Gemini Web im Hintergrund..." -ForegroundColor Cyan

# Runner ausfuehren
$cmd = "python " + ($pyArgs -join " ")
Invoke-Expression $cmd

if ($LASTEXITCODE -ne 0) {
    Throw "Ausfuehrung von gemini_cdp_runner.py fehlgeschlagen mit Exit-Code $LASTEXITCODE"
}

if (-not (Test-Path $OutputFile)) {
    Throw "Keine Antwort-Datei unter $OutputFile erzeugt."
}

Write-Host "[ARGON-CDP] Antwort erfolgreich erhalten: $OutputFile" -ForegroundColor Green

# Optional: Blueprint direkt anwenden
if ($Apply) {
    $applyScript = Join-Path $repoRoot "apply-argon-blueprint.ps1"
    if (-not (Test-Path $applyScript)) {
        Throw "apply-argon-blueprint.ps1 nicht gefunden unter $applyScript"
    }

    Write-Host "[ARGON-CDP] Wende Blueprint automatisch an..." -ForegroundColor Yellow
    $applyArgs = @("-FilePath", "`"$OutputFile`"")
    if ($DryRun) { $applyArgs += "-DryRun" }
    if ($ExecuteSteps) { $applyArgs += "-ExecuteSteps" }

    & $applyScript @applyArgs
}
