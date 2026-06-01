#Requires -Version 5.1
<#
.SYNOPSIS
    LidKeeper - Keep your laptop awake when AI agents are running.
    Prevents sleep on lid close for Claude Code, Codex, WorkBuddy, etc.
.DESCRIPTION
    Modifies Windows power policy to control lid-close behavior.
    Smart Mode: scheduled task monitors agent processes and toggles power settings.
    Always-On Mode: disables lid-close sleep permanently.
.NOTES
    Run as Administrator for full functionality.
    Source: https://github.com/Luchioxy/LidKeeper
#>

# ── Language Detection ─────────────────────────────────────────────────────────

$script:Lang = if ($PSUICulture -match '^zh') { 'zh' } else { 'en' }

function T {
    param([string]$Key)
    $texts = @{
        'BannerTagline'      = @{ en = 'No Sleep for AI Agents';                            zh = -join [char[]]@(0x41,0x49,0x0020,0x41,0x67,0x65,0x6E,0x74,0x0020,0x8FD0,0x884C,0x65F6,0x5408,0x76D6,0x4E0D,0x4F11,0x7720) }
        'StatusHeader'       = @{ en = '  Current Status:';                                 zh = -join [char[]]@(0x0020,0x0020,0x5F53,0x524D,0x72B6,0x6001,0xFF1A) }
        'LidActionPlugged'   = @{ en = '    Lid action (plugged in):';                      zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x5408,0x76D6,0x52A8,0x4F5C,0xFF08,0x63D2,0x7535,0xFF09,0x003A) }
        'LidActionBattery'   = @{ en = '    Lid action (on battery):';                      zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x5408,0x76D6,0x52A8,0x4F5C,0xFF08,0x7535,0x6C60,0xFF09,0x003A) }
        'TaskStatus'         = @{ en = '    Scheduled task:';                               zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x8BA1,0x5212,0x4EFB,0x52A1,0x72B6,0x6001,0x003A) }
        'TaskInstalled'      = @{ en = 'Installed';                                        zh = -join [char[]]@(0x5DF2,0x5B89,0x88C5) }
        'TaskNotInstalled'   = @{ en = 'Not installed';                                    zh = -join [char[]]@(0x672A,0x5B89,0x88C5) }
        'AgentsRunning'      = @{ en = '    Running agents:';                              zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x8FD0,0x884C,0x4E2D,0x0020,0x0041,0x0067,0x0065,0x006E,0x0074,0x003A) }
        'AgentsNone'         = @{ en = 'None';                                             zh = -join [char[]]@(0x65E0) }
        'MenuHeader'         = @{ en = '  Select mode:';                                   zh = -join [char[]]@(0x0020,0x0020,0x8BF7,0x9009,0x62E9,0x6A21,0x5F0F,0xFF1A) }
        'ModeSmart'          = @{ en = '  [1] Smart Mode  - No sleep only when agents run'; zh = -join [char[]]@(0x0020,0x0020,0x005B,0x0031,0x005D,0x0020,0x667A,0x80FD,0x6A21,0x5F0F,0x0020,0x0020,0x2014,0x0020,0x0041,0x0067,0x0065,0x006E,0x0074,0x0020,0x8FD0,0x884C,0x65F6,0x624D,0x963B,0x6B62,0x5408,0x76D6,0x4F11,0x7720) }
        'ModeAlwaysOn'       = @{ en = '  [2] Always-On   - Never sleep on lid close';     zh = -join [char[]]@(0x0020,0x0020,0x005B,0x0032,0x005D,0x0020,0x5E38,0x5F00,0x6A21,0x5F0F,0x0020,0x0020,0x2014,0x0020,0x59CB,0x7EC8,0x963B,0x6B62,0x5408,0x76D6,0x4F11,0x7720) }
        'ModeUninstall'      = @{ en = '  [3] Uninstall    - Remove all settings';          zh = -join [char[]]@(0x0020,0x0020,0x005B,0x0033,0x005D,0x0020,0x5378,0x8F7D,0x0020,0x0020,0x0020,0x0020,0x0020,0x2014,0x0020,0x79FB,0x9664,0x6240,0x6709,0x8BBE,0x7F6E,0xFF0C,0x6062,0x590D,0x9ED8,0x8BA4) }
        'ModeExit'           = @{ en = '  [0] Exit';                                       zh = -join [char[]]@(0x0020,0x0020,0x005B,0x0030,0x005D,0x0020,0x9000,0x51FA) }
        'PromptChoice'       = @{ en = '  Choose (0-3)';                                   zh = -join [char[]]@(0x0020,0x0020,0x8BF7,0x9009,0x62E9,0x0020,0x0028,0x0030,0x002D,0x0033,0x0029) }
        'InvalidChoice'      = @{ en = '  Invalid choice.';                                zh = -join [char[]]@(0x0020,0x0020,0x65E0,0x6548,0x9009,0x62E9,0x3002) }
        'Goodbye'            = @{ en = '  Goodbye!';                                       zh = -join [char[]]@(0x0020,0x0020,0x518D,0x89C1,0xFF01) }
        'PressKeyExit'       = @{ en = '  Press any key to exit...';                       zh = -join [char[]]@(0x0020,0x0020,0x6309,0x4EFB,0x610F,0x952E,0x9000,0x51FA,0x2026) }
        'PowerSourceHeader'  = @{ en = '  Power source:';                                  zh = -join [char[]]@(0x0020,0x0020,0x9009,0x62E9,0x751F,0x6548,0x7684,0x7535,0x6E90,0x573A,0x666F,0xFF1A) }
        'PowerAC'            = @{ en = '    [1] Plugged in only (recommended)';            zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x005B,0x0031,0x005D,0x0020,0x4EC5,0x63D2,0x7535,0x65F6,0xFF08,0x63A8,0x8350,0xFF0C,0x4FDD,0x62A4,0x7535,0x6C60,0xFF09) }
        'PowerDC'            = @{ en = '    [2] On battery only';                           zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x005B,0x0032,0x005D,0x0020,0x4EC5,0x7535,0x6C60,0x65F6) }
        'PowerBoth'          = @{ en = '    [3] Both';                                      zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x005B,0x0033,0x005D,0x0020,0x4E24,0x8005,0x90FD) }
        'PromptPower'        = @{ en = '  Choose (1-3)';                                   zh = -join [char[]]@(0x0020,0x0020,0x8BF7,0x9009,0x62E9,0x0020,0x0028,0x0031,0x002D,0x0033,0x0029) }
        'InvalidDefaultAC'   = @{ en = '  Invalid, defaulting to [1] Plugged in';         zh = -join [char[]]@(0x0020,0x0020,0x65E0,0x6548,0x9009,0x62E9,0xFF0C,0x9ED8,0x8BA4,0x4F7F,0x7528,0x0020,0x005B,0x0031,0x005D,0x0020,0x4EC5,0x63D2,0x7535) }
        'SmartConfiguring'   = @{ en = '  [Smart Mode] Configuring...';                    zh = -join [char[]]@(0x0020,0x0020,0x005B,0x667A,0x80FD,0x6A21,0x5F0F,0x005D,0x0020,0x914D,0x7F6E,0x4E2D,0x2026) }
        'SavedOriginal'      = @{ en = '  Saved original lid settings for restore.';       zh = -join [char[]]@(0x0020,0x0020,0x5DF2,0x4FDD,0x5B58,0x5F53,0x524D,0x5408,0x76D6,0x8BBE,0x7F6E,0x4F5C,0x4E3A,0x8FD8,0x539F,0x57FA,0x51C6,0x3002) }
        'AgentDetected'      = @{ en = '  Agent(s) detected, lid sleep disabled now.';     zh = -join [char[]]@(0x0020,0x0020,0x68C0,0x6D4B,0x5230,0x0020,0x0061,0x0067,0x0065,0x006E,0x0074,0x0020,0x6B63,0x5728,0x8FD0,0x884C,0xFF0C,0x5DF2,0x7ACB,0x5373,0x7981,0x7528,0x5408,0x76D6,0x4F11,0x7720,0x3002) }
        'SmartEnabled'       = @{ en = '  Smart Mode enabled!';                             zh = -join [char[]]@(0x0020,0x0020,0x667A,0x80FD,0x6A21,0x5F0F,0x5DF2,0x542F,0x7528,0xFF01) }
        'SmartDesc1'         = @{ en = '  Task checks every 1 minute:';                    zh = -join [char[]]@(0x0020,0x0020,0x8BA1,0x5212,0x4EFB,0x52A1,0x5C06,0x6BCF,0x0020,0x0031,0x0020,0x5206,0x949F,0x68C0,0x6D4B,0x4E00,0x6B21,0x0020,0x0061,0x0067,0x0065,0x006E,0x0074,0x0020,0x8FDB,0x7A0B,0xFF1A) }
        'SmartDesc2'         = @{ en = '    - Agent running -> no sleep on lid close';      zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x002D,0x0020,0x6709,0x0020,0x0061,0x0067,0x0065,0x006E,0x0074,0x0020,0x8FD0,0x884C,0x0020,0x2192,0x0020,0x5408,0x76D6,0x4E0D,0x4F11,0x7720) }
        'SmartDesc3'         = @{ en = '    - No agent       -> restore original behavior';  zh = -join [char[]]@(0x0020,0x0020,0x0020,0x0020,0x002D,0x0020,0x65E0,0x0020,0x0061,0x0067,0x0065,0x006E,0x0074,0x0020,0x8FD0,0x884C,0x0020,0x2192,0x0020,0x6062,0x590D,0x539F,0x59CB,0x5408,0x76D6,0x884C,0x4E3A) }
        'PowerSourceLabel'   = @{ en = '  Power source:';                                  zh = -join [char[]]@(0x0020,0x0020,0x751F,0x6548,0x7535,0x6E90,0x573A,0x666F,0x003A) }
        'AlwaysConfiguring'  = @{ en = '  [Always-On Mode] Configuring...';                zh = -join [char[]]@(0x0020,0x0020,0x005B,0x5E38,0x5F00,0x6A21,0x5F0F,0x005D,0x0020,0x914D,0x7F6E,0x4E2D,0x2026) }
        'AlwaysEnabled'      = @{ en = '  Always-On Mode enabled!';                        zh = -join [char[]]@(0x0020,0x0020,0x5E38,0x5F00,0x6A21,0x5F0F,0x5DF2,0x542F,0x7528,0xFF01) }
        'AlwaysDesc1'        = @{ en = '  Lid action set to "Do nothing"';                 zh = -join [char[]]@(0x0020,0x0020,0x5408,0x76D6,0x52A8,0x4F5C,0x5DF2,0x8BBE,0x4E3A,0x300C,0x4E0D,0x6267,0x884C,0x4EFB,0x4F55,0x64CD,0x4F5C,0x300D) }
        'AlwaysDesc2'        = @{ en = '  No background task needed. Setting is live.';     zh = -join [char[]]@(0x0020,0x0020,0x65E0,0x9700,0x540E,0x53F0,0x4EFB,0x52A1,0xFF0C,0x8BBE,0x7F6E,0x5DF2,0x76F4,0x63A5,0x751F,0x6548,0x3002) }
        'UninstallConfig'    = @{ en = '  [Uninstall] Cleaning up...';                     zh = -join [char[]]@(0x0020,0x0020,0x005B,0x5378,0x8F7D,0x005D,0x0020,0x6E05,0x7406,0x4E2D,0x2026) }
        'TaskRemoved'        = @{ en = '  Removed scheduled task:';                        zh = -join [char[]]@(0x0020,0x0020,0x5DF2,0x79FB,0x9664,0x8BA1,0x5212,0x4EFB,0x52A1,0x003A) }
        'TaskNotFound'       = @{ en = '  Task not found, skipped.';                       zh = -join [char[]]@(0x0020,0x0020,0x8BA1,0x5212,0x4EFB,0x52A1,0x4E0D,0x5B58,0x5728,0xFF0C,0x8DF3,0x8FC7,0x3002) }
        'RestoredPlugged'    = @{ en = '  Restored plugged-in lid action:';                zh = -join [char[]]@(0x0020,0x0020,0x5DF2,0x6062,0x590D,0x63D2,0x7535,0x5408,0x76D6,0x52A8,0x4F5C,0x003A) }
        'RestoredBattery'    = @{ en = '  Restored battery lid action:';                   zh = -join [char[]]@(0x0020,0x0020,0x5DF2,0x6062,0x590D,0x7535,0x6C60,0x5408,0x76D6,0x52A8,0x4F5C,0x003A) }
        'CleanedRegistry'    = @{ en = '  Cleaned registry config.';                       zh = -join [char[]]@(0x0020,0x0020,0x5DF2,0x6E05,0x7406,0x6CE8,0x518C,0x8868,0x914D,0x7F6E,0x3002) }
        'NoOriginalSettings' = @{ en = '  No original settings found, skipped restore.';   zh = -join [char[]]@(0x0020,0x0020,0x672A,0x627E,0x5230,0x539F,0x59CB,0x8BBE,0x7F6E,0xFF0C,0x8DF3,0x8FC7,0x6062,0x590D,0x3002) }
        'UninstallDone'      = @{ en = '  Uninstall complete!';                            zh = -join [char[]]@(0x0020,0x0020,0x5378,0x8F7D,0x5B8C,0x6210,0xFF01) }
        'LidDoNothing'       = @{ en = 'Do nothing';                                      zh = -join [char[]]@(0x4E0D,0x6267,0x884C,0x4EFB,0x4F55,0x64CD,0x4F5C) }
        'LidSleep'           = @{ en = 'Sleep';                                           zh = -join [char[]]@(0x7761,0x7720) }
        'LidHibernate'       = @{ en = 'Hibernate';                                      zh = -join [char[]]@(0x4F11,0x7720) }
        'LidShutdown'        = @{ en = 'Shutdown';                                        zh = -join [char[]]@(0x5173,0x673A) }
    }
    return $texts[$Key][$script:Lang]
}

