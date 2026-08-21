@tool
extends EditorPlugin
## 物品库编辑器 Dock 的插件入口。
## 把 item_dock_panel.gd 实例挂到编辑器左下底栏（与「文件系统」并列成标签页）。

const PANEL_SCRIPT := preload("res://addons/item_dock/item_dock_panel.gd")

var _panel: Control = null


func _enter_tree() -> void:
	_panel = PANEL_SCRIPT.new()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, _panel)


func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null
