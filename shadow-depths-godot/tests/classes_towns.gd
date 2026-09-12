extends SceneTree
var count = 0
func check(ok: bool,message: String):
	count += 1
	if not ok: push_error(message); quit(1)
	assert(ok,message)
func enemy(p: Vector2,uid: int = 1,hp: float = 500) -> Dictionary:
	return {"pos":p,"hp":hp,"max":hp,"type":0,"boss":false,"hit":0.0,"cd":2.0,"uid":uid}
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false); g.muted = true; g.save_path = "/tmp/embers-classes-save.json"
	check(g.in_town and g.modal=="title","New game opens on the title screen in town")
	for c in 5:
		g.chapter = c; g.in_town = true; g.quest_accepted = false; g.generate_map(); g.modal = ""
		check(g.enemies.is_empty() and g.drops.is_empty(),"Every chapter town is safe")
		check(g.townsfolk.size()==6,"Six NPC services including the companion broker")
		check(g.townsfolk[5].role=="伙伴契约","Sixth resident sells companions")
		check(g.flow.has(Vector2i(g.portal/30)),"Town gate reachable")
		for n in g.townsfolk: check(g.flow.has(Vector2i(n.pos/30)),"All services reachable")
		g.attack(false); g.attack(true); g.combat.ultimate()
		check(g.projectiles.is_empty() and g.effects.is_empty(),"Combat disabled in town")
		g.player = g.portal; g.interact(); check(g.in_town,"Quest required before departure")
		g.player = g.townsfolk[0].pos; g.interact(); check(g.modal=="npc","NPC interaction opens service screen")
		g.action("accept"); check(g.quest_accepted,"Quest accepted")
		g.player = g.portal; g.interact(); check(not g.in_town and g.enemies.size()>0,"Town gate leads to wilderness")
		g.return_town(); check(g.in_town and g.enemies.is_empty(),"Recall is safe")
		g.modal = ""; g.hp = 1; g.mana = 0; g.action("rest"); check(g.hp==g.max_hp() and g.mana==100,"Inn restores resources")
		g.gold = 25; var potions = g.potions; g.action("buy"); check(g.gold==0 and g.potions==potions+1,"Apothecary price and stock")
	g.chapter = 0; g.stage = 0
	for job in 3:
		g.modal = "trainer"; g.choose_class(job); g.in_town = false; g.generate_map(); g.modal = ""
		check(g.hero_class==job and g.hp==g.max_hp(),"Class selection updates health")
		g.player = Vector2(435,285); g.facing = Vector2.RIGHT; g.mana = 100; g.attack_cd = 0; g.nova_cd = 0; g.ultimate_cd = 0
		g.enemies = [enemy(g.player+Vector2(45,0),1),enemy(g.player+Vector2(95,0),2)]
		g.attack(false)
		if job==0: check(g.enemies[0].hp<500,"Warrior melee damage")
		else:
			check(g.projectiles.size()==1,"Ranged primary spawns projectile")
			for i in 15: g.combat.update(0.025)
			check(g.enemies[0].hp<500,"Ranged projectile deals damage")
		g.attack(true); check(g.nova_cd>0 and g.mana==75,"Secondary consumes resource and starts cooldown")
		if job==0:
			g.combat.update(0.3); check(g.effects.any(func(e): return e.kind=="whirlwind"),"Warrior sustained whirlwind")
		elif job==1: check(g.enemies[0].get("slow",0)>0,"Mage nova freezes")
		else: check(g.projectiles.size()>=5,"Archer five-way volley")
		var mana = g.mana; g.attack(true); check(g.mana==mana,"Cooldown prevents repeat spending")
		g.combat.ultimate(); check(g.ultimate_cd>0 and g.mana==30,"Ultimate has resource cost and cooldown")
		g.dash_cd = 0; var before = g.player; g.dash(); check(g.player!=before and g.invincible>0,"Class mobility moves with immunity")
		g.projectiles.clear(); g.effects.clear()
	# Walls stop projectiles and melee; fast projectile stepping cannot tunnel.
	g.hero_class = 2; g.player = Vector2(435,285); g.facing = Vector2.RIGHT
	g.tiles[9][16] = 0; g.enemies = [enemy(Vector2(525,285))]; g.attack_cd = 0; g.attack(false)
	g.combat.update(0.5); check(g.enemies[0].hp==500,"Arrow cannot pass through a wall")
	g.in_town = true; g.quest_accepted = true; g.save_game(); g.hero_class = 0; g.in_town = false; g.load_game()
	check(g.in_town and g.hero_class==2 and g.quest_accepted,"Save persists town, class and quest")
	# Chapter completion always arrives in the next town.
	g.chapter = 0; g.stage = 2; g.in_town = false; g.next_map()
	check(g.chapter==1 and g.in_town and not g.quest_accepted and g.enemies.is_empty(),"Next chapter spawns in its own town")
	g.modal = "dead"; g.action("retry"); check(g.in_town and g.hp>0,"Death respawns in town")
	# Pause freezes combat time and cooldowns.
	g.modal = "pause"; g.nova_cd = 3; g._process(1.0); check(g.nova_cd==3,"Pause freezes cooldowns")
	print("PASS: ",count," town/class checks")
	g.queue_free(); await process_frame; quit()