# Map lid action value to localized name
$LID_ACTION_NAMES = @{
    0 = T 'LidDoNothing'
    1 = T 'LidSleep'
    2 = T 'LidHibernate'
    3 = T 'LidShutdown'
}

# ── Configuration ──────────────────────────────────────────────────────────────

$REG_BASE        = "HKCU\SOFTWARE\LidKeeper"
$TASK_NAME       = "LidKeeper-Monitor"
$SCRIPT_DIR      = Split-Path -Parent $MyInvocation.MyCommand.Path
$MONITOR_SCRIPT  = Join-Path $SCRIPT_DIR "lid-monitor.ps1"

# Agent process names (Get-Process is case-insensitive on Windows)
$AGENT_PROCESSES = @("claude", "Codex", "WorkBuddy")

# Lid action values
$LID_DO_NOTHING = 0
$LID_SLEEP      = 1

# Power scheme GUIDs (sub-group and setting are fixed)
$SUB_BUTTONS_GUID  = "4f971e89-eebd-4455-a8de-9e59040e7347"
$LID_ACTION_GUID   = "5ca83367-6e45-459f-a27b-476b1d01c936"

# Dynamically detect active power scheme GUID
function Get-ActivePowerSchemeGUID {
    try {
        $output = & powercfg /getactivescheme 2>&1
        if ($output -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
            return $Matches[1]
        }
    }
    catch {}
    return "381b4222-f694-41f0-9685-ff5bb260df2e"
}

