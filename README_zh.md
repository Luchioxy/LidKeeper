# LidKeeper

> 合上笔记本盖子，AI Agent 继续运行，用手机远程操控。

[English](README.md)

## 痛点

你在笔记本上跑着 Claude Code、Codex 或 WorkBuddy。想合上盖子走人——去倒杯咖啡、躺沙发上、或者只是收拾桌面。但操作系统可能会在合盖时让笔记本休眠，Agent 任务直接中断。

## 解决方案

LidKeeper **在 AI Agent 运行时阻止合盖休眠**。当所有 Agent 退出后，系统自动恢复正常休眠行为。在没有合盖事件的台式 Mac 上，智能模式会改为阻止空闲休眠。

### 使用场景

```
1. 在笔记本上启动 Claude Code / Codex / WorkBuddy
2. 合上盖子 — 笔记本保持运行
3. 带着手机离开
4. 用 SSH / 远程桌面 / Web UI 监控和操控 Agent
5. 任务完成后打开盖子 — 或者等 Agent 自动结束，笔记本自动休眠
```

## 快速开始

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex
```

安装后输入 `lidkeeper` 重新运行设置。

### macOS / Linux (Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash
```

非交互安装：

```bash
# 智能模式
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --smart

# 常开模式
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --always
```

或克隆后手动运行：

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

## 模式

| 模式 | 行为 |
|------|------|
| **智能模式** | 每分钟检测 Agent 进程，仅在 Agent 运行时阻止合盖或空闲休眠 |
| **常开模式** | 始终阻止合盖休眠；在台式 Mac 上禁用 standby/autopoweroff 休眠 |

### 支持的 Agent

| Agent | 进程名 |
|-------|--------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `claude` |
| [Codex](https://openai.com/index/codex/) | `Codex` |
| [WorkBuddy](https://marvis.qq.com/) | `WorkBuddy` |

## 使用方法

### Windows

```powershell
# 首次安装
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex

# 随时重新设置
lidkeeper
```

### macOS / Linux

```bash
# 交互式菜单
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash

# 直接启用智能模式
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --smart

# 直接卸载
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --uninstall
```

设置菜单提供：
- `[1]` 智能模式 — 自动检测 Agent，智能切换合盖行为
- `[2]` 常开模式 — 始终阻止合盖休眠
- `[3]` 卸载 — 移除所有设置，恢复默认
- `[4]` 配置 Agent — 管理监控的进程列表
- `[0]` 退出

## 工作原理

- **智能模式**注册一个 Windows 计划任务（`LidKeeper-Monitor`），每 1 分钟运行一次
- 任务检测是否有 Agent 进程正在运行
- 检测到 Agent → 通过 `powercfg` 将合盖动作设为「不执行任何操作」
- 未检测到 Agent → 恢复合盖动作为原始值
- 设置存储在注册表 `HKCU\SOFTWARE\LidKeeper`
- Agent 进程列表存储在注册表 `AgentProcesses` 键中，由监控脚本读取
- macOS 通过 LaunchAgent 每分钟运行一次，并在 Agent 运行时使用 `caffeinate` 阻止休眠
- Linux 通过 systemd 用户定时器每分钟运行一次，并在 Agent 运行时使用 `systemd-inhibit` 阻止休眠
- macOS/Linux 的 Agent 列表存储在 `~/.lidkeeper/agents.conf`
- Mac mini 等台式 Mac 没有合盖事件；智能模式仍可在 Agent 运行时阻止空闲休眠

## 系统要求

| 平台 | 要求 |
|------|------|
| **Windows** | Windows 10/11，PowerShell 5.1+，管理员权限（自动请求） |
| **macOS** | macOS 10.13+，bash，`caffeinate`（内置），`launchctl`（内置） |
| **Linux** | systemd，bash，`systemd-inhibit`，常开模式需要 sudo 权限 |

## 常见问题

**Q: 合上盖子后还能用手机控制笔记本吗？**
A: 可以！这就是主要使用场景。配置好 SSH、远程桌面或 Agent 的 Web UI，笔记本保持运行，所有网络连接都不会断。

**Q: 电池模式下也能用吗？**
A: 笔记本可以，但具体电源行为取决于平台。Windows 通过电源设置管理插电和电池状态下的合盖动作；macOS 使用 `caffeinate`，Linux 使用 `systemd-inhibit`。Mac mini 等台式 Mac 没有电池，也没有合盖事件。

**Q: 如果在下次检测前就合盖了怎么办？**
A: 智能模式每分钟检测一次。启动 Agent 后，建议等到下一次检测完成再合盖；一旦检测到 Agent，阻止休眠会持续生效，直到所有被监控的 Agent 退出。

**Q: 能添加更多监控的进程吗？**
A: 使用菜单中的 `[4] 配置 Agent`，或直接编辑配置文件：
- Windows：注册表 `HKCU\SOFTWARE\LidKeeper\AgentProcesses`（逗号分隔）
- macOS/Linux：`~/.lidkeeper/agents.conf`（每行一个进程名）

**Q: 会不会很耗电？**
A: 智能模式下，只有 Agent 运行时才会阻止休眠。常开模式下，笔记本合盖后不会休眠，会持续耗电。

## 卸载

```powershell
lidkeeper
# 选择 [3] 卸载
```

macOS / Linux：

```bash
curl -fsSL https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.sh | bash -s -- --uninstall
```

或手动：
```powershell
Unregister-ScheduledTask -TaskName "LidKeeper-Monitor" -Confirm:$false
Remove-Item -Path "HKCU:\SOFTWARE\LidKeeper" -Recurse -Force
```

## 许可证

[MIT](LICENSE)
