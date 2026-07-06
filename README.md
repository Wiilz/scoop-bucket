# scoop-bucket

自用 Scoop bucket，用于安装和管理 `aicodeswitch`、`redisee`、`wechat-devtools` 等工具。

## 使用方法

### 添加 bucket

```powershell
scoop bucket add lz-bucket https://github.com/Wiilz/scoop-bucket
```

### 安装软件

```powershell
# 安装 aicodeswitch（需先安装 nodejs）
scoop install aicodeswitch

# 使用
aicodeswitch
aicos         # 短别名

# 更新
scoop update aicodeswitch

# 安装 redisee（Redis 桌面客户端，便携版，自动按 x64/arm64 选择）
scoop install redisee

# 更新
scoop update redisee

# 安装 wechat-devtools（微信开发者工具，自动按 x64/ia32 选择）
scoop install wechat-devtools

# 更新
scoop update wechat-devtools
```

## 包含的软件

| 软件 | 描述 |
|------|------|
| [aicodeswitch](https://github.com/tangshuang/aicodeswitch) | AI编程工具模型接口本地化管理和快速切换工具 |
| [redisee](https://redisee.com/zh) | 现代化的 Redis 桌面客户端（闭源 freemium，便携版，支持 x64/arm64） |
| [wechat-devtools](https://developers.weixin.qq.com/miniprogram/dev/devtools/devtools.html) | 微信开发者工具（闭源 Freeware，支持 x64/ia32） |
