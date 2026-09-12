extends SceneTree
# 暗黑2 式进阶：等级上限 100、三难度、区域等级、经验曲线与等级差惩罚。
var count = 0
func check(ok: bool, message: String):
	count += 1
	if not ok: push_error(message); quit(1)
	assert(ok, message)
func _initialize(): call_deferred("run")

# 按“清完每张图”的节奏推进，返回通关到某一难度时的角色等级。
func simulate(clear_rate: float, upto_diff: int, extra_cycles: int = 0) -> int:
	var level = 1
	var xp = 0
	var Data = load("res://scripts/content.gd")
	for d in range(upto_diff + 1):
		for idx in 15:
			var ch = int(idx / 3)
			var st = idx - ch * 3
			var m = Data.area_level(ch, st, 0, d)
			var total = int(float(22 + 6 * st) * clear_rate)
			var elites = int(float(4 + st) * clear_rate)
			xp += (total - elites) * Data.kill_xp(level, m, false, false)
			xp += elites * Data.kill_xp(level, m, true, false)
			if st == 2: xp += Data.kill_xp(level, m, false, true)
			while level < Data.LEVEL_CAP and xp >= Data.xp_need(level):
				xp -= Data.xp_need(level)
				level += 1
	# 地狱之上反复轮回，直到 100 级
	for c in range(1, extra_cycles + 1):
		if level >= Data.LEVEL_CAP: break
		for idx in 15:
			var ch = int(idx / 3)
			var st = idx - ch * 3
			var m = Data.area_level(ch, st, c, 2)
			var total = int(float(22 + 6 * st) * clear_rate)
			var elites = int(float(4 + st) * clear_rate)
			xp += (total - elites) * Data.kill_xp(level, m, false, false)
			xp += elites * Data.kill_xp(level, m, true, false)
			if st == 2: xp += Data.kill_xp(level, m, false, true)
			while level < Data.LEVEL_CAP and xp >= Data.xp_need(level):
				xp -= Data.xp_need(level)
				level += 1
	return level

