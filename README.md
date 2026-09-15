# scoop-bucket

自用 Scoop bucket，用于安装和管理 `aoci-code`、`redisee`、`wechat-devtools`、`sing-box-windows` 等应用，以及 `SFMono-NF`、PingFang SC / TC / HK / MO 字体。

## 使用方法

### 添加 bucket

```powershell
scoop bucket add lz-bucket https://github.com/Wiilz/scoop-bucket
```

### 安装软件

```powershell
# 安装 AOCI-CODE（CLI / MCP 服务，自动按 x64/arm64 选择）
scoop install lz-bucket/aoci-code

# 验证与更新（包名为 aoci-code，命令为 aoci）
aoci --version
scoop update aoci-code

# 安装 redisee（Redis 桌面客户端，便携版，自动按 x64/arm64 选择）
scoop install redisee

# 更新
scoop update redisee

# 安装 wechat-devtools（微信开发者工具，自动按 x64/ia32 选择）
scoop install wechat-devtools

# 更新
scoop update wechat-devtools

# 安装 sing-box-windows（Sing-Box GUI 客户端，便携版，自动按 x64/arm64 选择）
scoop install sing-box-windows

# 更新
scoop update sing-box-windows
```

## AOCI-CODE 管理说明

- 采用官方 Windows ZIP，声明式解压并由 Scoop 创建 `aoci` shim；不运行上游安装脚本，不写注册表，不搬迁 AppData，不自动初始化项目或配置 MCP。
- 当前上游只有 RC 预发布版，本包跟踪最新发布（包含 RC 和正式版），并从同一 Release 的 `SHA256SUMS` 获取更新校验值。许可证为 **FSL-1.1-MIT**，属于源码可用许可，不应当作当前已采用 MIT 的开源软件。
- 扫描 Git 仓库需要 `git` 在 PATH 中可用；manifest 仅提供安装建议，不强制重复安装已有的 Git。不需要 Go、Node.js 或 Python 运行环境。
- 更新前完成或妥善处理项目中的未完成事务，并关闭相关 AOCI MCP 服务及 UI 进程；更新后重新启动相关服务，正在运行的旧进程不会自动切换版本。
- MCP 配置推荐使用稳定绝对路径：运行 `Join-Path (scoop prefix aoci-code) 'aoci.exe'` 获取路径，避免绑定具体版本目录。已有手动安装不会自动迁移，可用 `Get-Command aoci -All` 检查路径冲突，并手动更新旧 MCP 配置。
- `scoop uninstall aoci-code` 仅移除 Scoop 管理的程序和 shim；不删除项目中的 `.aoci/`、索引或宿主配置，也不清理应用运行时产生的用户缓存。项目数据本就在安装目录外，因此无需 `persist`。

本仓库已有 Excavator 工作流，每天检查并更新 manifest；工作流在远程正常运行并推送更新后，本机仍需执行 `scoop update aoci-code`，不会在后台自动升级应用。

尚未推送到远程 bucket 时，可在本仓库根目录测试安装：

```powershell
scoop install .\bucket\aoci-code.json
aoci --version
scoop uninstall aoci-code
```

## 字体管理

以下说明适用于 `SFMono-NF` 和四个 `pingfang-*` 包。

### 默认安装到当前用户

Windows 10 1809+ 和 Windows 11 默认支持用户级安装，无需管理员权限，也无需安装 `sudo`。用户字体目录会设置应用包读取/执行权限（ACL），不再因 Windows 11 22H2+ 而强制全局安装。Windows 10 1809 之前仍需全局安装。

```powershell
# SF Mono 字体 + Nerd Fonts 补丁
scoop install lz-bucket/SFMono-NF

# PingFang 简体中文；按需选择变体，不必全部安装
scoop install lz-bucket/pingfang-sc
# scoop install lz-bucket/pingfang-tc  # 台湾繁体
# scoop install lz-bucket/pingfang-hk  # 香港繁体
# scoop install lz-bucket/pingfang-mo  # 澳门繁体

# 更新（其他字体包同理）
scoop update SFMono-NF
scoop update pingfang-sc

# 不再需要时卸载
scoop uninstall SFMono-NF
scoop uninstall pingfang-sc
```

PingFang 每个变体包含 Light、Medium、Regular、Semibold、Thin、Ultralight 六个字重。其 manifest 标记为 `Proprietary`（专有许可），使用或分发前请自行确认授权；上游仓库公开不代表字体可以任意使用或分发。

### 用户安装与全局安装

