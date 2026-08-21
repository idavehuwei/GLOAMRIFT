# 项目长期记忆 — 幽影深渊 (ShadowDepths)

## Godot 工程约定
- **Variant 推断类型会被当错误**：早前 P0/P1 出现过 "The variable type is being inferred from a Variant value" 编译失败(Notify.gd:45 / Main.gd:1272)。`project.godot` 未显式设置 `treat_warnings_as_errors`，疑似用户编辑器全局设置开启；无论来源，**从 Variant 推断类型一律显式标注**最稳妥。
  - 高危来源：`dict.get(...)` 返回值、`Array`/`Dictionary` 索引 `arr[i]`、`null` 字面量。
  - 修复方式：显式标注类型，如 `var col: Color = KIND_COLOR.get(...)`、`var cat: String = c[0]`、`var t: Dictionary = b[i]`、`static var host: Variant = null`。
  - 安全情况：`X.new()` 返回具名类型、`"字符串"`/`123` 字面量推断——无需改动。
- 沙箱无显示环境，Godot headless 卡在渲染初始化，**无法实跑语法校验**；改动须严格人工复核(确认无类名/函数冲突、无未定义全局)。
- 提交惯例：本地 commit(dev 分支,不主动 push);`key.md` 含 API 密钥,绝不纳入提交。

## 技术栈
- Godot 4.7,纯 GDScript 代码优先(无手工摆场景,`.tscn` 由 `tools/gen_scenes.py` 生成)。
- 自动加载:Game / WorldState / LootData / AchData / UiKit / Assets / Sfx / ThreadPool / EventBus / Notify / DialogueManager。
- 渲染已开启遮挡剔除 + 多线程渲染。

## UI 现状(P0 + P1 已落地)
- P0:EventBus 信号总线 + Notify 通知栈 + InvCell 可拖拽物品格 + 背包分类筛选 + 平滑血条。
- P1-6 任务追踪:`Game.quest_steps(q)` 支持 steps 多步骤 + `_track` 渲染 ✓/▢;`EventBus.quest_changed` 已发射(turn_in/unlock_quests)并接 `_refresh_hud`。
- P1-4 对话解耦:`autoload/DialogueManager.gd` 作为 TalkData 门面,开放 greet/topics/answer + branch 分支能力 + `dialogue_opened` 信号;`open_npc` 改走它。
- P1-5 物品 Resource 化 + 编辑器 Dock:`scripts/ItemData.gd`(class_name ItemData, Resource, type/rarity 用 `@export_enum` 下拉, desc 多行)提供 from_dict/to_dict 桥接;**编辑器 Dock 已完成**——`addons/item_dock`(EditorPlugin + 面板,挂左下底栏),支持浏览/新建/复制/删除/保存/另存为 + JSON 批量导入导出,编辑复用原生 EditorInspector。

## 仓库状态
- 纯本地仓库,**无远程(无 origin)**,`git push` 当前执行不了;需用户先提供 GitHub 仓库 URL 才能 `git remote add origin` + push dev 分支。
