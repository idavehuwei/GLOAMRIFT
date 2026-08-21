extends Node
## 全局事件总线：解耦 UI 与各游戏系统。
## 设计参考 HUD 最佳实践（EventBus + 信号驱动），让面板订阅事件而非每帧轮询。
##
## 接入约定：
##   - 数值/资源变更：stat_changed / leveled_up / gold_changed / bag_changed
##   - 反馈层：notify(title, body, kind)  -> 统一驱动 Notify 通知栈（kind: info/warn/good/loot/ach）

# —— 数值 / 资源 ——
signal stat_changed(kind: String, cur: float, maxv: float)  # kind: hp/mp/xp
signal leveled_up(lvl: int)
signal gold_changed(g: int)
signal bag_changed()
signal quest_changed()
signal target_changed()
signal buff_changed()

# —— 反馈层 ——
signal notify(title: String, body: String, kind: String)
signal achievement(id: String, name: String)
