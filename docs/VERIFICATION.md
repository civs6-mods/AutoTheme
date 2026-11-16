# 0.2.5 bilingual update / 双语更新

2026-11-17: Mod-list names and descriptions now use embedded en_US / zh_Hans_CN localization. Existing in-game translations are audited for matching keys and placeholders. Gameplay scripts and native binaries are unchanged. This update does not enable multiplayer or hotseat. No new in-game language-switch playtest is claimed.

# Verification / 验证范围

Release: AutoTheme 0.2.4, manifest 7. The seven files under `mod/` match the published Steam package. `release-manifest.json` records their SHA-256 hashes.

Offline checks cover the actual planner and toolbar scheduler: forming and preserving themes, locked works, legal exchange routes, availability refresh, serial requests, cancellation, manual changes, rejected or delayed operations, and turn end. These mocks do not validate Civilization VI's engine APIs.

Real-game evidence in the author's HD collection includes artwork, artifacts, corporation products, writing, music and relic organization. The release demo uses one 24-work collection: three automatic swaps increased themed buildings from one to five while retaining all 24 works. A 2026-11-15 supplement recorded real manual inspection and swapping before automatic organization. The result is specific to that save.

Windows Steam, Gathering Storm and one Harmony in Diversity collection have partial in-game coverage. Full feature/compatibility acceptance, other HD versions, other rulesets, multiplayer and hotseat are not verified; multiplayer and hotseat are disabled in the manifest. Do not present offline mocks or one demo as exhaustive acceptance.

源码与已发布包逐文件一致；本局 24 件藏品、三次交换、主题 1→5 为真实演示结果，不保证其他存档相同提升。离线回归与真实引擎验收分开记录。
