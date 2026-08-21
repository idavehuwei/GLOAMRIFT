@tool
extends VBoxContainer
## 物品库编辑器 Dock：浏览 / 新建 / 编辑 / 删除 / 复制 ItemData 资源，
## 并支持从运行时 dict 的 JSON 批量导入、导出全部为 JSON。
## 由 item_dock.gd(EditorPlugin) 挂入编辑器左下底栏（与「文件系统」并列成标签页）。
##
## 编辑能力直接复用 Godot 原生 EditorInspector，故 type/rarity 已通过 ItemData 的
## @export_enum 显示为下拉框，stats(Dictionary) / hex(Color) 等亦可原生编辑，无需重复造控件。

const ITEMS_DIR := "res://data/items"

var item_list: ItemList
var inspector: EditorInspector
var path_label: Label
var filter_edit: LineEdit
var import_dialog: AcceptDialog
var import_text: TextEdit
var confirm_del: ConfirmationDialog
var current: ItemData = null
var current_path: String = ""
var entries: Array = []  # Array[Dictionary]，元素 {path:String, res:ItemData}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var header := Label.new()
	header.text = "物品库 · ItemData"
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)

	var help := Label.new()
	help.text = "左列浏览，右列用属性面板编辑；编辑后点「保存」写回 .tres。"
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(help)

	var bar := HBoxContainer.new()
	add_child(bar)
	bar.add_child(_btn("＋ 新建", _on_new_pressed))
	bar.add_child(_btn("复制", _on_dup_pressed))
	bar.add_child(_btn("删除", _on_del_pressed))
	bar.add_child(_btn("保存", _on_save_pressed))
	bar.add_child(_btn("另存为", _on_save_as_pressed))
	bar.add_child(_btn("刷新", refresh))
	bar.add_child(_btn("导入JSON", _on_import_pressed))
	bar.add_child(_btn("导出JSON", export_all))

	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.size_flags_horizontal = SIZE_FILL
	split.add_child(left)

	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = "过滤名称 / 类型 / 稀有度"
	filter_edit.text_changed.connect(_on_filter_changed)
	left.add_child(filter_edit)

	item_list = ItemList.new()
	item_list.size_flags_vertical = SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_item_selected)
	left.add_child(item_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	split.add_child(right)

	path_label = Label.new()
	path_label.text = "（未选择）"
	path_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	right.add_child(path_label)

	inspector = EditorInspector.new()
	inspector.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(inspector)

	_build_import_dialog()
	_build_confirm_delete()

	refresh()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func refresh() -> void:
	entries.clear()
	_ensure_items_dir()
	var dir := DirAccess.open(ITEMS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".tres"):
				var p := ITEMS_DIR + "/" + fname
				var res := load(p) as ItemData
				if res != null:
					entries.append({"path": p, "res": res})
			fname = dir.get_next()
		dir.list_dir_end()
	_render_list()


## 4.7 中 DirAccess.make_dir_recursive 已变为实例方法，需用实例调用。
func _ensure_items_dir() -> void:
	if DirAccess.open(ITEMS_DIR) != null:
		return
	var da := DirAccess.open("res://")
	if da != null:
		da.make_dir_recursive(ITEMS_DIR)


func _render_list() -> void:
	item_list.clear()
	var q := filter_edit.text.strip_edges().to_lower()
	for i in entries.size():
		var e := entries[i] as Dictionary
		var res := e["res"] as ItemData
		var label := _label_for(res)
		if q != "" and not label.to_lower().contains(q):
			continue
		var idx: int = item_list.add_item(label)
		item_list.set_item_metadata(idx, i)


func _label_for(res: ItemData) -> String:
	var nm := res.name if res.name != "" else "(无名)"
	var tp := res.type if res.type != "" else "?"
	var rr := res.rarity if res.rarity != "" else "?"
	return "%s · %s [%s]" % [nm, tp, rr]


func _on_filter_changed(_text: String) -> void:
	_render_list()


func _on_item_selected(idx: int) -> void:
	var ei_v: Variant = item_list.get_item_metadata(idx)
	if typeof(ei_v) != TYPE_INT:
		return
	var e := entries[ei_v] as Dictionary
	_select(str(e["path"]), e["res"] as ItemData)


func _select(path: String, res: ItemData) -> void:
	current = res
	current_path = path
	inspector.edit(res)
	path_label.text = path


func _select_by_path(p: String) -> void:
	for item_v in entries:
		var e := item_v as Dictionary
		if str(e["path"]) == p:
			_select(str(e["path"]), e["res"] as ItemData)
			return


func _next_path() -> String:
	var i := 1
	while true:
		var p := "%s/item_%03d.tres" % [ITEMS_DIR, i]
		if not FileAccess.file_exists(p):
			return p
		i += 1


func _path_for(res: ItemData) -> String:
	var base := res.id if res.id != "" else (res.name if res.name != "" else "item")
	base = base.replace(" ", "_").replace("/", "_").replace("\\", "_")
	var p := "%s/%s.tres" % [ITEMS_DIR, base]
	var i := 1
	while FileAccess.file_exists(p):
		p = "%s/%s_%d.tres" % [ITEMS_DIR, base, i]
		i += 1
	return p


func _on_new_pressed() -> void:
	_ensure_items_dir()
	var res := ItemData.new()
	res.id = "item_new"
	res.name = "新物品"
	res.type = "weapon"
	res.rarity = "common"
	var p := _next_path()
	if ResourceSaver.save(res, p) != OK:
		push_error("新建物品失败：" + p)
		return
	refresh()
	_select_by_path(p)


func _on_dup_pressed() -> void:
	if current == null:
		return
	var res := current.duplicate() as ItemData
	if res == null:
		return
	res.id = current.id + "_copy"
	res.name = current.name + " 副本"
	var p := _path_for(res)
	if ResourceSaver.save(res, p) != OK:
		push_error("复制失败：" + p)
		return
	refresh()
	_select_by_path(p)


func _on_del_pressed() -> void:
	if current == null or current_path == "":
		return
	confirm_del.dialog_text = "删除 %s ？此操作不可撤销。" % current_path.get_file()
	confirm_del.popup_centered()


func _build_confirm_delete() -> void:
	confirm_del = ConfirmationDialog.new()
	confirm_del.title = "删除物品"
	confirm_del.confirmed.connect(_confirm_delete)
	add_child(confirm_del)


func _confirm_delete() -> void:
	if current_path == "":
		return
	var dir := DirAccess.open(ITEMS_DIR)
	if dir != null:
		dir.remove(current_path.get_file())
	current = null
	current_path = ""
	path_label.text = "（未选择）"
	inspector.edit(null)
	refresh()


func _on_save_pressed() -> void:
	if current == null or current_path == "":
		return
	if ResourceSaver.save(current, current_path) != OK:
		push_error("保存失败：" + current_path)
		return
	refresh()
	_select_by_path(current_path)


func _on_save_as_pressed() -> void:
	if current == null:
		return
	var p := _path_for(current)
	if ResourceSaver.save(current, p) != OK:
		push_error("另存为失败：" + p)
		return
	refresh()
	_select_by_path(p)


func _build_import_dialog() -> void:
	import_dialog = AcceptDialog.new()
	import_dialog.title = "从 JSON 导入物品（粘贴数组）"
	import_text = TextEdit.new()
	import_text.custom_minimum_size = Vector2(560, 320)
	import_text.placeholder_text = '[{"id":"hp_pot","name":"治疗药水","type":"scrap","rarity":"common","qty":1,"desc":"回血","stats":{"hp":10}}]'
	import_dialog.add_child(import_text)
	import_dialog.accepted.connect(_on_import_confirmed)
	add_child(import_dialog)


func _on_import_pressed() -> void:
	import_text.text = ""
	import_dialog.popup_centered(Vector2i(600, 400))


func _on_import_confirmed() -> void:
	_ensure_items_dir()
	var txt := import_text.text
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("导入失败：JSON 根节点不是数组")
		return
	var arr: Array = parsed
	var n := 0
	for it in arr:
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var d := it as Dictionary
		var res := ItemData.new()
		res.from_dict(d)
		var p := _path_for(res)
		if ResourceSaver.save(res, p) == OK:
			n += 1
	refresh()
	if n > 0:
		print("物品库：已导入 %d 个 ItemData 到 %s" % [n, ITEMS_DIR])
	else:
		push_warning("物品库：没有导入任何物品（JSON 为空或格式不正确）")


func export_all() -> void:
	if entries.is_empty():
		return
	var arr: Array = []
	for item_v in entries:
		var e := item_v as Dictionary
		var res := e["res"] as ItemData
		arr.append(res.to_dict())
	var txt := JSON.stringify(arr, "\t")
	var p := ITEMS_DIR + "/_all.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_error("导出失败：无法打开 " + p)
		return
	f.store_string(txt)
	f.close()
	print("物品库：已导出 %d 个物品到 %s" % [arr.size(), p])
