extends SceneTree
# 开始界面 / 存档管理的核对截图：tests/_title_*.png
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true
	g.slot_dir = "/tmp/embers_title_slots/"
	DirAccess.make_dir_recursive_absolute("/tmp/embers_title_slots")
	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))
	# 槽位一：深入第三章的法师
	g.new_game(0); g.action("diff:0"); g.choose_class(1)
	g.level = 14; g.gold = 3420; g.achv.bump("kills", 87); g.chapter = 2; g.stage = 1; g.in_town = false
	g.generate_map(); g.time = 4520.0; g.save_game()
	# 槽位二：刚出城的战士
	g.new_game(1); g.action("diff:0"); g.choose_class(0)
	g.level = 4; g.gold = 260; g.achv.bump("kills", 11); g.chapter = 0; g.stage = 0; g.in_town = true
	g.generate_map(); g.time = 640.0; g.save_game()
	g.refresh_slots()
	g.title_time = 6.0
	g.modal = "title"
	g.queue_redraw()
	await shot("res://tests/_title_screen.png")
	g.modal = "saves"; g.save_mode = "load"
	g.queue_redraw()
	await shot("res://tests/_title_saves_load.png")
	g.save_mode = "save"
	g.queue_redraw()
	await shot("res://tests/_title_saves_save.png")
	g.modal = "pause"
	g.queue_redraw()
	await shot("res://tests/_title_pause.png")
	g.modal = "class"
	g.queue_redraw()
	await shot("res://tests/_title_class.png")
	print("title previews written")
	g.queue_free(); await process_frame; quit()
