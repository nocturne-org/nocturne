<#
.SYNOPSIS
    Workspace-Cleaner: Validiert und erzwingt die strikte Projekt-Taxonomie und Typografie.
.DESCRIPTION
    Prueft das Projekt-Root auf unerlaubte Dateien, validiert die Ordner-Taxonomie (scripts/, docs/, src/, tests/, templates/),
    sucht nach unerlaubten Skript-Versionierungen (_v1, _copy) und stellt die Einhaltung der ASCII-Minus-Regel sicher.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = "Stop"
$rootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

Write-Host "=== Nocturne Workspace-Cleaner ===" -ForegroundColor Cyan
Write-Host "Projekt-Root: $rootPath"

# 1. Erlaubte Dateien und Verzeichnisse im Root
$allowedRootItems = @(
    ".git",
    ".github",
    ".gitignore",
    ".antigravityignore",
    "GEMINI.md",
    "README.md",
    "LICENSE",
    "pubspec.yaml",
    "pubspec.lock",
    "package.json",
    "pyproject.toml",
    "docs",
    "scripts",
    "src",
    "lib",
    "tests",
    "test",
    "templates",
    "android",
    "web",
    "assets"
)

# 2. Root-Verzeichnis pruefen
Write-Host "`n[1/4] Pruefe Root-Verzeichnis..." -ForegroundColor Yellow
$rootItems = Get-ChildItem -Path $rootPath -Force
$strayItems = @()

foreach ($item in $rootItems) {
    if ($allowedRootItems -notcontains $item.Name) {
        $strayItems += $item
    }
}

if ($strayItems.Count -gt 0) {
    Write-Warning "Unerwartete Dateien/Ordner im Root gefunden:"
    foreach ($stray in $strayItems) {
        Write-Warning "  - $($stray.Name)"
    }
} else {
    Write-Host "  OK: Root-Verzeichnis entspricht strikt der Taxonomie." -ForegroundColor Green
}

# 3. Skript-Hygiene & Versionierungs-Suffixe pruefen
Write-Host "`n[2/4] Pruefe Skript-Hygiene (Anti-Dubletten-Check)..." -ForegroundColor Yellow
$scriptFiles = Get-ChildItem -Path $rootPath -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\.git\\' -and ($_.Extension -match '\.(ps1|py|sh|bat|cmd)$')
}

$duplicateViolations = @()
foreach ($script in $scriptFiles) {
    if ($script.Name -match '(_v\d+|_neu|_backup|_copy|test\d+)\.') {
        $duplicateViolations += $script
    }
}

if ($duplicateViolations.Count -gt 0) {
    Write-Warning "Dateien mit unzulaessigen Versionierungs-Suffixen gefunden:"
    foreach ($v in $duplicateViolations) {
        Write-Warning "  - $($v.FullName)"
    }
} else {
    Write-Host "  OK: Keine redundanten Skripte mit Versions-Suffixen gefunden." -ForegroundColor Green
}

# 4. Typografie-Pruefung (Striktes ASCII-Minus)
Write-Host "`n[3/4] Pruefe Typografie (ASCII-Minus-Pflicht)..." -ForegroundColor Yellow
$textFiles = Get-ChildItem -Path $rootPath -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\.git\\' -and ($_.Extension -match '\.(md|txt|yaml|yml|json|ps1|dart)$')
}

$typographyViolations = @()
foreach ($file in $textFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $hasEnDash = $content.Contains([char]0x2013)
    $hasEmDash = $content.Contains([char]0x2014)
    if ($hasEnDash -or $hasEmDash) {
        $typographyViolations += $file
    }
}

if ($typographyViolations.Count -gt 0) {
    Write-Warning "Typografie-Verstoesse gefunden (En-Dash / Em-Dash):"
    foreach ($t in $typographyViolations) {
        Write-Warning "  - $($t.FullName)"
    }
} else {
    Write-Host "  OK: Alle Textdateien verwenden strikt Standard-ASCII-Minus (-)." -ForegroundColor Green
}

# 5. Git-Status
Write-Host "`n[4/4] Git-Status Uebersicht..." -ForegroundColor Yellow
$gitStatus = git -C $rootPath status --short
if ([string]::IsNullOrWhiteSpace($gitStatus)) {
    Write-Host "  OK: Working tree clean." -ForegroundColor Green
} else {
    Write-Host "  Offene Aenderungen vorhanden:" -ForegroundColor Cyan
    Write-Host $gitStatus
}

Write-Host "`nWorkspace-Pruefung erfolgreich beendet." -ForegroundColor Green
