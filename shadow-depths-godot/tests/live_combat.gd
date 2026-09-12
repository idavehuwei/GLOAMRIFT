extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false); g.muted = true
	g.save_path = "/tmp/embers-live-test.json"
	var frames = 0
	for job in 3:
		g.hero_class = job; g.in_town = false; g.chapter = 0; g.stage = 0; g.generate_map(); g.modal = ""
		g.player = Vector2(435,285); g.facing = Vector2.RIGHT
		for i in 300:
			g.hp = g.max_hp()
			if i%28==0: g.attack(false)
			if i%100==0: g.attack(true)
			if i%180==0: g.combat.ultimate()
			g._process(1.0/30)
			frames += 1
		g.return_town()
		assert(g.in_town and g.enemies.is_empty())
	for c in 5:
		g.chapter = c; g.stage = 2; g.in_town = false; g.generate_map(); g.modal = ""
		var boss = g.enemies.filter(func(e): return e.boss)[0]
		g.player = boss.pos-Vector2(95,0); boss.hp = boss.max*0.4; boss.skill_cd = 0
		for i in 240:
			g.hp = g.max_hp(); g.modal = ""
			g._process(1.0/30)
			frames += 1
		assert(boss.get("enraged",false))
		assert(g.hp>=0)
	print("PASS: ",frames," continuous combat frames; 3 classes, 5 enraged bosses, town transitions")
	g.queue_free(); await process_frame; quit()
