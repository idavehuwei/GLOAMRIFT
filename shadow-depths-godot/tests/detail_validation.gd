extends SceneTree
func _initialize(): call_deferred("run")
func capture(g,path: String):
	g.queue_redraw(); await process_frame; await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false); g.muted = true
	g.save_path = "/tmp/embers-details-test.json"
	var holder = Node3D.new(); root.add_child(holder)
	var part = g.renderer_3d.block(holder,Vector3.ZERO,Vector3(2,0.1,0.1),g.renderer_3d.materials.values()[0],Vector3(0,0,PI/2))
	assert((part.basis * Vector3(0.5,0,0)).distance_to(Vector3(0,1,0)) < 0.001)
	holder.queue_free()
	g.renderer_3d.preview_turntable = false
	g.modal = "gallery"
	for i in 15:
		g.gallery_index = i
		await capture(g,"res://tests/model_%02d.png" % i)
		assert(g.renderer_3d.preview_subject != null)
	g.modal = "contracts"
	await capture(g,"res://tests/panel_contracts.png")
	g.modal = "character"
	await capture(g,"res://tests/panel_character.png")
	g.modal = ""; g.in_town = false; g.generate_map()
	g.player = g.activities.sites[0].pos; g.renderer_3d.update_camera(0,true); g.renderer_3d.sync(0.1)
	await capture(g,"res://tests/altar.png")
	assert(g.renderer_3d.materials.values().any(func(m): return m.roughness_texture!=null))
	print("PASS: 15 model gallery views; portrait, contracts, altar and roughness maps")
	g.queue_free(); await process_frame; quit()
