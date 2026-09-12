extends SceneTree
# 开始界面与三存档槽：新建 / 读取 / 覆盖 / 删除、元信息、旧档兼容、界面绘制。
var pass_count = 0
var fail_count = 0

func check(cond: bool, msg: String):
	if cond: pass_count += 1
	else:
		fail_count += 1
		print("FAIL: ", msg)

func _initialize(): call_deferred("run")

func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.muted = true
	g.slot_dir = "/tmp/embers_slots/"
	DirAccess.make_dir_recursive_absolute("/tmp/embers_slots")
	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))
	g.refresh_slots()

	check(g.slot_path(0) != g.slot_path(1) and g.slot_path(1) != g.slot_path(2), "Each slot has its own file")
	check(g.slot_cache.size() == 3, "Three slots are cached")
	check(bool(g.slot_info(0).get("empty", false)), "Fresh slots read as empty")
	check(g.latest_slot() == -1, "No latest slot while every slot is empty")
	check(g.first_empty_slot() == 0, "First empty slot is the first one")

	# --- 新游戏 ---
	g.new_game(0)
	check(g.modal == "difficulty", "New game opens difficulty selection")
	check(g.difficulty_unlocked(0) and not g.difficulty_unlocked(1), "Only normal is unlocked at first")
	g.action("diff:0")
	check(g.modal == "class", "Picking a difficulty opens class selection")
	check(g.slot == 0 and g.save_path == g.slot_path(0), "New game targets the chosen slot")
	check(g.level == 1 and g.gold == 0 and g.inventory.is_empty(), "New game wipes previous progress")
	check(g.chapter == 0 and g.stage == 0 and g.cycle == 0, "New game restarts the story")
	check(g.pets.roster.is_empty(), "New game clears the pet roster")
	check(g.achv.done() == 0, "New game clears achievements")
	g.choose_class(2)
	check(g.hero_class == 2, "Class is chosen")
	check(FileAccess.file_exists(g.slot_path(0)), "Choosing a class writes the slot")

	g.level = 9
	g.achv.bump("kills", 12)
	g.gold = 777
	g.save_game()
	g.refresh_slots()
	var m = g.slot_meta(0)
	check(int(m.get("level", 0)) == 9, "Meta keeps the level")
	check(int(m.get("gold", 0)) == 777, "Meta keeps the gold")
	check(int(m.get("hero_class", 0)) == 2, "Meta keeps the class")
	check(int(m.get("kills", 0)) == 12, "Meta keeps the kill count")
	check(str(m.get("location", "")) != "", "Meta keeps the location name")
	check(int(m.get("saved", 0)) > 0, "Meta keeps a save timestamp")
	check(not bool(g.slot_info(0).get("empty", true)), "Used slot is no longer empty")

	# --- 第二个槽位互不干扰 ---
	g.new_game(1)
	g.action("diff:0")
	check(g.level == 1 and g.gold == 0, "Second slot starts fresh")
	g.choose_class(0)
	g.level = 3
	g.save_game()
	g.refresh_slots()
	check(int(g.slot_meta(0).get("level", 0)) == 9, "Slot one keeps its own progress")
	check(int(g.slot_meta(1).get("level", 0)) == 3, "Slot two stores its own progress")
	check(g.latest_slot() == 1, "Latest slot is the most recently saved one")

	# --- 读取 ---
	g.continue_slot(0)
	check(g.level == 9 and g.gold == 777, "Continue restores slot one")
	check(g.hero_class == 2, "Continue restores the class")
	check(g.slot == 0, "Continue tracks the loaded slot")
	check(g.modal == "", "Continue closes every modal")

	# --- 保存到指定槽位 ---
	g.action("slot_save:2")
	check(FileAccess.file_exists(g.slot_path(2)), "Saving into slot three writes a file")
	check(g.slot == 2 and g.save_path == g.slot_path(2), "Current slot follows the save target")
	check(g.modal == "", "Saving into a slot resumes the game")
	g.refresh_slots()
	check(g.latest_slot() == 2, "Saving into a slot makes it the latest")

	# --- 删除需要二次确认 ---
	g.action("slot_del:2")
	check(FileAccess.file_exists(g.slot_path(2)), "First delete click only asks")
	check(g.del_confirm == 2, "Delete confirmation is armed")
	g.action("del_cancel")
	check(g.del_confirm == -1, "Cancel disarms the deletion")
	g.action("slot_del:2")
	g.action("slot_del:2")
	check(not FileAccess.file_exists(g.slot_path(2)), "Confirmed delete removes the file")
	g.refresh_slots()
	check(bool(g.slot_info(2).get("empty", true)), "Deleted slot reads as empty")

	# --- 旧档（没有 meta 段）也能被识别 ---
	var legacy = JSON.parse_string(FileAccess.get_file_as_string(g.slot_path(0)))
	legacy.erase("meta")
	var lf = FileAccess.open(g.slot_path(1), FileAccess.WRITE)
	lf.store_string(JSON.stringify(legacy))
	lf.close()
	g.refresh_slots()
	var lm = g.slot_meta(1)
	check(not bool(g.slot_info(1).get("empty", true)), "Legacy save without meta is detected")
	check(int(lm.get("level", 0)) == 9, "Legacy meta falls back to top level fields")
	check(int(lm.get("hero_class", 0)) == 2, "Legacy meta falls back for the class")

	# --- 界面绘制 ---
	g.modal = "title"
	g.refresh_slots()
	g.queue_redraw()
	await process_frame
	var ids = []
	for b in g.buttons: ids.append(str(b.id))
	check(ids.has("slot_new:2"), "Title screen offers the empty slot")
	check(ids.has("slot_load:0") and ids.has("slot_load:1"), "Title screen offers both saves")
	check(ids.has("quit") and ids.has("mute"), "Title screen has quit and sound controls")
	g.action("saves")
	g.save_mode = "load"
	g.queue_redraw()
	await process_frame
	check(g.modal == "saves" and g.buttons.size() > 0, "Save manager draws in load mode")
	g.save_mode = "save"
	g.queue_redraw()
	await process_frame
	check(g.buttons.size() > 0, "Save manager draws in save mode")
	g.modal = "pause"
	g.queue_redraw()
	await process_frame
	check(g.buttons.size() > 0, "Pause menu still draws")
	g.modal = ""
	g.queue_redraw()
	await process_frame
	check(g.buttons.size() > 0, "HUD draws outside any panel")

	# --- 回车：全空则新开，有档则续 ---
	g.modal = "title"
	g.refresh_slots()
	g.action("title_enter")
	check(g.level == 9, "Enter resumes the latest save")
	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))
	g.refresh_slots()
	g.action("title_enter")
	check(g.modal == "difficulty", "Enter offers difficulty selection when every slot is empty")

	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))
	print("PASS ", pass_count, " checks")
	if fail_count > 0: print("FAILED ", fail_count)
	quit()
