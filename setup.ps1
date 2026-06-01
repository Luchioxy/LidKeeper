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
    Source: https://github.com/YOUR_USERNAME/LidKeeper
#>

# ── Language Detection ─────────────────────────────────────────────────────────

$script:Lang = if ($PSUICulture -match '^zh') { 'zh' } else { 'en' }

$script:T = @{
    # Banner
    BannerTagline     = @{ en = 'No Sleep for AI Agents'                          ; zh = 'AI Agent 运行时合盖不休眠' }[$Lang]
    # Status
    StatusHeader      = @{ en = '  Current Status:'                               ; zh = '  当前状态：' }[$Lang]
    LidActionPlugged  = @{ en = '    Lid action (plugged in):'                    ; zh = '    合盖动作（插电）:' }[$Lang]
    LidActionBattery  = @{ en = '    Lid action (on battery):'                    ; zh = '    合盖动作（电池）:' }[$Lang]
    TaskStatus        = @{ en = '    Scheduled task:'                              ; zh = '    计划任务状态:' }[$Lang]
    TaskInstalled     = @{ en = 'Installed'                                        ; zh = '已安装' }[$Lang]
    TaskNotInstalled  = @{ en = 'Not installed'                                    ; zh = '未安装' }[$Lang]
    AgentsRunning     = @{ en = '    Running agents:'                              ; zh = '    运行中的 Agent:' }[$Lang]
    AgentsNone        = @{ en = 'None'                                             ; zh = '无' }[$Lang]
    # Menu
    MenuHeader        = @{ en = '  Select mode:'                                  ; zh = '  请选择模式：' }[$Lang]
    ModeSmart         = @{ en = '  [1] Smart Mode  - No sleep only when agents run'; zh = '  [1] 智能模式  — Agent 运行时才阻止合盖休眠' }[$Lang]
    ModeAlwaysOn      = @{ en = '  [2] Always-On   - Never sleep on lid close'     ; zh = '  [2] 常开模式  — 始终阻止合盖休眠' }[$Lang]
    ModeUninstall     = @{ en = '  [3] Uninstall    - Remove all settings'          ; zh = '  [3] 卸载      — 移除所有设置，恢复默认' }[$Lang]
    ModeExit          = @{ en = '  [0] Exit'                                        ; zh = '  [0] 退出' }[$Lang]
    PromptChoice      = @{ en = '  Choose (0-3)'                                   ; zh = '  请选择 (0-3)' }[$Lang]
    InvalidChoice     = @{ en = '  Invalid choice.'                                ; zh = '  无效选择。' }[$Lang]
    Goodbye           = @{ en = '  Goodbye!'                                       ; zh = '  再见！' }[$Lang]
    PressKeyExit       = @{ en = '  Press any key to exit...'                      ; zh = '  按任意键退出...' }[$Lang]
    # Power source
    PowerSourceHeader = @{ en = '  Power source:'                                  ; zh = '  选择生效的电源场景：' }[$Lang]
    PowerAC           = @{ en = '    [1] Plugged in only (recommended)'            ; zh = '    [1] 仅插电时（推荐，保护电池）' }[$Lang]
    PowerDC           = @{ en = '    [2] On battery only'                           ; zh = '    [2] 仅电池时' }[$Lang]
    PowerBoth         = @{ en = '    [3] Both'                                      ; zh = '    [3] 两者都' }[$Lang]
    PromptPower       = @{ en = '  Choose (1-3)'                                   ; zh = '  请选择 (1-3)' }[$Lang]
    InvalidDefaultAC   = @{ en = '  Invalid, defaulting to [1] Plugged in'         ; zh = '  无效选择，默认使用 [1] 仅插电' }[$Lang]
    # Smart mode
    SmartConfiguring   = @{ en = '  [Smart Mode] Configuring...'                   ; zh = '  [智能模式] 配置中...' }[$Lang]
    SavedOriginal      = @{ en = '  Saved original lid settings for restore.'      ; zh = '  已保存当前合盖设置作为还原基准。' }[$Lang]
    AgentDetected      = @{ en = '  Agent(s) detected, lid sleep disabled now.'    ; zh = '  检测到 agent 正在运行，已立即禁用合盖休眠。' }[$Lang]
    SmartEnabled       = @{ en = '  Smart Mode enabled!'                            ; zh = '  智能模式已启用！' }[$Lang]
    SmartDesc1         = @{ en = '  Task checks every 1 minute:'                   ; zh = '  计划任务将每 1 分钟检测一次 agent 进程：' }[$Lang]
    SmartDesc2         = @{ en = '    - Agent running -> no sleep on lid close'     ; zh = '    - 有 agent 运行 → 合盖不休眠' }[$Lang]
    SmartDesc3         = @{ en = '    - No agent       -> restore original behavior' ; zh = '    - 无 agent 运行 → 恢复原始合盖行为' }[$Lang]
    PowerSourceLabel   = @{ en = '  Power source:'                                  ; zh = '  生效电源场景:' }[$Lang]
    # Always-on mode
    AlwaysConfiguring  = @{ en = '  [Always-On Mode] Configuring...'               ; zh = '  [常开模式] 配置中...' }[$Lang]
    AlwaysEnabled      = @{ en = '  Always-On Mode enabled!'                       ; zh = '  常开模式已启用！' }[$Lang]
    AlwaysDesc1        = @{ en = '  Lid action set to "Do nothing"'                ; zh = '  合盖动作已设为「不执行任何操作」' }[$Lang]
    AlwaysDesc2        = @{ en = '  No background task needed. Setting is live.'    ; zh = '  无需后台任务，设置已直接生效。' }[$Lang]
    # Uninstall
    UninstallConfig     = @{ en = '  [Uninstall] Cleaning up...'                   ; zh = '  [卸载] 清理中...' }[$Lang]
    TaskRemoved         = @{ en = '  Removed scheduled task:'                       ; zh = '  已移除计划任务:' }[$Lang]
    TaskNotFound        = @{ en = '  Task not found, skipped.'                      ; zh = '  计划任务不存在，跳过。' }[$Lang]
    RestoredPlugged     = @{ en = '  Restored plugged-in lid action:'              ; zh = '  已恢复插电合盖动作:' }[$Lang]
    RestoredBattery     = @{ en = '  Restored battery lid action:'                 ; zh = '  已恢复电池合盖动作:' }[$Lang]
    CleanedRegistry     = @{ en = '  Cleaned registry config.'                     ; zh = '  已清理注册表配置。' }[$Lang]
    NoOriginalSettings  = @{ en = '  No original settings found, skipped restore.' ; zh = '  未找到原始设置，跳过恢复。' }[$Lang]
    UninstallDone       = @{ en = '  Uninstall complete!'                          ; zh = '  卸载完成！' }[$Lang]
    # Lid action names
    LidDoNothing        = @{ en = 'Do nothing'                                     ; zh = '不执行任何操作' }[$Lang]
    LidSleep            = @{ en = 'Sleep'                                          ; zh = '睡眠' }[$Lang]
    LidHibernate        = @{ en = 'Hibernate'                                     ; zh = '休眠' }[$Lang]
    LidShutdown         = @{ en = 'Shutdown'                                       ; zh = '关机' }[$Lang]
}

