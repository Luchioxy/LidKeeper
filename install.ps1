#Requires -Version 5.1
<#
.SYNOPSIS
    One-line installer for LidKeeper.
    Downloads scripts, installs to ~/LidKeeper, adds 'lidkeeper' command.
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex
#>

$repo = "Luchioxy/LidKeeper"
$branch = "main"
$baseRaw = "https://raw.githubusercontent.com/$repo/$branch"
$installDir = Join-Path $HOME "LidKeeper"

# Create install directory
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

Write-Host ""
Write-Host "  Installing LidKeeper..." -ForegroundColor Cyan

# Download both scripts
$files = @("setup.ps1", "lid-monitor.ps1")
foreach ($file in $files) {
    $url = "$baseRaw/$file"
    $dest = Join-Path $installDir $file
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

# Add 'lidkeeper' command to PowerShell profile
$profileLine = 'function lidkeeper { & "$HOME\LidKeeper\setup.ps1" }'
$profilePath = $PROFILE.CurrentUserAllHosts

# Ensure profile directory exists
$profileDir = Split-Path $profilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Add function if not already present
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match 'lidkeeper') {
        Write-Host "    'lidkeeper' command already in profile." -ForegroundColor DarkGray
    }
    else {
        Add-Content -Path $profilePath -Value "`n# LidKeeper`n$profileLine"
        Write-Host "    Added 'lidkeeper' command to profile." -ForegroundColor Green
    }
}
else {
    Set-Content -Path $profilePath -Value "# LidKeeper`n$profileLine"
    Write-Host "    Added 'lidkeeper' command to profile." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done!" -ForegroundColor Green
Write-Host "  Installed to: $installDir" -ForegroundColor White
Write-Host ""
Write-Host "  Launching setup..." -ForegroundColor Cyan
Write-Host ""

# Run setup.ps1 from install directory
& (Join-Path $installDir "setup.ps1")
