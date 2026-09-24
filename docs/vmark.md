# VMark

[返回软件清单](../README.md)

面向人类与 AI 协作的纯文本工作区，支持 Markdown 所见即所得编辑、多格式预览和 MCP 集成。许可证为 ISC；当前官方 Windows 发布包仅提供 x64。

## 安装与更新

```powershell
scoop install lz-bucket/vmark
scoop update vmark
scoop uninstall vmark
```

- 直接解压官方 NSIS 安装包，保留 `vmark.exe`、`vmark-mcp-server.exe` 和 `resources`，仅删除安装器插件与卸载器。不运行官方安装/卸载程序，不自动注册文件关联。
- Scoop 创建 `vmark` 命令和 **VMark** 开始菜单快捷方式。需要文件关联时，可自行在 Windows“打开方式”中选择 `scoop prefix vmark` 所指目录中的 `vmark.exe`。
- 依赖 Microsoft Edge WebView2 Runtime；Windows 11 通常已内置，缺失时需先安装。
- 使用 `scoop update vmark` 更新，不使用应用内更新按钮，以免运行上游安装器、脱离 Scoop 管理。本包未修改程序或强制禁用其更新检查。
- 更新、卸载前先保存文档并完整退出应用；启用关闭到托盘时，仅关闭窗口不等于退出。还应关闭正在使用 VMark MCP 服务的客户端，避免文件占用。
- MCP 集成由用户在应用设置中按需配置，本包不会修改其他 AI 客户端的配置。外部客户端若保存了带版本号的可执行文件路径，更新后可能需要重新配置；手动配置时优先使用 Scoop 的 `current` 路径。

## 数据与现有安装

VMark 使用原有的 `%APPDATA%\app.vmark` 应用数据目录，以及 `%LOCALAPPDATA%\app.vmark` 下的 WebView2 等本地数据。本包不声明 `persist`，也不提供自动备份。

- **安装、更新（包括强制更新）保留数据**，不搬迁或覆盖上述目录。
- **`scoop uninstall vmark` 会删除当前用户的上述两个目录，无需 `-p`**。设置、会话恢复/未保存内容、WebView2 数据等都会丢失；请提前保存文档并备份需要保留的数据。`-p` 不改变本包的 AppData 清理行为。
- 清理放在 `post_uninstall`，且仅在 Scoop 命令为 `uninstall` 时执行；更新过程中同样会调用这个 hook，但不会触发删除。程序移除失败时不会提前清理数据。
- 仅清理运行卸载命令的用户，即使全局卸载也不遍历其他用户目录。不删除 AppData 根目录或其他软件的数据。AppData 环境变量为空或非根路径时跳过；若 `app.vmark` 本身是用户创建的链接/联接目录，则警告并跳过，需手动处理。
- 文件占用或权限不足会报错，不会强杀进程或静默宣称清理成功。请完整退出程序/MCP 客户端后处理残留；程序文件可能已被移除。

**这不是完整的便携模式**：运行期间仍使用 AppData；只是卸载时清理已知的应用数据目录。若与官方安装版并存，它们可能共用数据，这次卸载也会删除共用的上述目录。

如已通过官方安装器安装 VMark，请先退出旧程序，备份上述目录及自己的文档，再卸载旧程序（不要勾选删除应用数据），然后通过 Scoop 安装，避免两个版本并存。文档仍保存在用户选择的位置；应单独备份。API 密钥可能保存在 Windows 凭据管理器中，仅复制 AppData 不代表完整备份；本包也不清理凭据或其他客户端的 MCP 配置。

## 已安装旧清单的用户

Scoop 卸载使用安装目录内的 `manifest.json` 快照。仅更新 bucket 不会更改该快照；本次程序版本仍为 `0.9.83`，普通同版本更新也不会应用新的清理 hook。

新清单发布到你使用的 bucket 后，先保存文档、完整退出应用/MCP 客户端并备份，再执行：

```powershell
scoop update
scoop update vmark --force
```

强制更新会重新安装程序、刷新清单快照，但保留 AppData。可检查 `(scoop prefix vmark)\manifest.json` 中是否包含带 `uninstall` 命令判断的 `post_uninstall`，然后再卸载。若安装来源是本地 JSON，请先确认它已替换为本仓库的新清单。

## 验证

在仓库根目录运行（需要已安装 Scoop 和 7-Zip）：

```powershell
pwsh -NoProfile -File ./tests/vmark.Tests.ps1
```

如已下载与清单版本匹配的官方安装包，可同时验证 SHA256、真实 Scoop 解包、清理脚本及 MCP/资源保留：

```powershell
pwsh -NoProfile -File ./tests/vmark.Tests.ps1 -Archive ./VMark_0.9.83_x64-setup.exe
```

测试覆盖安装/更新保留数据、普通卸载删除两个 VMark 数据目录、无关数据保留、目录不存在时的重复清理、无效环境变量及联接目录保护。测试仅使用临时目录，不执行安装器、不启动 GUI 或 MCP 服务，不修改真实用户数据或文件关联；不替代完整安装/卸载、GUI 和 MCP 功能验证。