function Get-LidActionRegPath {
    $schemeGUID = Get-ActivePowerSchemeGUID
    return "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$schemeGUID\$SUB_BUTTONS_GUID\$LID_ACTION_GUID"
}

# ── Helper Functions ───────────────────────────────────────────────────────────

function Write-Banner {
    # Box-drawing chars as Unicode escapes to survive irm|iex encoding
    $tl = -join [char[]]@(0x2554)  # ╔
    $tr = -join [char[]]@(0x2557)  # ╗
    $bl = -join [char[]]@(0x255A)  # ╚
    $br = -join [char[]]@(0x255D)  # ╝
    $h  = -join [char[]]@(0x2550)  # ═
    $v  = -join [char[]]@(0x2551)  # ║
    $sp = -join [char[]]@(0x0020)  # space

    $hline = $h * 43
    Clear-Host
    Write-Host ""
    Write-Host "  $tl$hline$tr" -ForegroundColor Cyan
    Write-Host "  ${v}${sp}${sp}${sp}${sp}${sp}${sp}${sp}LidKeeper v1.0${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${sp}${v}" -ForegroundColor Cyan
    $tagline = T 'BannerTagline'
    Write-Host "  ${v}${sp}${sp}${sp}${sp}${sp}${sp}$($tagline.PadRight(29))${v}" -ForegroundColor Cyan
    Write-Host "  $bl$hline$br" -ForegroundColor Cyan
    Write-Host ""
}

