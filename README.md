# scoop-bucket

自用 Scoop bucket，目前收录 **5 款应用、5 个字体包**。

## 包含的软件与字体

| 包名 | 简介 | 使用说明 |
|------|------|----------|
| [aoci-code](https://github.com/aoci-spec/aoci-code) | 面向 AI 编码代理的 CLI / MCP 服务，支持 x64/ARM64，包含 RC 更新 | [文档](docs/aoci-code.md) |
| [redisee](https://redisee.com/zh) | Redis 桌面客户端，支持 x64/ARM64 | [文档](docs/redisee.md) |
| [wechat-devtools](https://developers.weixin.qq.com/miniprogram/dev/devtools/devtools.html) | 微信开发者工具，支持 x64（新版已不再提供 Windows ia32） | — |
| [sing-box-windows](https://github.com/xinggaoya/sing-box-windows) | Sing-Box GUI 客户端，支持 x64/ARM64 | [文档](docs/sing-box-windows.md) |
| [tigervnc](https://tigervnc.org) | TigerVNC Viewer 远程桌面客户端，支持 x64/ia32 | — |
| [SFMono-NF](https://github.com/epk/SF-Mono-Nerd-Font) | SF Mono 字体 + Nerd Fonts 补丁 | [文档](docs/SFMono-NF.md) |
| [pingfang-sc](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 简体中文，6 个字重 | [文档](docs/pingfang.md) |
| [pingfang-tc](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 台湾繁体，6 个字重 | [文档](docs/pingfang.md) |
| [pingfang-hk](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 香港繁体，6 个字重 | [文档](docs/pingfang.md) |
| [pingfang-mo](https://github.com/ACT-02/PingFang-for-Windows) | PingFang 澳门繁体，6 个字重 | [文档](docs/pingfang.md) |

## 使用方法

```powershell
# 添加 bucket
scoop bucket add lz-bucket https://github.com/Wiilz/scoop-bucket

# 以 redisee 为例，替换为上表中的包名即可
scoop install lz-bucket/redisee
scoop update redisee
scoop uninstall redisee
```

安装细节、数据管理、排障及测试说明见上表文档链接。
