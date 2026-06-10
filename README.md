# scoop-bucket

自用 Scoop bucket，用于安装和管理 `aicodeswitch` 等工具。

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
```

## 包含的软件

| 软件 | 描述 |
|------|------|
| [aicodeswitch](https://github.com/tangshuang/aicodeswitch) | AI编程工具模型接口本地化管理和快速切换工具 |
