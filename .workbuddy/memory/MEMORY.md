# 项目长期记忆 — 幽影深渊 (ShadowDepths)

## Godot 工程约定
- **Variant 推断类型会被当错误**：早前 P0/P1 出现过 "The variable type is being inferred from a Variant value" 编译失败(Notify.gd:45 / Main.gd:1272)。`project.godot` 未显式设置 `treat_warnings_as_errors`，疑似用户编辑器全局设置开启；无论来源，**从 Variant 推断类型一律显式标注**最稳妥。
  - 高危来源：`dict.get(...)` 返回值、`Array`/`Dictionary` 索引 `arr[i]`、`null` 字面量。
  - 修复方式：显式标注类型，如 `var col: Color = KIND_COLOR.get(...)`、`var cat: String = c[0]`、`var t: Dictionary = b[i]`、`static var host: Variant = null`。
  - 安全情况：`X.new()` 返回具名类型、`"字符串"`/`123` 字面量推断——无需改动。
- 沙箱无显示环境，Godot headless 卡在渲染初始化，**无法实跑语法校验**；改动须严格人工复核(确认无类名/函数冲突、无未定义全局)。
- 提交惯例：本地 commit（分支已为 `main`，原 `dev` 于 2026-08-21 改名）。`key.md` 含真实 API 密钥，**曾误入历史**，已用 `git filter-repo --force --path key.md --invert-paths` 从全部提交彻底清除（备份 `/Users/weihu/key.md.backup`，清除后恢复到工作区并加入 `.gitignore`，磁盘保留、永不进 git）。新文件/改动务必确认不含明文密钥。

## 技术栈
- Godot 4.7,纯 GDScript 代码优先(无手工摆场景,`.tscn` 由 `tools/gen_scenes.py` 生成)。
- 自动加载:Game / WorldState / LootData / AchData / UiKit / Assets / Sfx / ThreadPool / EventBus / Notify / DialogueManager。
- 渲染已开启遮挡剔除 + 多线程渲染。

## UI 现状(P0 + P1 已落地)
- P0:EventBus 信号总线 + Notify 通知栈 + InvCell 可拖拽物品格 + 背包分类筛选 + 平滑血条。
- P1-6 任务追踪:`Game.quest_steps(q)` 支持 steps 多步骤 + `_track` 渲染 ✓/▢;`EventBus.quest_changed` 已发射(turn_in/unlock_quests)并接 `_refresh_hud`。
- P1-4 对话解耦:`autoload/DialogueManager.gd` 作为 TalkData 门面,开放 greet/topics/answer + branch 分支能力 + `dialogue_opened` 信号;`open_npc` 改走它。
- P1-5 物品 Resource 化 + 编辑器 Dock:`scripts/ItemData.gd`(class_name ItemData, Resource, type/rarity 用 `@export_enum` 下拉, desc 多行)提供 from_dict/to_dict 桥接;**编辑器 Dock 已完成且已在编辑器内实跑通**——`addons/item_dock`(EditorPlugin + 面板,挂左下底栏),支持浏览/新建/复制/删除/保存/另存为 + 粘贴 JSON 导入 + 导出 JSON;**新增「导入loot.json」按钮**:用 Godot 原生 ResourceSaver 把 `data/loot.json` 的 UNIQUES(25)/SET 部件(47)/CHARM_UNIQUES(5) 共约 77 件转成 `ItemData.tres`(rarity int→字符串映射、hex 取 RARITY 颜色、stats 取 affix 的 k:max、desc 合并 flavor+pw)。注意 GDScript 对 `Variant` 变量不能直接调 `.get()/.has()`,须先 `as Dictionary` 或显式 `var d: Dictionary = v` 强转(4.7 编译期强制)。

