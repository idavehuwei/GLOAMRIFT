# 视觉/玩法验收清单（P4，需编辑器实机目检）

> headless 自动化只能验证“资源加载/骨架/动画剪辑存在/无报错”，**无法验证观感与手感**。以下项需在 Godot 编辑器或导出包中人工确认。
> 自动化已验证的（可放心）：19 个优化 GLB 全部 `meshes/armatures/anims` 正常、动画剪辑名 [idle,run,attack,die] 齐全、启动零报错、`WPN_GRIP` 配置存在（Data.gd:695）。

## 待人工目检
- [ ] **武器握把缩放**：各武器类型 `WPN_GRIP[id].scl`（当前 0.6~0.7）在角色手中比例是否自然，是否需要按角色骨骼微调。
- [ ] **怪物动画手感**：golem/treant/wraith/skeleton/ghoul 的 idle/run/attack/die 在游戏内播放是否流畅、是否与碰撞体同步。
- [ ] **建筑摆放**：`WorldState._build_field_landmarks` 按区域主题放置 world_tower(waste/ash/sinkf/shaft) / world_shrine(wood/frost/shore)，落点 tile 是否避让主地标、是否穿模。
- [ ] **掉落武器漂旋**：地面掉落武器 GLB 是否按预期自转/漂浮。
- [ ] **字体渲染**：NotoSansSC-Regular / NotoSerifSC-Black 在中文 UI 下是否清晰、无豆腐块。
- [ ] **整体帧率**：标题屏→建角→进入地牢→Boss 战各阶段 FPS 是否满足目标。
- [ ] **纹理观感**：19 个资产纹理降至 1024² 后，近景/特写是否出现模糊（尤其角色面部与 Boss 材质）。

## 可后续优化的资产（非阻塞）
- 3 个 Boss（boss_caster/undead/warrok）各 ~4.5MB，纹理已 ≤1024，体积大头为几何体+动画；进一步压缩需网格减面（mesh decimation），风险较高，建议评估后再做。
- 历史 18 个已跟踪的外部纹理 PNG（EMBED 切换后的孤儿）仍占仓库空间，不影响加载，可择机 `git rm` 清理。
