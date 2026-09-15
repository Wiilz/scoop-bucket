# Sing-Box Windows

[返回软件清单](../README.md)

基于 Tauri 的 Sing-Box GUI 客户端，支持 x64 / ARM64，许可证为 MIT。

## 安装与更新

```powershell
scoop install lz-bucket/sing-box-windows
scoop update sing-box-windows
scoop uninstall sing-box-windows
```

**已有旧配置安装的用户，先阅读下方“旧安装的安全修复”，不要直接更新或卸载。**

- 直接解压官方 Portable ZIP，由 Scoop 创建 shim 和快捷方式，不运行安装器，也不包含自定义安装/卸载脚本。
- 依赖 WebView2 Runtime；Windows 11 通常已内置，缺失时需要另行安装。
- TUN 模式需要管理员权限，普通安装不需要因此改成全局安装。
- 使用 Scoop 更新，不使用应用内升级。上游应用内升级可能下载并运行 MSI/EXE 安装器，脱离 Scoop 的版本管理。
- 更新或卸载前，在应用中停止内核、关闭系统代理/TUN，并从托盘完整退出；关闭窗口不一定会退出后台进程。卸载前还应关闭已启用的开机自启。
- Scoop 主要检查其安装目录内的进程，不能依赖它检测位于 AppData 的独立内核。manifest 不强杀内核、不修改代理注册表，也不尝试自动恢复网络设置，避免影响其他代理软件。

## 数据位置与保留范围

| 路径 | 内容 |
|------|------|
| `%APPDATA%\cn.moncn.singbox` | SQLite 设置数据库、订阅信息、启动偏好、窗口状态 |
| `%LOCALAPPDATA%\sing-box-windows` | 内核、活动 `config.json`、`sing-box\configs` 下的订阅配置和备份、日志等 |
| `%LOCALAPPDATA%\cn.moncn.singbox` | WebView2 数据 |

`%LOCALAPPDATA%\sing-box-windows` **不只是缓存**，不能因“内核可重新下载”就整目录删除。

安装、更新和卸载脚本均不搬迁、覆盖或删除上述数据，也不声明 `persist`。跨版本继续使用 AppData 中的已有数据，不等于 Scoop 已提供备份；旧版可能存在的 `persist\sing-box-windows\appdata` 也不会自动恢复或同步。

需要备份时，先正常退出应用及内核，再备份 Roaming 设置目录和 Local 工作目录；不要在数据库仍写入时将数据库与 `-wal`、`-shm` 文件逐个复制后当作一致性快照。也可使用应用内导出功能作为补充，但应自行确认其覆盖范围。备份可能包含订阅地址、节点凭据等敏感信息，请妥善保存。

普通卸载只删除 Scoop 管理的程序、shim 和快捷方式，保留上述数据。`scoop uninstall -p` 也不会自动清理任意 AppData 目录，但会删除 Scoop 对应 persist 目录中的旧备份，使用前需确认。旧版本与下载缓存可按需通过 `scoop cleanup sing-box-windows`、`scoop cache rm sing-box-windows` 清理，它们不用于删除用户配置。

## 旧安装的安全修复

旧 `2.3.1` manifest 的 `pre_uninstall` 会将整个 `%LOCALAPPDATA%\sing-box-windows` 当作缓存删除，且更新时同样会执行。其备份仅覆盖 Roaming 数据，无法保护被删的 Local 配置。旧 `post_install` 还存在不完整恢复和旧备份混用风险。

**仅更新 bucket 不会修改已安装的 `manifest.json` 快照；同版本的普通 `scoop update` 也不保证应用修复。** 正确处理顺序：

1. 正常退出应用和内核，备份用户数据。不要先用 Scoop 卸载旧版。
2. 用 `scoop prefix sing-box-windows` 定位安装目录，备份其中的 `manifest.json`，保存到安装目录之外，例如 `<Scoop 根目录>\backups\sing-box-windows`，避免卸载时备份一并被删。
3. 在该安装快照中仅移除旧 `post_install` 和 `pre_uninstall` 字段，并保持 JSON 有效。若要替换成仓库中的完整修正版，必须先确认版本、各架构下载 URL/hash、解包布局、bin 和快捷方式等安装信息与旧快照一致；不同版本不可直接替换。
4. 确认快照不再含旧 hook 后，才执行必要的更新或卸载。不要通过重新启用旧清理脚本来“恢复备份”。全局安装需操作对应全局目录并使用匹配的权限。

本次修复仍为 `2.3.1`，下载地址、hash 和程序布局均未改变，不需要为了修复 hook 而重新下载或运行程序。修复发布到远程 bucket 前，不要从仍含旧脚本的 bucket 重装或升级，以免再次装入旧 hook。

## 回归测试

在本仓库根目录运行：

```powershell
powershell -NoProfile -File ./tests/sing-box-windows.Tests.ps1
```

[测试脚本](../tests/sing-box-windows.Tests.ps1)验证 schema、两种架构均无生命周期脚本，并通过 Scoop hook 调用函数检查假数据库、配置、内核、WebView2 数据和旧备份不会被搬迁或删除。提供与 manifest 版本匹配的官方 ZIP 时，还会验证 SHA256 和真实 Scoop 解包结果：

```powershell
powershell -NoProfile -File ./tests/sing-box-windows.Tests.ps1 -Archive64bit ./sing-box-windows-portable.zip -ArchiveArm64 ./sing-box-windows-arm64-portable.zip
```

也可用 `pwsh -NoProfile -File` 运行。测试只使用临时假数据，不启动 GUI/内核、不读写真实数据库、不改动网络，也不执行完整的系统安装/卸载；不替代实际代理、TUN、自启动及 GUI 功能验证。
