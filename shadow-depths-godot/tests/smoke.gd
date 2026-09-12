extends SceneTree
var checks = 0
func check(ok: bool, message: String):
	if not ok: push_error(message); quit(1)
	assert(ok,message)
	checks += 1
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.muted = true
	game.in_town = false
	game.save_path = "/tmp/embers-test-save.json"
	for c in 5:
		for s in 3:
			game.chapter = c; game.stage = s; game.generate_map()
			check(game.walkable(game.player),"Spawn must be walkable")
			check(game.flow.has(Vector2i(game.portal/30)),"Exit must be reachable")
			for d in game.drops: check(game.flow.has(Vector2i(d.pos/30)),"Quest item must be reachable")
			for e in game.enemies: check(game.flow.has(Vector2i(e.pos/30)),"Enemy must be reachable")
			for chest in game.chests: check(game.flow.has(Vector2i(chest.pos/30)),"Chest must be reachable")
			check(not game.ready_exit(),"Cannot skip quest")
			check(game.enemies.filter(func(e): return e.boss).size() == (1 if s==2 else 0),"Chapter boss placement")
	game.chapter = 0; game.stage = 0; game.generate_map(); game.modal = ""
	game.enemies = [{"pos":game.player+Vector2(20,0),"hp":1.0,"max":1.0,"type":0,"boss":false,"hit":0.0,"cd":0.0}]
	game.attack(false)
	check(game.enemies.is_empty(),"Melee defeats enemy")
	check(game.xp>0 and game.gold>0,"Combat awards XP and gold")
	game.marks = 3
	check(game.ready_exit(),"Completed quest unlocks exit")
	for n in 15:
		if game.in_town: game.quest_accepted = true; game.leave_town()
		game.next_map()
	check(game.chapter==0 and game.stage==0 and game.cycle==1,"All five chapters lead to endless cycle")
	var unique = {}
	for n in 1000:
		var item = game.Data.loot(game.rng,n+1)
		unique[item.name] = true
		check(item.power>n,"Endless loot scales")
	check(unique.size()>500,"Loot variety")
	game.inventory = [game.Data.loot(game.rng,8,true)]
	var slot = game.inventory[0].slot
	var name_before = game.inventory[0].name
	game.equip_item()
	check(game.equipped[slot].name==name_before,"Equip changes correct slot")
	game.gold = 1234; game.save_game(); game.gold = 0; game.load_game()
	check(game.gold==1234 and game.cycle==1,"Save/load round trip")
	game.hp = 1; game.potions = 1; game.heal()
	check(game.hp>1 and game.potions==0,"Potion restores HP and consumes charge")
	game.modal = "dead"
	var event = InputEventKey.new(); event.physical_keycode = KEY_ESCAPE; event.pressed = true
	game._input(event)
	check(game.modal=="dead","Escape cannot bypass death")
	print("PASS: ",checks," checks; 15 maps, combat, loot, equipment, persistence, endless loop")
	game.queue_free()
	await process_frame
	quit()
