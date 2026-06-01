# LidKeeper

> AI Agent 运行时，合上笔记本盖子也不会休眠。

[English](README.md)

## 功能介绍

LidKeeper 可以让你的 Windows 笔记本在**运行 AI Agent 时**合盖不休眠。当所有 Agent 退出后，系统自动恢复正常休眠行为。

### 两种模式

| 模式 | 行为 |
|------|------|
| **智能模式** | 每分钟检测 Agent 进程，仅在 Agent 运行时阻止合盖休眠 |
| **常开模式** | 始终阻止合盖休眠，无论 Agent 是否运行 |

### 支持的 Agent

| Agent | 进程名 |
|-------|--------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `claude` |
| [Codex](https://openai.com/index/codex/) | `Codex`、`codex` |
| [WorkBuddy](https://marvis.qq.com/) | `WorkBuddy` |

## 快速开始

### 一行命令安装（推荐）

打开 PowerShell 运行：

```powershell
irm https://raw.githubusercontent.com/Luchioxy/LidKeeper/main/install.ps1 | iex
```

这会：
1. 下载脚本到 `~/LidKeeper`
2. 添加 `lidkeeper` 命令到你的 PowerShell 配置
3. 启动交互式安装

安装后，在任何新的 PowerShell 窗口中输入 `lidkeeper` 即可重新运行设置（切换模式、卸载等）。

> **提示：** 建议以管理员身份运行，以确保所有功能正常。

### 手动安装

```powershell
# 克隆仓库
git clone https://github.com/Luchioxy/LidKeeper.git
cd LidKeeper

# 以管理员身份运行
.\setup.ps1
```

## 使用方法

1. 运行 `setup.ps1`（或双击 `LidKeeper.bat`）
2. 选择模式：
   - `[1]` 智能模式 — 自动检测 Agent，智能切换合盖行为
   - `[2]` 常开模式 — 始终阻止合盖休眠
   - `[3]` 卸载 — 移除所有设置，恢复默认
3. 选择电源场景（仅插电 / 仅电池 / 两者都）

脚本会在修改前保存你当前的电源设置，卸载时会自动恢复。

## 工作原理

- **智能模式**会注册一个 Windows 计划任务（`LidKeeper-Monitor`），每 1 分钟运行一次
- 任务检测是否有 Agent 进程正在运行
- 检测到 Agent → 通过 `powercfg` 将合盖动作设为「不执行任何操作」
- 未检测到 Agent → 恢复合盖动作为原始值
- 设置存储在注册表 `HKCU\SOFTWARE\LidKeeper`

## 卸载

运行 `setup.ps1` 选择 `[3] 卸载`，或手动执行：

```powershell
# 移除计划任务
Unregister-ScheduledTask -TaskName "LidKeeper-Monitor" -Confirm:$false

# 移除注册表配置
Remove-Item -Path "HKCU:\SOFTWARE\LidKeeper" -Recurse -Force
```

## 系统要求

- Windows 10/11
- PowerShell 5.1+
- 管理员权限（修改电源设置需要）

## 常见问题

**Q: 电池模式下也能用吗？**
A: 可以。安装时可以选择仅插电、仅电池或两者都生效。

**Q: 如果在下次检测前就合盖了怎么办？**
A: 计划任务每分钟检测一次。只要 Agent 在运行，合盖动作就已经设为「不执行任何操作」了，合盖不会触发休眠。

**Q: 能添加更多监控的进程吗？**
A: 编辑 `setup.ps1` 和 `lid-monitor.ps1` 中的 `$AGENT_PROCESSES` 数组即可。

**Q: 会不会很耗电？**
A: 智能模式下，只有 Agent 运行时才会阻止休眠。常开模式下，笔记本合盖后不会休眠，会持续耗电。

## 许可证

[MIT](LICENSE)
