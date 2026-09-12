extends RefCounted
# 成就与收藏系统：统计驱动成就解锁，同时维护怪物图鉴、装备陈列、首领纪念与伙伴名录。
# 统计键由 game / combat / activities / pets 各处上报，解锁后自动发放奖励并弹出提示。
const Data = preload("res://scripts/content.gd")
const TOAST_TIME = 4.6
var g
var stats: Dictionary = {}
var unlocked: Dictionary = {}
var order: Array = []
var toasts: Array = []
var bestiary: Dictionary = {}
var armory: Array = []
var trophies: Dictionary = {}
var pet_seen: Dictionary = {}
var classes_tried: Dictionary = {}
var last_gold = 0
var clock = 0.0

func _init(owner_game):
	g = owner_game
	last_gold = int(g.gold)

# ---------- 统计 ----------
func value(key: String) -> float: return float(stats.get(key, 0))
func bump(key: String, amount: float = 1.0):
	stats[key] = value(key) + amount
	check()
func set_max(key: String, amount: float):
	if amount <= value(key): return
	stats[key] = amount
	check()
func has(id: String) -> bool: return bool(unlocked.get(id, false))
func total() -> int: return Data.ACHIEVEMENTS.size()
func done() -> int: return unlocked.size()
func progress_of(a: Dictionary) -> Array:
	return [mini(int(value(str(a.stat))), int(a.goal)), int(a.goal)]

# ---------- 解锁 ----------
func check():
	for a in Data.ACHIEVEMENTS:
		var id = str(a.id)
		if unlocked.has(id): continue
		if value(str(a.stat)) >= float(a.goal): unlock(a)
func unlock(a: Dictionary, quiet: bool = false):
	var id = str(a.id)
	if unlocked.has(id): return
	unlocked[id] = true
	order.append(id)
	pay(a.get("reward", {}))
	if not quiet:
		toasts.append({"title": str(a.name), "desc": str(a.desc), "color": Color(Data.ACH_KIND_COLORS[int(a.kind)]), "life": TOAST_TIME})
		if toasts.size() > 3: toasts.remove_at(0)
		g.note("成就解锁：" + str(a.name) + " · " + str(a.desc))
		g.tone(920, 0.18)
func pay(reward: Dictionary):
	if reward.is_empty(): return
	var gold = int(reward.get("gold", 0))
	var potions = int(reward.get("potions", 0))
	var shards = int(reward.get("shards", 0))
	if gold > 0: g.gold += gold
	if potions > 0: g.potions += potions
	if shards > 0 and g.activities != null: g.activities.shards += shards

# ---------- 战斗上报 ----------
func killed(e: Dictionary):
	bump("kills")
	var title = str(e.get("name", "亡者"))
	var key = "%d:%d" % [int(g.chapter), int(e.get("type", 0))]
	var entry = bestiary.get(key, {"kills": 0, "depth": g.depth(), "name": title})
	entry["kills"] = int(entry.get("kills", 0)) + 1
	entry["name"] = title
	bestiary[key] = entry
	if bool(e.get("boss", false)):
		bump("bosses")
		var tk = str(int(g.chapter))
		var t = trophies.get(tk, {"count": 0, "depth": g.depth(), "name": title})
		t["count"] = int(t.get("count", 0)) + 1
		t["name"] = title
		t["depth"] = mini(int(t.get("depth", g.depth())), g.depth())
		trophies[tk] = t
	if bool(e.get("elite", false)): bump("elites")
func hit(quantity: float): set_max("max_hit", quantity)
func died(): bump("deaths")
func looted(item: Dictionary):
	var rarity = int(item.get("rarity", 0))
	if rarity >= 4: bump("legendaries")
	if rarity >= 3:
		var name = str(item.get("name", ""))
		var found = null
		for a in armory:
			if str(a.get("name", "")) == name: found = a; break
		if found != null:
			if int(item.get("power", 0)) > int(found.get("power", 0)):
				found["power"] = int(item.get("power", 0))
				found["rarity"] = rarity
				found["depth"] = g.depth()
		else:
			armory.append({"name": name, "slot": int(item.get("slot", 0)), "rarity": rarity, "power": int(item.get("power", 0)), "depth": g.depth()})
			armory.sort_custom(func(a, b): return int(a.get("rarity", 0)) * 10000 + int(a.get("power", 0)) > int(b.get("rarity", 0)) * 10000 + int(b.get("power", 0)))
			if armory.size() > Data.ARMORY_CAP: armory = armory.slice(0, Data.ARMORY_CAP)
