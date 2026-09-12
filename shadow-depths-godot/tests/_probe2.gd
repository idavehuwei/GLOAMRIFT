extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true; g.modal = ""
	g.save_path = "/tmp/embers-pet-probe.json"
	g.in_town = false; g.chapter = 0; g.stage = 0; g.generate_map()
	g.player = Vector2(300, 300)
	g.pets.roster.clear(); g.pets.active = -1
	g.pets.grant(0, 0)
	g.renderer_3d.rebuild()
	g.pets.pos = g.player + Vector2(46, 18)
	for k in 10: g.renderer_3d.sync(0.016)
	var r = g.renderer_3d
	print("ring=", r.pet_ring, " ring_parent=", r.pet_ring.get_parent() if r.pet_ring else null)
	print("model=", r.pet_model)
	if r.pet_model:
		print("pos=", r.pet_model.position, " visible=", r.pet_model.visible, " scale=", r.pet_model.scale, " children=", r.pet_model.get_child_count())
		for c in r.pet_model.get_children(): print("  child ", c.get_class(), " ", c.name if "name" in c else "", " vis=", c.visible if "visible" in c else "")
	print("pets.pos=", g.pets.pos, " active_pet=", g.pets.active_pet() != null)
	quit()
