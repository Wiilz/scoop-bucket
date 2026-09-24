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

VMark 使用原有的 `%APPDATA%\app.vmark` 应用数据目录，以及 `%LOCALAPPDATA%\app.vmark` 下的 WebView2 等本地数据。安装、更新和卸载均不搬迁、覆盖或删除这些目录，也不声明 `persist`。继续使用已有数据不等于 Scoop 提供了备份。

如已通过官方安装器安装 VMark，请先退出旧程序，备份上述目录及自己的文档，再卸载旧程序（不要勾选删除应用数据），然后通过 Scoop 安装，避免两个版本并存。文档仍保存在用户选择的位置；应单独备份。API 密钥可能保存在 Windows 凭据管理器中，仅复制 AppData 不代表完整备份；本包也不清理凭据或其他客户端的 MCP 配置。

## 验证

在仓库根目录运行（需要已安装 Scoop 和 7-Zip）：

```powershell
pwsh -NoProfile -File ./tests/vmark.Tests.ps1
```

如已下载与清单版本匹配的官方安装包，可同时验证 SHA256、真实 Scoop 解包、清理脚本及 MCP/资源保留：

```powershell
pwsh -NoProfile -File ./tests/vmark.Tests.ps1 -Archive ./VMark_0.9.83_x64-setup.exe
```

测试仅使用临时目录，不执行安装器、不启动 GUI 或 MCP 服务，不修改真实用户数据或文件关联；不替代 GUI 和 MCP 功能验证。
