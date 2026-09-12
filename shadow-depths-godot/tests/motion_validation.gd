extends SceneTree
var checks = 0
func check(ok: bool,message: String):
	if not ok: push_error(message); quit(1); assert(ok,message)
	checks += 1
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g)
	g.set_process(false); g.muted = true; g.save_path = "/tmp/embers-motion-test.json"
	g.modal = "gallery"
	var w = g.renderer_3d; w.set_process(false); w.preview_turntable = false
	var holder = Node3D.new(); root.add_child(holder)
	var test_mat = StandardMaterial3D.new()
	w.profile(holder,Vector3.ZERO,[[0.0,0.2,0.2],[0.5,0.3,0.2]],test_mat)
	w.block(holder,Vector3(0,0.6,0),Vector3.ONE*0.2,test_mat)
	var expected_faces = 0
	for mesh in holder.get_children(): expected_faces += mesh.mesh.get_faces().size()
	w.detailer.bake(holder)
	check(holder.get_child(0).mesh.get_faces().size()==expected_faces,"Custom armor triangles survive indexed mesh merging")
	holder.free()
	var transition_model = w.character(-1); root.add_child(transition_model)
	w.motion.update(transition_model,0,false,"attack",0.48)
	var before = transition_model.get_node("SwordArm").quaternion
	w.motion.play(transition_model,"hit",0.4)
	w.motion.update(transition_model,1.0/120.0)
	check(before.angle_to(transition_model.get_node("SwordArm").quaternion)<0.25,"Interrupted attack blends without a shoulder snap")
	w.motion.play(transition_model,"attack",0.5)
	w.motion.update(transition_model,0.2,true)
	var walking_leg = transition_model.get_node("LeftLeg").rotation
	w.motion.update(transition_model,0.2,false)
	check(walking_leg.distance_to(transition_model.get_node("LeftLeg").rotation)>0.05,"Movement is retained under upper-body attacks")
	w.motion.play(transition_model,"death",0.5)
	w.motion.play(transition_model,"hit",0.2)
	check(transition_model.get_meta("action")=="death","Late hit cannot interrupt death")
	transition_model.free()
	var kinds = [-1,-10,-11,-2,-3,-4,-5,-6,0,1,2,4,5,6,3]
	for i in kinds.size():
		g.gallery_index = i; w.preview(kinds[i]); g.queue_redraw()
		var model = w.preview_subject
		var sheet = Image.create(1280,800,false,Image.FORMAT_RGBA8); sheet.fill(Color("161e24"))
		for a in 8:
			var action = w.motion.ACTIONS[a]; w.preview_action = action
			w.motion.update(model,0.016,false,action,0.42)
			check(model.get_meta("pose_action")==action,"Every model supports action "+action)
			check(model.transform.is_finite(),"Finite model transform")
			g.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var shot = w.preview_viewport.get_texture().get_image()
			sheet.blit_rect(shot,Rect2i(0,0,320,400),Vector2i((a%4)*320,int(a/4)*400))
		if i in [0,1,2,5,11,12,14]: sheet.save_png("res://tests/motion_%02d.png" % i)
		if kinds[i]==-11:
			w.motion.update(model,0,false,"attack",0.4)
			check(model.get_node("ShieldArm/Elbow/Bow/NockedArrow").scale.x>0.9,"Arrow is nocked during draw")
			w.motion.update(model,0,false,"idle",0.4)
			check(model.get_node("ShieldArm/Elbow/Bow/NockedArrow").scale.x<0.01,"Arrow hides after release")
		if kinds[i] in [4,5]:
			w.motion.update(model,0,false,"walk",0.2)
			var one = model.get_node("Leg_-1_0"); var two = model.get_node("Leg_1_0")
			check(one.rotation.distance_to(two.rotation)>0.05,"Independent left/right foot phases")
		else:
			check(model.has_node("Head") and model.has_node("LeftLeg/Knee") and model.has_node("SwordArm/Elbow"),"Articulated humanoid hierarchy")
	w.preview_action = "idle"
	g.modal = ""; g.in_town = false; g.generate_map()
	for cls in 3:
		g.hero_class = cls; g.generate_map(); g.attack_cd = 0; g.mana = 100
		g.combat.attack(false); check(w.hero.get_meta("action")=="attack","Attack event reaches model")
		g.ultimate_cd = 0; g.combat.ultimate(); check(w.hero.get_meta("action")=="skill","Ultimate event reaches model")
		g.dash_cd = 0; g.combat.dodge(); check(w.hero.get_meta("action")=="dodge","Dodge event reaches model")
		g.invincible = 0; g.combat.hurt_player(1); check(w.hero.get_meta("action")=="hit","Hit event reaches model")
		w.motion.update(w.hero,1.0); check(w.hero.get_meta("pose_action")=="idle","Action returns to idle")
	var count = w.actors.size(); g.defeat(0); w.sync(0.016)
	check(w.actors.size()==count-1 and w.fallen.size()==1,"Dead actor retained only as animated corpse")
	for frame in 100: w.sync(0.02)
	check(w.fallen.is_empty(),"Corpse cleaned up")
	g.in_town = true; g.generate_map()
	check(w.npc_models.size()==g.townsfolk.size(),"Every town profession has an animated model")
	var smith = w.npc_models[2]
	w.motion.update(smith,0.016,false,"work",0.1); var start = smith.get_node("SwordArm").rotation
	w.motion.update(smith,0.016,false,"work",0.6)
	check(start.distance_to(smith.get_node("SwordArm").rotation)>0.1,"Smith work animation changes over time")
	print("PASS: %d motion checks; 15 models, 8 actions, live combat hooks, corpse cleanup and NPC work" % checks)
	g.queue_free(); await process_frame; quit()
