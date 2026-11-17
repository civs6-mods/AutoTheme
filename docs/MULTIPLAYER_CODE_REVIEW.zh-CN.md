# AutoTheme 联机源码对照与审查

日期：2026-11-17。审查起点：`9b15a88`（0.3.0-mp.1）；修复版本：0.3.0-mp.2 / manifest 10。

结论：AutoTheme 的原生操作提交方式与参考实现一致。本次查出的调度边界已修复，离线回归通过。这个结论针对可见 Lua/XML 代码及模拟执行，不是对游戏网络核心或实际双客户端同步的证明。

## 参考来源与适用范围

| 来源 | 实际检查的内容 | 对 AutoTheme 的意义 |
|---|---|---|
| 原版 `Base/Assets/UI/GreatWorksOverview.lua`，906–914 行 | 手动拖动巨作使用 `UI.RequestPlayerOperation`、`MOVE_GREAT_WORK`，携带玩家、源/目标城市与建筑、作品索引和目标槽位七个参数 | AutoTheme 使用同一个入口及参数集合；实际移动交由游戏核心处理 |
| [Great Works Viewer](https://steamcommunity.com/sharedfiles/filedetails/?id=1652106496)，本机工坊副本 | `GreatWorksView.modinfo` 第 10 行声明支持联机；`greatworksoverview.lua` 973–981 行仍使用上述原生请求 | 最接近本功能的巨作界面参考；支持标记本身不等于本次实机验证 |
| [CQUI / Better Trade Screen 自动商路](https://github.com/civfanatics/CQUI_Community-Edition/blob/9ff1e4709a2c44e263e07cc9d72c550bf878c819/Integrations/BTS/UI/tradesupport.lua#L477-L547) | 枚举本地玩家单位，检查待执行操作与合法性，通过 `UnitManager.RequestOperation` 自动续约商路 | 本地 UI 可以计算自动化决策，再提交原生操作；这是同类设计参考，操作类型与巨作不同 |
| [CQUI ActionPanel](https://github.com/civfanatics/CQUI_Community-Edition/blob/9ff1e4709a2c44e263e07cc9d72c550bf878c819/Assets/UI/actionpanel.lua#L648-L660) 及原版 ActionPanel | 检查 `IsTurnActiveComplete`、`IsProcessingMessages`、`HasSentTurnComplete`、`IsTurnTimerElapsed` | 单独检查 `IsTurnActive` 不足以覆盖回合切换、消息处理及本地计时器边界 |
| [Multiplayer Helper 1.8.0](https://steamcommunity.com/sharedfiles/filedetails/?id=3307282026) 的 [DropControl](https://github.com/CivilizationVIBetterBalancedGame/MultiplayerHelper/blob/60fd715d8d2f15284720bb7594507ff19cc9eb7f/ui/Additions/DropControl.lua#L19-L39) 与 [MPHOptions](https://github.com/CivilizationVIBetterBalancedGame/MultiplayerHelper/blob/60fd715d8d2f15284720bb7594507ff19cc9eb7f/ui/Additions/MPHOptions.lua#L131-L150) | 区分本地玩家与房主；断线后可暂停；客户端收到房主结束回合指令后提交本地原生动作 | 自动整理需要尊重暂停、结束回合及会话变化；个人藏品整理无需仅允许房主操作 |
| MPH 的 [MP_helper.lua](https://github.com/CivilizationVIBetterBalancedGame/MultiplayerHelper/blob/60fd715d8d2f15284720bb7594507ff19cc9eb7f/data/MP_helper.lua#L117-L144) 及 modinfo | 自动科技/市政属于 Gameplay 脚本，由 `GameEvents.OnGameTurnStarted` 触发；房主迁移事件在同文件 403–404 行有登记 | 参考代码存在不同执行上下文。AutoTheme 已有原生巨作操作入口，保留 UI 规划与原生请求的架构 |

远程代码固定到 MPH `60fd715d8d2f15284720bb7594507ff19cc9eb7f` 和 CQUI `9ff1e4709a2c44e263e07cc9d72c550bf878c819`。没有把其他 Mod 的支持声明当作 AutoTheme 的兼容性验收结果。

## AutoTheme 核查结果

- **玩家隔离：** 运行开始时绑定本地玩家；收集、槽位读取与请求参数都使用该玩家。读取时核对城市归属。观察者不能开始；两名玩家即使城市/槽位编号相同，也不会共用计划和待确认记录。
- **唯一提交路径：** `mod/AutoTheme.lua` 只有一处 `UI.RequestPlayerOperation`。没有直接改写巨作状态的 setter、Gameplay 脚本或自定义网络传输。主机与加入者走同一个入口。
- **事件与重复执行：** 巨作/建筑事件只让可用性信息失效，不触发整理。只有用户点击会创建新计划；断线、玩家切换、读档、重同步及房主迁移不会自动恢复旧计划。
- **顺序与确认：** 每名本地玩家最多保留一笔未确认交换；读取真实槽位后才继续。每次发出请求前重新收集藏品，核对作品、槽位数量和交换合法性。超时、取消、API 异常和外部藏品变化都不会自动重发。
- **本地规划：** 规划顺序和 UI 时间只影响发起者何时请求移动；其他客户端不需要执行相同规划。同步正确性仍依赖游戏对原生请求的处理。
- **单机行为：** 单机支持标记、规划算法和评分规则保持原样；新增保护用于暂停或停止不适合继续提交的状态。原有单机离线用例通过。

## 本次修复

1. **计时器与回合初始化：** 检查本地计时器到期及回合激活是否完成，并在收集完快照、即将提交时再次检查。解决引擎仍返回 `IsTurnActive=true` 时的提交窗口。
2. **消息处理及会话变化：** 游戏处理消息时暂停读取与提交；暂停游戏时停止当前计划；监听两种房主迁移事件。恢复状态后不会自动重启已停止的计划。
3. **跨回合未确认请求：** 删除“回合号变化就解除保护”的推断。参考实现没有提供该推断的保证。现在持续等待两端实际槽位匹配；重新载入游戏会开启新的 UI 会话并丢弃旧计划。如果请求被拒绝且永远没有确认，按钮会保持等待，需重新载入存档后再操作。这是有意采用的保守恢复方式。

## 验证

`scripts/test.py` 运行真实 Lua 调度器，包含规划、可用性、交互、双模拟 UI 客户端及双语校验。全部通过；双客户端模拟包含同时整理、重叠对象 ID、延迟、超时、迟到结果、取消、外部修改、结束回合、计时器、暂停、消息处理、玩家/房主变化、重同步、读档及异常清理。

新增跨回合用例在 mp.1 上先失败，再在修复后通过。双模拟客户端套件共 953 次断言，其中包含重复的参数/归属检查，不能理解为 953 个独立场景。其他套件包括规划 25 次断言和 30 对中英文文本键。Lua 测试运行器会把断言失败作为非零退出码返回。

这些模拟不能执行 Civ VI 的封闭网络核心，也不能验证实际包传输、远端存档、主机迁移或 Windows–macOS 版本兼容。当前可据此确认的是：采用了有参考依据的原生操作方式，已识别的 Lua 调度问题得到修复，离线测试未发现剩余失败。没有声称实际联机已验证稳定。

## 本地参考文件指纹

记录 SHA-256，便于识别本次检查的安装版本；不在仓库分发游戏或其他作者的源码。

| 文件 | SHA-256 |
|---|---|
| 原版 `GreatWorksOverview.lua` | `0782a00ffbad0e39a5aa4a5c10997156ad7347ff788b3f345267b61d02c9f8c5` |
| 原版 `ActionPanel.lua` | `1a290b0e33c24c5b78515b58447768a6ecc3382387e0fdf6928b10f408875da3` |
| Great Works Viewer `greatworksoverview.lua` | `dde3aeb2d017a6e64396460b6f8039f1b383a12d5d4a9ce8f23df899934a9a3c` |
| Great Works Viewer `GreatWorksView.modinfo` | `3daafc82124a41f3638b102fc4560e7baa642cbbadc2c7cf79481897208fa488` |
