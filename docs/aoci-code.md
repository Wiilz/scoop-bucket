# AOCI-CODE

[返回软件清单](../README.md)

## 安装与更新

```powershell
scoop install lz-bucket/aoci-code
aoci --version
scoop update aoci-code
scoop uninstall aoci-code
```

包名为 `aoci-code`，命令为 `aoci`。支持 x64 / ARM64。

## 管理说明

- 采用官方 Windows ZIP，声明式解压并由 Scoop 创建 `aoci` shim；不运行上游安装脚本，不写注册表，不搬迁 AppData，不自动初始化项目或配置 MCP。
- 当前上游只有 RC 预发布版，本包跟踪最新发布（包含 RC 和正式版），并从同一 Release 的 `SHA256SUMS` 获取更新校验值。许可证为 **FSL-1.1-MIT**，属于源码可用许可，不应当作当前已采用 MIT 的开源软件。
- 扫描 Git 仓库需要 `git` 在 PATH 中可用；manifest 仅提供安装建议，不强制重复安装已有的 Git。不需要 Go、Node.js 或 Python 运行环境。
- 更新前完成或妥善处理项目中的未完成事务，并关闭相关 AOCI MCP 服务及 UI 进程；更新后重新启动相关服务，正在运行的旧进程不会自动切换版本。
- MCP 配置推荐使用稳定绝对路径：运行 `Join-Path (scoop prefix aoci-code) 'aoci.exe'` 获取路径，避免绑定具体版本目录。已有手动安装不会自动迁移，可用 `Get-Command aoci -All` 检查路径冲突，并手动更新旧 MCP 配置。
- `scoop uninstall aoci-code` 仅移除 Scoop 管理的程序和 shim；不删除项目中的 `.aoci/`、索引或宿主配置，也不清理应用运行时产生的用户缓存。项目数据本就在安装目录外，因此无需 `persist`。

本仓库的 [Excavator 工作流](../.github/workflows/excavator.yml)每天检查并更新 manifest；工作流在远程正常运行并推送更新后，本机仍需执行 `scoop update aoci-code`，不会在后台自动升级应用。

## 本地测试

尚未推送到远程 bucket 时，可在本仓库根目录测试安装：

```powershell
scoop install "./bucket/aoci-code.json"
aoci --version
scoop uninstall aoci-code
```

本地文件安装会记录该文件为更新来源。远程 bucket 发布后，可在卸载状态下使用 `scoop install lz-bucket/aoci-code`，确保后续从 bucket 获取更新。