func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.muted = true
	g.modal = ""
	g.save_path = "/tmp/embers-progression-test.json"
	var Data = g.Data

	# --- 等级上限与经验曲线 ---
	check(Data.LEVEL_CAP == 100, "Level cap is 100")
	check(Data.xp_need(100) == 0, "No experience is required past the cap")
	for L in range(1, 99):
		check(Data.xp_need(L + 1) > Data.xp_need(L), "Experience requirement grows: " + str(L))
	check(Data.xp_need(1) > 0 and Data.xp_need(1) < 500, "First level is quick but not free")
	check(Data.xp_need(50) > Data.xp_need(20) * 5, "Mid levels cost far more than early ones")

	# --- 区域等级：三难度 + 深渊 ---
	check(Data.area_level(0, 0, 0, 0) == 1, "Normal act one starts at level 1")
	check(Data.area_level(4, 2, 0, 0) == 30, "Normal act five ends at level 30")
	check(Data.area_level(0, 0, 0, 1) == 31, "Nightmare starts where normal ends")
	check(Data.area_level(0, 0, 0, 2) == 61, "Hell starts above nightmare")
	check(Data.area_level(4, 2, 0, 2) == 90, "Hell act five reaches level 90")
	check(Data.area_level(4, 2, 5, 2) == 100, "Area level is capped at 100")
	for d in 3:
		for idx in 15:
			var lv = Data.area_level(int(idx / 3), idx - int(idx / 3) * 3, 0, d)
			check(lv >= 1 and lv <= 100, "Area level stays in range")
	check(Data.area_level(2, 1, 1, 2) > Data.area_level(2, 1, 0, 2), "Abyss cycles raise the area level")

	# --- 等级差修正（暗黑2 的核心机制） ---
	check(abs(Data.xp_ratio(30, 30) - 1.0) < 0.001, "Same level gives full experience")
	check(Data.xp_ratio(30, 40) > 1.0, "Stronger monsters give a bonus")
	check(Data.xp_ratio(30, 60) <= 1.5, "Bonus is capped at +50%")
	check(Data.xp_ratio(30, 25) < 1.0 and Data.xp_ratio(30, 25) > 0.2, "Weaker monsters give less")
	check(Data.xp_ratio(80, 60) < 0.25, "Farming far below your level is punished hard")
	check(Data.xp_ratio(80, 30) < 0.05, "Trivial monsters give almost nothing")
	check(Data.xp_ratio(99, 1) >= 0.02, "Experience ratio never reaches zero")

	# --- 怪物强度随等级与难度 ---
	check(Data.monster_hp(50, false, false, 0) > Data.monster_hp(20, false, false, 0), "Higher level monsters have more life")
	check(Data.monster_hp(50, true, false, 0) > Data.monster_hp(50, false, false, 0), "Elites are tougher")
	check(Data.monster_hp(50, false, true, 0) > Data.monster_hp(50, true, false, 0), "Bosses are the toughest")
	check(Data.monster_hp(50, false, false, 2) > Data.monster_hp(50, false, false, 1), "Hell monsters outlive nightmare monsters")
	check(Data.monster_hp(50, false, false, 1) > Data.monster_hp(50, false, false, 0), "Nightmare monsters outlive normal monsters")
	check(Data.monster_damage(60, 2) > Data.monster_damage(60, 1), "Hell monsters hit harder than nightmare")
	check(Data.monster_damage(60, 1) > Data.monster_damage(60, 0), "Nightmare monsters hit harder than normal")

	# --- 难度表 ---
	check(Data.DIFFICULTIES.size() == 3, "Three difficulties exist")
	check(str(Data.DIFFICULTIES[0].name) == "普通" and str(Data.DIFFICULTIES[2].name) == "地狱", "Difficulties are named")
	check(float(Data.DIFFICULTIES[0].death_xp) == 0.0, "Normal has no experience penalty")
	check(float(Data.DIFFICULTIES[2].death_xp) > float(Data.DIFFICULTIES[1].death_xp), "Hell punishes death harder than nightmare")

	# --- 节奏：普通 / 噩梦 / 地狱 通关等级 ---
	var norm = simulate(1.0, 0)
	var nm = simulate(1.0, 1)
	var hell = simulate(1.0, 2)
	check(norm >= 27 and norm <= 40, "Normal run ends around level 33, got " + str(norm))
	check(nm >= 52 and nm <= 72, "Nightmare run ends around level 62, got " + str(nm))
	check(hell >= 78 and hell <= 95, "Hell run ends around level 86, got " + str(hell))
	check(simulate(0.7, 0) < norm, "Skipping monsters slows you down")
	check(simulate(1.0, 2, 3) == 100, "Abyss cycles are needed to reach level 100")
	check(simulate(1.0, 2, 1) < 100, "One abyss cycle is not enough for level 100")

	# --- 游戏内升级流程 ---
	g.new_game(0)
	g.action("diff:0")
	g.choose_class(0)
	g.in_town = false
	g.chapter = 0
	g.stage = 0
	g.generate_map()
	check(g.level == 1 and g.xp == 0, "A fresh run starts at level one")
	check(g.difficulty == 0, "The chosen difficulty is applied")
	g.gain_xp(Data.xp_need(1) - 1)
	check(g.level == 1, "One experience short of the threshold does not level up")
	g.gain_xp(1)
	check(g.level == 2, "Reaching the threshold levels up")
	check(g.hp == g.max_hp(), "Levelling restores life")
	g.gain_xp(2000000000)
	check(g.level == Data.LEVEL_CAP, "Experience gain is capped at level 100")
	check(g.xp_next() == 0, "No next level at the cap")
	check(g.maxed(), "maxed() reports the cap")
	check(str(g.xp_text()) == "已满级", "Capped characters show a full level label")
	g.gain_xp(999999)
	check(g.level == Data.LEVEL_CAP, "Experience does not overflow the cap")

	# --- 升级不再廉价：低级怪几乎不给经验 ---
	g.level = 60
	g.xp = 0
	g.chapter = 4
	g.stage = 2
	g.difficulty = 2
	g.generate_map()
	var deep = Data.kill_xp(60, g.ilvl(), false, false)
	g.level = 60
	var shallow = Data.kill_xp(60, 5, false, false)
	check(deep > shallow * 20, "On-level kills dwarf low level kills")

	# --- 死亡惩罚 ---
	g.difficulty = 2
	g.level = 50
	g.xp = Data.xp_need(50) - 10
	var before = g.xp
	g.lose_xp_on_death()
	check(g.xp < before, "Dying in hell costs experience")
	var expected = before - int(round(float(Data.xp_need(50)) * float(Data.DIFFICULTIES[2].death_xp)))
	check(g.xp == maxi(0, expected), "Hell takes ten percent of the level")
	g.difficulty = 0
	g.xp = 500
	g.lose_xp_on_death()
	check(g.xp == 500, "Normal difficulty never costs experience")

	# --- 难度解锁与晋升 ---
	g.cleared = [false, false, false]
	check(g.difficulty_unlocked(0) and not g.difficulty_unlocked(1) and not g.difficulty_unlocked(2), "Only normal is unlocked at first")
	g.difficulty = 0
	g.mark_cleared()
	check(g.cleared[0] and g.difficulty_unlocked(1) and not g.difficulty_unlocked(2), "Clearing normal unlocks nightmare")
	check(g.achv.has("nm_clear") == false or g.achv.value("nm_clear") == 0, "Clearing normal does not grant the nightmare achievement")
	g.level = 33
	g.ascend()
	check(g.difficulty == 1, "Ascending moves to nightmare")
	check(g.chapter == 0 and g.stage == 0 and g.cycle == 0, "Ascending restarts the story")
	check(g.level == 33, "Ascending keeps your level")
	check(g.ilvl() > 30, "Nightmare maps start above level 30")
	g.mark_cleared()
	check(g.achv.value("nm_clear") >= 1, "Clearing nightmare is recorded")
	g.ascend()
	check(g.difficulty == 2, "Ascending again moves to hell")
	g.mark_cleared()
	check(g.achv.value("hell_clear") >= 1, "Clearing hell is recorded")
	g.ascend()
	check(g.difficulty == 2, "There is no difficulty beyond hell")

	# --- 存档：难度与解锁状态持久化 ---
	g.difficulty = 2
	g.cleared = [true, true, false]
	g.save_game()
	g.difficulty = 0
	g.cleared = [false, false, false]
	g.load_game()
	check(g.difficulty == 2, "Save keeps the difficulty")
	check(g.cleared[0] and g.cleared[1] and not g.cleared[2], "Save keeps which difficulties are cleared")

	# --- 界面绘制 ---
	g.modal = "difficulty"
	g.queue_redraw()
	await process_frame
	var ids = []
	for b in g.buttons: ids.append(str(b.id))
	check(ids.has("diff:0") and ids.has("diff:1") and ids.has("diff:2"), "Difficulty screen lists every difficulty")
	g.cleared = [false, false, false]
	g.queue_redraw()
	await process_frame
	var offered = 0
	for b in g.buttons:
		if str(b.id).begins_with("diff:"): offered += 1
	check(offered == 1, "Locked difficulties cannot be started")
	g.cleared = [true, true, true]
	g.queue_redraw()
	await process_frame
	offered = 0
	for b in g.buttons:
		if str(b.id).begins_with("diff:"): offered += 1
	check(offered == 3, "Every difficulty opens once cleared")
	g.modal = ""
	g.queue_redraw()
	await process_frame
	check(g.buttons.size() > 0, "HUD still draws")

	print("PASS: ", count, " progression/difficulty checks")
	g.queue_free()
	await process_frame
	quit()
