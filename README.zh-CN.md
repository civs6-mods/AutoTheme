# AutoTheme 巨作一键整理

[English](README.md) · [Steam 创意工坊](https://steamcommunity.com/sharedfiles/filedetails/?id=3840337211) · [详细规则](docs/BEHAVIOR.zh-CN.md)

在《文明 VI》中点击一次，整理自己已经拥有的巨作。保留已有主题，先尝试组合新主题，再改善其余藏品的存放位置。

![巨作一键整理](workshop/preview.png)

## 当前版本

**0.2.4，单机预览版，已公开发布。** `mod/` 与已核验的 Steam 发布包七个文件完全一致，清单版本 7。

- 扫描整个巨作面板的实际作品与合法槽位，包含艺术品、文物、遗物、著作、音乐、公司及奇观产品等。
- 通过原生移动指令逐笔交换，确认实际槽位内容后再继续。
- 保留已有主题，遵守艺术品冷却、文物馆满槽转移及槽位类型限制。
- 点击停止或关闭窗口，等待已提交的一笔完成后停止；已完成交换保留。
- 使用有界启发式规划，不保证全局最优，也不保证适配任意第三方自定义主题脚本。

演示中同一批 24 件藏品经过三次交换，主题由 1 座变 5 座，仅代表该存档。实机和离线模拟的覆盖范围见[验证记录](docs/VERIFICATION.md)。

## 安装与使用

订阅工坊，等待下载完成，在“额外内容 → 模组”启用“巨作一键整理 / Auto Theme”。进入自己的回合，打开巨作窗口，点击“一键整理”，等待完成。

手动安装：退出游戏，将本仓库的 `mod` 文件夹复制到游戏 `Mods` 目录，并命名为 `AutoTheme`。本地版与工坊版使用同一 Mod ID，请只保留一种安装方式。

目标环境为《风云变幻》与《和而不同》；仅一个 HD 模组组合完成部分实测，其他组合尚未验证。多人和热座不支持。只整理已有藏品，不自动生产产品、挖掘文物或交易其他文明的巨作。

## 开发、验证与打包

```sh
python scripts/verify.py
npm ci
python scripts/test.py
python scripts/package.py
```

`mod/` 为可安装源码，`tests/` 为离线回归，`workshop/` 为封面、双语介绍与实机截图。生成包位于 `dist/AutoTheme-0.2.4.zip`。

## 参与开发与许可

欢迎通过 [Issues](https://github.com/civs6-mods/AutoTheme/issues) 反馈问题与建议，提供游戏、DLC、HD 版本、启用模组、复现步骤及日志报错。也欢迎参与翻译、测试和 Lua / UI 开发并提交 Pull Request。

原创代码采用 [MIT](LICENSE)。游戏截图及游戏内容的权利归各自权利人；演示配乐另按其授权署名，见[配乐说明](docs/MUSIC-CREDIT.txt)。非 Firaxis、2K、Aspyr 或 HD 官方作品。
