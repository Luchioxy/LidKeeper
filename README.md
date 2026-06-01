# LidKeeper

> Close your laptop lid, keep your AI agents running, and control them from your phone.

[中文说明](README_zh.md)

## The Problem

You're running Claude Code, Codex, or WorkBuddy on your laptop. You want to close the lid and walk away — maybe grab a coffee, move to the couch, or just keep your desk clean. But Windows puts the laptop to sleep when you close the lid, killing your agents mid-task.

## The Solution

LidKeeper intercepts the lid-close event and prevents sleep **when your AI agents are running**. When all agents exit, normal sleep behavior resumes automatically.

### The Workflow

```
1. Start Claude Code / Codex / WorkBuddy on your laptop
2. Close the lid — laptop stays awake
3. Walk away with your phone
4. Use SSH / remote desktop / web UI to monitor and control your agents
5. When done, open the lid — or just let the agents finish and the laptop sleeps
```

## Quick Start

### One-Line Install

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex
```

This will:
1. Download scripts to `~/LidKeeper`
2. Add a `lidkeeper` command to your PowerShell profile
3. Launch the interactive setup

After installation, just type `lidkeeper` in any PowerShell window to re-run setup.

> **Note:** The script will auto-request admin privileges when needed.

### Manual Install

```powershell
git clone https://github.com/Luchioxy/LidKeeper.git
cd LidKeeper
.\setup.ps1
```

## Modes

| Mode | Behavior |
|------|----------|
| **Smart Mode** | Monitors agent processes every minute. Lid-close sleep is disabled only when agents are running. |
| **Always-On Mode** | Disables lid-close sleep permanently. |

### Supported Agents

| Agent | Process Name |
|-------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `claude` |
| [Codex](https://openai.com/index/codex/) | `Codex` |
| [WorkBuddy](https://marvis.qq.com/) | `WorkBuddy` |

## Usage

```powershell
# First time setup
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex

# Re-run setup anytime
lidkeeper
```

The `lidkeeper` command gives you:
- `[1]` Smart Mode — auto-detects agents, toggles lid behavior
- `[2]` Always-On — permanently disable lid-close sleep
- `[3]` Uninstall — remove all settings, restore defaults
- `[0]` Exit

## How It Works

- **Smart Mode** registers a Windows Scheduled Task (`LidKeeper-Monitor`) that runs every 1 minute
- The task checks if any agent process is running
- If agents are detected → sets lid-close action to "Do nothing" via `powercfg`
- If no agents are found → restores the original lid-close action
- Settings are stored in `HKCU\SOFTWARE\LidKeeper` (registry)

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Administrator rights (auto-requested if needed)

## FAQ

**Q: Can I control my laptop from my phone after closing the lid?**
A: Yes! That's the main use case. Set up SSH, remote desktop, or use your agent's web UI. The laptop stays awake, so all network connections remain active.

**Q: Does this work on battery?**
A: Yes. You choose whether it applies to plugged-in, battery, or both during setup.

**Q: What if I close the lid before the next check?**
A: The task checks every minute. If an agent is running, the lid action is already set to "Do nothing" — closing the lid won't trigger sleep.

**Q: Can I add more processes to monitor?**
A: Edit the `$AGENT_PROCESSES` array in `setup.ps1` and `lid-monitor.ps1`.

**Q: Will this drain my battery?**
A: In Smart Mode, the laptop only stays awake while agents are running. In Always-On Mode, yes — the laptop will not sleep on lid close.

## Uninstall

```powershell
lidkeeper
# Select [3] Uninstall
```

Or manually:
```powershell
Unregister-ScheduledTask -TaskName "LidKeeper-Monitor" -Confirm:$false
Remove-Item -Path "HKCU:\SOFTWARE\LidKeeper" -Recurse -Force
```

## License

[MIT](LICENSE)
