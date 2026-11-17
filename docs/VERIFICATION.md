# 0.3.0-mp.2 source comparison and scheduling fixes / 源码对照与修复

2026-11-17: Manifest 10. Compared native Great Work moves with Great Works Viewer, CQUI/Better Trade Screen automation and Multiplayer Helper's gameplay/UI separation, disconnect and host tooling. Pinned references and findings are in [the code review](MULTIPLAYER_CODE_REVIEW.zh-CN.md).

The scheduler now checks turn activation completion, local timer expiration and game pause; waits during message processing; rechecks eligibility immediately before submission; and stops on host-migration events. A turn-number change no longer clears an unconfirmed request. Only observed exchanged slots or a new loaded session release that guard. No automatic retry or old-plan replay is added.

All offline suites pass: planner (25 assertions), availability, interactions, multiplayer scheduler (953 assertions, including repeated mock ownership checks, not 953 distinct scenarios), and bilingual metadata / 30 in-game text keys. New cases cover timer expiry while the core still reports an active turn, timer/message changes during snapshot collection, incomplete activation, pause/unpause, message processing, late confirmation across turns, recovery after loading and both host-migration events. Existing single-player scenarios also pass. The cross-turn guard test failed against mp.1 before the implementation change.

Conclusion: the native-operation integration is consistent with the reviewed sources; identified scheduling issues are fixed and the offline regressions pass. Actual peer replication, packet loss, reconnect/save-load, Windows–macOS interoperability and arbitrary mod combinations remain outside code-only verification. No live multiplayer result is claimed. Steam's public 0.2.5 package is unchanged.

# 0.3.0-mp.1 multiplayer test build / 历史联机测试包

2026-11-17: Manifest 9 enables network multiplayer (`SupportsMultiplayer=1`), retaining hotseat disabled. `release-manifest.json` records this test package, not the public Steam release. The original single-player planner and scoring rules remain; execution now pins player and turn, observes submitted End Turn, stops on player departure/change and resync, and retains outstanding requests after timeout, error or external collection changes. No request is automatically retried. A matching pair of actual exchanged slots or a new authoritative turn releases the guard. Reconnect/load discards all former UI plans.

The installed base-game `GreatWorksOverview.lua` (native drag/drop handler, lines 906–914) uses the same `UI.RequestPlayerOperation` and `MOVE_GREAT_WORK` parameter set. `ActionPanel.lua` also uses `UI.HasSentTurnComplete`, and the native load screen uses `UI.IsResyncLoadInProgress`. This is source evidence for the integration path, not proof of multiplayer synchronization.

Offline verification: planner (including explicit owner reads, captured cities and missing slots), availability, interaction scheduler and two independent simulated UI clients all pass. Multiplayer cases cover overlapping city IDs, simultaneous runs, long latency, late acknowledgement after timeout, cancel/reopen, external work changes, end-turn submission, turn rollover, observer/player changes, disconnect/resync, game-core busy periods, API errors after submission, and event cleanup. Bilingual metadata plus 30 paired in-game text keys pass validation. The Lua runner now returns a nonzero exit status on assertion errors; its failure path is checked separately.

No dual-client game, live reconnect, host migration, or multiplayer save/load result is claimed. The test package and [acceptance steps](MULTIPLAYER.md) are ready for that verification. Steam's public 0.2.5 package is unchanged.

# 0.2.5 bilingual update / 双语更新（历史版本）

2026-11-17: Mod-list names and descriptions use embedded en_US / zh_Hans_CN localization. Existing in-game translations are audited for matching keys and placeholders. Gameplay scripts are unchanged. This version does not enable multiplayer or hotseat. A subsequent English-language single-player check on the demo save displayed “Arrange Great Works” and “Arrangement complete”, with themed buildings increasing from 1 to 5. This was before the multiplayer changes above.

# 0.2.4 verification / 历史验证范围

Historical release: AutoTheme 0.2.4, manifest 7. At release, its seven installable files matched the published Steam package.

Offline checks cover the actual planner and toolbar scheduler: forming and preserving themes, locked works, legal exchange routes, availability refresh, serial requests, cancellation, manual changes, rejected or delayed operations, and turn end. These mocks do not validate Civilization VI's engine APIs.

Real-game evidence in the author's HD collection includes artwork, artifacts, corporation products, writing, music and relic organization. The release demo uses one 24-work collection: three automatic swaps increased themed buildings from one to five while retaining all 24 works. A 2026-11-15 supplement recorded real manual inspection and swapping before automatic organization. The result is specific to that save.

Windows Steam, Gathering Storm and one Harmony in Diversity collection had partial in-game coverage. Full feature/compatibility acceptance, other HD versions, other rulesets, multiplayer and hotseat were not verified; multiplayer and hotseat were disabled in that release. Do not present offline mocks or one demo as exhaustive acceptance.

当时源码与已发布包逐文件一致；本局 24 件藏品、三次交换、主题 1→5 为真实演示结果，不保证其他存档相同提升。离线回归与真实引擎验收分开记录。
