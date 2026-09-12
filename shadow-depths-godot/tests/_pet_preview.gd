extends SceneTree
# 一次性检查脚本：把十种小宠物造型渲染成截图，便于人工核对。
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true; g.modal = ""
	g.save_path = "/tmp/embers-pet-preview.json"
	g.in_town = false; g.chapter = 0; g.stage = 0; g.generate_map()
	g.player = Vector2(300, 300)
	g.renderer_3d.update_camera(0, true)
	for i in 10:
		g.pets.roster.clear(); g.pets.active = -1
		var rarity = int(g.Data.PETS[i].rarity)
		g.pets.grant(i, rarity)
		g.pets.result_name = ""
		g.renderer_3d.rebuild()
		g.enemies.clear()
		g.spawn_enemy(g.player + Vector2(-70, 30), 0)
		g.pets.pos = g.player + Vector2(46, 18)
		for k in 26: g.renderer_3d.sync(0.016)
		await shot("res://tests/_pet_%d.png" % i)
	print("Companion previews written to res://tests/_pet_*.png")
	g.queue_free(); await process_frame; quit()
