# LidKeeper

> Close your laptop lid, keep your AI agents running, and control them from your phone.

[中文说明](README_zh.md)

## The Problem

You're running Claude Code, Codex, or WorkBuddy on your laptop. You want to close the lid and walk away — maybe grab a coffee, move to the couch, or just keep your desk clean. But your OS may put the laptop to sleep when you close the lid, killing your agents mid-task.

## The Solution

LidKeeper prevents lid-close sleep **when your AI agents are running**. When all agents exit, normal sleep behavior resumes automatically. On desktop Macs, where there is no lid-close event, Smart Mode prevents idle sleep instead.

### The Workflow

```
1. Start Claude Code / Codex / WorkBuddy on your laptop
2. Close the lid — laptop stays awake
3. Walk away with your phone
4. Use SSH / remote desktop / web UI to monitor and control your agents
5. When done, open the lid — or just let the agents finish and the laptop sleeps
```

## Quick Start

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex
```

After installation, type `lidkeeper` to re-run setup.

### macOS / Linux (Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash
```

Non-interactive install:

```bash
# Smart Mode
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --smart

# Always-On Mode
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --always
```

Or clone and run manually:

```bash
git clone https://github.com/Luchioxy/LidKeeper.git
cd LidKeeper

# macOS
chmod +x macos/setup.sh && ./macos/setup.sh

# Linux
chmod +x linux/setup.sh && ./linux/setup.sh

# Windows
.\setup.ps1
```

## Modes

| Mode | Behavior |
|------|----------|
| **Smart Mode** | Monitors agent processes every minute. Lid-close or idle sleep is disabled only when agents are running. |
| **Always-On Mode** | Disables lid-close sleep permanently, or standby/autopoweroff sleep on desktop Macs. |

### Supported Agents

| Agent | Process Name |
|-------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `claude` |
| [Codex](https://openai.com/index/codex/) | `Codex` |
| [WorkBuddy](https://marvis.qq.com/) | `WorkBuddy` |

## Usage

### Windows

```powershell
# First time setup
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex

# Re-run setup anytime
lidkeeper
```

### macOS / Linux

```bash
# Interactive menu
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash

# Enable Smart Mode directly
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --smart

# Uninstall directly
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --uninstall
```

The setup menu gives you:
- `[1]` Smart Mode — auto-detects agents, toggles lid behavior
- `[2]` Always-On — permanently disable lid-close sleep
- `[3]` Uninstall — remove all settings, restore defaults
- `[4]` Configure Agents — manage monitored process list
- `[0]` Exit

## How It Works

- **Smart Mode** registers a Windows Scheduled Task (`LidKeeper-Monitor`) that runs every 1 minute
- The task checks if any agent process is running
- If agents are detected → sets lid-close action to "Do nothing" via `powercfg`
- If no agents are found → restores the original lid-close action
- Settings are stored in `HKCU\SOFTWARE\LidKeeper` (registry)
- Agent process list is stored in registry (`AgentProcesses` key) and read by the monitor script
- On macOS, a LaunchAgent runs every minute and uses `caffeinate` while agents are running
- On Linux, a systemd user timer runs every minute and uses `systemd-inhibit` while agents are running
- On macOS/Linux, the agent list is stored in `~/.lidkeeper/agents.conf`
- On desktop Macs such as Mac mini, there is no lid-close event; Smart Mode still prevents idle sleep while agents run

## Requirements

| Platform | Requirements |
|----------|-------------|
| **Windows** | Windows 10/11, PowerShell 5.1+, Administrator rights (auto-requested) |
| **macOS** | macOS 10.13+, bash, `caffeinate` (built-in), `launchctl` (built-in) |
| **Linux** | systemd, bash, `systemd-inhibit`, sudo access for Always-On mode |

## FAQ

**Q: Can I control my laptop from my phone after closing the lid?**
A: Yes! That's the main use case. Set up SSH, remote desktop, or use your agent's web UI. The laptop stays awake, so all network connections remain active.

**Q: Does this work on battery?**
A: On laptops, yes, but the exact power-source behavior depends on the platform. Windows manages AC and battery lid actions through power settings. macOS uses `caffeinate`, and Linux uses `systemd-inhibit`. Desktop Macs such as Mac mini have no battery or lid-close event.

**Q: What if I close the lid before the next check?**
A: Smart Mode checks every minute. After starting an agent, wait for the next check before closing the lid. Once the agent has been detected, sleep prevention stays active until all monitored agents exit.

**Q: Can I add more processes to monitor?**
A: Use `[4] Configure Agents` in the menu, or edit the config file directly:
- Windows: registry key `HKCU\SOFTWARE\LidKeeper\AgentProcesses` (comma-separated)
- macOS/Linux: `~/.lidkeeper/agents.conf` (one process name per line)

**Q: Will this drain my battery?**
A: In Smart Mode, the laptop only stays awake while agents are running. In Always-On Mode, yes — the laptop will not sleep on lid close.

## Uninstall

```powershell
lidkeeper
# Select [3] Uninstall
```

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --uninstall
```

Or manually:
```powershell
Unregister-ScheduledTask -TaskName "LidKeeper-Monitor" -Confirm:$false
Remove-Item -Path "HKCU:\SOFTWARE\LidKeeper" -Recurse -Force
```

## License

[MIT](LICENSE)
