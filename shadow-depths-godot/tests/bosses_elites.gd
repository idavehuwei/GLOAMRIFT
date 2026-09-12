extends SceneTree
var count = 0
func check(ok: bool,message: String):
	count += 1
	if not ok: push_error(message); quit(1)
	assert(ok,message)
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false); g.muted = true; g.modal = ""; g.in_town = false
	g.save_path = "/tmp/embers-boss-test.json"
	for c in 5:
		for s in 3:
			g.chapter = c; g.stage = s; g.generate_map()
			check(g.W*g.H==1944,"Expanded maps are 54 by 36")
			check(g.enemies.filter(func(e): return e.get("elite",false)).size()==4+s,"Each map has 4-6 elites")
			var kinds = {}
			for e in g.enemies: kinds[e.type] = true
			check(kinds.size()>=6,"Six regular monster types on each map")
			for d in g.drops: check(g.flow.has(Vector2i(d.pos/30)),"Distant quest item reachable")
		g.enemies.clear(); g.spawn_enemy(Vector2(525,285),3,false,true)
		g.player = Vector2(435,285)
		var boss = g.enemies[0]
		boss.skill_cd = 0; g.enemy_skills.update(boss,0.1)
		check(not g.effects.is_empty() or not g.projectiles.is_empty(),"Boss uses a special ability")
		boss.skill_cd = 0; g.enemy_skills.update(boss,0.1)
		if c==0: check(g.enemies.size()>1,"Gravekeeper summons skeletons")
		if c==2: check(g.projectiles.any(func(p): return p.kind=="icebolt"),"Ice knight uses freezing projectiles")
		if c==4: check(g.projectiles.size()>=8,"Void king fires radial projectiles")
		boss.hp = boss.max*0.4; boss.skill_cd = 0; g.enemy_skills.update(boss,0.1)
		check(boss.get("enraged",false) and boss.skill_cd<3,"Each boss enters faster phase two")
		g.drops.clear(); g.defeat(0)
		check(g.drops.size()==3,"Boss drops three items")
		check(g.drops.any(func(d): return d.item.rarity==4),"Boss guarantees legendary")
		g.enemies.clear(); g.drops.clear(); g.spawn_enemy(Vector2(435,285),0,true)
		g.defeat(0)
		check(g.drops.size()==2 and g.drops.all(func(d): return d.item.rarity>=2),"Elite guarantees two rare-or-better items")
		g.effects.clear(); g.projectiles.clear()
	# Telegraph is visible first; damage only arrives after warning expires.
	g.hp = g.max_hp(); g.invincible = 0
	g.enemy_skills.zone(g.player,70,Color.RED)
	var hp = g.hp; g.combat.update(0.5); check(g.hp==hp,"Boss warning gives reaction time")
	g.combat.update(0.6); check(g.hp<hp,"Boss zone applies real damage")
	print("PASS: ",count," map/elite/boss checks")
	g.queue_free(); await process_frame; quit()
