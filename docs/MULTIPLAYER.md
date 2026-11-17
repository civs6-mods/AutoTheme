# AutoTheme 0.3.0-mp.1 — 联机测试 / Multiplayer testing

本包启用网络联机；热座未启用。Steam 公开版仍为 0.2.5。本包已通过离线测试，尚未完成双客户端实机同步验证。

This package enables network multiplayer, with hotseat disabled. Steam's public release remains 0.2.5. Offline checks pass; two-client synchronization has not yet been playtested.

## 安装 / Install

1. 两台电脑使用相同游戏版本、规则集、DLC 与 Mod 版本；首轮建议仅启用官方内容和本包。
2. 退出游戏，临时取消订阅公开版 AutoTheme，将已有本地 AutoTheme 文件夹移到 `Mods` 目录外备份。解压本包，将其中 `AutoTheme/` 放入游戏用户目录的 `Mods/`，确保相同 Mod ID 只保留一份。
3. 双方启用巨作一键整理后建立网络对局。轮到自己且尚未提交结束回合时，打开巨作面板，点击一键整理。主机、加入者均使用这个入口。
4. 回到公开版时退出游戏，移走本包并恢复工坊订阅。

Use the same game, ruleset, DLC and mod versions on both computers. For the first test, enable only official content and this mod. Exit the game, temporarily unsubscribe from the public AutoTheme item, and back up any local copy outside `Mods`. Extract `AutoTheme/` into the game's user `Mods/` directory, keeping only one copy of this mod ID. Enable it on both computers before hosting/joining. Click Arrange Great Works during your active turn, before submitting End Turn. To restore the public version, exit the game, remove this package and resubscribe.

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

每轮绑定玩家和回合，一次只提交一笔并读取实际槽位确认。30 秒未确认则停止规划，保留该笔指令的记录；确认后或下一回合允许重新规划，不自动重发。已经提交给游戏核心的交换无法由停止按钮撤销。

The planner runs only in the initiating UI. Every actual swap uses the same native operation as manually dragging a Great Work. No custom network messages, gameplay scripts or DLLs are added. Runs bind to one player and turn and submit one operation at a time. After 30 seconds without confirmation, the plan stops while retaining the outstanding-operation guard. Confirmation or the next authoritative turn permits a fresh plan; operations are never automatically retried. Stop cannot revoke a request already submitted to the game core.
