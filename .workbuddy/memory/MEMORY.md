# 项目长期记忆 — 幽影深渊 (ShadowDepths)

## 掉落 / 装备系统扩展约定
- **词缀 k 约束**：Data.gd 的 `AFFIX`/`FEEL_AFFIX` 新增条目，其 `k` 必须属于 `apply_mod` 已消费集合（Game.gd 中 `p_stats()` 初始字典键 + `apply_mod` 显式 if/elif 链）。白名单：str/dex/vit/ene/armor/hp/mp/dmg/crit/as/leech/ms/critDmg/dr/cdr/mpre/hpre/dodge/all/main/skDmg/pierce/resPhys/resFire/resIce/resShadow/resAll/gf/mf/killhp/killmp/thorns/chillhit/freezehit/killburst/lowhp/elitedmg。未知 k 会被静默忽略（白名单 if/elif 无 else）。
- **新符文**：向 `Data.RUNES` 追加即可被 `rune_by_id`/`roll_rune`/`make_rune_item` 无缝消费（按 `tier` 权重 62/28/10）。
- **怪物专属掉落**：`Data.MOB_DROP` const，key = 怪物 `type`（`e.type`）；字段 `itemMul`(物品掉率乘子)/`force`(装备类型倾向数组)/`runes`(专属符文 id 数组)/`runeCh`(专属符文概率)/`charmMul`(护符乘子)。在 `Game.gd roll_drop` 中 `md = Data.MOB_DROP.get(str(e.type), {})` 读取，无表怪 `md={}` 不影响原逻辑。
- **loot.json 注入**：用 `tools/inject_loot.py` 脚本安全追加 `SETS`/`UNIQUES`/`CHARM_UNIQUES`/`CHARM_AFFIX`/`CHARM_BASE`，内置 k 消费校验与重复 id 检查，保证 JSON 合法且 diff 干净。勿手工数逗号直接改 JSON。
- **roll_item 签名**：`roll_item(lvl, force_rare=false, cls_hint="", force_type="", crate=false)`；`force_type` 必须是 `weapon` 或 `Data.BASES` 的 key。

## 现有掉落基线（2026-08-22）
基础装备 ~50、AFFIX 27 + FEEL 16、RUNES 16、套装 11、传奇 35、传奇护符 8、护符词缀 26、护符底 size1=7/2=6/3=5。普通怪物品掉率 32%、护符 14%；精英/ boss/hoard 掉率更高。

## Boss 能力系统约定（2026-08-22）
- **Boss 定义**：`Data.gd` 的 `ETYPES[bossId]`，字段 `boss=true`、`skill`(单技能，兼容旧逻辑)、`skills`(数组，多能力轮转，优先级高于 skill)、`enrage`(半血狂暴开关)、`enrageStrong`(柯尔用，强狂暴)、`enrageAt`(默认 0.5 触发比例)。
- **能力轮转**：`WorldState._boss_skill(e)` 按 `e.skills[skIdx]` 依次施放并 `skIdx++`；每个技能独立冷却，狂暴时 `cd×0.7`。`skills` 为空则回退到 `e.skill` 单技能（兼容 boneking 等旧 Boss）。
- **可用能力类型**：`nova`(12 发骨刺环)/`slam`(跃击延迟落点)/`summon`(召 3 子嗣)/`volley`(朝玩家 7 发扇形散射)/`beam`(精准高伤射线)/`curse`(玩家脚下 `add_zone` 伤害区持续掉血)。新增类型须在 `_boss_skill` 加 `elif` 分支 + 设 `cd`，并复用 `_proj`/`add_zone` 原语。
- **enrage 触发**：在 `tick_world` 每帧检测 `e.enrage && !e.enraged && hp<=hpMax*enrageAt`，触发后提速/加快攻速/加伤（enrageStrong 更猛），仅一次。
- **spawn_enemy 透传**：`e` 字典已含 `skills/skIdx/enrage/enrageAt/enrageStrong/enraged`，改 Boss 定义后无需改 spawn 逻辑。
- **玩家伤害机制提示**：`aoe_player` 实际打敌人；`_tick_zones` 中 `hurt="player"` 才用 `Game.hurt_player` 打玩家（诅咒领域用此分支）。

## 烬下 · Below the Embers（shadow-depths-godot，Godot 4.7 程序化 ARPG）
- 全部模型/贴图/特效为 GDScript 程序化生成，无外部资产；GLB 仅作导出产物，游戏运行时不消费，hy-3d 生成的模型对该项目无直接用途。
- 特效分层：`scripts/vfx_3d.gd`（程序化网格特效池 + 5 盏点光）由 `world_3d.sync(dt)` 驱动；`particles_3d.gd` 负责 CPUParticles3D（spark/burst/ember/frost/dust/smoke/snow/motes + trail/attach）。
- 命中反馈链路：`combat.hit_enemy` → `renderer_3d.impact()` + `game.hitstop`（暴击 75ms）→ `world_3d.sync` 里按 `e.hit` 做挤压回弹与 `knock_dir` 后退；`game.cast` 驱动法杖 CastOrb、`game.slash` 驱动剑刃 BladeGlow（注意 `ball()/block()` 返回节点的 scale 是尺寸，必须乘 base 不能覆盖）。
- 动画：`model_motion.gd` 的 `strike(phase)` 三段攻击曲线（WINDUP=0.30/CONTACT=0.50）是全角色攻击/施法的主曲线；弓箭手搭箭可见性由 `drawing`（phase<CONTACT）决定，改动画后必须跑 `tests/motion_validation.gd`（含「Arrow hides after release」断言）。
- 贴图：`tools/make_textures.py`（v6）由高度场算法线 + 烘 AO；改完要重跑生成并重跑 `tests/render_3d.gd`（有 roughness_texture 断言）。
- 验证基线（2026-09-12 全部 PASS）：smoke 1629 / activities 15 / bosses_elites 120 / classes_towns 109 / live_combat 2100 帧 / motion_validation 277 / render_3d 36（90 帧 754ms，draw calls≈1316）。`tests/_fx_preview.gd` 一键出特效核对截图。
- 踩坑：Godot 4 没有 `CircleMesh`；`get_meta(key,default)` 缺 key 会报错需先 `has_meta`；Bash 的 grep 对含中文的 .gd 偶发无输出，用 Grep 工具。
- headless 下 `renderer_3d` 为 null（`game._ready` 判断 DisplayServer），所以 detail_validation / motion_validation / render_3d / visual 必须带窗口跑。
- 小宠物系统（0.8）：`scripts/pets.gd` 子系统挂在 `game.pets`；物种表 `content.gd Data.PETS`（10 种，rarity 0-4 各 2 种）；抽卡价 `90+depth*18`；boss 掉落 rarity=clamp(chapter+1,2,4)；宠物模型 `world_3d.companion()` + `motion.rig(root,4)`，翅膀走 `has_meta("wings")` 后置驱动；面板 `draw_pet_panel()`，热键 P；存档 v3 含 `pets` 字段；测试 `tests/pets.gd`、预览 `tests/_pet_preview.gd`/`_pet_ui_preview.gd`。
- Edit 工具含中文 old_string 偶发静默失败（报成功但未写盘），重要改动后必须 grep 验证；大段中文替换改用 python 读改写。
