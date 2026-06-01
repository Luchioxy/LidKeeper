#Requires -Version 5.1
<#
.SYNOPSIS
    LidKeeper Smart Mode monitor script.
    Called by Windows Scheduled Task every 1 minute.
    智能模式监控脚本，由计划任务每 1 分钟调用一次。
.DESCRIPTION
    Checks if AI agent processes are running:
    - Agents running  -> disable lid-close sleep (set to "Do nothing")
    - No agents       -> restore original lid-close behavior
    检测 AI agent 进程：有运行则禁用合盖休眠，无则恢复原始行为。
.NOTES
    This script is called automatically by the scheduled task.
    此脚本由计划任务自动调用，无需手动运行。
    Parameters: -PowerSource <AC|DC|Both>
#>

param(
    [ValidateSet("AC", "DC", "Both")]
    [string]$PowerSource = "Both"
)

# ── Configuration ──────────────────────────────────────────────────────────────

$REG_BASE       = "HKCU\SOFTWARE\LidKeeper"
$TASK_NAME      = "LidKeeper-Monitor"

# Agent process names (Get-Process is case-insensitive on Windows)
# Agent 进程名列表（Get-Process 在 Windows 上不区分大小写）
$AGENT_PROCESSES = @("claude", "Codex", "WorkBuddy")

# Lid action values / 合盖动作值
$LID_DO_NOTHING = 0

# Power scheme GUIDs (sub-group and setting are fixed)
# 电源方案 GUID（子组和设置是固定的）
$SUB_BUTTONS_GUID = "4f971e89-eebd-4455-a8de-9e59040e7347"
$LID_ACTION_GUID  = "5ca83367-6e45-459f-a27b-476b1d01c936"

# ── Helper Functions ───────────────────────────────────────────────────────────

function Get-ActivePowerSchemeGUID {
    <#
    .SYNOPSIS
        Get the GUID of the currently active power scheme.
        获取当前活动电源方案的 GUID。
    #>
    try {
        $output = & powercfg /getactivescheme 2>&1
        if ($output -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
            return $Matches[1]
        }
    }
    catch {}
    return "381b4222-f694-41f0-9685-ff5bb260df2e"  # Fallback: Balanced
}

function Get-LidActionRegPath {
    $schemeGUID = Get-ActivePowerSchemeGUID
    return "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$schemeGUID\$SUB_BUTTONS_GUID\$LID_ACTION_GUID"
}

function Get-OriginalLidAction {
    <#
    .SYNOPSIS
        Read original lid action from LidKeeper registry.
        从 LidKeeper 注册表读取原始合盖动作设置。
    #>
    $result = @{ AC = 1; DC = 1 }  # Default: Sleep / 默认睡眠
    try {
        $props = Get-ItemProperty -Path $REG_BASE -ErrorAction Stop
        if ($null -ne $props.OriginalLidActionAC) {
            $result.AC = [int]$props.OriginalLidActionAC
        }
        if ($null -ne $props.OriginalLidActionDC) {
            $result.DC = [int]$props.OriginalLidActionDC
        }
    }
    catch {
        # Registry key not found, use defaults / 注册表键不存在，使用默认值
    }
    return $result
}

function Set-LidAction {
    <#
    .SYNOPSIS
        Set lid-close action via powercfg.
        通过 powercfg 设置合盖动作。
    .PARAMETER Value  0=Do nothing, 1=Sleep, 2=Hibernate, 3=Shutdown
    .PARAMETER PowerSource  "AC", "DC", or "Both"
    #>
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
    <#
    .SYNOPSIS
        Check if any AI agent process is running.
        检测是否有 AI agent 进程正在运行。
    #>
    foreach ($name in $AGENT_PROCESSES) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            return $true
        }
    }
    return $false
}

# ── Main Logic ────────────────────────────────────────────────────────────────

# Exit if task is disabled (user may have manually disabled it)
# 如果任务被禁用则退出
$task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($task -and $task.State -eq "Disabled") {
    exit 0
}

# Read original settings / 获取原始设置
$original = Get-OriginalLidAction

# Check agent processes / 检测 agent 进程
$agentsRunning = Test-AgentsRunning

# Read current system lid action from registry (uses active scheme)
# 从注册表读取当前系统合盖设置（使用活动方案）
$regPath = Get-LidActionRegPath
$currentAC = $original.AC
$currentDC = $original.DC
try {
    $sysProps = Get-ItemProperty -Path $regPath -ErrorAction Stop
    if ($null -ne $sysProps.ACSettingIndex) { $currentAC = [int]$sysProps.ACSettingIndex }
    if ($null -ne $sysProps.DCSettingIndex) { $currentDC = [int]$sysProps.DCSettingIndex }
} catch {}

if ($agentsRunning) {
    # Agents running -> ensure lid doesn't sleep (only call powercfg if not already set)
    # 有 agent 在运行 → 确保合盖不休眠（仅在未设置时才调用 powercfg）
    $needsChange = $false
    if ($PowerSource -eq "AC" -or $PowerSource -eq "Both") {
        if ($currentAC -ne $LID_DO_NOTHING) { $needsChange = $true }
    }
    if ($PowerSource -eq "DC" -or $PowerSource -eq "Both") {
        if ($currentDC -ne $LID_DO_NOTHING) { $needsChange = $true }
    }
    if ($needsChange) {
        Set-LidAction -Value $LID_DO_NOTHING -PowerSource $PowerSource
    }
}
else {
    # No agents -> restore original settings (only if currently different)
    # 无 agent 在运行 → 恢复原始设置（仅在当前不是原始值时才恢复）
    $needsRestore = $false
    if ($PowerSource -eq "AC" -or $PowerSource -eq "Both") {
        if ($currentAC -ne $original.AC) { $needsRestore = $true }
    }
    if ($PowerSource -eq "DC" -or $PowerSource -eq "Both") {
        if ($currentDC -ne $original.DC) { $needsRestore = $true }
    }
    if ($needsRestore) {
        if ($PowerSource -eq "AC" -or $PowerSource -eq "Both") {
            Set-LidAction -Value $original.AC -PowerSource "AC"
        }
        if ($PowerSource -eq "DC" -or $PowerSource -eq "Both") {
            Set-LidAction -Value $original.DC -PowerSource "DC"
        }
    }
}
