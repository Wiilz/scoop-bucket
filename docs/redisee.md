# Redisee

[返回软件清单](../README.md)

## 安装与更新

```powershell
scoop install lz-bucket/redisee
scoop update redisee
scoop uninstall redisee
```

支持 x64 / ARM64。Redisee 是闭源商业软件（freemium）：免费档可用，付费档解锁高级特性。

## 管理说明

- 使用 Scoop 的 `extract_dir: current` 提取官方便携 ZIP 内的真实程序，省去外层启动器、`Update.exe` 和手动复制/删除目录的脚本。仅在安装目录创建空的 `.portable` 标记，以保留旧 manifest 展平后的文件布局；该标记不等于数据已被重定向到 Scoop。
- 当前布局下，应用数据和日志位于 `%LOCALAPPDATA%\Redisee`（连接等数据库通常在 `Data` 子目录）。安装、更新和卸载脚本均不搬迁、覆盖或删除这些数据，也不自动清理可能存在的旧版根目录数据库。
- 已移除旧 `persist\redisee\Data` 向 AppData 的自动迁移，避免覆盖现有收藏、偏好等数据库。需要恢复旧数据时，先关闭应用、备份源和目标数据，再手动确认恢复方案；不要直接合并覆盖数据库文件。本包没有 `persist`，不提供自动数据备份。
- 使用 `scoop update redisee` 更新，更新或卸载前关闭应用。未安装 Velopack 更新器不代表禁用所有联网检查；不建议使用应用内升级。
- `scoop uninstall redisee` 删除 Scoop 管理的程序、shim 和快捷方式，保留上述 AppData 数据。旧程序版本和下载缓存属于 Scoop 的正常保留机制，需要时可分别运行 `scoop cleanup redisee`、`scoop cache rm redisee`，这两条命令不用于清理 AppData。

## 应用配置优化与本地测试

`1.1.10` 的解包配置优化不改变软件版本、下载地址和 hash，也不会自动改写已安装版本的 `manifest.json` 快照。现有安装可以继续使用，等下次版本更新时应用新配置；如需立即重装验证，在本仓库根目录执行以下命令（先关闭应用并备份数据，不加 `-p`，以免删除仍有价值的旧 persist 备份）：

```powershell
scoop uninstall redisee
scoop install "./bucket/redisee.json"
```

本地 manifest 安装主要用于测试，会记录本地文件为更新来源。远程 bucket 发布修复后，可在卸载状态下改用 `scoop install lz-bucket/redisee`，确保后续从 bucket 获取更新。

## 解包回归测试

准备与 manifest 版本一致的两个官方 Windows Portable ZIP，从仓库根目录运行（下面的路径替换为实际下载位置）：

```powershell
powershell -NoProfile -File ./tests/redisee-install.Tests.ps1 -Archive64bit ./Redisee-win-x64-stable-Portable.zip -ArchiveArm64 ./Redisee-win-arm64-stable-Portable.zip
```

[测试脚本](../tests/redisee-install.Tests.ps1)校验 schema、两个 ZIP 的 SHA256、解包后全部程序文件与 `.portable` 的内容、hook 重复执行，以及旧 persist 假数据不会迁移或覆盖目标假数据。使用本机 Scoop 的原生 ZIP 解包函数；已安装 Scoop 7-Zip 时也测试对应解包函数。全部解包和假数据操作都在临时目录，不启动 Redisee、不读写真实数据库，也不创建实际 shim 或快捷方式。该测试不替代 GUI、任务栏固定和真实安装/卸载验证；也可用 `pwsh -NoProfile -File` 运行。
