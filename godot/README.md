# 幽影深渊 · Godot 4.7

网页版（Three.js / `shadow-depths.html`）的一比一移植工程。语言用 **GDScript**，不用 C#。

## 为什么用 GDScript

- 官方一等公民，文档和插件都围着它转。
- 网页导出、社区微信小游戏插件都更顺，C# 要 .NET 运行时。
- 本机引擎是 `/Applications/Godot.app`（4.7.stable），不是 `Godot_mono.app`。

C# 适合已经有 .NET 团队、或要和现有 C# 后端共用代码。这个项目没有那些前提。

## 打开

1. 用 Godot 4.7 打开 `godot/project.godot`。
2. 跑标题页。新游戏选职业进石桥镇。

## 导出网页

网页只能用 Compatibility 渲染。桌面仍是 Forward+，浏览器走 `gl_compatibility`。无线程导出，本地 `python3 -m http.server` 即可，不必配 COOP/COEP。

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --export-release Web export/web/index.html
cd godot/export/web && python3 -m http.server 8080
```

浏览器打开 `http://127.0.0.1:8080`。不要直接双击 html，本地文件协议跑不起来。产物在 `godot/export/web/`（已 gitignore）。

网页没有系统字体。工程已捆绑 `fonts/NotoSansSC-Regular.ttf`（OFL），并打开 ICU 文本数据，中文才能在浏览器里显示。

缺模板时：编辑器 → 管理导出模板，只装 **Web Single-Threaded**；或从 [4.7-stable 模板包](https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz) 解出 `web_nothreads_release.zip` 放到 `~/Library/Application Support/Godot/export_templates/4.7.stable/`。

## 打开，换外观只改对应场景。源 GLB 在 `res://models/src/`。缺模型会回落 `fallback_human` / `fallback_beast` / `fallback_box`。人物与怪物播 GLB 里的 `idle` / `run` / `attack`。

面板对齐网页：暗金 plate / 四角折角、左侧 C/I/S/K/J/Y、角色纸娃娃环绕装备槽、8×5 行囊凹槽与 tooltip、技能/天赋分栏、委托双栏，功绩册，暂停导出，NPC 打听，副本确认。卡登/玛拉/沃恩用商店卡片。沃恩单骰猜大小与今夜赌货。右上小地图。窗口 **1980×1080**。物品与技能用 `icons/` 里的 game-icons（Lorc，CC BY 3.0）暗金 SVG。

重新生成包裹（会覆盖自动生成的 tscn）：

```
python3 godot/tools/make_models.py
```

## 操作

- 左键点地走路，点敌人攻击，点掉落名拾取，点 NPC 交谈
- 右键释放绑定技能（新号默认绑第一个技能）。Shift 站住打/放技能
- 1–6 技能　Q/E 药水　C 角色　I 背包　S 技能　K 天赋　J 委托　Y 功绩　T 回城　R 重新计票　Esc 暂停
- Alt 显示全部掉落名。暂停里可打开「显示普通掉落名」

## 已迁

地图表、三职业十八技能、怪物、副本、裂隙、任务、难度（普通/地狱/噩梦）、开场与副本/Boss/终局动画、JSON 存档、点地 A*、城镇与野外生成。

场景外观对齐网页：野外阻挡物（树/尖岩/冰柱/沉船/乱石）、地牢墙帽与柱、地标、石桥镇房屋。掉落与投射物有 mesh，敌人有血条，NPC 有名字。每座据点从城门走进（石桥从桥头），广场有复活井：死亡在井边醒，也可喝水补满。

系统对齐网页：超级独特怪、精英词缀、物品前后缀、卡登、玛拉回想、符文三级、套装与传奇、遗物袋、每日悬赏、跨角色银行、野外事件（商队/宝箱/涌流/学徒）。

裂隙词缀（第五层起）、特殊房间（宝库/祭坛/囚笼/陷阱厅）、六大天赋与技能符文、塞克拉两阶段与喊名字、章节 Boss 的召唤/新星/跃击。

功绩册（Y）、小地图迷雾、角色纸娃娃、商店格子卡片、沃恩骰子与赌货。暗金 HUD（HP/MP 球、技能槽、角色/行囊合页）。窗口 1980×1080。

传奇战斗（unique 伤害/叠层/R 重新计票/未唱完）、顿帧连击与镜头震动、标题三槽与卷宗导入、遗物袋纸条鉴定、目标词缀与事件条、地牢火把点光。物品/技能/药水/装备槽用暗金图标。地上掉落飘稀有度颜色名字（金自动吸，点名字捡，可关白色）。左键/右键技能，Shift 站住。Tooltip 对比已装备绿红差。十八技能各有形态符文。野外精英成团，传奇落地光柱。

## 下一趟再对齐网页的

技能中间节点（网页也是空的）不必造。剩下主要是更多章节过场。
