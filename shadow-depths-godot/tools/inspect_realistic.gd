extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var world = Node3D.new(); root.add_child(world)
	var env = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("242b32"); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color.WHITE; e.ambient_light_energy = 0.65; env.environment = e; world.add_child(env)
	var light = DirectionalLight3D.new(); world.add_child(light); light.rotation_degrees = Vector3(-35,-35,0); light.light_energy = 1.8
	var cam = Camera3D.new(); world.add_child(cam); cam.position = Vector3(2,1.4,3.8); cam.look_at(Vector3(0,0.95,0)); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.5
	var paths = ["01_角色/ShadowDepths/char_warrior.glb","02_怪物/ShadowDepths/boss_warrok.glb","01_角色/永雾大陆2026/char_human_m.glb","01_角色/永雾大陆2026/char_human_f.glb","03_NPC/ShadowDepths/npc_mara.glb","02_怪物/永雾大陆2026/mon_drowned.glb"]
	for i in paths.size():
		var doc = GLTFDocument.new(); var state = GLTFState.new(); var err = doc.append_from_file("/Users/weihu/AI/GLB资源/原始GLB/"+paths[i],state)
		if err!=OK: continue
		var model = doc.generate_scene(state); world.add_child(model)
		var bounds = AABB(); var first = true
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var box = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box); first = false
		var s = 1.8 / bounds.size.y; model.scale = Vector3.ONE*s; model.position = Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*s
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/candidate_%d.png"%i)
		print(i," ",paths[i]," ",bounds)
		model.free()
	quit()
