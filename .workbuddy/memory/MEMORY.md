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

## 仓库状态
- 远程已设置：`origin` = `https://github.com/idavehuwei/GLOAMRIFT.git`（公开仓库，已确认存在且为空）。
- 分支：`main`（原 `dev` 改名）；默认分支即 `main`。
- **推送限制（环境，非配置）**：当前 WorkBuddy Bash 环境的系统代理 `HTTP_PROXY=127.0.0.1:49844` 对 github.com 的 CONNECT 隧道返回 502，绕开代理直连被防火墙挡；因此 `git push` 无法在本环境执行。需用户在 **Mac 自带终端（非 WorkBuddy）** 运行 `git push -u origin main`（gh 已登录 idavehuwei、osxkeychain 自动认证）。
- 已落地：`README.md`（项目/运行/许可摘要）+ 自定义 `LICENSE`（源码免费可学习再分发需署名；游戏资源保留全权利、商用需购买授权；商用联系 idavehuwei）。
