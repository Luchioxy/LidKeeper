#Requires -Version 5.1
<#
.SYNOPSIS
    One-line installer for LidKeeper.
    Downloads both scripts to a temp directory and runs setup.
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/USER/LidKeeper/main/install.ps1 | iex
    Downloads setup.ps1 and lid-monitor.ps1, then launches the interactive setup.
#>

$repo = "YOUR_USERNAME/LidKeeper"
$branch = "main"
$baseRaw = "https://raw.githubusercontent.com/$repo/$branch"
$tempDir = Join-Path $env:TEMP "LidKeeper"

# Create temp directory
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-Host ""
Write-Host "  Downloading LidKeeper..." -ForegroundColor Cyan

# Download both scripts
$files = @("setup.ps1", "lid-monitor.ps1")
foreach ($file in $files) {
    $url = "$baseRaw/$file"
    $dest = Join-Path $tempDir $file
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        Write-Host "    $file ... OK" -ForegroundColor Green
    }
    catch {
        Write-Host "    $file ... FAILED" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "  Launching setup..." -ForegroundColor Cyan
Write-Host ""

# Run setup.ps1 from the temp directory
& (Join-Path $tempDir "setup.ps1")
