extends SceneTree
var count = 0
func check(ok: bool,message: String):
	count += 1
	if not ok: push_error(message); quit(1)
	assert(ok,message)
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate(); root.add_child(g); g.set_process(false); g.muted = true; g.modal = ""
	g.save_path = "/tmp/embers-achv-test.json"
	g.in_town = false; g.chapter = 0; g.stage = 0; g.generate_map()
	var a = g.achv
	var Data = g.Data
	check(a != null,"Achievement subsystem exists")

	# --- table integrity ---
	var ids = {}
	for entry in Data.ACHIEVEMENTS:
		var id = str(entry.id)
		check(not ids.has(id),"Achievement id is unique: " + id)
		ids[id] = true
		check(int(entry.kind)>=0 and int(entry.kind)<Data.ACH_KINDS.size(),"Kind in range: " + id)
		check(str(entry.stat)!="","Stat key present: " + id)
		check(int(entry.goal)>0,"Goal positive: " + id)
		check(str(entry.name)!="" and str(entry.desc)!="","Text present: " + id)
	check(Data.ACHIEVEMENTS.size()==39,"39 achievements defined")
	check(Data.bestiary_entries().size()==35,"Bestiary covers 35 entries")

	# --- unlocking by stat ---
	check(not a.has("first_blood"),"First blood starts locked")
	a.bump("kills")
	check(a.has("first_blood"),"First blood unlocks on first kill")
	check(a.done()==1,"Exactly one achievement unlocked")
	a.bump("kills")
	check(a.done()==1,"Unlocking is idempotent")

	# reward payout
	var gold_before = g.gold
	a.bump("kills", 49)
	check(a.has("slayer_50"),"Slayer unlocks at 50 kills")
	check(g.gold > gold_before,"Achievement pays gold reward")
	var potions_before = g.potions
	a.bump("kills", 150)
	check(a.has("slayer_200"),"Slayer 200 unlocks")
	check(g.potions > potions_before,"Potion reward granted")
	check(a.progress_of({"stat":"kills","goal":200}) == [200,200],"Progress caps at goal")

	# --- max-style stats ---
	a.hit(120); check(not a.has("heavy_hit"),"Weak hit does not unlock")
	a.hit(420); check(a.has("heavy_hit"),"Heavy hit unlocks")
	check(int(a.value("max_hit"))==420,"Max hit keeps the highest value")
	a.hit(300); check(int(a.value("max_hit"))==420,"Max hit never decreases")

	# --- combat reports feed bestiary and trophies ---
	var boss = null
	for e in g.enemies:
		if e.boss: boss = e
	if boss == null:
		g.spawn_enemy(g.player+Vector2(40,0),3,false,true)
		boss = g.enemies[g.enemies.size()-1]
	boss.hp = 1.0
	g.combat.hit_enemy(g.enemies.find(boss), 999.0)
	check(a.has("boss_1"),"Boss kill unlocks the slayer achievement")
	check(a.trophies.has("0"),"Trophy recorded for chapter one")
	check(int(a.trophies["0"].get("count",0))==1,"Trophy counts one kill")
	check(a.trophy_count()>=1,"Trophy total counts kills")
	check(a.bestiary.has("0:3"),"Boss recorded in bestiary")
	check(a.bestiary_count()>=1,"Bestiary unlock counter advances")

	# --- loot collection ---
	var shards_before = g.activities.shards
	a.looted({"name":"测试传说剑","slot":0,"rarity":4,"power":120})
	check(a.has("legend_1"),"First legendary unlocks")
	check(a.armory_count()==1,"Legendary enters the armory")
	a.looted({"name":"测试传说剑","slot":0,"rarity":4,"power":90})
	check(a.armory_count()==1,"Duplicate armory entries merge")
	check(int(a.armory[0].get("power",0))==120,"Armory keeps the strongest copy")
	a.looted({"name":"测试史诗甲","slot":1,"rarity":3,"power":60})
	check(a.armory_count()==2,"Epic loot is collected too")
	a.looted({"name":"普通货","slot":0,"rarity":1,"power":10})
	check(a.armory_count()==2,"Common loot is ignored")
	for i in 40: a.looted({"name":"传说 %d" % i,"slot":0,"rarity":4,"power":100+i})
	check(a.armory.size()<=Data.ARMORY_CAP,"Armory respects its cap")
	check(a.has("legend_8"),"Legendary collector unlocks")
	a.upgraded()
	a.contract_done()
	check(int(a.value("upgrades"))==1 and int(a.value("contracts"))==1,"Economy stats recorded")
	check(g.activities.shards >= shards_before,"Achievements can grant shards")

	# --- companions feed the collection ---
	for i in Data.PETS.size(): a.pet_granted(i, 1)
	check(a.has("pet_first"),"First companion unlocks")
	check(a.has("pet_5"),"Five species unlocks")
	check(a.has("pet_all"),"All ten species unlocks")
	a.pet_granted(0, 12)
	check(a.has("pet_lv10"),"Companion level achievement unlocks")
	check(a.pet_seen_count()==Data.PETS.size(),"Companion collection counts species")

	# --- exploration ---
	for i in 9: a.chest()
	a.chest()
	check(a.has("chest_10"),"Chest achievement unlocks")
	for i in 15: a.mark()
	check(a.has("marks_15"),"Mark achievement unlocks")
	g.chapter = 4; g.stage = 2; g.cycle = 3
	a.map_done(true)
	check(int(a.value("max_depth"))>=50,"Depth stat follows depth()")
	check(a.has("deep_20") and a.has("deep_50"),"Depth achievements unlock")
	check(a.has("chapter_5"),"Chapter five unlocks")
	check(a.has("cycle_1"),"Second cycle unlocks")
	check(a.has("flawless"),"Flawless clear unlocks")
	a.victory()
	check(a.has("hidden_return"),"Hidden victory achievement unlocks")
	a.class_picked(0); a.class_picked(1); a.class_picked(2)
	check(a.has("hidden_classes"),"Hidden class achievement unlocks")
	a.died(); check(a.has("death_1"),"Death achievement unlocks")

	# --- gold earned is tracked automatically ---
	g.gold += 5000; a.update(0.016)
	check(int(a.value("gold_total"))>=5000,"Gold earned accumulates")
	check(a.has("rich_1000"),"Gold achievement unlocks")

	# --- filters and pages ---
	check(a.kind_total(0)+a.kind_total(1)+a.kind_total(2)+a.kind_total(3)+a.kind_total(4)==a.total(),"Kind totals sum to total")
	check(a.kind_done(0)<=a.kind_total(0),"Kind progress is bounded")
	check(a.recent().size()>0,"Recent list keeps the newest unlocks")

	# --- panels render through the engine's own draw pass ---
	g.modal = "achievements"
	for tab in 2:
		g.achv_tab = tab
		for kind in [-1,0,1,2,3,4]:
			g.achv_kind = kind
			for page in 3:
				g.achv_page = page
				g.queue_redraw()
				await process_frame
				check(g.buttons.size()>0,"Panel builds clickable elements")
	for t in 4:
		g.coll_tab = t
		g.achv_tab = 1
		g.queue_redraw()
		await process_frame
		check(g.buttons.size()>0,"Collection tab builds clickable elements")
	g.modal = ""
	g.queue_redraw()
	await process_frame
	check(g.buttons.size()>0,"HUD keeps its buttons outside the panel")

	# --- save round trip ---
	g.save_game()
	var raw = JSON.parse_string(FileAccess.get_file_as_string(g.save_path))
	check(int(raw.get("version",0))==6,"Save is version 6")
	check(raw.has("meta"),"Save carries slot metadata")
	check(raw.has("achv"),"Save carries the achievement block")
	var done_before = a.done()
	var stats_before = int(a.value("kills"))
	var bestiary_before = a.bestiary_count()
	var armory_before = a.armory_count()
	a.unlocked.clear(); a.stats.clear(); a.bestiary.clear(); a.armory.clear(); a.pet_seen.clear()
	g.load_game()
	check(g.achv.done()==done_before,"Unlocks survive a save round trip")
	check(int(g.achv.value("kills"))==stats_before,"Stats survive a save round trip")
	check(g.achv.bestiary_count()==bestiary_before,"Bestiary survives a save round trip")
	check(g.achv.armory_count()==armory_before,"Armory survives a save round trip")
	check(g.achv.pet_seen_count()==Data.PETS.size(),"Companion collection survives a save round trip")

	print("PASS achievements: ", count, " checks")
	quit()