| 安装范围 | 字体目录 | 字体注册表位置 | 权限 |
|----------|----------|----------------|------|
| 当前用户（默认） | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` | HKCU | 普通用户 |
| 所有用户（显式 `-g`） | `%windir%\Fonts` | HKLM | 管理员 |

注册表项位于上述根键的 `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` 下。用户安装仍会复制字体并写入 HKCU，并非只解压到 Scoop 目录，但不会写入系统字体目录或 HKLM。

需要所有用户共享，或使用 Windows 10 1809 之前的系统时，在管理员终端使用 `-g`；更新和卸载也应保持相同范围：

```powershell
scoop install -g lz-bucket/SFMono-NF
scoop update -g SFMono-NF
scoop uninstall -g SFMono-NF
```

### 卸载与占用处理

字体清理在 `pre_uninstall` 中执行，以规避部分 Scoop 版本在调用 `uninstaller.script` 时错误传递 `-Global` 的问题。日志会显示实际清理的目录和 HKCU / HKLM 范围。

卸载会先校验对应注册项的归属，再移除注册项、释放 Windows 字体资源并发送字体变更通知，最后删除字体文件；不再用“无法独占打开文件”直接判定卸载失败，也不会静默忽略删除错误。

- **卸载成功但应用仍显示字体**：先重启该应用，可能是应用缓存；也可能还安装了其他同名字体。
- **提示 `file cleanup is incomplete`**：对应注册项已移除，但部分文件仍待清理。关闭使用字体的应用，必要时重启 Windows，再执行相同范围的卸载命令。清理完成前不要重新安装，以免重新注册字体；仍失败时查看错误详情和文件权限。
- **注册项指向其他位置**：脚本会中止，不会删除该冲突安装；应先检查是否存在手动安装或其他来源的同名字体。

以当前用户安装的 PingFang SC 为例，成功卸载后可检查文件和注册项，两条检查均应无输出：

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'PingFangSC-*.otf'
(Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts').PSObject.Properties |
    Where-Object Name -Like 'PingFangSC-*' |
    Select-Object Name, Value
```

### 旧版本修复与全局版迁移

**Scoop 卸载读取的是安装目录内的 `manifest.json` 快照，更新 bucket 不会自动更新旧安装的快照。** 因此，旧安装可能仍使用旧的全局安装限制、占用检查或卸载脚本。

需要为旧安装应用脚本修复时，先备份 `<Scoop 根目录>\apps\<包名>\current\manifest.json`，并确认修正版的版本、下载 URL、hash 和解压目录与已安装包一致，再替换快照。全局安装需要操作全局 Scoop 根目录下的快照，并使用管理员权限。不要直接用不同版本的 manifest 覆盖旧安装记录。

已有的全局安装不会自动迁移为用户安装。应先按需更新旧快照，再在管理员终端卸载全局版，确认文件和注册项清理完成后，回到普通终端安装用户版。例如先执行 `scoop uninstall -g SFMono-NF`，成功后再执行 `scoop install lz-bucket/SFMono-NF`。

如果旧脚本已经报告卸载成功、Scoop 安装记录已消失，但对应字体文件和注册项仍有残留，可以使用同版本的修正版 manifest 在原安装范围内重新安装后再卸载。不要混用用户和全局范围。

尚未发布到远程 bucket 的修复，可在本仓库根目录使用本地 manifest 测试：

```powershell
# 适用于该范围内当前尚未安装的包；已有安装应先处理其旧快照
scoop install .\bucket\pingfang-sc.json
scoop uninstall pingfang-sc
```

从全局字体迁移到用户字体期间，使用该字体的终端或编辑器可能需要临时切换字体，并在迁移完成后重启应用。

## 包含的软件

| 软件 | 描述 |
|------|------|
| [aoci-code](https://github.com/aoci-spec/aoci-code) | 面向 AI 编码代理的代码与数据库知识 CLI / MCP 服务（FSL-1.1-MIT，支持 x64/arm64，包含 RC 更新） |
| [redisee](https://redisee.com/zh) | 现代化的 Redis 桌面客户端（闭源 freemium，便携版，支持 x64/arm64） |
| [wechat-devtools](https://developers.weixin.qq.com/miniprogram/dev/devtools/devtools.html) | 微信开发者工具（闭源 Freeware，支持 x64/ia32） |
| [sing-box-windows](https://github.com/xinggaoya/sing-box-windows) | 基于 Tauri 2.0 的 Sing-Box GUI 客户端（MIT 开源，便携版，支持 x64/arm64） |
| [SFMono-NF](https://github.com/epk/SF-Mono-Nerd-Font) | Apple SF Mono 字体 + Nerd Fonts 补丁（MIT，默认当前用户安装） |
| [pingfang-sc](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 简体中文，6 个字重（Proprietary，默认当前用户安装） |
| [pingfang-tc](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 台湾繁体，6 个字重（Proprietary，默认当前用户安装） |
| [pingfang-hk](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 香港繁体，6 个字重（Proprietary，默认当前用户安装） |
| [pingfang-mo](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 澳门繁体，6 个字重（Proprietary，默认当前用户安装） |

## 字体回归测试

在 Windows 上安装 Scoop 后，从本仓库根目录运行。每条命令启动独立 PowerShell 进程，以隔离测试用的原生 API 替身和类型定义：

```powershell
# Windows PowerShell 5.1
powershell -NoProfile -File .\tests\sfmono-install.Tests.ps1
powershell -NoProfile -File .\tests\pingfang-uninstall.Tests.ps1

# 如已安装 PowerShell 7，也可使用 pwsh 验证
pwsh -NoProfile -File .\tests\sfmono-install.Tests.ps1
pwsh -NoProfile -File .\tests\pingfang-uninstall.Tests.ps1
```

- `sfmono-install.Tests.ps1`：验证 SFMono-NF 的用户/全局安装、Windows 版本判断、ACL 设置及安装失败处理。
- `pingfang-uninstall.Tests.ps1`：覆盖四个 PingFang 变体和 SFMono-NF，验证 Scoop 调用链中的安装范围、更新时的卸载路径、字体资源释放、文件占用、清理重试及注册项归属保护。

测试读取本机 Scoop 的 hook 函数，使用临时文件、模拟注册表、模拟字体 API 和 ACL 写入，不会实际安装或卸载系统字体，也不会修改 Scoop 程序。测试通过不替代真实字体可见性及安装/卸载验证。
