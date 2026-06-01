# LidKeeper

> Keep your laptop awake when AI agents are running. No more interrupted tasks on lid close.

[中文说明](README_zh.md)

## What It Does

LidKeeper prevents your Windows laptop from sleeping when you close the lid **if** an AI agent (Claude Code, Codex, WorkBuddy) is actively running. When all agents exit, normal sleep behavior resumes automatically.

### Two Modes

| Mode | Behavior |
|------|----------|
| **Smart Mode** | Monitors agent processes every minute. Lid-close sleep is disabled only when agents are running. |
| **Always-On Mode** | Disables lid-close sleep permanently. Use when you want the laptop awake regardless of agents. |

### Supported Agents

| Agent | Process Name |
|-------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `claude` |
| [Codex](https://openai.com/index/codex/) | `Codex`, `codex` |
| [WorkBuddy](https://marvis.qq.com/) | `WorkBuddy` |

## Quick Start

### One-Line Install (Recommended)

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex
```

This will:
1. Download scripts to `~/LidKeeper`
2. Add a `lidkeeper` command to your PowerShell profile
3. Launch the interactive setup

After installation, just type `lidkeeper` in any new PowerShell window to re-run setup (change mode, uninstall, etc.).

> **Note:** Run as Administrator for full functionality.

### Manual Install

```powershell
# Clone the repo
git clone https://github.com/Luchioxy/LidKeeper.git
cd LidKeeper

# Run setup (as Administrator)
.\setup.ps1
```

## Usage

1. Run `setup.ps1` (or double-click `LidKeeper.bat`)
2. Select a mode:
   - `[1]` Smart Mode — auto-detects agents, toggles lid behavior
   - `[2]` Always-On — permanently disable lid-close sleep
   - `[3]` Uninstall — remove all settings, restore defaults
3. Choose power source (plugged in / battery / both)

That's it. The script saves your original settings before making changes, so uninstalling always restores the previous state.

## How It Works

- **Smart Mode** registers a Windows Scheduled Task (`LidKeeper-Monitor`) that runs every 1 minute
- The task checks if any agent process is running
- If agents are detected → sets lid-close action to "Do nothing" via `powercfg`
- If no agents are found → restores the original lid-close action
- Settings are stored in `HKCU\SOFTWARE\LidKeeper` (registry)

## Uninstall

Run `setup.ps1` and select `[3] Uninstall`, or:

```powershell
# Remove the scheduled task
Unregister-ScheduledTask -TaskName "LidKeeper-Monitor" -Confirm:$false

# Remove registry config
Remove-Item -Path "HKCU:\SOFTWARE\LidKeeper" -Recurse -Force
```

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Administrator rights (for modifying power settings)

## FAQ

**Q: Does this work with the laptop on battery?**
A: Yes. You choose whether it applies to plugged-in, battery, or both during setup.

**Q: What if I close the lid before the next check?**
A: The task checks every minute. If an agent is running, the lid action is already set to "Do nothing" — closing the lid won't trigger sleep.

**Q: Can I add more processes to monitor?**
A: Edit the `$AGENT_PROCESSES` array in `setup.ps1` and `lid-monitor.ps1`.

**Q: Will this drain my battery?**
A: In Smart Mode, the laptop only stays awake while agents are running. In Always-On Mode, yes — the laptop will not sleep on lid close.

## License

[MIT](LICENSE)
