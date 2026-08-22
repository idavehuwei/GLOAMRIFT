# 巨型 autoload 模块化拆分方案（P3 #93）

> 状态：**设计与分析完成，代码拆分待编辑器实机回归后执行**（headless 仅能验证“加载”，无法验证 12.6k 行玩法逻辑）。
> 当前 headless 启动 3.18s、autoload 全加载、无 error/warning/deprecation —— 拆分前基线健康。

## 现状体量
| 文件 | 行数 | 角色 |
|---|---|---|
| autoload/Game.gd | 4324 | 玩家/战斗/物品/任务/存档/UI 信号中枢，共享状态 `P` |
| autoload/WorldState.gd | 3742 | 世界网格/寻路/城镇与地牢生成/房间装饰/实体移动 |
| scripts/Main.gd | 3373 | 输入/场景管理/UI 粘合 |
| autoload/Data.gd | 722 | 纯数据常量 + 少量纯函数 |
| autoload/Assets.gd | 368 | 资源加载/武器挂接 |
| autoload/UiKit.gd / Cfg.gd | 106 / 106 | UI 构件 / 配置 |

## 风险点（决定不能盲拆）
1. **共享可变状态**：Game.gd 的 `P: Dictionary` 被全项目读写；WorldState 的 `W/world_root/actors_root` 是实例变量，被生成函数链深度依赖。
2. **跨 autoload 互调**：Game→WorldState/Data/Assets、WorldState→Game/Data 形成调用网，拆分需保持调用契约。
3. **headless 无法验证玩法**：只验证“能加载/能进标题屏”，拆分后的战斗/掉落/任务流转必须在编辑器实机回归。

## 建议目标模块（按职责聚类）
| 新模块 | 来源 | 内容 |
|---|---|---|
| `Profile.gd` | Game.gd | `P` 玩家档案、reset_blank、save/load 存档 |
| `Combat.gd` | Game.gd | hurt_player / aoe_player / 伤害结算 |
| `Items.gd` | Game.gd + Data | roll_item / 词缀 / 符文 / 护符(charm) |
| `WorldGen.gd` | WorldState.gd | gen_town / gen_field / gen_rooms / 房间装饰 |
| `Pathfind.gd` | WorldState.gd | find_path / find_path_async / los_free |
| `WorldGrid.gd` | WorldState.gd | W 网格状态 / walk / can_stand / paint / reveal |
| 保留 | Game.gd / WorldState.gd | 作为编排层，委托给上述子模块（薄壳） |

## 执行路线图（需编辑器回归门禁）
1. **阶段 0（安全、headless 可验）**：本文件 + 在各巨型文件顶部用注释标注模块边界（零行为变更），已 headless 复验加载。
2. **阶段 1**：提取 `Pathfind.gd`（最独立、无共享可变状态依赖），跑编辑器回归。
3. **阶段 2**：提取 `WorldGrid.gd`（仅依赖 `W` 实例变量，随 WorldState 生命周期）。
4. **阶段 3**：提取 `Items.gd`（纯函数为主，依赖 Data 常量）。
5. **阶段 4**：提取 `Combat.gd` / `Profile.gd`（最耦合，最后做，需完整战斗+存档回归）。
6. 每阶段均需在编辑器实机跑：建角色→战斗→掉落→存档读档→进出地牢→Boss 战。

## 结论
代码拆分的“设计与分析”已完成；实际拆分因无法 headless 验证玩法，建议按上述路线图在编辑器回归门禁下分阶段执行，避免一次盲拆破坏已发布游戏。
