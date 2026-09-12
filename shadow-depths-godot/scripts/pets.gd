extends RefCounted
# 小宠物系统：抽卡获取、首领掉落、自动作战、阵亡 30 秒后自动复活。
# 战斗数值全部按 depth() 缩放，保证后期宠物依然有意义。
const Data = preload("res://scripts/content.gd")
const REVIVE_TIME = 30.0
const MAX_ROSTER = 10
var g
var roster: Array = []
var active = -1
var pos = Vector2.ZERO
var facing = Vector2.RIGHT
var cd = 0.0
var moving = false
var result_name = ""
var result_rarity = -1
var result_new = false

func _init(owner_game):
	g = owner_game
	pos = owner_game.player + Vector2(-26, 26)

# ---------- 数值 ----------
func spec(p: Dictionary) -> Dictionary: return Data.PETS[clampi(int(p.species), 0, Data.PETS.size() - 1)]
func active_pet():
	if active >= 0 and active < roster.size(): return roster[active]
	return null
func max_hp(p: Dictionary) -> float: return float(spec(p).hp) + int(p.rarity) * 30 + int(p.level) * 24
func power(p: Dictionary) -> float: return (float(spec(p).power) + int(p.rarity) * 4 + int(p.level) * 3.4) * (1.0 + g.depth() * 0.10)
func rate(p: Dictionary) -> float: return maxf(0.34, float(spec(p).rate) - int(p.rarity) * 0.05 - int(p.level) * 0.008)
func ranged(p: Dictionary) -> bool: return bool(spec(p).ranged)
func reach(p: Dictionary) -> float: return 210.0 if ranged(p) else 48.0
func rarity_color(p: Dictionary) -> Color: return Color(Data.RARITY_COLORS[clampi(int(p.rarity), 0, 4)])

# ---------- 获取 ----------
func cost() -> int: return 90 + g.depth() * 18
func roll_rarity(rng: RandomNumberGenerator, floor_rarity: int) -> int:
	var weights = [54.0, 26.0, 13.0, 5.0, 2.0]
	var total = 0.0
	for i in 5:
		if i < floor_rarity: weights[i] = 0.0
		total += weights[i]
	var r = rng.randf() * total
	for i in 5:
		r -= weights[i]
		if r <= 0: return i
	return 0
func pick_species(rng: RandomNumberGenerator, rarity: int) -> int:
	var pool = []
	for i in Data.PETS.size():
		if int(Data.PETS[i].rarity) == rarity: pool.append(i)
	if pool.is_empty(): pool = [0]
	return pool[rng.randi_range(0, pool.size() - 1)]
func grant(species: int, rarity: int):
	var info = Data.PETS[species]
	var pet = null
	for p in roster:
		if int(p.species) == species: pet = p; break
	if pet != null:
		# 重复物种转为进阶，避免背包被低星宠物塞满。
		pet.level = int(pet.level) + 2
		pet.hp = max_hp(pet); pet.alive = true; pet.revive = 0.0
		result_name = str(pet.name) + " 进阶 Lv." + str(pet.level)
		result_new = false
	else:
		if roster.size() >= MAX_ROSTER: make_room()
		pet = {"species": species, "name": info.name, "rarity": rarity, "level": 1, "xp": 0, "hp": 0.0, "alive": true, "revive": 0.0}
		pet.hp = max_hp(pet)
		roster.append(pet)
		result_name = str(info.name)
		result_new = true
	result_rarity = rarity
	if active < 0 or active >= roster.size(): active = roster.find(pet)
	return pet
# 栏位满了又抽到新物种时，最弱的一只自行离开，避免首领掉落被浪费。
func make_room():
	if roster.size() < MAX_ROSTER: return
	var weakest = 0
	for i in roster.size():
		var a = roster[i]; var b = roster[weakest]
		if int(a.rarity) * 100 + int(a.level) < int(b.rarity) * 100 + int(b.level): weakest = i
	var gone = roster[weakest]
	g.note("伙伴栏已满，" + str(gone.name) + " 选择离开，把位置让给新人。")
	roster.remove_at(weakest)
	if active == weakest: active = -1 if roster.is_empty() else 0
	elif active > weakest: active -= 1
