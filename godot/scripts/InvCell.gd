class_name InvCell
extends Button
## 可拖拽物品格：点击触发原行为（装备/鉴定/卸下），拖拽在 背包↔装备↔护符 间移动。
## 借鉴 jame581 inventory-system 的 数据/UI 解耦，使用 Godot 原生拖拽 API。
##
## 拖拽落点由 Main._inv_drop(src, dst) 统一协调，复用既有 Game.equip_from_bag / unequip_slot。

static var host = null   # 由 Main._ready 设为场景实例

var cell_kind := "bag"      # bag | charm | equip
var cell_idx := -1
var slot_key := ""
var it_ref: Dictionary = {}


func _get_drag_data(_at: Vector2) -> Variant:
	if it_ref.is_empty():
		return null
	set_drag_preview(_make_preview())
	return {"kind": cell_kind, "idx": cell_idx, "slot": slot_key, "it": it_ref}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("kind")


func _drop_data(_at: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if host != null and host.has_method("_inv_drop"):
		host._inv_drop(data, {"kind": cell_kind, "idx": cell_idx, "slot": slot_key})


func _make_preview() -> Control:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", UiKit.cell(LootData.item_hex(it_ref)))
	var ic := TextureRect.new()
	ic.texture = UiKit.tex(UiKit.icon_for_item(it_ref))
	ic.custom_minimum_size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wrap.add_child(ic)
	return wrap