function Ensure-Registry {
    if (-not (Test-Path $REG_BASE)) {
        New-Item -Path $REG_BASE -Force | Out-Null
    }
}

function Get-CurrentLidAction {
    $result = @{ AC = $LID_SLEEP; DC = $LID_SLEEP }
    $regPath = Get-LidActionRegPath
    try {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        if ($null -ne $props.ACSettingIndex) { $result.AC = [int]$props.ACSettingIndex }
        if ($null -ne $props.DCSettingIndex) { $result.DC = [int]$props.DCSettingIndex }
    }
    catch {}
    return $result
}

function Set-LidAction {
    param(
        [int]$Value,
        [ValidateSet("AC", "DC", "Both")]
        [string]$PowerSource = "Both"
    )

    if ($PowerSource -eq "AC" -or $PowerSource -eq "Both") {
        & powercfg /setacvalueindex SCHEME_CURRENT $SUB_BUTTONS_GUID $LID_ACTION_GUID $Value 2>&1 | Out-Null
    }
    if ($PowerSource -eq "DC" -or $PowerSource -eq "Both") {
        & powercfg /setdcvalueindex SCHEME_CURRENT $SUB_BUTTONS_GUID $LID_ACTION_GUID $Value 2>&1 | Out-Null
    }

    & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
}

