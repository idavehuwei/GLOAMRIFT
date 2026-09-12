extends SceneTree
# 把五栋建筑一字排开单独渲染核对
func _initialize(): call_deferred("run")
func shot(path):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var scene_root = Node3D.new(); root.add_child(scene_root)
	var cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.7
	scene_root.add_child(cam); cam.position = Vector3(0, 1.2, 1.0); cam.look_at(Vector3(0,0.05,0))
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -35, 0); sun.light_energy = 1.2
	scene_root.add_child(sun)
	var env = WorldEnvironment.new(); var e = Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("20242a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("9aa3ad"); e.ambient_light_energy = 0.7
	env.environment = e; scene_root.add_child(env)
	var names = ["smithy","alchemy","inn","den","tower"]
	for i in names.size():
		var packed = load("res://assets/models/architecture/%s.glb" % names[i])
		if packed == null: print("missing ", names[i]); continue
		var m = packed.instantiate()
		scene_root.add_child(m)
		m.position = Vector3((i-2)*0.42, 0, 0)
	await shot("res://tests/_buildings_all.png")
	print("isolate shot done")
	quit()
