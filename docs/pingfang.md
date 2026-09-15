# PingFang

[返回软件清单](../README.md)

上游：[ACT-02/PingFang-for-Windows](https://github.com/ACT-02/PingFang-for-Windows)。四个变体分别打包，可按需安装：

| 包名 | 变体 |
|------|------|
| `pingfang-sc` | 简体中文 |
| `pingfang-tc` | 台湾繁体 |
| `pingfang-hk` | 香港繁体 |
| `pingfang-mo` | 澳门繁体 |

每个变体包含 Light、Medium、Regular、Semibold、Thin、Ultralight 六个字重。manifest 标记为 **Proprietary**（专有许可），使用或分发前请自行确认授权；上游仓库公开不代表字体可以任意使用或分发。

## 安装与更新

Windows 10 1809+ 和 Windows 11 默认安装到当前用户，无需管理员权限。

```powershell
scoop install lz-bucket/pingfang-sc
# 其他变体按需安装
# scoop install lz-bucket/pingfang-tc
# scoop install lz-bucket/pingfang-hk
# scoop install lz-bucket/pingfang-mo

scoop update pingfang-sc
scoop uninstall pingfang-sc
```

全局安装、旧版迁移、卸载占用排查和回归测试见[字体共用说明](fonts.md)。Windows 10 1809 之前需要全局安装。
