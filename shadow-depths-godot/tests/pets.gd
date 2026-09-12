extends SceneTree
var count = 0
func check(ok: bool,message: String):
	count += 1
	if not ok: push_error(message); quit(1)
	assert(ok,message)
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false); g.muted = true; g.modal = ""
	g.save_path = "/tmp/embers-pets-test.json"
	g.in_town = false; g.chapter = 0; g.stage = 0; g.generate_map()
	var pets = g.pets
	check(pets != null,"Pet subsystem exists")
	# Town has the pet merchant as a sixth resident.
	g.in_town = true; g.generate_map()
	check(g.townsfolk.size()==6,"Town hosts six residents including the pet merchant")
	check(g.townsfolk[5].role=="伙伴契约","Sixth resident is the companion broker")
	g.in_town = false; g.generate_map()
	# Gacha: spend gold, fill the roster, duplicates convert into levels.
	g.gold = 999999
	var price = pets.cost()
	check(price>0,"Gacha has a gold price")
	for i in 40: check(pets.gacha(),"Gacha succeeds with enough gold")
	check(pets.roster.size()<=10,"Roster is capped at ten companions")
	check(pets.active_pet()!=null,"An active companion is selected")
	for p in pets.roster:
		check(int(p.species)>=0 and int(p.species)<10,"Companion species in range")
		check(int(p.rarity)>=0 and int(p.rarity)<=4,"Companion rarity in range")
		check(pets.max_hp(p)>0 and pets.power(p)>0,"Companion has stats")
		check(float(p.hp)>0,"Companion has health")
	var poor = g.gold; g.gold = 0
	check(not pets.gacha(),"Gacha refuses without gold"); g.gold = poor
	# Combat: a melee companion damages enemies on its own.
	pets.set_active(0)
	var p = pets.active_pet()
	p.species = 1; p.rarity = 0; p.level = 1; p.hp = pets.max_hp(p); p.alive = true
	g.enemies.clear()
	g.spawn_enemy(g.player+Vector2(60,0),0)
	var e = g.enemies[0]
	pets.pos = e.pos + Vector2(30,0)
	var hp_before = e.hp
	for i in 40: pets.update(0.08)
	check(e.hp<hp_before or g.enemies.is_empty(),"Melee companion damages enemies automatically")
	# Ranged companion fires projectiles instead of biting.
	g.projectiles.clear(); g.enemies.clear()
	g.spawn_enemy(g.player+Vector2(120,0),0)
	e = g.enemies[0]
	p.species = 4; p.hp = pets.max_hp(p); p.alive = true
	pets.pos = e.pos + Vector2(120,0)
	for i in 40: pets.update(0.08)
	check(g.projectiles.any(func(pr): return not pr.hostile),"Ranged companion shoots projectiles")
	# Death and automatic 30 second revival.
	g.projectiles.clear()
	p.hp = 5.0
	pets.hurt(999.0)
	check(not bool(p.alive),"Companion dies at zero health")
	check(absf(float(p.revive)-30.0)<0.01,"Revival timer starts at 30 seconds")
	pets.update(29.0)
	check(not bool(p.alive),"Companion stays down before the timer ends")
	pets.update(1.2)
	check(bool(p.alive),"Companion revives automatically after 30 seconds")
	check(float(p.hp)>0,"Revived companion has health")
	# Soaking: a nearby companion can take the hit for the player.
	g.enemies.clear(); g.spawn_enemy(pets.pos+Vector2(20,0),0)
	var player_hp = g.hp
	var soaked = false
	for i in 12:
		if pets.soak(g.enemies[0],10.0): soaked = true
	check(soaked,"Companion can soak damage for the player")
	check(pets.soak({"pos":g.player+Vector2(900,0)},10.0)==false,"Distant companion cannot soak")
	# Boss drops: every chapter boss yields rare-or-better companions.
	for c in 5:
		g.chapter = c; g.stage = 2; g.generate_map()
		g.enemies.clear(); g.drops.clear()
		g.spawn_enemy(g.player+Vector2(60,0),3,false,true)
		var before = pets.roster.size()
		g.defeat(0)
		var best = -1
		for q in pets.roster: best = maxi(best,int(q.rarity))
		check(best>=2,"Chapter %d boss drops rare-or-better companion" % (c+1))
		check(pets.roster.size()>=before,"Boss reward never shrinks the roster")
	var legendary = false
	for q in pets.roster:
		if int(q.rarity)==4: legendary = true
	check(legendary,"Final chapter boss grants a legendary companion")
	# Save and load round trip keeps the roster.
	g.in_town = true; g.generate_map()
	var size_before = pets.roster.size()
	var name_before = str(pets.active_pet().name)
	g.save_game(); g.load_game()
	check(g.pets.roster.size()==size_before,"Saved roster size survives reload")
	check(str(g.pets.active_pet().name)==name_before,"Active companion survives reload")
	print("PASS: ",count," companion system checks")
	g.queue_free(); await process_frame; quit()
func Data_rarity(p: Dictionary) -> int: return int(p.rarity)