# Map lid action value to localized name
$LID_ACTION_NAMES = @{
    0 = $T.LidDoNothing
    1 = $T.LidSleep
    2 = $T.LidHibernate
    3 = $T.LidShutdown
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
    # Fallback: Balanced plan
    return "381b4222-f694-41f0-9685-ff5bb260df2e"
}

function Get-LidActionRegPath {
    $schemeGUID = Get-ActivePowerSchemeGUID
    return "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$schemeGUID\$SUB_BUTTONS_GUID\$LID_ACTION_GUID"
}

# ── Helper Functions ───────────────────────────────────────────────────────────

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           LidKeeper v1.0                  ║" -ForegroundColor Cyan
    Write-Host "  ║       $($T.BannerTagline.PadRight(29))║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Ensure-Registry {
    if (-not (Test-Path $REG_BASE)) {
        New-Item -Path $REG_BASE -Force | Out-Null
    }
}

function Get-CurrentLidAction {
    <#
    .SYNOPSIS
        Read current lid-close action from registry (AC and DC).
        Returns @{ AC = <int>; DC = <int> }
    #>
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
    <#
    .SYNOPSIS
        Set lid-close action via powercfg.
    .PARAMETER Value  0=Do nothing, 1=Sleep, 2=Hibernate, 3=Shutdown
    .PARAMETER PowerSource  "AC", "DC", or "Both"
    #>
    param(
        [int]$Value,
        [ValidateSet("AC", "DC", "Both")]
        [string]$PowerSource = "Both"
    )

    $subGroup = $SUB_BUTTONS_GUID
    $setting  = $LID_ACTION_GUID

    if ($PowerSource -eq "AC" -or $PowerSource -eq "Both") {
        & powercfg /setacvalueindex SCHEME_CURRENT $subGroup $setting $Value 2>&1 | Out-Null
    }
    if ($PowerSource -eq "DC" -or $PowerSource -eq "Both") {
        & powercfg /setdcvalueindex SCHEME_CURRENT $subGroup $setting $Value 2>&1 | Out-Null
    }

    & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
}