func chest(): bump("chests")
func mark(): bump("marks")
func upgraded(): bump("upgrades")
func contract_done(): bump("contracts")
func class_picked(index: int):
	classes_tried[str(index)] = true
	set_max("classes", classes_tried.size())
func pet_granted(species: int, level: int):
	bump("pets")
	var key = str(species)
	var cur = int(pet_seen.get(key, 0))
	if level > cur: pet_seen[key] = level
	set_max("pet_species", pet_seen.size())
	set_max("pet_level", maxi(int(pet_seen.get(key, 0)), level))
func map_done(no_hit: bool):
	set_max("max_depth", g.depth())
	set_max("max_chapter", g.chapter + 1)
	set_max("cycle", g.cycle)
	set_max("max_level", g.level)
	if no_hit: bump("clean_maps")
func cycle_done(): set_max("cycle", g.cycle)
func victory(): bump("victories")

# ---------- 每帧 ----------
func update(dt: float):
	bump_quiet("playtime", dt)
	for t in toasts: t.life -= dt
	toasts = toasts.filter(func(t): return float(t.life) > 0)
	clock -= dt
	if g.gold > last_gold: bump("gold_total", g.gold - last_gold)
	last_gold = int(g.gold)
	if clock <= 0:
		clock = 1.0
		set_max("max_level", g.level)
		set_max("max_depth", g.depth())
		set_max("max_chapter", g.chapter + 1)
		set_max("cycle", g.cycle)
func bump_quiet(key: String, amount: float): stats[key] = value(key) + amount

# ---------- 查询 ----------
func bestiary_count() -> int:
	var n = 0
	for e in Data.bestiary_entries():
		if bestiary.has(str(e.key)): n += 1
	return n
func pet_seen_count() -> int: return pet_seen.size()
func armory_count() -> int: return armory.size()
func trophy_count() -> int:
	var n = 0
	for k in trophies: n += int(trophies[k].get("count", 0))
	return n
func kind_done(kind: int) -> int:
	var n = 0
	for a in Data.ACHIEVEMENTS:
		if int(a.kind) == kind and has(str(a.id)): n += 1
	return n
func kind_total(kind: int) -> int:
	var n = 0
	for a in Data.ACHIEVEMENTS:
		if int(a.kind) == kind: n += 1
	return n
func recent() -> Array:
	var out = []
	for i in range(order.size() - 1, maxi(-1, order.size() - 4), -1): out.append(order[i])
	return out

# ---------- 存档 ----------
func snapshot() -> Dictionary:
	return {"stats": stats, "unlocked": unlocked, "order": order, "bestiary": bestiary, "armory": armory, "trophies": trophies, "pet_seen": pet_seen, "classes": classes_tried}
func restore(data: Dictionary):
	stats = {}
	var st = data.get("stats", {})
	if st is Dictionary:
		for k in st: stats[str(k)] = float(st[k])
	unlocked = {}
	var un = data.get("unlocked", {})
	if un is Dictionary:
		for k in un: unlocked[str(k)] = bool(un[k])
	elif un is Array:
		for k in un: unlocked[str(k)] = true
	order = []
	for id in data.get("order", []): order.append(str(id))
	for id in unlocked:
		if not order.has(id): order.append(id)
	bestiary = {}
	var be = data.get("bestiary", {})
	if be is Dictionary:
		for k in be: bestiary[str(k)] = be[k]
	armory = []
	for a in data.get("armory", []): armory.append(a)
	trophies = {}
	var tr = data.get("trophies", {})
	if tr is Dictionary:
		for k in tr: trophies[str(k)] = tr[k]
	pet_seen = {}
	var ps = data.get("pet_seen", {})
	if ps is Dictionary:
		for k in ps: pet_seen[str(k)] = int(ps[k])
	classes_tried = {}
	var cl = data.get("classes", {})
	if cl is Dictionary:
		for k in cl: classes_tried[str(k)] = true
	last_gold = int(g.gold)
	toasts.clear()
