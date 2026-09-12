extends SceneTree
var checks = 0
func check(ok: bool,message: String):
	checks += 1
	if not ok: push_error(message); quit(1)
	assert(ok,message)
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false); g.muted = true; g.modal = ""
	g.save_path = "/tmp/embers-activity-test.json"
	var a = g.activities
	a.contract_action(0); check(a.contracts[0].accepted,"Town contract can be accepted")
	for i in 12: a.progress("kill")
	var gold = g.gold; a.contract_action(0)
	check(a.contracts[0].claimed and g.gold>gold and g.inventory.size()==1,"Contract awards item and gold")
	gold = g.gold; a.contract_action(0); check(g.gold==gold,"Cannot claim twice")
	var before = a.shards; a.salvage(); check(a.shards>before and g.inventory.is_empty(),"Salvage yields material")
	g.gold = 100000; a.shards = 1000
	var power = g.equipped[0].power
	for i in 6: a.upgrade(0)
	check(g.equipped[0].upgrade==5 and g.equipped[0].power==power+5*(2+int(g.ilvl()*0.4)),"Upgrade caps at five")
	g.in_town = false; g.generate_map()
	var rank = g.equipped[0].upgrade; a.upgrade(0); check(g.equipped[0].upgrade==rank,"Cannot craft outside town")
	for site in a.sites: check(g.flow.has(Vector2i(site.pos/30)),"Activity site reachable")
	var damage = g.damage(); g.player = a.sites[0].pos; g.interact()
	check(a.buff_time==90 and g.damage()>damage,"Altar grants actual damage buff")
	a.update(91); check(g.damage()==damage,"Buff expires")
	g.enemies.clear(); g.player = a.sites[1].pos; g.interact()
	check(g.enemies.size()==3 and a.challenge_active,"Trial summons three elites")
	var shards = a.shards; g.drops.clear()
	while not g.enemies.is_empty(): g.defeat(0)
	check(not a.challenge_active and a.shards>=shards+10,"Trial completion awards shards")
	check(g.drops.any(func(d): return d.item.rarity>=3),"Trial grants epic gear")
	g.in_town = true; g.save_game(); a.shards = 0; g.load_game()
	check(a.shards>0 and a.contracts[0].claimed,"Activity persistence")
	a.next_chapter(); check(not a.contracts[0].accepted and a.contracts[0].count==0,"New chapter refreshes contracts")
	print("PASS: ",checks," activities/crafting checks")
	g.queue_free(); await process_frame; quit()