function Test-AgentsRunning {
    <#
    .SYNOPSIS
        Check if any AI agent process is currently running.
    #>
    foreach ($name in $AGENT_PROCESSES) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            return $true
        }
    }
    return $false
}

function Show-CurrentStatus {
    <#
    .SYNOPSIS
        Display current status information.
    #>
    $current = Get-CurrentLidAction
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue

    Write-Host $T.StatusHeader -ForegroundColor Yellow
    Write-Host "$($T.LidActionPlugged) $($LID_ACTION_NAMES[[int]$current.AC])" -ForegroundColor White
    Write-Host "$($T.LidActionBattery) $($LID_ACTION_NAMES[[int]$current.DC])" -ForegroundColor White
    $taskText = if ($taskExists) { $T.TaskInstalled } else { $T.TaskNotInstalled }
    Write-Host "$($T.TaskStatus) $taskText" -ForegroundColor White

    $agents = @()
    foreach ($name in $AGENT_PROCESSES) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            $agents += $name
        }
    }
    if ($agents.Count -gt 0) {
        Write-Host "$($T.AgentsRunning) $($agents -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "$($T.AgentsRunning) $($T.AgentsNone)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Read-PowerSourceChoice {
    Write-Host $T.PowerSourceHeader -ForegroundColor Yellow
    Write-Host $T.PowerAC
    Write-Host $T.PowerDC
    Write-Host $T.PowerBoth
    Write-Host ""
    $powerChoice = Read-Host $T.PromptPower

    switch ($powerChoice) {
        "1" { return "AC" }
        "2" { return "DC" }
        "3" { return "Both" }
        default {
            Write-Host $T.InvalidDefaultAC -ForegroundColor Red
            return "AC"
        }
    }
}

# ── Mode Implementations ──────────────────────────────────────────────────────

function Install-SmartMode {
    <#
    .SYNOPSIS
        Smart Mode: register a scheduled task that monitors agent processes.
    #>
    Write-Host $T.SmartConfiguring -ForegroundColor Cyan
    Write-Host ""

    $powerSource = Read-PowerSourceChoice
    Write-Host ""

    # Save current settings
    Ensure-Registry
    $current = Get-CurrentLidAction
    Set-ItemProperty -Path $REG_BASE -Name "OriginalLidActionAC" -Value $current.AC -Force
    Set-ItemProperty -Path $REG_BASE -Name "OriginalLidActionDC" -Value $current.DC -Force
    Set-ItemProperty -Path $REG_BASE -Name "PowerSource" -Value $powerSource -Force
    Set-ItemProperty -Path $REG_BASE -Name "Mode" -Value "Smart" -Force

    Write-Host $T.SavedOriginal -ForegroundColor Green

    # If agents are running right now, apply immediately
    if (Test-AgentsRunning) {
        Set-LidAction -Value $LID_DO_NOTHING -PowerSource $powerSource
        Write-Host $T.AgentDetected -ForegroundColor Green
    }

    # Register scheduled task
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MONITOR_SCRIPT`" -PowerSource $powerSource"

    $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) `
        -RepetitionInterval (New-TimeSpan -Minutes 1) `
        -RepetitionDuration ([TimeSpan]::MaxValue)

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

    $descText = if ($Lang -eq 'zh') {
        "LidKeeper 智能模式：检测 AI agent 进程并自动管理合盖休眠行为"
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
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  $($T.SmartEnabled)" -ForegroundColor Green
    Write-Host ""
    Write-Host $T.SmartDesc1 -ForegroundColor White
    Write-Host $T.SmartDesc2 -ForegroundColor White
    Write-Host $T.SmartDesc3 -ForegroundColor White
    Write-Host "$($T.PowerSourceLabel) $powerSource" -ForegroundColor White
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
}

function Install-AlwaysOnMode {
    <#
    .SYNOPSIS
        Always-On Mode: disable lid-close sleep permanently.
    #>
    Write-Host $T.AlwaysConfiguring -ForegroundColor Cyan
    Write-Host ""

    $powerSource = Read-PowerSourceChoice
    Write-Host ""

    # Save current settings
    Ensure-Registry
    $current = Get-CurrentLidAction
    Set-ItemProperty -Path $REG_BASE -Name "OriginalLidActionAC" -Value $current.AC -Force
    Set-ItemProperty -Path $REG_BASE -Name "OriginalLidActionDC" -Value $current.DC -Force
    Set-ItemProperty -Path $REG_BASE -Name "PowerSource" -Value $powerSource -Force
    Set-ItemProperty -Path $REG_BASE -Name "Mode" -Value "AlwaysOn" -Force

    Set-LidAction -Value $LID_DO_NOTHING -PowerSource $powerSource

    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  $($T.AlwaysEnabled)" -ForegroundColor Green
    Write-Host ""
    Write-Host $T.AlwaysDesc1 -ForegroundColor White
    Write-Host "$($T.PowerSourceLabel) $powerSource" -ForegroundColor White
    Write-Host $T.AlwaysDesc2 -ForegroundColor White
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
}

function Uninstall-All {
    <#
    .SYNOPSIS
        Uninstall: remove scheduled task and restore original power settings.
    #>
    Write-Host $T.UninstallConfig -ForegroundColor Cyan
    Write-Host ""

    # Remove scheduled task
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
        Write-Host "$($T.TaskRemoved) $TASK_NAME" -ForegroundColor Green
    }
    else {
        Write-Host $T.TaskNotFound -ForegroundColor DarkGray
    }

    # Restore original power settings
    $hasOriginal = Test-Path $REG_BASE
    if ($hasOriginal) {
        $origAC = Get-ItemProperty -Path $REG_BASE -Name "OriginalLidActionAC" -ErrorAction SilentlyContinue
        $origDC = Get-ItemProperty -Path $REG_BASE -Name "OriginalLidActionDC" -ErrorAction SilentlyContinue

        if ($null -ne $origAC) {
            & powercfg /setacvalueindex SCHEME_CURRENT $SUB_BUTTONS_GUID $LID_ACTION_GUID $origAC.OriginalLidActionAC 2>&1 | Out-Null
            Write-Host "$($T.RestoredPlugged) $($LID_ACTION_NAMES[[int]$origAC.OriginalLidActionAC])" -ForegroundColor Green
        }
        if ($null -ne $origDC) {
            & powercfg /setdcvalueindex SCHEME_CURRENT $SUB_BUTTONS_GUID $LID_ACTION_GUID $origDC.OriginalLidActionDC 2>&1 | Out-Null
            Write-Host "$($T.RestoredBattery) $($LID_ACTION_NAMES[[int]$origDC.OriginalLidActionDC])" -ForegroundColor Green
        }

        & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null

        Remove-Item -Path $REG_BASE -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host $T.CleanedRegistry -ForegroundColor Green
    }
    else {
        Write-Host $T.NoOriginalSettings -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  $($T.UninstallDone)" -ForegroundColor Green
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Banner
Show-CurrentStatus

Write-Host $T.MenuHeader -ForegroundColor Yellow
Write-Host ""
Write-Host $T.ModeSmart     -ForegroundColor White
Write-Host $T.ModeAlwaysOn  -ForegroundColor White
Write-Host $T.ModeUninstall -ForegroundColor White
Write-Host $T.ModeExit      -ForegroundColor White
Write-Host ""

$choice = Read-Host $T.PromptChoice

switch ($choice) {
    "1" { Install-SmartMode }
    "2" { Install-AlwaysOnMode }
    "3" { Uninstall-All }
    "0" {
        Write-Host $T.Goodbye -ForegroundColor Cyan
        exit 0
    }
    default {
        Write-Host $T.InvalidChoice -ForegroundColor Red
        exit 1
    }
}

Write-Host $T.PressKeyExit -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
