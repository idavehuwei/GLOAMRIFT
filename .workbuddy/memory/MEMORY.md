# 项目长期记忆 — 幽影深渊 (ShadowDepths)

## Godot 工程约定
- **`treat_warnings_as_errors` 已开启**：任何"从 Variant 值推断变量类型"的 `var x := ...` 都会编译失败(报错 "The variable type is being inferred from a Variant value")。
  - 高危来源：`dict.get(...)` 返回值、`Array`/`Dictionary` 索引 `arr[i]`、`null` 字面量。
  - 修复方式：显式标注类型，如 `var col: Color = KIND_COLOR.get(...)`、`var cat: String = c[0]`、`var t: Dictionary = b[i]`、`static var host: Variant = null`。
  - 安全情况：`X.new()` 返回具名类型、`"字符串"`/`123` 字面量推断——无需改动。
- 沙箱无显示环境，Godot headless 卡在渲染初始化，**无法实跑语法校验**；改动须严格人工复核(确认无类名/函数冲突、无未定义全局)。
- 提交惯例：本地 commit(dev 分支,不主动 push);`key.md` 含 API 密钥,绝不纳入提交。

## 技术栈
- Godot 4.7,纯 GDScript 代码优先(无手工摆场景,`.tscn` 由 `tools/gen_scenes.py` 生成)。
- 自动加载:Game / WorldState / LootData / AchData / UiKit / Assets / Sfx / ThreadPool / EventBus / Notify。
- 渲染已开启遮挡剔除 + 多线程渲染。

## UI 现状(P0 已落地)
- EventBus 信号总线 + Notify 通知栈 + InvCell 可拖拽物品格 + 背包分类筛选 + 平滑血条。
- P1 待做:数据驱动对话(解耦 TalkData 硬编码)、任务追踪 HUD、物品 Resource 化 + 编辑器 Dock。
