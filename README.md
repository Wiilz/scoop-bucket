# scoop-bucket

自用 Scoop bucket，用于安装和管理 `redisee`、`wechat-devtools`、`sing-box-windows`、`SFMono-NF` 等工具。

## 使用方法

### 添加 bucket

```powershell
scoop bucket add lz-bucket https://github.com/Wiilz/scoop-bucket
```

### 安装软件

```powershell
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

# 安装 SFMono-NF（SF Mono 字体 + Nerd Fonts 补丁）
# Windows 10 1809+ / Windows 11 默认安装到当前用户，无需管理员权限
scoop install SFMono-NF

# 更新 / 卸载当前用户安装
scoop update SFMono-NF
scoop uninstall SFMono-NF

# 仅需要所有用户共享时，在管理员终端显式使用 -g
# scoop install -g SFMono-NF
```

### SFMono-NF 安装范围

默认使用 `%LOCALAPPDATA%\Microsoft\Windows\Fonts` 和 HKCU 字体注册项；通过用户字体目录的应用包读取/执行权限修复支持 Windows 11，不再强制全局安装。Windows 10 1809 之前仍需全局安装。

已有的全局安装不会自动迁移。迁移前应先卸载全局版（`scoop uninstall -g SFMono-NF`），确认清理完成后，再在普通终端安装用户版。注意：Scoop 卸载使用安装目录中的 `manifest.json` 快照，更新 bucket 不会更新旧快照；旧版卸载脚本需要先备份并替换为匹配版本的修正版，避免沿用静默忽略删除错误的旧逻辑。

## 包含的软件

| 软件 | 描述 |
|------|------|
| [redisee](https://redisee.com/zh) | 现代化的 Redis 桌面客户端（闭源 freemium，便携版，支持 x64/arm64） |
| [wechat-devtools](https://developers.weixin.qq.com/miniprogram/dev/devtools/devtools.html) | 微信开发者工具（闭源 Freeware，支持 x64/ia32） |
| [sing-box-windows](https://github.com/xinggaoya/sing-box-windows) | 基于 Tauri 2.0 的 Sing-Box GUI 客户端（MIT 开源，便携版，支持 x64/arm64） |
| [SFMono-NF](https://github.com/epk/SF-Mono-Nerd-Font) | Apple SF Mono 字体 + Nerd Fonts 补丁（MIT，Windows 10 1809+ / Windows 11 支持当前用户安装） |