function Test-AgentsRunning {
    foreach ($name in $AGENT_PROCESSES) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            return $true
        }
    }
    return $false
}

function Show-CurrentStatus {
    $current = Get-CurrentLidAction
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue

    Write-Host (T 'StatusHeader') -ForegroundColor Yellow
    Write-Host "$((T 'LidActionPlugged')) $($LID_ACTION_NAMES[[int]$current.AC])" -ForegroundColor White
    Write-Host "$((T 'LidActionBattery')) $($LID_ACTION_NAMES[[int]$current.DC])" -ForegroundColor White
    $taskText = if ($taskExists) { T 'TaskInstalled' } else { T 'TaskNotInstalled' }
    Write-Host "$((T 'TaskStatus')) $taskText" -ForegroundColor White

    $agents = @()
    foreach ($name in $AGENT_PROCESSES) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            $agents += $name
        }
    }
    if ($agents.Count -gt 0) {
        Write-Host "$((T 'AgentsRunning')) $($agents -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "$((T 'AgentsRunning')) $((T 'AgentsNone'))" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Read-PowerSourceChoice {
    Write-Host (T 'PowerSourceHeader') -ForegroundColor Yellow
    Write-Host (T 'PowerAC')
    Write-Host (T 'PowerDC')
    Write-Host (T 'PowerBoth')
    Write-Host ""
    $powerChoice = Read-Host (T 'PromptPower')

    switch ($powerChoice) {
        "1" { return "AC" }
        "2" { return "DC" }
        "3" { return "Both" }
        default {
            Write-Host (T 'InvalidDefaultAC') -ForegroundColor Red
            return "AC"
        }
    }
}

