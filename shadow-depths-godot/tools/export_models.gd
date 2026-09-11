extends SceneTree
# Export original, articulated geometry and sampled joint clips for external editing.
func _initialize(): call_deferred("run")
func clean_hidden(n: Node):
	for c in n.get_children():
		if c is Node3D and not c.visible: c.free()
		else: clean_hidden(c)
func own_and_clean(n: Node,owner_root: Node):
	for key in n.get_meta_list(): n.remove_meta(key)
	for c in n.get_children(): c.owner = owner_root; own_and_clean(c,owner_root)
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false)
	g.muted = true; g.save_path = "/tmp/embers-export-test.json"; g.modal = "gallery"
	var w = g.renderer_3d; w.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models"))
	var entries = [[-1,"warrior"],[-10,"mage"],[-11,"ranger"],[-2,"courier"],[-3,"apothecary"],[-4,"smith"],[-5,"tutor"],[-6,"innkeeper"],[0,"soldier"],[1,"skeleton"],[2,"cultist"],[4,"hound"],[5,"spider"],[6,"crossbowman"]]
	for chapter in 5: entries.append([3,"boss_%d" % (chapter+1),chapter])
	for entry in entries:
		g.chapter = entry[2] if entry.size()>2 else 0
		var export_root = Node3D.new(); export_root.name = entry[1]; root.add_child(export_root)
		var model = w.character(entry[0]); model.name = "Model"; export_root.add_child(model)
		clean_hidden(model); w.motion.cache(model)
		var player = AnimationPlayer.new(); player.name = "AnimationPlayer"; export_root.add_child(player)
		var lib = AnimationLibrary.new(); player.add_animation_library("",lib)
		var joints = model.get_meta("joints").duplicate()
		joints[""] = {"node":model}
		for action in w.motion.ACTIONS:
			var anim = Animation.new(); anim.length = 1.0
			var loop = action in ["idle","walk","work"]
			anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			var tracks = {}
			for path in joints:
				var node_path = "Model"+("/"+path if path!="" else "")
				var pos_track = anim.add_track(Animation.TYPE_POSITION_3D); anim.track_set_path(pos_track,NodePath(node_path))
				var rot_track = anim.add_track(Animation.TYPE_ROTATION_3D); anim.track_set_path(rot_track,NodePath(node_path))
				var scale_track = anim.add_track(Animation.TYPE_SCALE_3D); anim.track_set_path(scale_track,NodePath(node_path))
				tracks[path] = [pos_track,rot_track,scale_track]
			for frame in 25:
				var time = float(frame)/24
				w.motion.update(model,0,false,action,0.0 if frame==24 and loop else minf(time,0.999))
				for path in joints:
					var node = joints[path].node
					anim.position_track_insert_key(tracks[path][0],time,node.position)
					anim.rotation_track_insert_key(tracks[path][1],time,node.quaternion)
					anim.scale_track_insert_key(tracks[path][2],time,node.scale)
			lib.add_animation(action,anim)
		w.motion.update(model,0,false,"idle",0)
		own_and_clean(export_root,export_root)
		var document = GLTFDocument.new(); var state = GLTFState.new()
		var err = document.append_from_scene(export_root,state)
		if err!=OK: push_error("GLTF conversion failed "+entry[1]); quit(1); return
		var path = "res://assets/models/"+entry[1]+".glb"
		err = document.write_to_filesystem(state,path)
		if err!=OK: push_error("GLTF write failed "+entry[1]); quit(1); return
		var verify = GLTFState.new()
		if document.append_from_file(path,verify)!=OK or verify.get_animations().size()!=8:
			push_error("GLTF reimport/animation verification failed "+entry[1]); quit(1); return
		print("EXPORTED ",entry[1],": ",verify.get_animations().size()," clips")
		export_root.free()
	print("PASS: 19 articulated GLB assets exported and reimported; 152 animation clips")
	g.queue_free(); await process_frame; quit()
