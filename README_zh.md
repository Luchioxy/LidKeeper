# LidKeeper

> 合上笔记本盖子，AI Agent 继续运行，用手机远程操控。

[English](README.md)

## 痛点

你在笔记本上跑着 Claude Code、Codex 或 WorkBuddy。想合上盖子走人——去倒杯咖啡、躺沙发上、或者只是收拾桌面。但 Windows 一合盖就休眠，Agent 任务直接中断。

## 解决方案

LidKeeper 拦截合盖事件，**在 AI Agent 运行时阻止休眠**。当所有 Agent 退出后，系统自动恢复正常休眠行为。

### 使用场景

```
1. 在笔记本上启动 Claude Code / Codex / WorkBuddy
2. 合上盖子 — 笔记本保持运行
3. 带着手机离开
4. 用 SSH / 远程桌面 / Web UI 监控和操控 Agent
5. 任务完成后打开盖子 — 或者等 Agent 自动结束，笔记本自动休眠
```

## 快速开始

### 一行命令安装

打开 PowerShell 运行：

```powershell
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex
```

这会：
1. 下载脚本到 `~/LidKeeper`
2. 添加 `lidkeeper` 命令到你的 PowerShell 配置
3. 启动交互式安装

安装后，在任何 PowerShell 窗口输入 `lidkeeper` 即可重新运行设置。

> **提示：** 脚本会自动请求管理员权限（注册计划任务需要）。

### 手动安装

```powershell
git clone https://github.com/Luchioxy/LidKeeper.git
cd LidKeeper
.\setup.ps1
```

## 模式

| 模式 | 行为 |
|------|------|
| **智能模式** | 每分钟检测 Agent 进程，仅在 Agent 运行时阻止合盖休眠 |
| **常开模式** | 始终阻止合盖休眠 |

### 支持的 Agent

| Agent | 进程名 |
|-------|--------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `claude` |
| [Codex](https://openai.com/index/codex/) | `Codex` |
| [WorkBuddy](https://marvis.qq.com/) | `WorkBuddy` |

## 使用方法

```powershell
# 首次安装
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex

# 随时重新设置
lidkeeper
```

`lidkeeper` 命令提供：
- `[1]` 智能模式 — 自动检测 Agent，智能切换合盖行为
- `[2]` 常开模式 — 始终阻止合盖休眠
- `[3]` 卸载 — 移除所有设置，恢复默认
- `[0]` 退出

## 工作原理

- **智能模式**注册一个 Windows 计划任务（`LidKeeper-Monitor`），每 1 分钟运行一次
- 任务检测是否有 Agent 进程正在运行
- 检测到 Agent → 通过 `powercfg` 将合盖动作设为「不执行任何操作」
- 未检测到 Agent → 恢复合盖动作为原始值
- 设置存储在注册表 `HKCU\SOFTWARE\LidKeeper`

## 系统要求

- Windows 10/11
- PowerShell 5.1+
- 管理员权限（脚本会自动请求）

## 常见问题

**Q: 合上盖子后还能用手机控制笔记本吗？**
A: 可以！这就是主要使用场景。配置好 SSH、远程桌面或 Agent 的 Web UI，笔记本保持运行，所有网络连接都不会断。

**Q: 电池模式下也能用吗？**
A: 可以。安装时可以选择仅插电、仅电池或两者都生效。

**Q: 如果在下次检测前就合盖了怎么办？**
A: 计划任务每分钟检测一次。只要 Agent 在运行，合盖动作就已经设为「不执行任何操作」了，合盖不会触发休眠。

**Q: 能添加更多监控的进程吗？**
A: 编辑 `setup.ps1` 和 `lid-monitor.ps1` 中的 `$AGENT_PROCESSES` 数组即可。

**Q: 会不会很耗电？**
A: 智能模式下，只有 Agent 运行时才会阻止休眠。常开模式下，笔记本合盖后不会休眠，会持续耗电。

## 卸载

```powershell
lidkeeper
# 选择 [3] 卸载
```

或手动：
```powershell
Unregister-ScheduledTask -TaskName "LidKeeper-Monitor" -Confirm:$false
Remove-Item -Path "HKCU:\SOFTWARE\LidKeeper" -Recurse -Force
```

## 许可证

[MIT](LICENSE)