- P1-7 物品悬浮 Tooltip（已增强）：基础版早已存在——`Game.item_tip(it, cmp)` 返回多行富文本，`_item_cell`/`_equip_slot` 经 `_wire_tip` 接入 hover（`_tip_lab` RichTextLabel + `bbcode_enabled=true`）。**本次增强**（`scripts/Main.gd`）：tooltip 容器改为 `HBoxContainer`（`_tip_box`），新增 `_tip_icon`(TextureRect 44×44) + `_tip_sep`(VSeparator)，物品格 hover 时由 `LootData.item_hex(it)` 取十六色经 `Cfg.hex_color` 转 Color 给边框配色（`UiKit.tip().duplicate() as StyleBoxFlat` 改 `border_color`+`set_border_width_all(2)`）；非物品类 tip（技能等）保持原 hicolor 行为。`_wire_tip(c, txt, icon, hex)` 加可选 `icon: Texture2D`/`hex: int` 参数，调用方以 `UiKit.tex(UiKit.icon_for_item(it))` 传图标；`it` 在背包/装备上下文已是 Dictionary（已 typeof 校验或 `as Dictionary` 强转），类型安全。
- P1-8 HUD 增强（`scripts/Main.gd`，纯增量零回归，4.7 类型安全）：
  - ① WoW 风格底部微型菜单：右下角 6 颗 48×30 仅图标按钮（复用 nav 字体图标，无文字），活动 sheet 经新增 `_sync_micro()` 高亮，与左下 `_nav` 并列不重叠；
  - ② 技能/快捷动作条整体包入 `UiKit.plate()` 圆角面板框（`skplate` 容器，原 skrow 改为其子节点）；
  - ③ 血/蓝球各加 `_level_badge` 圆形等级徽章（`orb_ring` 风格 32×32，显示 `Game.P.lvl`，`_refresh_bars` 更新）；
  - ④ 小地图加 `plate_inner` 内描边（`mmframe`） + 右下角坐标读条 `X %d Z %d`（`_mm_coord`，`_tick_minimap` 节流更新）。

## 仓库状态
- 远程已设置：`origin` = `https://github.com/idavehuwei/GLOAMRIFT.git`（公开仓库，已确认存在且为空）。
- 分支：`main`（原 `dev` 改名）；默认分支即 `main`。
- **已成功推送**：2026-08-21 通过代理 `http://127.0.0.1:29290` 完成 `git push -u origin main`，共 **31 个提交** 已上 GitHub（`idavehuwei/GLOAMRIFT`，public），远程 `main` 已建立（`db699b4`），`key.md` 确认不在任何提交/索引中。注：WorkBuddy 默认代理 49844 对 github 返回 502，需改用 29290 代理方可连通。
- 已落地：`README.md`（项目/运行/许可摘要）+ 自定义 `LICENSE`（源码免费可学习再分发需署名；游戏资源保留全权利、商用需购买授权；商用联系 idavehuwei）。

## 叙事/文案写作口径（用户长期偏好）
- **「简单粗暴、直白」是本项目文案硬要求**：NPC 对话、任务描述、过场、物品 flavor、docs 剧本一律短句、狠动词、直接告诉玩家「去哪、杀谁」，**禁止玄乎意象/深奥背景**（如原「伤口自己会说话」「一声声赞成在砸人」「裂口爱偷名字」「三百年了没人回答他」均要改写）。
- 唯一保留的怪设定是「裂口会弄乱名字」= 桥头念名存档机制，写法用「弄乱」而非「偷」这类玄乎词。
- 文案集中位置：`godot/scripts/TalkData.gd`(对话)、`godot/autoload/Data.gd`(CH_KEYS.d/END_CINE.d/DOOR_LINE/DUNGEONS.desc/SUPER_UNIQUES.last+codex/PHRASES.flavor/QUESTS.d)、`godot/data/loot.json`(物品 flavor)、`docs/*-script.html`+`boss-loot-design.html`(剧本/设计)。改游戏文案须同步对齐 docs 引用，避免不一致。
- loot.json 批量改 flavor 用 `tools/simplify_loot_flavor.py`（json indent=2 + ensure_ascii=False，只动 flavor 字段）。