func gacha() -> bool:
	var price = cost()
	if roster.size() >= MAX_ROSTER: g.note("伙伴栏已满（%d / %d），先放生一只再来。" % [roster.size(), MAX_ROSTER]); return false
	if g.gold < price: g.note("金币不足，抽一次需要 %d 金。" % price); return false
	g.gold -= price
	var rarity = roll_rarity(g.rng, 0)
	var pet = grant(pick_species(g.rng, rarity), rarity)
	if pet == null: return false
	if result_new: g.note("伙伴加入：" + str(pet.name) + "（" + Data.RARITY_NAMES[int(pet.rarity)] + "）")
	else: g.note(result_name)
	g.tone(760, 0.16)
	if g.renderer_3d != null: g.renderer_3d.cast_charge(g.player, rarity_color(pet), 90, 0.5)
	return true
func boss_reward():
	# 每章首领掉落更好的伙伴：稀有起步，最终章必出传说。
	var rarity = clampi(g.chapter + 1 + (1 if g.rng.randf() < 0.3 else 0), 2, 4)
	if g.chapter >= 4: rarity = 4
	var pet = grant(pick_species(g.rng, rarity), rarity)
	if pet == null: return
	if result_new: g.note("首领掉落伙伴：" + str(pet.name) + "（" + Data.RARITY_NAMES[int(pet.rarity)] + "）")
	else: g.note(result_name + " · 来自首领的馈赠")
	g.tone(880, 0.22)
	if g.renderer_3d != null: g.renderer_3d.cast_charge(g.player, rarity_color(pet), 130, 0.7)

# ---------- 战斗 ----------
func nearest_enemy() -> int:
	var best = -1
	var best_dist = 1e9
	for i in g.enemies.size():
		var e = g.enemies[i]
		var d = pos.distance_to(e.pos)
		if d < best_dist: best_dist = d; best = i
	return best
func attack_target(p: Dictionary, index: int):
	if index < 0 or index >= g.enemies.size(): return
	var e = g.enemies[index]
	var dmg = power(p)
	if ranged(p):
		g.combat.shoot(pos, pos.direction_to(e.pos), str(spec(p).bolt), dmg, false, 1)
	else:
		g.combat.hit_enemy(index, dmg)
		if index < g.enemies.size() and g.enemies[index] == e and g.renderer_3d != null:
			g.renderer_3d.impact(e.pos, Color(str(spec(p).color)), 0.7)
	gain_xp(p, 3)
	if g.renderer_3d != null: g.renderer_3d.animate_pet("attack", 0.40)
func gain_xp(p: Dictionary, amount: int):
	p.xp = int(p.xp) + amount
	var need = int(p.level) * 22
	while int(p.xp) >= need:
		p.xp = int(p.xp) - need
		p.level = int(p.level) + 1
		p.hp = max_hp(p)
		need = int(p.level) * 22
		g.note(str(p.name) + " 升到 Lv." + str(p.level))
		g.tone(700, 0.12)
func follow_only(dt: float):
	var goal = g.player + Vector2(-26, 26)
	var delta = goal - pos
	moving = delta.length() > 7.0
	if moving:
		pos = g.move_actor(pos, delta.normalized() * minf(150.0 * dt, delta.length()))
		if delta.length() > 2.0: facing = delta.normalized()
	if pos.distance_to(g.player) > 430: pos = g.move_actor(g.player, Vector2(-24, 24))
func update(dt: float):
	var p = active_pet()
	if p == null: return
	if not bool(p.alive):
		p.revive = maxf(0.0, float(p.revive) - dt)
		moving = false
		if p.revive <= 0: revive(p)
		return
	cd = maxf(0.0, cd - dt)
	var index = nearest_enemy()
	var goal = g.player + Vector2(-26, 26)
	var engage = false
	if index >= 0:
		var e = g.enemies[index]
		if e.pos.distance_to(g.player) < 430:
			engage = true
			var away = (pos - e.pos)
			if away.length() < 0.01: away = Vector2.DOWN
			goal = e.pos + away.normalized() * (reach(p) * 0.72)
			if pos.distance_to(e.pos) <= reach(p):
				facing = pos.direction_to(e.pos) if pos.distance_to(e.pos) > 1 else facing
				if cd <= 0:
					cd = rate(p)
					attack_target(p, index)
		else: index = -1
	if not engage and index < 0:
		p.hp = minf(max_hp(p), float(p.hp) + maxf(4.0, max_hp(p) * 0.05) * dt)
	var delta = goal - pos
	var dist = delta.length()
	moving = dist > 7.0
	if moving:
		var speed = 168.0 if pos.distance_to(g.player) > 260 else 142.0
		if engage and index < g.enemies.size() and pos.distance_to(g.enemies[index].pos) <= reach(p): speed = 0.0
		pos = g.move_actor(pos, delta.normalized() * minf(speed * dt, dist))
		if delta.length() > 2.0: facing = delta.normalized()
	# 卡住或掉队太远时拉回主人身边，避免宠物留在地图另一头。
	if pos.distance_to(g.player) > 430: pos = g.move_actor(g.player, Vector2(-24, 24))
