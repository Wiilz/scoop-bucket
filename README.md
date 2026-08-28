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
# 注意：Windows 11 22H2 及以上需全局安装
scoop install sudo
sudo scoop install -g SFMono-NF

# 更新
scoop update SFMono-NF
```

## 包含的软件

| 软件 | 描述 |
|------|------|
| [redisee](https://redisee.com/zh) | 现代化的 Redis 桌面客户端（闭源 freemium，便携版，支持 x64/arm64） |
| [wechat-devtools](https://developers.weixin.qq.com/miniprogram/dev/devtools/devtools.html) | 微信开发者工具（闭源 Freeware，支持 x64/ia32） |
| [sing-box-windows](https://github.com/xinggaoya/sing-box-windows) | 基于 Tauri 2.0 的 Sing-Box GUI 客户端（MIT 开源，便携版，支持 x64/arm64） |
| [SFMono-NF](https://github.com/epk/SF-Mono-Nerd-Font) | Apple SF Mono 字体 + Nerd Fonts 补丁（MIT，Windows 11 22H2+ 需全局安装） |
