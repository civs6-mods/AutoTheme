# AutoTheme 0.3.0-mp.2 — 联机测试 / Multiplayer testing

支持单机与联机，联机功能目前处于测试阶段；热座未启用。已通过代码审查与离线回归，双客户端实机同步仍待验证。

Single-player and multiplayer are supported, with multiplayer currently in beta and hotseat disabled. Code review and offline regressions pass; live two-client synchronization is still awaiting validation.

## 安装 / Install

1. 所有玩家订阅 Steam 工坊的 AutoTheme，等待更新完成，在“额外内容 → 模组”中启用。
2. 双方使用相同游戏版本、规则集、DLC 与 Mod 版本；首轮建议仅启用官方内容和 AutoTheme。
3. 双方启用巨作一键整理后建立网络对局。轮到自己且尚未提交结束回合时，打开巨作面板，点击一键整理。主机、加入者均使用这个入口。
4. 手动安装可使用发布包中的 `AutoTheme/` 文件夹；采用手动包时，确保它与工坊订阅不会重复加载。

All players should subscribe on Steam, finish updating and enable AutoTheme before hosting or joining. Use the same game, ruleset, DLC and mod versions on both computers. For the first test, enable only official content and this mod. Click Arrange Great Works during your active turn, before submitting End Turn. Manual installation is also available through the package's `AutoTheme/` folder; avoid loading duplicate local and Workshop copies.

## 验证步骤 / Acceptance steps

| 场景 / Scenario | 检查 / Expected result |
|---|---|
| 主机和加入者分别整理 / Host and joining player arrange separately | 每人只修改自己的藏品；总数不变，原主题保留 / Own collection only; counts and existing themes preserved |
| 同时回合中双方同时整理 / Both arrange in simultaneous turns | 各自独立完成，游戏无失同步提示 / Independent results without desync |
| 整理途中点停止、关闭面板 / Stop or close during an exchange | 已提交的一笔仍可完成，后续不再发送 / Submitted swap may complete; no further requests |
| 延迟或断线 / Delayed response or disconnect | 不重复提交；迟到确认不自动恢复旧计划 / No retry; late replies do not resume a stopped plan |
| 整理途中结束回合、计时器到期 / End turn or timer expiration | 不把旧计划继续执行到下一回合 / No old plan continues into the next turn |
| 巨作交易、城市被占、建筑被毁 / Trade a work, capture a city, remove a building | 计划失效后停止；重新点击时读取现状 / Stop stale plan; replan from current state |
| 保存读档、退出重连 / Save/load and reconnect | 已完成位置一致；不会自动恢复整理 / Saved positions agree; no automatic restart |

保存双方整理前后的存档，记录作品总数、主题数和关键槽位。保存读档及重连后再次核对。发生失同步或错误时，保留双方 `Lua.log`、`Modding.log`、规则集和启用 Mod 列表；分享前先查看日志内容。

Keep before/after saves and note work counts, theme counts and key slots. Compare again after save/load and reconnect. For errors or desyncs, retain both clients' `Lua.log`, `Modding.log`, ruleset and mod list; review logs before sharing.

## 实现 / Implementation

规划只在点击按钮的客户端运行，实际交换使用原版 `UI.RequestPlayerOperation(..., MOVE_GREAT_WORK, ...)`。没有自定义网络消息、Gameplay 脚本或 DLL，也不要求所有客户端重复执行同一规划。

每轮绑定玩家和回合，一次只提交一笔并读取实际槽位确认。30 秒未确认则停止规划，保留该笔指令的记录，跨回合也不自动清除；实际交换确认后允许重新规划，不自动重发。若一直未确认，重新载入存档后再操作。已经提交给游戏核心的交换无法由停止按钮撤销。计时器到期、暂停、玩家变化及房主迁移会停止旧计划；消息处理期间等待，处理完成后再读取槽位。

The planner runs only in the initiating UI. Every actual swap uses the same native operation as manually dragging a Great Work. No custom network messages, gameplay scripts or DLLs are added. Runs bind to one player and turn and submit one operation at a time. After 30 seconds without confirmation, the plan stops while retaining the outstanding-operation guard, including across turns. Observed slot results permit a fresh plan; operations are never automatically retried. If confirmation never arrives, reload the save before trying again. Stop cannot revoke a request already submitted to the game core. Timer expiration, pauses, player changes and host migration stop the old plan. Message processing suspends slot reads and submissions until it finishes.

参考实现、修复依据及验证边界见 [代码审查 / Source review](MULTIPLAYER_CODE_REVIEW.zh-CN.md)。