func hurt(amount: float):
	var p = active_pet()
	if p == null or not bool(p.alive): return
	p.hp = maxf(0.0, float(p.hp) - amount)
	g.floating(pos, "-" + str(int(amount)), Color("d78f7f"))
	if g.renderer_3d != null: g.renderer_3d.impact(pos, Color("d78f7f"), 0.6)
	if p.hp <= 0:
		p.alive = false
		p.revive = REVIVE_TIME
		g.note(str(p.name) + " 倒下了，30 秒后会重新站起。")
		g.tone(150, 0.18)
		if g.renderer_3d != null: g.renderer_3d.animate_pet("death", 0.9)
func splash(amount: float):
	var p = active_pet()
	if p == null or g.in_town: return
	hurt(amount)
func soak(e: Dictionary, amount: float) -> bool:
	# 宠物在附近时会替主人挡下一部分攻击：这也是它会阵亡的原因。
	var p = active_pet()
	if p == null or not bool(p.alive) or g.in_town: return false
	if pos.distance_to(e.pos) > 100.0: return false
	if g.rng.randf() < 0.60:
		hurt(amount)
		if g.renderer_3d != null: g.renderer_3d.impact(pos, Color("e8c08a"), 0.5)
		return true
	hurt(amount * 0.35)
	return false
func revive(p: Dictionary):
	p.alive = true
	p.revive = 0.0
	p.hp = max_hp(p) * 0.7
	g.note(str(p.name) + " 重新站了起来！")
	g.tone(720, 0.20)
	g.burst(pos, Color(str(spec(p).color)))
	if g.renderer_3d != null: g.renderer_3d.animate_pet("idle", 0.4)

# ---------- 指令 ----------
func set_active(index: int):
	if index < 0 or index >= roster.size(): return
	active = index
	var p = roster[index]
	g.note(str(p.name) + " 出战。")
	g.tone(660, 0.12)
func toggle():
	var p = active_pet()
	if p == null: g.note("还没有伙伴。去城镇宠物商那里抽一只。"); return
	if active == -1: return
	# 关闭出战 = 收起宠物；再点一次放回场上。
	if p.get("resting", false):
		p.resting = false; g.note(str(p.name) + " 出战。")
	else:
		p.resting = true; g.note(str(p.name) + " 回到笼子里休息。")
	g.tone(600, 0.1)
func release():
	var p = active_pet()
	if p == null: return
	g.note("放生了 " + str(p.name) + "。它看了你一眼，走了。")
	roster.remove_at(active)
	active = -1 if roster.is_empty() else clampi(active, 0, roster.size() - 1)
func reset_position():
	pos = g.player + Vector2(-26, 26)
	cd = 0.0
	if g.in_town:
		var p = active_pet()
		if p != null: p.hp = max_hp(p); p.alive = true; p.revive = 0.0
func snapshot() -> Dictionary: return {"roster": roster, "active": active}
func restore(data: Dictionary):
	var list = data.get("roster", [])
	roster.clear()
	if list is Array:
		for entry in list:
			if not entry is Dictionary: continue
			var pet = {
				"species": clampi(int(entry.get("species", 0)), 0, Data.PETS.size() - 1),
				"name": str(entry.get("name", Data.PETS[0].name)),
				"rarity": clampi(int(entry.get("rarity", 0)), 0, 4),
				"level": maxi(1, int(entry.get("level", 1))),
				"xp": maxi(0, int(entry.get("xp", 0))),
				"hp": float(entry.get("hp", 1.0)),
				"alive": bool(entry.get("alive", true)),
				"revive": float(entry.get("revive", 0.0))}
			roster.append(pet)
	active = clampi(int(data.get("active", -1)), -1, roster.size() - 1)
	for p in roster: p.hp = clampf(float(p.hp), 1.0, max_hp(p))
	reset_position()
