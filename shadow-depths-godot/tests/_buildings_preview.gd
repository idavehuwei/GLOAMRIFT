extends SceneTree
# 城镇建筑（HY3D GLB）核对截图：tests/_town_buildings.png
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true
	g.slot_dir = "/tmp/embers_bld_slots/"
	DirAccess.make_dir_recursive_absolute("/tmp/embers_bld_slots")
	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))

	g.new_game(0); g.action("diff:0"); g.choose_class(0)
	g.in_town = true
	g.generate_map()
	g.modal = ""
	# 拉远相机看整个城镇广场与四栋建筑
	var w = g.renderer_3d
	for c in w.scenery.get_children():
		if str(c.name).begins_with("Building_"):
			print("placed: ", c.name, " pos=", c.position)
	# 停掉渲染器自身的 _process，避免 sync 每帧覆盖相机
	if w != null: w.set_process(false)
	if w != null:
		w.camera.size = 22.0
		g.player = Vector2(435, 300)
		w.update_camera(1.0, true)
	g.queue_redraw()
	await shot("res://tests/_town_buildings.png")

	if w != null:
		w.camera.size = 14.0
		g.player = Vector2(435, 165)
		w.update_camera(1.0, true)
	await shot("res://tests/_town_buildings_north.png")

	if w != null:
		g.player = Vector2(420, 465)
		w.update_camera(1.0, true)
	await shot("res://tests/_town_buildings_south.png")

	for i in g.SLOT_COUNT: g.remove_save(g.slot_path(i))
	print("town buildings previews written")
	g.queue_free(); await process_frame; quit()