# ── Mode Implementations ──────────────────────────────────────────────────────

function Install-SmartMode {
    Write-Host (T 'SmartConfiguring') -ForegroundColor Cyan
    Write-Host ""

    $powerSource = Read-PowerSourceChoice
    Write-Host ""

    Ensure-Registry
    $current = Get-CurrentLidAction
    New-ItemProperty -Path $REG_BASE -Name "OriginalLidActionAC" -Value $current.AC -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $REG_BASE -Name "OriginalLidActionDC" -Value $current.DC -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $REG_BASE -Name "PowerSource" -Value $powerSource -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $REG_BASE -Name "Mode" -Value "Smart" -PropertyType String -Force | Out-Null

    Write-Host (T 'SavedOriginal') -ForegroundColor Green

    if (Test-AgentsRunning) {
        Set-LidAction -Value $LID_DO_NOTHING -PowerSource $powerSource
        Write-Host (T 'AgentDetected') -ForegroundColor Green
    }

    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MONITOR_SCRIPT`" -PowerSource $powerSource"

    $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) `
        -RepetitionInterval (New-TimeSpan -Minutes 1) `
        -RepetitionDuration (New-TimeSpan -Days 36500)

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

    $descText = if ($script:Lang -eq 'zh') {
        -join [char[]]@(0x4C,0x69,0x64,0x4B,0x65,0x65,0x70,0x65,0x72,0x0020,0x667A,0x80FD,0x6A21,0x5F0F,0xFF1A,0x68C0,0x6D4B,0x0020,0x41,0x49,0x0020,0x61,0x67,0x65,0x6E,0x74,0x0020,0x8FDB,0x7A0B,0x5E76,0x81EA,0x52A8,0x7BA1,0x7406,0x5408,0x76D6,0x4F11,0x7720,0x884C,0x4E3A)
    } else {
        "LidKeeper Smart Mode: monitors AI agent processes and manages lid-close sleep"
    }

    Register-ScheduledTask `
        -TaskName $TASK_NAME `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description $descText `
        -RunLevel Highest `
        -Force | Out-Null

    Write-Host ""
    Write-Host "  $((-join [char[]]@(0x2550)) * 46)" -ForegroundColor Green
    Write-Host "  $((T 'SmartEnabled'))" -ForegroundColor Green
    Write-Host ""
    Write-Host (T 'SmartDesc1') -ForegroundColor White
    Write-Host (T 'SmartDesc2') -ForegroundColor White
    Write-Host (T 'SmartDesc3') -ForegroundColor White
    Write-Host "$((T 'PowerSourceLabel')) $powerSource" -ForegroundColor White
    Write-Host "  $((-join [char[]]@(0x2550)) * 46)" -ForegroundColor Green
    Write-Host ""
}

function Install-AlwaysOnMode {
    Write-Host (T 'AlwaysConfiguring') -ForegroundColor Cyan
    Write-Host ""

    $powerSource = Read-PowerSourceChoice
    Write-Host ""

    Ensure-Registry
    $current = Get-CurrentLidAction
    New-ItemProperty -Path $REG_BASE -Name "OriginalLidActionAC" -Value $current.AC -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $REG_BASE -Name "OriginalLidActionDC" -Value $current.DC -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $REG_BASE -Name "PowerSource" -Value $powerSource -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $REG_BASE -Name "Mode" -Value "AlwaysOn" -PropertyType String -Force | Out-Null

    Set-LidAction -Value $LID_DO_NOTHING -PowerSource $powerSource

    Write-Host ""
    Write-Host "  $((-join [char[]]@(0x2550)) * 46)" -ForegroundColor Green
    Write-Host "  $((T 'AlwaysEnabled'))" -ForegroundColor Green
    Write-Host ""
    Write-Host (T 'AlwaysDesc1') -ForegroundColor White
    Write-Host "$((T 'PowerSourceLabel')) $powerSource" -ForegroundColor White
    Write-Host (T 'AlwaysDesc2') -ForegroundColor White
    Write-Host "  $((-join [char[]]@(0x2550)) * 46)" -ForegroundColor Green
    Write-Host ""
}

function Uninstall-All {
    Write-Host (T 'UninstallConfig') -ForegroundColor Cyan
    Write-Host ""

    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
        Write-Host "$((T 'TaskRemoved')) $TASK_NAME" -ForegroundColor Green
    }
    else {
        Write-Host (T 'TaskNotFound') -ForegroundColor DarkGray
    }

    $hasOriginal = Test-Path $REG_BASE
    if ($hasOriginal) {
        $origAC = Get-ItemProperty -Path $REG_BASE -Name "OriginalLidActionAC" -ErrorAction SilentlyContinue
        $origDC = Get-ItemProperty -Path $REG_BASE -Name "OriginalLidActionDC" -ErrorAction SilentlyContinue

        if ($null -ne $origAC) {
            & powercfg /setacvalueindex SCHEME_CURRENT $SUB_BUTTONS_GUID $LID_ACTION_GUID $origAC.OriginalLidActionAC 2>&1 | Out-Null
            Write-Host "$((T 'RestoredPlugged')) $($LID_ACTION_NAMES[[int]$origAC.OriginalLidActionAC])" -ForegroundColor Green
        }
        if ($null -ne $origDC) {
            & powercfg /setdcvalueindex SCHEME_CURRENT $SUB_BUTTONS_GUID $LID_ACTION_GUID $origDC.OriginalLidActionDC 2>&1 | Out-Null
            Write-Host "$((T 'RestoredBattery')) $($LID_ACTION_NAMES[[int]$origDC.OriginalLidActionDC])" -ForegroundColor Green
        }

        & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null

        Remove-Item -Path $REG_BASE -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host (T 'CleanedRegistry') -ForegroundColor Green
    }
    else {
        Write-Host (T 'NoOriginalSettings') -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  $((-join [char[]]@(0x2550)) * 46)" -ForegroundColor Green
    Write-Host "  $((T 'UninstallDone'))" -ForegroundColor Green
    Write-Host "  $((-join [char[]]@(0x2550)) * 46)" -ForegroundColor Green
    Write-Host ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Banner
Show-CurrentStatus

Write-Host (T 'MenuHeader') -ForegroundColor Yellow
Write-Host ""
Write-Host (T 'ModeSmart')     -ForegroundColor White
Write-Host (T 'ModeAlwaysOn')  -ForegroundColor White
Write-Host (T 'ModeUninstall') -ForegroundColor White
Write-Host (T 'ModeExit')      -ForegroundColor White
Write-Host ""

$choice = Read-Host (T 'PromptChoice')

switch ($choice) {
    "1" { Install-SmartMode }
    "2" { Install-AlwaysOnMode }
    "3" { Uninstall-All }
    "0" {
        Write-Host (T 'Goodbye') -ForegroundColor Cyan
        exit 0
    }
    default {
        Write-Host (T 'InvalidChoice') -ForegroundColor Red
        exit 1
    }
}

Write-Host (T 'PressKeyExit') -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
