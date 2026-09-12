extends SceneTree
# 难度系统与经验曲线的核对截图：tests/_difficulty_*.png
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true
	g.slot_dir = "/tmp/embers_diff_slots/"
	DirAccess.make_dir_recursive_absolute("/tmp/embers_diff_slots")
	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))

	# 只解锁普通难度
	g.new_game(0)
	g.modal = "difficulty"
	g.queue_redraw()
	await shot("res://tests/_difficulty_select.png")

	# 全解锁：三个难度都可选
	g.cleared = [true, true, true]
	g.queue_redraw()
	await shot("res://tests/_difficulty_unlocked.png")

	# 地狱难度第五章：HUD 上的难度、区域等级与经验条
	g.action("diff:2")
	g.choose_class(1)
	g.level = 87
	g.xp = int(g.Data.xp_need(87) * 0.42)
	g.gold = 184000
	g.chapter = 4; g.stage = 2; g.cycle = 1; g.in_town = false
	g.generate_map()
	g.hp = g.max_hp() * 0.72
	g.modal = ""
	g.queue_redraw()
	await shot("res://tests/_difficulty_hud.png")

	# 角色面板：等级 / 经验 / 难度
	g.modal = "character"
	g.queue_redraw()
	await shot("res://tests/_difficulty_character.png")

	# 通关地狱后的胜利面板：可以留在深渊继续深入
	g.cycle = 1
	g.modal = "victory"
	g.queue_redraw()
	await shot("res://tests/_difficulty_victory.png")

	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))
	print("difficulty previews written")
	g.queue_free(); await process_frame; quit()
