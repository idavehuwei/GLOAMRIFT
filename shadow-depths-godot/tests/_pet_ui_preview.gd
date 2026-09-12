extends SceneTree
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true
	g.save_path = "/tmp/embers-pet-ui.json"
	g.in_town = false; g.chapter = 0; g.stage = 0; g.generate_map()
	g.gold = 1234
	g.pets.roster.clear(); g.pets.active = -1
	for i in [0,1,4,9]: g.pets.grant(i, int(g.Data.PETS[i].rarity))
	g.pets.active = 2
	g.pets.active_pet().hp = g.pets.max_hp(g.pets.active_pet())*0.6
	g.modal = "pets"
	g.queue_redraw()
	for i in 6: await process_frame
	await shot("res://tests/_pet_ui_modal.png")
	g.modal = ""
	g.pets.pos = g.player + Vector2(46, 18)
	for k in 20: g.renderer_3d.sync(0.016)
	g.queue_redraw()
	for i in 4: await process_frame
	await shot("res://tests/_pet_ui_hud.png")
	print("pet UI previews written")
	g.queue_free(); await process_frame; quit()
