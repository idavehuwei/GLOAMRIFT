extends SceneTree

var checks := 0
func check(ok: bool,msg: String):
	if not ok: push_error(msg); quit(1); return
	checks += 1

func _initialize(): call_deferred("run")

func run():
	var expected = {"warrior": ["male", "sword", "shield"], "mage": ["female", "staff", ""], "archer": ["female", "bow", "quiver"]}
	var ages = {"warrior":36,"mage":27,"archer":23,"npc_courier":24,"npc_apothecary":48,"npc_smith":52,"npc_mentor":72,"npc_innkeeper":66,"npc_petkeeper":21}
	for file in ages:
		if not expected.has(file): expected[file] = ["female" if file in ["npc_apothecary","npc_mentor","npc_petkeeper"] else "male", "", ""]
	var report = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/realistic/authored/build_report.json"))
	var face_signatures = {}
	for file in expected:
		check(report[file].age == ages[file],file+" age recorded")
		check(report[file].gender == expected[file][0],file+" gender recorded")
		var scene: PackedScene = load("res://assets/models/realistic/authored/"+file+".glb")
		check(scene != null,file+" GLB is importable")
		var model = scene.instantiate(); root.add_child(model)
		var skeleton: Skeleton3D = model.get_node_or_null("Rig/Skeleton3D")
		check(skeleton != null,file+" has a Skeleton3D")
		print(file," bones=",skeleton.get_bone_count()); check(skeleton.get_bone_count() >= 30,file+" has hand/finger/garment bones")
		var player: AnimationPlayer = model.get_node_or_null("AnimationPlayer")
		check(player != null,file+" has AnimationPlayer")
		for action in ["idle","walk","attack","skill","dodge","hit","death","work"]: check(player.has_animation(action),file+" missing "+action)
		var variant_count = 0
		for child in skeleton.get_children():
			if child is MeshInstance3D and child.name.begins_with("Gear_"): variant_count += 1
			if child is MeshInstance3D and child.name == "Body_head":
				var signature = hash(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
				check(not face_signatures.has(signature),file+" has distinct face geometry")
				face_signatures[signature] = true
		check(variant_count >= 8,file+" has separate removable gear slot meshes")
		# Equipment sockets are created at runtime by world_3d so weapon assets can be replaced.
		for socket_bone in ["hand_r", "hand_l", "lower_arm_l", "chest"]: check(skeleton.find_bone(socket_bone) >= 0,file+" has "+socket_bone+" socket bone")
		model.free()
	check(face_signatures.size() == ages.size(),"All nine identities have a distinct head mesh")
	print("PASS: ",checks," authored realistic class, skeleton, slot and animation checks")
	quit()
