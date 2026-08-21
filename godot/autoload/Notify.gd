extends CanvasLayer
## 通知 / Toast 系统：右上角通知栈，统一承载拾取 / 升级 / 成就 / 系统提示。
## 参考 Source of Mana 的 NotificationBox 与 hud-system 的轻量反馈层设计。
##
## 用法：
##   Notify.toast("拾取", "幽铁长剑", "loot")
##   EventBus.notify.emit("升级！", "12 级", "good")   # 自动路由到本系统

const KIND_COLOR := {
	"info": Color(0.78, 0.7, 0.52),
	"good": Color(0.55, 0.86, 0.45),
	"warn": Color(0.95, 0.72, 0.32),
	"loot": Color(0.69, 0.55, 0.31),
	"ach":  Color(0.96, 0.82, 0.42),
}

var _stack: VBoxContainer

func _ready() -> void:
	layer = 128
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_stack = VBoxContainer.new()
	_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stack.offset_right = -16
	_stack.offset_top = 16
	_stack.add_theme_constant_override("separation", 8)
	root.add_child(_stack)
	EventBus.notify.connect(_on_notify)
	EventBus.achievement.connect(func(_id, n): _spawn("成就达成", str(n), "ach"))


## 便捷入口：直接触发通知（内部走 EventBus.notify，与 _on_notify 同一管线）。
static func toast(title: String, body: String = "", kind: String = "info") -> void:
	EventBus.notify.emit(title, body, kind)


func _on_notify(t: String, b: String, k: String) -> void:
	_spawn(t, b, k)


func _spawn(title: String, body: String, kind: String) -> void:
	var col := KIND_COLOR.get(kind, KIND_COLOR["info"])
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.plate())
	p.modulate.a = 0.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(220, 0)
	p.add_child(v)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 14)
	tl.add_theme_color_override("font_color", col)
	v.add_child(tl)
	if body != "":
		var bl := Label.new()
		bl.text = body
		bl.add_theme_font_size_override("font_size", 12)
		bl.add_theme_color_override("font_color", UiKit.bone())
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(bl)
	_stack.add_child(p)
	while _stack.get_child_count() > 5:
		_stack.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.22)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
