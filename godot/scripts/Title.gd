extends Control
## 标题页：三槽新游戏 / 继续 / 导入卷宗。

var _name_edit: LineEdit
var _cls := "warrior"
var _status: Label
var _slot := 0
var _slot_row: HBoxContainer
var _import: TextEdit


func _ready() -> void:
	theme = UiKit.hud_theme()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.047, 0.039, 0.031)
	add_child(bg)
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.015, 0.01, 0.35)
	add_child(veil)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.plate())
	plate.set_anchors_preset(Control.PRESET_CENTER)
	plate.offset_left = -320
	plate.offset_right = 320
	plate.offset_top = -420
	plate.offset_bottom = 420
	add_child(plate)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_top", 22)
	pad.add_theme_constant_override("margin_bottom", 22)
	plate.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)
	var brand := Label.new()
	brand.text = "GLOAMRIFT"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 13)
	brand.add_theme_color_override("font_color", UiKit.ash())
	v.add_child(brand)
	var title := Label.new()
	title.text = "幽影深渊"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UiKit.brass_hi())
	v.add_child(title)
	var sub := Label.new()
	sub.text = "镇子建在一道裂口上。桥头把名字刻上了木牌。"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", UiKit.bone())
	v.add_child(sub)
	UiKit.rule(v)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "你的名字"
	_name_edit.text = "流浪者"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name_edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for c in ["warrior", "mage", "archer"]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = c == "warrior"
		var ic := "sword" if c == "warrior" else ("staff" if c == "mage" else "bow")
		UiKit.stamp_btn(b, ic, Data.CLASSES[c].n, 28)
		b.pressed.connect(_pick_cls.bind(c, row))
		row.add_child(b)
	var desc := Label.new()
	desc.name = "ClsDesc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", UiKit.ash())
	desc.text = Data.CLASSES.warrior.desc
	v.add_child(desc)
	var slot_lab := Label.new()
	slot_lab.text = "卷宗槽"
	slot_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lab.add_theme_font_size_override("font_size", 12)
	slot_lab.add_theme_color_override("font_color", UiKit.ash())
	v.add_child(slot_lab)
	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_slot_row)
	_refresh_slots()
	var ng := Button.new()
	ng.text = "新的旅程"
	ng.pressed.connect(_new_game)
	v.add_child(ng)
	var cont := Button.new()
	cont.text = "继续下行"
	cont.pressed.connect(_continue)
	v.add_child(cont)
	_import = TextEdit.new()
	_import.custom_minimum_size = Vector2(0, 72)
	_import.placeholder_text = "粘贴 GLOAM1. 卷宗，或存档 JSON"
	v.add_child(_import)
	var imp := Button.new()
	imp.text = "导入卷宗到空槽"
	imp.pressed.connect(_import_save)
	v.add_child(imp)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.45, 0.4, 0.36))
	_status.text = "GDScript · Godot 4.7 · 点地走 · 右键技能 · Shift 站住 · 1–6 · R 重新计票"
	v.add_child(_status)
	if "--smoke" in OS.get_cmdline_user_args():
		Game.start_new("测", "warrior")
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _slot_label(i: int) -> String:
	var m := Game.slot_meta(i)
	if m.is_empty():
		return "槽 %d · 空" % (i + 1)
	var cn: String = str(Data.CLASSES[m.cls].n) if Data.CLASSES.has(m.cls) else str(m.cls)
	return "槽 %d · %s · %s %d 级" % [i + 1, m.name, cn, int(m.lvl)]


func _refresh_slots() -> void:
	for c in _slot_row.get_children():
		c.queue_free()
	if not Game.has_save(_slot):
		var empty := Game.first_empty_slot()
		_slot = empty if empty >= 0 else 0
	for i in 3:
		var b := Button.new()
		b.text = _slot_label(i)
		b.toggle_mode = true
		b.button_pressed = i == _slot
		b.pressed.connect(_pick_slot.bind(i))
		_slot_row.add_child(b)


func _pick_slot(i: int) -> void:
	_slot = i
	for j in _slot_row.get_child_count():
		var b: Button = _slot_row.get_child(j)
		b.button_pressed = j == i


func _pick_cls(c: String, row: HBoxContainer) -> void:
	_cls = c
	for b in row.get_children():
		var btn := b as Button
		var id := "warrior"
		if btn.text.find("法师") >= 0:
			id = "mage"
		elif btn.text.find("弓箭手") >= 0:
			id = "archer"
		btn.button_pressed = id == c
	var d := find_child("ClsDesc", true, false)
	if d:
		d.text = Data.CLASSES[c].desc


func _new_game() -> void:
	Game.save_slot = _slot
	Game.start_new(_name_edit.text, _cls)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _continue() -> void:
	if not Game.load_slot(_slot):
		_status.text = "这个槽是空的"
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _import_save() -> void:
	var slot := Game.first_empty_slot()
	if slot < 0:
		_status.text = "三个槽都满了。先开一局覆盖，或选空槽。"
		return
	var err := Game.import_save_text(_import.text, slot)
	if err != "":
		_status.text = err
		return
	_slot = slot
	_refresh_slots()
	_status.text = "已写入槽 %d。点「继续下行」。" % (slot + 1)
