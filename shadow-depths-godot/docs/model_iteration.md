# 0.6 模型与动作迭代记录

本轮使用程序构建的原创几何，参考盔甲结构与动物步态图片进行建模。没有接入自动图片转 3D 服务；GLB 来自项目中的模型和动作控制器，不是单张图片的自动重建结果。

## 图片参考

- [Denver Art Museum：盔甲部件展示](https://www.denverartmuseum.org/en/blog/5-phrases-age-armor-still-used-today)。查看实物照片中的重叠肩甲、锁子甲袖、肘甲、护手与足甲，落实为分层肩甲、护手与可动肘膝。照片仅用于结构参考，没有作为游戏纹理或随包素材。
- [kabacalyaan：Wolf Anatomy — Skeleton](https://www.deviantart.com/kabacalyaan/art/Wolf-Anatomy-Skeleton-943232956)、[Wolf Gait](https://www.deviantart.com/kabacalyaan/art/Wolf-Gait-943241697)。用于查找四足比例、腿部折线及步态参考；未复制原画或将原图映射到模型。

## 截图迭代

| 对象 | 修改前 | 修改后 |
| --- | --- | --- |
| 战士 | [0.5 截图](../tests/before_warrior.png) | [0.6 截图](../tests/model_00.png) |
| 猎犬 | [0.5 截图](../tests/before_hound.png) | [0.6 截图](../tests/model_11.png) |
| 蜘蛛 | [0.5 截图](../tests/before_spider.png) | [0.6 截图](../tests/model_12.png) |

1. 加入胸甲轮廓、重叠肩甲、手指和独立关节，截图发现自定义非索引网格在与索引网格合并后丢面；为自定义表面建立索引，并增加三角面数量回归断言。
2. 动作截图发现弓的上下半段被分配到不同关节；改为完整弓体节点，随手臂运动时补偿角度，保持竖直持弓。增加动态弓弦与搭箭。
3. 重建猎犬的四足、口鼻、下颌和尾巴，蜘蛛使用八条独立腿与膝关节。截图后减弱毛皮纹理，缩小背部毛簇，并将下颌挂到头部以保持连接。
4. 动作与战斗事件连接：攻击、技能、闪避、受击、倒地。宝箱使用平滑开盖；对应回归验证中间状态和最终打开位置。

[战士姿态](../tests/motion_00.png) · [法师姿态](../tests/motion_01.png) · [弓箭手姿态](../tests/motion_02.png) · [铁匠动作](../tests/motion_05.png) · [猎犬姿态](../tests/motion_11.png) · [蜘蛛姿态](../tests/motion_12.png)

姿态图从左到右，上排为待机、行走、攻击、技能；下排为闪避、受击、倒地、职业动作。图中为动作中间帧。游戏 N 图鉴可以播放完整动作和转台。

## 可编辑模型

`assets/models/` 包含 warrior、mage、ranger、courier、apothecary、smith、tutor、innkeeper、soldier、skeleton、cultist、hound、spider、crossbowman、boss_1 至 boss_5，共 19 个 GLB。每个包含 idle / walk / attack / skill / dodge / hit / death / work 共八个命名片段。

关节为 Node3D 分件层级，导出时采样位置、旋转和缩放；并非蒙皮角色或动作捕捉。GLB 可作为编辑起点，游戏运行时仍使用程序生成版本。重新生成：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/export_models.gd
```

导出采用 [Godot GLTFDocument](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html)，每个文件导出后重新解析并检查八个动作存在。

## 验证

- 277 项模型动作检查：十五类模型 × 八种状态、关节结构、弓箭显示、战斗触发、倒地清理、NPC 职业动作、网格合并面数。
- 36 项场景检查：五章模型、相机、投影、面板与宝箱开盖。
- 1,629 项基础流程、109 项城镇职业、120 项地图精英 Boss、15 项委托锻造检查，以及 2,100 帧连续战斗模拟。
- 19 个 GLB 导出后重新解析成功，合计 152 个动作片段。

这仍是风格化可玩原型。刚性关节在大幅动作时仍可能出现轻微穿插；后续精修可以在导出的模型上增加蒙皮、手工权重和更细的动作曲线。
