extends Node
## 玩家、战斗、物品、任务、存档。数值对齐网页版。

signal log_line(text: String)
signal hint_line(text: String)
signal zone_changed(n: String, sub: String)
signal died
signal cine(kind: String, meta: Dictionary)
signal npc_open(id: String)
signal world_ui(kind: String, payload: Dictionary)
signal ui_refresh
signal floats(pos: Vector3, text: String, color: Color, size: int)

var P: Dictionary = {}
var item_seq := 1
var save_slot := 0
var way_diff_pick := "normal"
var last_cursor := Vector3.ZERO
var pending_enter := ""
var pending_intro := false
var booting := false
var story: Dictionary = {}
var cine_boss: Dictionary = {}
var shop_stock: Array = []
var gamble_stake := 1
var last_gamble: Dictionary = {}
var feel: Dictionary = {}
var cam_shake := 0.0

const SLOT_KEYS := ["helm", "amulet", "ring1", "ring2", "belt", "weapon", "armor", "offhand", "gloves", "boots"]


func _ready() -> void:
	reset_blank()


func reset_blank() -> void:
	P = {
		"name": "流浪者", "cls": "warrior", "x": 0.0, "z": 0.0, "dir": 0.0,
		"lvl": 1, "xp": 0, "xpNext": 60, "gold": 150, "pts": 0, "skPts": 1,
		"base": {"str": 14, "dex": 12, "vit": 16, "ene": 10},
		"hp": 1.0, "mp": 1.0, "hpMax": 1.0, "mpMax": 1.0,
		"path": [], "target": null, "atkCd": 0.0,
		"anim": {"walk": 0.0, "atk": 0.0, "atkDone": true},
		"equip": {}, "bag": [], "potHp": 5, "potMp": 4,
		"ranks": {}, "barSkills": ["", "", "", "", "", ""], "mouseSkills": ["", ""], "cds": {},
		"potCd": 0.0, "alive": true, "kills": 0, "eliteKills": 0, "bossKills": 0,
		"killByType": {}, "cleared": {},
		"shield": 0.0, "shieldT": 0.0, "invuln": 0.0, "buffs": {},
		"casting": "", "castT": 0.0, "channel": null,
		"pickupTarget": null, "npcTarget": "", "onMark": null, "trackId": "q1",
		"hub": "town", "nameForgotten": false, "flags": {}, "talents": {},
		"knownPhrases": {}, "skRunes": {}, "phrases": {},
		"diff": "normal", "diffMax": "normal", "clearedDiff": {}, "nameLost": 0,
		"quests": {}, "discovered": {}, "stats": {}, "ach": {},
		"stun": 0.0, "chill": 0.0, "frozen": 0.0, "lastSkill": "aa",
		"lastChase": 0.0, "lastHold": 0.0, "recallNotes": 0, "shopDisc": 0, "suKills": 0, "charms": [],
		"relics": [], "codex": [], "tokens": {}, "luck": {}, "powers": {}, "sets": {}, "up": {},
		"bountyDay": "", "bountyList": [], "bountyClaimed": {}, "bountyChest": false,
		"bountyPotless": 0, "bountyDun": {}, "enough": 0.0, "holdStand": false
	}
	for k in SLOT_KEYS:
		P.equip[k] = null
	for q in Data.QUESTS:
		P.quests[q.id] = {"state": "locked" if str(q.req) != "" else "open"}
	P.quests["q1"] = {"state": "open"}
	item_seq = 1
	shop_stock = []
	gamble_stake = 1
	last_gamble = {}
	ensure_ach()
	reset_feel()


func say(t: String) -> void:
	log_line.emit(t)


func hint(t: String) -> void:
	hint_line.emit(t)


func float_at(x: float, y: float, z: float, t: String, col: Color = Color(0.95, 0.89, 0.77), sz: int = 16) -> void:
	floats.emit(Vector3(x, y, z), t, col, sz)


func start_new(pname: String, cls: String) -> void:
	reset_blank()
	P.name = pname if pname.strip_edges() != "" else "流浪者"
	P.cls = cls
	var c: Dictionary = Data.CLASSES[cls]
	P.base = c.base.duplicate()
	P.equip.weapon = starting_weapon(cls)
	var first: Dictionary = Data.first_skill(cls)
	P.ranks[first.id] = 1
	P.barSkills[0] = first.id
	P.mouseSkills = ["", first.id]
	P.skPts = 0
	P.trackId = "q1"
	P.hub = "town"
	P.flags = {}
	refresh_max(true)
	P.hp = P.hpMax
	P.mp = P.mpMax
	ensure_diff()
	pending_enter = "town"
	pending_intro = true
	WorldState.W.arrive_mode = "gate"
	WorldState.W.arrive_from = ""
	say("镇子建在一道裂口上。桥头把「%s」刻上了木牌——裂口爱偷这个。" % P.name)
	say("你以%s的身份进了镇。去广场北面找塞琳领活。" % c.n)
	ui_refresh.emit()


func starting_weapon(cls: String) -> Dictionary:
	var base: Dictionary = Data.BASES.weapon[cls][0]
	item_seq += 1
	return {
		"id": item_seq, "type": "weapon", "glyph": base.g, "rarity": 0,
		"name": "磨损的" + str(base.n), "ilvl": 1,
		"dmgMin": base.d[0], "dmgMax": base.d[1], "armor": 0,
		"affixes": [], "spd": base.sp, "cls": cls, "sockets": [], "reforged": 0
	}


func displayed_name() -> String:
	var lost := int(P.nameLost)
	if P.nameForgotten:
		return "？？？"
	if diff_id() == "nightmare" and lost > 0:
		var chars: String = str(P.name)
		var n := mini(lost, maxi(1, chars.length() - 1))
		return chars.substr(0, chars.length() - n) + "□".repeat(n)
	return P.name


func ensure_ach() -> void:
	if typeof(P.get("ach")) != TYPE_DICTIONARY:
		P.ach = {}
	if typeof(P.get("stats")) != TYPE_DICTIONARY:
		P.stats = {}
	for k in ["deaths", "goldLooted", "maxRarity", "reforged", "punched", "socketed", "recalled", "recited", "bounties", "nudged", "setLoot", "phrases"]:
		if not P.stats.has(k):
			P.stats[k] = 0


func note_loot(it: Dictionary) -> void:
	if it.is_empty():
		return
	ensure_ach()
	P.stats.maxRarity = maxi(int(P.stats.get("maxRarity", 0)), int(it.get("rarity", 0)))
	if it.get("set"):
		P.stats.setLoot = int(P.stats.get("setLoot", 0)) + 1
	if str(it.get("type", "")) == "scrap":
		learn_scrap(it)


func bump_gold(n: int) -> void:
	if n <= 0:
		return
	ensure_ach()
	P.stats.goldLooted = int(P.stats.get("goldLooted", 0)) + n


func ach_check(silent: bool = false) -> void:
	AchData.check(silent)


func give_won_item(it: Dictionary, msg: String) -> void:
	if add_to_bag(it):
		say(msg)
		return
	var st := stash_items()
	if st.size() < Cfg.STASH:
		st.append(it)
		write_stash(st)
		say(msg + " 行囊满了，进了银行。")
	else:
		P.gold += sell_price(it)
		say("箱子和行囊都满了，东西折成了金币。")


func refresh_stock() -> void:
	shop_stock = []
	var lv := maxi(1, int(P.lvl))
	for i in 6:
		shop_stock.append(roll_item(clampi(lv + Cfg.ri(-1, 2), 1, 99), Cfg._rng.randf() < 0.3))


func gamble_cost(mul: int = -1) -> int:
	if mul < 0:
		mul = gamble_stake
	return int(round((55.0 + float(P.lvl) * 16.0) * float(mul)))


func buy_stock(i: int) -> void:
	if i < 0 or i >= shop_stock.size():
		return
	var it: Dictionary = shop_stock[i]
	var c := shop_price(buy_price(it))
	if P.gold < c:
		hint("金币不足")
		return
	if not add_to_bag(it):
		return
	P.gold -= c
	note_shop_buy()
	shop_stock.remove_at(i)
	Sfx.gold()
	say("从赌台上拿走 %s" % it.name)
	save_soon()
	ui_refresh.emit()


func play_gamble(side: String) -> Dictionary:
	var cost := gamble_cost(gamble_stake)
	if P.gold < cost:
		hint("金币不足")
		return {}
	P.gold -= cost
	var die := Cfg.ri(1, 6)
	var is_big := die >= 4
	var win: bool = (side == "big") == is_big
	var face := "大" if is_big else "小"
	var text := "骰子 %d · %s。" % [die, face]
	last_gamble = {"die": die, "win": win, "text": text}
	if win:
		var extra := 0
		if gamble_stake > 1:
			extra += 1
		if gamble_stake > 2:
			extra += 1
		var lv := clampi(int(P.lvl) + Cfg.ri(0, 1 + extra), 1, 99)
		var rare := false
		if gamble_stake >= 4:
			rare = true
		elif gamble_stake >= 2:
			rare = Cfg._rng.randf() < 0.55
		else:
			rare = Cfg._rng.randf() < 0.18
		var it := roll_item(lv, rare)
		Sfx.level()
		give_won_item(it, "押中 %s。抓到 %s" % [face, it.name])
		last_gamble.text = text + "你赢了 %s。" % it.name
	else:
		last_gamble.text = text + "金币归我。"
		Sfx.hit()
		say("押错了。骰子是 %d。" % die)
	save_soon()
	ach_check()
	ui_refresh.emit()
	return last_gamble


func diff_now() -> Dictionary:
	return Data.DIFF.get(P.diff, Data.DIFF.normal)


func diff_id() -> String:
	return P.diff if Data.DIFF.has(P.diff) else "normal"


func diff_max_id() -> String:
	return P.diffMax if Data.DIFF.has(P.diffMax) else "normal"


func ensure_diff() -> void:
	if not Data.DIFF.has(P.diff):
		P.diff = "normal"
	if not Data.DIFF.has(P.diffMax):
		P.diffMax = "normal"
	if typeof(P.clearedDiff) != TYPE_DICTIONARY:
		P.clearedDiff = {}
	for id in Data.DIFF_ORDER:
		if typeof(P.clearedDiff.get(id)) != TYPE_DICTIONARY:
			P.clearedDiff[id] = {}
	if typeof(P.flags) != TYPE_DICTIONARY:
		P.flags = {}


func all_ch_beat(id: String) -> bool:
	ensure_diff()
	for c in Data.CH_KEYS:
		if not P.clearedDiff[id].get(c.dun, false):
			return false
	return true


func ch_beat_on(id: String, ch: int) -> bool:
	ensure_diff()
	for c in Data.CH_KEYS:
		if int(c.ch) == ch:
			return bool(P.clearedDiff[id].get(c.dun, false))
	return false


func refresh_diff_unlock() -> void:
	ensure_diff()
	if all_ch_beat("normal") and Data.DIFF_ORDER.find(diff_max_id()) < 1:
		P.diffMax = "hell"
	if all_ch_beat("hell") and Data.DIFF_ORDER.find(diff_max_id()) < 2:
		P.diffMax = "nightmare"
	ach_check()


func diff_unlocked(id: String) -> bool:
	if not Data.DIFF.has(id):
		return false
	refresh_diff_unlock()
	return Data.DIFF_ORDER.find(id) <= Data.DIFF_ORDER.find(diff_max_id())


func set_diff(id: String) -> bool:
	if not diff_unlocked(id):
		return false
	P.diff = id
	WorldState.W.diff = id
	return true


func area_ch(id: String) -> int:
	if Data.AREA.has(id):
		return int(Data.AREA[id].get("ch", 1))
	var d := Data.dun_by_id(id)
	if not d.is_empty() and Data.AREA.has(d.from):
		return int(Data.AREA[d.from].get("ch", 1))
	return 1


func can_enter_diff(id: String, dest: String) -> bool:
	if not diff_unlocked(id):
		return false
	if id == "normal":
		return true
	var ch := area_ch(dest)
	var prev := "normal" if id == "hell" else "hell"
	return ch_beat_on(prev, ch)


func mark_dun_clear(id: String) -> void:
	ensure_diff()
	P.clearedDiff[diff_id()][id] = 1
	if diff_id() == "normal":
		P.cleared[id] = true
	refresh_diff_unlock()


func dun_cleared_on(id: String) -> bool:
	ensure_diff()
	return bool(P.clearedDiff[diff_id()].get(id, false))


func elite_chance(depth: int = 0) -> float:
	var D := diff_now()
	if D.id == "nightmare":
		return 0.30 + depth * 0.02
	if D.id == "hell":
		return 0.18 + depth * 0.015
	return 0.09 + depth * 0.012


func pal_for_diff(pal: Dictionary) -> Dictionary:
	if pal.is_empty():
		return pal
	var D := diff_now()
	if D.id == "normal":
		return pal
	var p := pal.duplicate()
	if D.id == "hell":
		p.fog = Cfg.tint_hex(int(pal.get("fog", 0x2a2620)), 0x401010, 0.46)
		p.sky = Cfg.tint_hex(int(pal.get("sky", 0x2e2a24)), 0x280808, 0.5)
		p.amb = float(pal.get("amb", 0.7)) * 0.72
		p.sun = float(pal.get("sun", 0.6)) * 0.82
		p.sunc = 0xff6a3a
		p.dens = float(pal.get("dens", 0.02)) * 1.38
	else:
		p.fog = Cfg.tint_hex(int(pal.get("fog", 0x2a2620)), 0x120818, 0.55)
		p.sky = Cfg.tint_hex(int(pal.get("sky", 0x2e2a24)), 0x080610, 0.62)
		p.amb = float(pal.get("amb", 0.7)) * 0.56
		p.sun = float(pal.get("sun", 0.6)) * 0.52
		p.sunc = 0x8a6ad0
		p.dens = float(pal.get("dens", 0.02)) * 1.72
	return p


func phrase_on(id: String) -> bool:
	return bool(P.phrases.get(id, false))


func worn_phrases() -> Dictionary:
	var o := {}
	for k in SLOT_KEYS:
		var it = P.equip.get(k)
		if it and it.get("phrase"):
			o[it.phrase] = 1
	return o


func rebuild_powers() -> void:
	P.powers = {}
	for k in SLOT_KEYS:
		var it = P.equip.get(k)
		if it == null:
			continue
		if str(it.get("uid", "")) == "":
			continue
		var cls_v = it.get("cls", "")
		if str(cls_v) != "" and str(cls_v) != str(P.cls):
			continue
		var pw = it.get("power", {})
		var v = {}
		if typeof(pw) == TYPE_DICTIONARY:
			v = pw.get("v", {})
			if typeof(v) != TYPE_DICTIONARY:
				v = {}
		P.powers[str(it.uid)] = v
	if not pwr("u_rule").is_empty() and not pwr("u_custom").is_empty():
		P.powers.erase("u_custom")
		if typeof(P.up) != TYPE_DICTIONARY:
			P.up = {}
		P.up.clash = 1
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	P.sets = worn_sets()
	P.phrases = worn_phrases()


func pwr(id: String) -> Dictionary:
	var powers = P.get("powers", {})
	if typeof(powers) != TYPE_DICTIONARY:
		return {}
	var v = powers.get(id)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return v


func worn_sets() -> Dictionary:
	var n := {}
	for k in SLOT_KEYS:
		var it = P.equip.get(k)
		if it == null or not it.get("set"):
			continue
		var cls_v = it.get("cls", "")
		if str(cls_v) != "" and str(cls_v) != str(P.cls):
			continue
		var sid := str(it.set)
		n[sid] = int(n.get(sid, 0)) + 1
	return n


func set_n(id: String) -> int:
	var sets = P.get("sets", {})
	if typeof(sets) != TYPE_DICTIONARY:
		return 0
	return int(sets.get(id, 0))


func set_on(id: String, need: int) -> bool:
	return set_n(id) >= need


func charm_size(it: Dictionary) -> int:
	return clampi(int(it.get("sz", 1)), 1, 3)


func charm_used() -> int:
	var s := 0
	for it in P.get("charms", []):
		s += charm_size(it)
	return s


func add_to_charms(it: Dictionary) -> bool:
	if typeof(P.charms) != TYPE_ARRAY:
		P.charms = []
	if charm_used() + charm_size(it) > Cfg.CHARM:
		return false
	P.charms.append(it)
	return true


func cpwr(id: String) -> Dictionary:
	for c in P.get("charms", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if str(c.get("cid", "")) != id:
			continue
		if c.get("unknown"):
			continue
		var pw = c.get("power", {})
		if typeof(pw) != TYPE_DICTIONARY:
			return {}
		var v = pw.get("v", {})
		if typeof(v) != TYPE_DICTIONARY:
			return {}
		return v
	return {}


func known_phrase(id: String) -> bool:
	return bool(P.knownPhrases.get(id, false))


func unlock_phrase(id: String) -> bool:
	if known_phrase(id):
		return false
	P.knownPhrases[id] = 1
	var p := Data.phrase_by_id(id)
	if not p.is_empty():
		say("想起来一句：「%s」" % p.n)
		hint("念法 「%s」" % p.n)
	return true


func match_phrase(it: Dictionary) -> Dictionary:
	if it.is_empty() or it.get("unique") or it.get("set"):
		return {}
	if it.get("type") == "rune" or it.get("type") == "charm" or it.get("type") == "scrap":
		return {}
	var ids: Array = []
	for s in it.get("sockets", []):
		ids.append(s.id if s else "")
	if ids.is_empty() or ids.has(""):
		return {}
	for p in Data.PHRASES:
		if int(p.need) != ids.size():
			continue
		if not p.types.has(it.type):
			continue
		var ok := true
		for i in p.runes.size():
			if str(p.runes[i]) != str(ids[i]):
				ok = false
				break
		if ok:
			return p
	return {}


func seal_phrase(it: Dictionary) -> Dictionary:
	var p := match_phrase(it)
	if p.is_empty():
		it.phrase = null
		return {}
	if str(it.get("phrase", "")) != str(p.id):
		it.phrase = p.id
		unlock_phrase(p.id)
		P.stats.phrases = int(P.stats.get("phrases", 0)) + 1
		say("念出来了：「%s」" % p.n)
		hint("「%s」" % p.n)
		Sfx.level()
		ach_check()
	else:
		it.phrase = p.id
	return p


func tal_rank(id: String) -> int:
	return int(P.talents.get(id, 0))


func class_talents() -> Array:
	return Data.class_talents(str(P.cls))


func tal_earned() -> int:
	if P.lvl < 10:
		return 0
	return 2 if P.lvl >= 20 else 1


func tal_spent() -> int:
	var n := 0
	for t in class_talents():
		n += tal_rank(str(t.id))
	return n


func tal_pts() -> int:
	return maxi(0, tal_earned() - tal_spent())


func tal_reset_cost() -> int:
	return 250 + tal_spent() * 120


func tal_can(nd: Dictionary) -> bool:
	return P.lvl >= 10 and tal_pts() > 0 and tal_rank(str(nd.id)) < int(nd.get("max", 1))


func learn_talent(nd: Dictionary) -> void:
	if not tal_can(nd):
		return
	P.talents[str(nd.id)] = 1
	Sfx.level()
	say("点亮 %s" % nd.n)
	refresh_max(false)
	save_soon()
	ach_check()
	ui_refresh.emit()


func reset_talents() -> void:
	if tal_spent() <= 0:
		hint("没有天赋可洗")
		return
	var cost := tal_reset_cost()
	if P.gold < cost:
		hint("金币不足")
		return
	P.gold -= cost
	P.talents = {}
	Sfx.gold()
	say("天赋已洗。点重新分配。")
	refresh_max(false)
	save_soon()
	ui_refresh.emit()


func sk_rune(id: String) -> String:
	return str(P.skRunes.get(id, ""))


func set_sk_rune(id: String, rid: String) -> void:
	if not Data.SK_RUNES.has(id):
		return
	if rid == "" or sk_rune(id) == rid:
		P.skRunes.erase(id)
	else:
		P.skRunes[id] = rid
	save_soon()
	ach_check()
	ui_refresh.emit()


func mouse_skill(which: int) -> String:
	var arr = P.get("mouseSkills", ["", ""])
	if typeof(arr) != TYPE_ARRAY or which < 0 or which >= arr.size():
		return ""
	return str(arr[which])


func assign_mouse(skill_id: String, which: int) -> void:
	if which < 0 or which > 1:
		return
	if typeof(P.mouseSkills) != TYPE_ARRAY or P.mouseSkills.size() < 2:
		P.mouseSkills = ["", ""]
	P.mouseSkills[which] = skill_id
	ui_refresh.emit()
	save_soon()


func alt_loot() -> bool:
	return Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META)


func show_white_loot() -> bool:
	var f = P.get("flags", {})
	if typeof(f) != TYPE_DICTIONARY:
		return false
	return f.get("showWhiteLoot") == true


func toggle_white_loot() -> bool:
	if typeof(P.flags) != TYPE_DICTIONARY:
		P.flags = {}
	P.flags.showWhiteLoot = not show_white_loot()
	save_soon()
	ui_refresh.emit()
	return show_white_loot()


func rift_has(id: String) -> bool:
	var mods = WorldState.W.get("riftMods", [])
	return typeof(mods) == TYPE_ARRAY and mods.has(id)


func rift_loot_of(ids) -> int:
	var s := 0
	if typeof(ids) != TYPE_ARRAY:
		return 0
	for id in ids:
		var a := Data.rift_affix_by_id(str(id))
		s += int(a.get("loot", 0))
	return s


func rift_loot_mul() -> float:
	return 1.0 + float(rift_loot_of(WorldState.W.get("riftMods", []))) / 100.0


func rift_cd_mul() -> float:
	return 1.35 if rift_has("hush") else 1.0


func rift_reroll_cost(depth: int, rerolls: int) -> int:
	return int(round((8.0 + float(depth) * 4.0) * (1.0 + float(rerolls) * 0.45)))


func roll_rift_affixes(depth: int) -> Array:
	if depth < 5:
		return []
	var pool: Array = []
	for a in Data.RIFT_AFFIXES:
		pool.append(a.id)
	var D := diff_now()
	var extra := 2 if D.id == "nightmare" else (1 if D.id == "hell" else 0)
	var n: int = (2 if Cfg._rng.randf() < (0.62 if depth >= 8 else 0.38) else 1) + extra
	n = mini(4, n)
	var ids: Array = []
	while ids.size() < n and pool.size():
		var i := Cfg._rng.randi_range(0, pool.size() - 1)
		ids.append(pool[i])
		pool.remove_at(i)
	return ids


func ensure_rift_offer(depth: int) -> Dictionary:
	var o = WorldState.W.get("riftOffer")
	if typeof(o) == TYPE_DICTIONARY and int(o.get("depth", -1)) == depth:
		return o
	o = {"depth": depth, "ids": roll_rift_affixes(depth), "rerolls": 0}
	WorldState.W.riftOffer = o
	return o


func reroll_rift_offer() -> Dictionary:
	var o = WorldState.W.get("riftOffer")
	if typeof(o) != TYPE_DICTIONARY:
		return {}
	var cost := rift_reroll_cost(int(o.depth), int(o.get("rerolls", 0)))
	if P.gold < cost:
		hint("金币不足")
		return o
	P.gold -= cost
	Sfx.gold()
	o.ids = roll_rift_affixes(int(o.depth))
	o.rerolls = int(o.get("rerolls", 0)) + 1
	save_soon()
	ui_refresh.emit()
	return o


func take_rift_offer(depth: int) -> void:
	var o := ensure_rift_offer(depth)
	var ids = o.get("ids", [])
	WorldState.W.riftMods = ids.duplicate() if typeof(ids) == TYPE_ARRAY else []
	WorldState.W.riftOffer = null


func clear_rift_mods() -> void:
	WorldState.W.riftMods = []
	WorldState.W.riftOffer = null


func knockback_player(sx: float, sz: float, force: float) -> void:
	var dx: float = float(P.x) - sx
	var dz: float = float(P.z) - sz
	var d: float = Cfg.hypot(dx, dz)
	if d < 0.01:
		d = 1.0
	WorldState.move_entity(P, float(P.x) + dx / d * force, float(P.z) + dz / d * force)


func syn_mul(id: String) -> float:
	var add := 0.0
	for sk in Data.SKILLS:
		for s in sk.get("syn", []):
			if s.id == id:
				add += float(P.ranks.get(sk.id, 0)) * float(s.get("per", 0))
	return 1.0 + add / 100.0


func apply_mod(s: Dictionary, k: String, v: float) -> void:
	if k == "armor":
		s.armor += v
	elif k == "hp":
		s.hpB += v
	elif k == "mp":
		s.mpB += v
	elif k == "dmg":
		s.dmgF += v
	elif k == "crit":
		s.crit += v
	elif k == "as":
		s.asB += v
	elif k == "leech":
		s.leech += v
	elif k == "ms":
		s.ms += v
	elif k == "critDmg":
		s.critDmg += v
	elif k == "dr":
		s.dr += v
	elif k == "cdr":
		s.cdr = float(s.get("cdr", 0)) + v
	elif k == "mpre":
		s.mpre = float(s.get("mpre", 0)) + v
	elif k == "hpre":
		s.hpre = float(s.get("hpre", 0)) + v
	elif k == "dodge":
		s.dodge = float(s.get("dodge", 0)) + v
	elif k == "all":
		s.str += v
		s.dex += v
		s.vit += v
		s.ene += v
	elif k == "main":
		var m: String = "str" if P.cls == "warrior" else ("dex" if P.cls == "archer" else "ene")
		s[m] += v
	elif s.has(k):
		s[k] += v


func p_stats() -> Dictionary:
	var s := {
		"str": float(P.base.str), "dex": float(P.base.dex), "vit": float(P.base.vit), "ene": float(P.base.ene),
		"armor": 0.0, "dmgMin": 1.0, "dmgMax": 3.0, "crit": 5.0, "hpB": 0.0, "mpB": 0.0,
		"dmgF": 0.0, "asB": 0.0, "leech": 0.0, "ms": 0.0, "wspd": 1.0, "dr": 0.0, "critDmg": 0.0, "skDmg": 0.0,
		"resPhys": 0.0, "resFire": 0.0, "resIce": 0.0, "resShadow": 0.0, "resAll": 0.0, "pierce": 0.0,
		"cdr": 0.0, "mpre": 0.0, "hpre": 0.0, "dodge": 0.0, "gf": 0.0, "mf": 0.0,
		"killhp": 0.0, "killmp": 0.0, "thorns": 0.0, "chillhit": 0.0, "freezehit": 0.0,
		"killburst": 0.0, "lowhp": 0.0, "elitedmg": 0.0
	}
	for k in P.equip:
		var it = P.equip[k]
		if it == null:
			continue
		s.armor += float(it.get("armor", 0))
		if it.get("type") == "weapon":
			s.dmgMin += float(it.get("dmgMin", 0))
			s.dmgMax += float(it.get("dmgMax", 0))
			s.wspd = float(it.get("spd", 1))
		for a in it.get("affixes", []):
			apply_mod(s, str(a.k), float(a.v))
		for sock in it.get("sockets", []):
			if sock:
				apply_mod(s, str(sock.k), float(sock.v))
	for ch in P.get("charms", []):
		if typeof(ch) != TYPE_DICTIONARY or ch.get("unknown"):
			continue
		for a in ch.get("affixes", []):
			apply_mod(s, str(a.k), float(a.v))
	rebuild_powers()
	if set_on("rift", 2):
		s.ms += 12
		s.mf += 15
	if set_on("dive", 2):
		s.str += 8
		s.dex += 8
		s.vit += 8
		s.ene += 8
		s.elitedmg += 18
	if set_on("dive", 4):
		s.gf += 30
		s.killburst = maxf(float(s.killburst), 24)
	if P.buffs.has("setas"):
		s.asB += float(P.buffs.setas.get("v", 30))
	if P.buffs.has("setdr"):
		s.dr += float(P.buffs.setdr.get("v", 25))
	if P.buffs.has("downdr"):
		s.dr += float(P.buffs.downdr.get("v", 30))
	var nineteen := pwr("u_nineteen")
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	if not nineteen.is_empty():
		var near_n := near_enemies(3)
		s.dr += float(nineteen.get("dr", 1.2)) * mini(19, near_n)
		if near_n >= 19 and not P.up.get("freeUsed"):
			P.up.freeMp = true
		if near_n < 19:
			P.up.freeUsed = false
	if set_on("dive", 6) and P.hp <= float(P.hpMax) * 0.4:
		s.dr += 15
	var lace := cpwr("c_lace")
	if not lace.is_empty() and P.hp < float(P.hpMax) * 0.4:
		s.dr += float(lace.get("dr", 6))
	if phrase_on("offkey"):
		s.pierce += 15
		s.ms += 8
	var D := diff_now()
	var cap := 85.0 if phrase_on("still") else 75.0
	s.resCap = cap
	var pen := float(D.get("res", 0))
	var fl := float(D.get("floor", -40))
	s.resPhys = clampf(s.resPhys + s.resAll + pen, fl, cap)
	s.resFire = clampf(s.resFire + s.resAll + pen, fl, cap)
	s.resIce = clampf(s.resIce + s.resAll + pen, fl, cap)
	s.resShadow = clampf(s.resShadow + s.resAll + pen, fl, cap)
	var main: float = float(s.str if P.cls == "warrior" else (s.dex if P.cls == "archer" else s.ene))
	var bd := 1.0
	if P.buffs.has("dmg"):
		bd = 1.0 + float(P.buffs.dmg.v) / 100.0
	s.dmgMin = round((s.dmgMin + s.dmgF) * (1.0 + main / 110.0) * bd)
	s.dmgMax = round((s.dmgMax + s.dmgF) * (1.0 + main / 110.0) * bd)
	s.armor += round(s.dex * 0.8)
	s.hpMax = 60 + s.vit * 7 + P.lvl * 11 + s.hpB
	s.mpMax = 32 + s.ene * 6 + P.lvl * 5 + s.mpB
	if P.buffs.has("swift"):
		s.hpMax = round(s.hpMax * 0.8)
	s.crit = s.crit + s.dex * 0.18
	if tal_rank("wf6") and P.hp < s.hpMax * 0.4:
		s.dmgMin = round(s.dmgMin * 1.2)
		s.dmgMax = round(s.dmgMax * 1.2)
	if tal_rank("wb6"):
		s.armor = round(s.armor * 1.12)
		s.dr = maxf(s.dr, 8)
	if tal_rank("mfl6"):
		s.skDmg += 15
	if tal_rank("mfr6"):
		s.armor = round(s.armor * 1.08)
	if tal_rank("ap6"):
		s.crit += 6
	if tal_rank("ag6"):
		s.ms += 8
	if P.buffs.has("swift"):
		s.ms += 20
		s.asB += 20
	if P.buffs.has("enough"):
		s.dmgMin = round(s.dmgMin * (1.0 + float(P.buffs.enough.get("v", 40)) / 100.0))
		s.dmgMax = round(s.dmgMax * (1.0 + float(P.buffs.enough.get("v", 40)) / 100.0))
	s.crit = clampf(s.crit, 0, 70)
	s.atkTime = clampf((0.92 / s.wspd) / (1.0 + (s.asB + s.dex * 0.4) / 100.0), 0.24, 1.4)
	s.speed = 6.4 * (1.0 + s.ms / 100.0)
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	var acres := pwr("u_acres")
	if not acres.is_empty():
		s.dr += float(P.up.get("stayN", 0)) * float(acres.get("dr", 2))
	if not pwr("u_breath").is_empty() and P.up.get("beatOn"):
		s.speed *= 1.6
	if not pwr("u_green").is_empty() and typeof(P.up.get("potHot")) == TYPE_DICTIONARY:
		s.speed *= 1.25
	return s


func refresh_max(full: bool = false) -> void:
	var s := p_stats()
	var hr: float = 1.0 if full else float(P.hp) / maxf(float(P.hpMax), 1.0)
	var mr: float = 1.0 if full else float(P.mp) / maxf(float(P.mpMax), 1.0)
	P.hpMax = s.hpMax
	P.mpMax = s.mpMax
	P.hp = clampf(P.hpMax * hr, 1.0, P.hpMax)
	P.mp = clampf(P.mpMax * mr, 0.0, P.mpMax)


func crit_x(s: Dictionary, crit: bool) -> float:
	return (2.0 + float(s.get("critDmg", 0)) / 100.0) if crit else 1.0


func sk_dmg(s: Dictionary, n: float, id: String) -> float:
	return n * (1.0 + float(s.get("skDmg", 0)) / 100.0) * syn_mul(id)


func res_key(elem: String) -> String:
	return {"phys": "resPhys", "fire": "resFire", "ice": "resIce", "shadow": "resShadow"}.get(elem, "resPhys")


func apply_enemy_res(e: Dictionary, amount: float, elem: String) -> float:
	elem = elem if elem != "" else "phys"
	var st := p_stats()
	var res := 100.0 if e.get("imm", "") == elem else float(e.get("res", {}).get(elem, 0))
	res -= float(st.get("pierce", 0))
	if e.get("imm", "") == elem:
		res = maxf(20.0, res)
	else:
		res = clampf(res, -30.0, 75.0)
	if res >= 100.0:
		float_at(e.x, 2.4, e.z, Data.ELEM[elem].imm, Color(0.56, 0.83, 1), 14)
		return 0.0
	return amount * (1.0 - res / 100.0)


func skill_elem(id: String) -> String:
	var sk := Data.sk_by_id(id)
	if not sk.is_empty() and sk.has("elem"):
		return sk.elem
	return "shadow" if P.cls == "mage" else "phys"


func reset_feel() -> void:
	feel = {"stop": 0.0, "stopCd": 0.0, "slow": 0.0, "slowMul": 1.0, "queue": null, "combo": 0, "comboT": 0.0, "lastSoft": false}
	cam_shake = 0.0


func punch_hit(e: Dictionary, crit: bool) -> void:
	if float(feel.get("stopCd", 0)) > 0:
		return
	var d := 0.035
	if crit:
		d = 0.065
	if e.get("elite"):
		d = maxf(d, 0.058)
	if e.get("boss"):
		d = maxf(0.042, d * 0.85)
	feel.stop = maxf(float(feel.get("stop", 0)), d)
	feel.stopCd = 0.42


func punch_kill(e: Dictionary) -> void:
	if e.get("boss"):
		feel.slow = maxf(float(feel.get("slow", 0)), 0.65)
		feel.slowMul = minf(float(feel.get("slowMul", 1)), 0.22)
		feel.stop = maxf(float(feel.get("stop", 0)), 0.08)
		cam_shake = maxf(cam_shake, 0.42)
	elif e.get("su"):
		if float(feel.get("slow", 0)) < 0.42:
			feel.slow = 0.42
			feel.slowMul = 0.28
		cam_shake = maxf(cam_shake, 0.34)
	elif e.get("elite"):
		if float(feel.get("slow", 0)) < 0.28:
			feel.slow = 0.28
			feel.slowMul = 0.32
		cam_shake = maxf(cam_shake, 0.26)
	elif int(feel.get("combo", 0)) >= 6 and float(feel.get("slow", 0)) <= 0 and not feel.get("lastSoft"):
		feel.slow = 0.1
		feel.slowMul = 0.45


func bump_combo() -> void:
	feel.combo = int(feel.get("combo", 0)) + 1
	feel.comboT = 2.2


func consume_feel(raw: float) -> float:
	cam_shake = maxf(0.0, cam_shake - raw * 1.4)
	if float(feel.get("stopCd", 0)) > 0:
		feel.stopCd = maxf(0.0, float(feel.stopCd) - raw)
	if float(feel.get("comboT", 0)) > 0:
		feel.comboT = float(feel.comboT) - raw
		if float(feel.comboT) <= 0:
			feel.combo = 0
	var q = feel.get("queue")
	if typeof(q) == TYPE_DICTIONARY:
		q.t = float(q.get("t", 0)) - raw
		if float(q.t) <= 0:
			feel.queue = null
	if float(feel.get("stop", 0)) > 0:
		feel.stop = float(feel.stop) - raw
		if float(feel.stop) > 0:
			return 0.0
	if float(feel.get("slow", 0)) > 0:
		feel.slow = float(feel.slow) - raw
		var dt: float = raw * float(feel.get("slowMul", 0.3))
		if float(feel.slow) <= 0:
			feel.slowMul = 1.0
		return dt
	return raw


func try_cast(i: int) -> void:
	if i < 0 or i >= P.barSkills.size():
		return
	try_cast_id(str(P.barSkills[i]))


func try_mouse(which: int) -> void:
	try_cast_id(mouse_skill(which))


func try_cast_id(id: String) -> void:
	if not P.alive or str(WorldState.W.area.get("kind", "")) == "town":
		return
	if story.size() > 0 or cine_boss.size() > 0:
		return
	if id == "":
		return
	if player_locked() and id != "roll":
		return
	var cd := float(P.cds.get(id, 0))
	if cd > 0.001:
		if cd <= 0.32:
			feel.queue = {"id": id, "t": 0.45}
		return
	if float(feel.get("stop", 0)) > 0:
		feel.queue = {"id": id, "t": 0.45}
		return
	feel.queue = null
	cast_skill_id(id)


func flush_skill_queue() -> void:
	var q = feel.get("queue")
	if typeof(q) != TYPE_DICTIONARY:
		return
	if story.size() > 0 or cine_boss.size() > 0 or float(feel.get("stop", 0)) > 0:
		return
	var id: String = str(q.get("id", ""))
	if id == "" and q.has("i"):
		var i := int(q.get("i", -1))
		if i >= 0 and i < P.barSkills.size():
			id = str(P.barSkills[i])
	if id == "":
		feel.queue = null
		return
	if player_locked() and id != "roll":
		return
	if float(P.cds.get(id, 0)) > 0.001:
		return
	feel.queue = null
	cast_skill_id(id)


func interrupt_player(why: String = "") -> void:
	if phrase_on("notyou"):
		return
	P.channel = null
	if str(P.casting) != "":
		P.casting = ""
		if why != "":
			hint(why)


func near_enemies(r: float) -> int:
	var n := 0
	var rr := r * r
	for e in WorldState.W.enemies:
		if e.get("dead"):
			continue
		if Cfg.dist2(float(e.x), float(e.z), float(P.x), float(P.z)) < rr:
			n += 1
	return n


func unique_dmg_mul(e: Dictionary, amount: float) -> float:
	var m := 1.0
	var ruler := pwr("u_ruler")
	if not ruler.is_empty() and float(e.get("hpMax", 0)) > 0:
		var r: float = float(e.hp) / float(e.hpMax)
		if r > 0.75:
			m *= 1.0 + float(ruler.get("hi", 15)) / 100.0
		elif r < 0.25:
			m *= 1.0 + float(ruler.get("lo", 15)) / 100.0
	var voc := pwr("u_voices")
	if not voc.is_empty() and int(P.up.get("voiceN", 0)) > 0:
		m *= 1.0 + float(voc.get("d", 0.8)) * mini(47, int(P.up.voiceN)) / 100.0
	var third := pwr("u_third")
	if not third.is_empty() and int(P.up.get("sameId", -1)) == int(e.get("id", -2)):
		m *= 1.0 + float(third.get("s", 4)) * mini(10, int(P.up.get("sameN", 0))) / 100.0
	var tide := pwr("u_tide")
	if not tide.is_empty() and int(P.up.get("waterHit", 0)) > 0:
		m *= 1.0 + float(tide.get("s", 3)) * float(P.up.waterHit) / 100.0
		P.up.waterHit = 0
	var law := pwr("u_law")
	if not law.is_empty():
		m *= 1.0 + float(law.get("d", 20)) / 100.0
	var aye := pwr("u_aye")
	if not aye.is_empty():
		m *= 1.0 + float(aye.get("s", 8)) * float(WorldState.zone_count()) / 100.0
	var son := pwr("u_son")
	if not son.is_empty() and P.buffs.has("potsh"):
		m *= 1.0 + float(son.get("d", 12)) / 100.0
	var custom := pwr("u_custom")
	if not custom.is_empty() and int(P.up.get("sameSk", 0)) > 1:
		m *= 1.0 + float(custom.get("d", 3)) * mini(6, int(P.up.sameSk) - 1) / 100.0
	if not pwr("u_unfinished").is_empty() and P.up.get("unfin"):
		m *= 1.5
	var erl := pwr("u_erl")
	if not erl.is_empty() and float(e.hp) >= float(e.hpMax) * 0.99:
		if int(P.up.get("erlMark", -1)) != int(e.id):
			P.up.erlMark = e.id
			m *= 1.0 + float(erl.get("d", 80)) / 100.0
			P.up.erlPend = e.id
	if float(P.up.get("erlDown", 0)) > 0:
		m *= 0.8
	var sec := pwr("u_second")
	if not sec.is_empty():
		var nails = P.up.get("nails")
		if typeof(nails) == TYPE_ARRAY:
			for n in nails:
				if Cfg.dist2(float(e.x), float(e.z), float(n.x), float(n.z)) < 25.0:
					m *= 1.0 + float(sec.get("dmg", 20)) / 100.0
					break
	var st := p_stats()
	if st.lowhp and P.hp <= P.hpMax * 0.4:
		m *= 1.0 + st.lowhp / 100.0
	if st.elitedmg and (e.get("elite") or e.get("boss") or e.get("su")):
		m *= 1.0 + st.elitedmg / 100.0
	if set_on("dive", 6) and P.hp <= P.hpMax * 0.4:
		m *= 1.35
	if set_on("dusk", 6) and WorldState.in_rain(float(e.x), float(e.z)):
		m *= 1.25
	if P.buffs.has("enough"):
		m *= 1.0 + float(P.buffs.enough.get("v", 40)) / 100.0
	return amount * m


func skill_rad(r: float) -> float:
	var m := 1.0
	if P.up.get("voiceBoom"):
		m *= 2.0
	var aye := pwr("u_aye")
	if not aye.is_empty():
		m *= 1.0 + float(aye.get("s", 8)) * float(WorldState.zone_count()) / 100.0
	return r * m


func spawn_stone_wall(x: float, z: float) -> void:
	WorldState.spawn_stone_wall(x, z)


func place_nail(x: float, z: float) -> void:
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	var nails: Array = P.up.get("nails", [])
	if typeof(nails) != TYPE_ARRAY:
		nails = []
	if nails.size() >= 3:
		var old: Dictionary = nails.pop_front()
		if old.get("mesh"):
			old.mesh.queue_free()
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.14
	cyl.height = 1.6
	cyl.radial_segments = 6
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Cfg.hex_color(0x8a7a52)
	mesh.material_override = mat
	mesh.position = Vector3(x, 0.8, z)
	if WorldState.world_root:
		WorldState.world_root.add_child(mesh)
	nails.append({"x": x, "z": z, "mesh": mesh})
	P.up.nails = nails


func fire_retally() -> void:
	var v := pwr("u_retally")
	if v.is_empty():
		return
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	if float(P.up.get("retallyCd", 0)) > 0:
		hint("重新计票冷却中")
		return
	P.up.retallyCd = 45.0
	for k in P.cds.keys():
		P.cds[k] = 0
	var dealt: float = float(P.up.get("hurt10", 0)) * float(v.get("d", 60)) / 100.0
	P.up.hurt10 = 0
	var hits: Array = []
	for e in WorldState.W.enemies:
		if e.get("dead"):
			continue
		if Cfg.dist2(float(e.x), float(e.z), float(P.x), float(P.z)) < 100.0:
			hits.append(e)
	if hits.size() and dealt > 0:
		var each: float = dealt / float(hits.size())
		for e in hits:
			deal_to_enemy(e, each, false, Color(0.78, 0.64, 1))
	Sfx.quest()
	hint("重新计票")


func update_unique(dt: float) -> void:
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	var u: Dictionary = P.up
	for k in ["retallyCd", "unfinCd", "thimbleCd", "erlDown", "dashGrace", "chargeEcho", "blinkEcho", "shoeLock", "ticketCd"]:
		if float(u.get(k, 0)) > 0:
			u[k] = maxf(0.0, float(u[k]) - dt)
	if float(u.get("shoeLock", 0)) > 0:
		P.path = []
	var delay = u.get("delayHit")
	if typeof(delay) == TYPE_DICTIONARY:
		delay.t = float(delay.t) - dt
		if float(delay.t) <= 0:
			var dmg: float = float(delay.dmg)
			u.delayHit = null
			P.hp -= dmg
			float_at(P.x, 2.4, P.z, "-%d" % int(round(dmg)), Color(1, 0.48, 0.42), 18)
			if P.hp <= 0:
				die()
	WorldState.tick_walls(dt)
	if not pwr("u_breath").is_empty():
		u.beatT = float(u.get("beatT", 0)) + dt
		if float(u.beatT) >= 4.0:
			u.beatT = float(u.beatT) - 4.0
		u.beatOn = float(u.beatT) >= 3.0
	else:
		u.beatOn = false
	if phrase_on("unsung"):
		u.phraseBeat = float(u.get("phraseBeat", 0)) + dt
		if float(u.phraseBeat) >= 4.0:
			u.phraseBeat = 0
			u.freeMp = true
	var moving: bool = P.path.size() > 0
	if moving:
		u.stillT = 0
		if not pwr("u_tide").is_empty() and int(u.get("water", 0)) > 0:
			u.waterHit = u.water
			u.water = 0
	else:
		u.stillT = float(u.get("stillT", 0)) + dt
		if not pwr("u_tide").is_empty():
			u.wacc = float(u.get("wacc", 0)) + dt
			if float(u.wacc) >= 1.0:
				u.wacc = 0
				u.water = mini(10, int(u.get("water", 0)) + 1)
		if not pwr("u_second").is_empty() and float(u.stillT) >= 2.0:
			u.stillT = 0
			place_nail(float(P.x), float(P.z))
	var aid := ""
	if WorldState.W.dun:
		aid = "d:%s:%s" % [WorldState.W.dun.id, WorldState.W.dunFloor]
	else:
		aid = str(WorldState.W.area.get("id", ""))
	if not pwr("u_acres").is_empty():
		if str(u.get("stayArea", "")) != aid:
			u.stayArea = aid
			u.stayT = 0
			u.stayN = 0
		else:
			u.stayT = float(u.get("stayT", 0)) + dt
			if float(u.stayT) >= 30.0:
				u.stayT = 0
				u.stayN = mini(8, int(u.get("stayN", 0)) + 1)
	else:
		u.stayN = 0
	if float(u.get("voiceT", 0)) > 0:
		u.voiceT = float(u.voiceT) - dt
		if float(u.voiceT) <= 0:
			u.voiceN = 0
			u.voiceSet = {}
	var hot = u.get("potHot")
	if typeof(hot) == TYPE_DICTIONARY:
		hot.t = float(hot.t) - dt
		hot.acc = float(hot.get("acc", 0)) + dt
		if float(hot.acc) >= 0.5:
			hot.acc = 0
			var h := heal_player(float(hot.get("tick", 0)))
			if h > 0:
				float_at(P.x, 2.2, P.z, "+%d" % int(round(h)), Color(0.54, 0.87, 0.35), 13)
		if float(hot.t) <= 0:
			u.potHot = null
	if u.get("unfin"):
		u.unfinT = float(u.get("unfinT", 0)) - dt
		P.hp = maxf(1.0, float(P.hp))
		if float(u.unfinT) <= 0:
			u.unfin = false
			if int(u.get("unfinKills", 0)) >= 1:
				P.hp = maxf(1.0, float(P.hpMax) * 0.3)
				P.alive = true
				float_at(P.x, 2.6, P.z, "还没唱完", Color(0.78, 0.64, 1), 22)
				say("最后一段接上了。你还活着。")
			else:
				u.realDie = 1
				die()
	var log = u.get("hurtLog")
	if typeof(log) == TYPE_ARRAY:
		var log_arr: Array = log
		var i: int = log_arr.size() - 1
		while i >= 0:
			log_arr[i].t = float(log_arr[i].t) - dt
			if float(log_arr[i].t) <= 0:
				log_arr.remove_at(i)
			i -= 1
		var s := 0.0
		for x in log_arr:
			s += float(x.d)
		u.hurt10 = s
		u.hurtLog = log_arr


func event_line() -> String:
	var ev = WorldState.W.get("event")
	if typeof(ev) != TYPE_DICTIONARY:
		return ""
	var st := str(ev.get("state", ""))
	if st == "done" or st == "fail" or st == "looted" or st == "closed":
		return ""
	var k := str(ev.get("kind", ""))
	if k == "caravan":
		if st == "ambush":
			return "商队遇袭 · 清掉周围"
		return "护送商队 %d 秒 · 别走远" % maxi(0, int(ceil(float(ev.get("t", 0)))))
	if k == "chest":
		return "箱子可以开了" if st == "ready" else "有人守着一口箱子"
	if k == "riftwell":
		return "裂口还在喷 · 站上去封"
	if k == "apprentice":
		return "迷路的学徒" if st == "idle" else "跟上学徒 · 别走散"
	return ""


func target_mods(e: Dictionary) -> String:
	var bits: PackedStringArray = []
	if e.get("boss"):
		bits.append("首领")
	if e.get("su"):
		bits.append("独特")
	if e.get("hoard"):
		bits.append("囤积")
	if e.get("elite") and not e.get("boss"):
		bits.append("精英")
	var combo := str(e.get("combo", ""))
	if combo != "":
		bits.append(combo)
	else:
		for id in e.get("mods", []):
			var m := Data.elite_mod_by_id(str(id))
			if not m.is_empty():
				bits.append(str(m.n))
	return " · ".join(bits)


func unique_stacks() -> Array:
	var out: Array = []
	if typeof(P.up) != TYPE_DICTIONARY:
		return out
	if not pwr("u_names").is_empty():
		out.append("✉ %d/11" % int(P.up.get("names", 0)))
	if not pwr("u_tide").is_empty() and int(P.up.get("water", 0)) > 0:
		out.append("🌊 %d" % int(P.up.water))
	if not pwr("u_voices").is_empty() and int(P.up.get("voiceN", 0)) > 0:
		out.append("🎙 %d" % int(P.up.voiceN))
	return out


func recall_from_bag(i: int) -> void:
	if i < 0 or i >= P.bag.size():
		return
	var it: Dictionary = P.bag[i]
	if not it.get("unknown"):
		return
	if int(P.get("recallNotes", 0)) <= 0:
		hint("回石桥镇找玛拉回想，或买张回想的纸条")
		return
	P.recallNotes = int(P.recallNotes) - 1
	identify_item(it)
	Sfx.loot()
	ensure_ach()
	P.stats.recalled = int(P.stats.get("recalled", 0)) + 1
	say("你想起来了：%s" % it.name)
	refresh_max(false)
	save_soon()
	ach_check()
	ui_refresh.emit()


func recall_from_charm(i: int) -> void:
	var charms: Array = P.get("charms", [])
	if i < 0 or i >= charms.size():
		return
	var it: Dictionary = charms[i]
	if not it.get("unknown"):
		return
	if int(P.get("recallNotes", 0)) <= 0:
		hint("回石桥镇找玛拉回想，或买张回想的纸条")
		return
	P.recallNotes = int(P.recallNotes) - 1
	identify_item(it)
	Sfx.loot()
	ensure_ach()
	P.stats.recalled = int(P.stats.get("recalled", 0)) + 1
	say("你想起来了：%s" % it.name)
	refresh_max(false)
	save_soon()
	ach_check()
	ui_refresh.emit()


func charm_to_bag(i: int) -> void:
	var charms: Array = P.get("charms", [])
	if i < 0 or i >= charms.size():
		return
	if P.bag.size() >= Cfg.BAG:
		hint("行囊已满")
		return
	var it: Dictionary = charms[i]
	charms.remove_at(i)
	P.charms = charms
	P.bag.append(it)
	refresh_max(false)
	save_soon()
	ui_refresh.emit()


func discard_charm(i: int) -> void:
	var charms: Array = P.get("charms", [])
	if i < 0 or i >= charms.size():
		return
	charms.remove_at(i)
	P.charms = charms
	refresh_max(false)
	save_soon()
	ui_refresh.emit()


func deal_to_enemy(e: Dictionary, amount: float, crit: bool = false, color: Color = Color(0.95, 0.89, 0.77), _soft: bool = false, spell: bool = false, elem: String = "") -> void:
	if e.get("dead", false) or e.get("ally") or e.get("escaped"):
		return
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	if P.up.get("missNext"):
		P.up.missNext = false
		float_at(e.x, 2.3, e.z, "落空", Color(0.54, 0.5, 0.44), 16)
		return
	if spell and float(e.get("spellImm", 0)) > 0:
		float_at(e.x, 2.3, e.z, "免疫", Color(0.56, 0.83, 1), 15)
		return
	if elem == "":
		elem = skill_elem(P.lastSkill) if spell else ("shadow" if P.cls == "mage" else "phys")
	if tal_rank("mfr6") and (float(e.get("slow", 0)) > 0 or float(e.get("frozen", 0)) > 0):
		amount *= 1.2
	if P.buffs.has("shadow"):
		amount *= 1.5
		P.buffs.erase("shadow")
	var pitch := pwr("u_pitch")
	if spell and not pitch.is_empty() and Cfg._rng.randf() * 100.0 < float(pitch.get("p", 15)):
		amount *= 2.0
		e.spellImm = 2.0
		float_at(e.x, 2.7, e.z, "高半度", Color(0.78, 0.64, 1), 15)
	amount = unique_dmg_mul(e, amount)
	if P.buffs.has("hawkmark") and int(P.buffs.hawkmark.get("id", -1)) == int(e.get("id", -2)):
		amount *= 1.25
	if WorldState.has_mod(e, "guard"):
		var shared := 0
		for o in WorldState.W.enemies:
			if o == e or o.get("dead"):
				continue
			if Cfg.dist2(o.x, o.z, e.x, e.z) < 36:
				shared += 1
		if shared:
			amount *= 0.62
	amount = apply_enemy_res(e, amount, elem)
	if amount <= 0:
		return
	var rift_dr: float = float(e.get("riftDr", 0))
	if rift_dr > 0:
		amount *= 1.0 - rift_dr
	e.hp -= amount
	e.hitFlash = 0.14
	WorldState._show_bar(e, true)
	float_at(e.x, 2.3, e.z, ("✦ " if crit else "") + str(int(round(amount))), Color(1.0, 0.66, 0.18) if crit else color, 27 if crit else 17)
	Sfx.hit()
	if not _soft and WorldState.has_mod(e, "frost") and P.alive:
		P.chill = maxf(float(P.chill), 2.2)
		float_at(P.x, 2.4, P.z, "冻", Color(0.56, 0.83, 1), 12)
	var s := p_stats()
	if s.leech > 0:
		heal_player(amount * s.leech / 100.0)
	if not _soft and P.alive:
		if s.freezehit and Cfg._rng.randf() * 100.0 < s.freezehit:
			e.frozen = maxf(float(e.frozen), 1.35)
		elif s.chillhit and Cfg._rng.randf() * 100.0 < s.chillhit:
			e.slow = maxf(float(e.slow), 2.2)
	feel.lastSoft = _soft
	if not _soft:
		bump_combo()
		punch_hit(e, crit)
		if not pwr("u_voices").is_empty():
			var vs = P.up.get("voiceSet")
			if typeof(vs) != TYPE_DICTIONARY:
				vs = {}
			if not vs.get(e.id):
				vs[e.id] = 1
				P.up.voiceN = int(P.up.get("voiceN", 0)) + 1
			P.up.voiceSet = vs
			P.up.voiceT = 6.0
			if int(P.up.get("voiceN", 0)) >= 47:
				P.up.voiceBoom = true
		if not pwr("u_third").is_empty():
			if int(P.up.get("sameId", -1)) == int(e.id):
				P.up.sameN = mini(10, int(P.up.get("sameN", 0)) + 1)
			else:
				P.up.sameId = e.id
				P.up.sameN = 1
		if int(P.up.get("erlPend", -1)) == int(e.id):
			P.up.erlPend = null
			if float(e.hp) > 0:
				P.up.erlDown = 6.0
	if e.hp <= 0:
		if WorldState.has_mod(e, "rise") and not e.get("risen"):
			e.risen = true
			e.hp = maxf(1, round(e.hpMax * 0.4))
			e.stun = 0.5
			e.hitFlash = 0.35
			float_at(e.x, 3.1, e.z, "不肯散", Color(0.89, 0.77, 0.5), 18)
			return
		var split: bool = (WorldState.has_mod(e, "split") or (rift_has("echo") and e.get("elite") and not e.get("boss") and not e.get("hoard") and not e.get("splitling"))) and not e.get("didSplit")
		if split:
			e.didSplit = true
		kill_enemy(e)
		if split:
			WorldState.spawn_splits(e)


func kill_enemy(e: Dictionary) -> void:
	if e.get("dead", false):
		return
	if e.get("ally"):
		WorldState.ally_leave(e, "散了")
		return
	if e.get("escaped"):
		return
	e.dead = true
	e.dieT = 0.0
	e.hp = 0
	WorldState._show_bar(e, false)
	Sfx.die()
	punch_kill(e)
	P.kills += 1
	P.killByType[e.type] = int(P.killByType.get(e.type, 0)) + 1
	if e.get("elite", false):
		P.eliteKills += 1
	if e.get("su"):
		P.suKills = int(P.get("suKills", 0)) + 1
		var su := Data.su_by_id(str(e.su))
		if not su.is_empty() and su.get("last"):
			say("%s：「%s」" % [e.name, su.last])
		_on_su_kill(e, su)
	gain_xp(int(e.xp))
	roll_drop(e)
	if e.get("hoard"):
		say("揣着的东西散了一地。")
	if str(e.get("evt", "")) == "chest":
		WorldState.on_chest_guard_kill()
	if str(e.get("evt", "")) == "caravan":
		WorldState.on_caravan_kill()
	if e.get("sekhra") and not P.flags.get("thimble"):
		P.flags.thimble = true
		say("塞克拉（战败）：「……找到了。」")
		WorldState.drop_at(e.x, e.z, {"kind": "relic", "relic": LootData.RELIC_THIMBLE})
	if e.get("childOf"):
		for o in WorldState.W.enemies:
			if o.id == e.childOf and not o.get("dead") and not o.get("enraged"):
				o.enraged = true
				o.speed = float(o.speed) * 1.4
				float_at(o.x, 3.0, o.z, "暴怒", Color(1, 0.4, 0.2), 16)
				break
	if e.get("boss", false):
		P.bossKills += 1
		say("%s 倒下了。" % e.name)
		var W := WorldState.W
		if W.area.get("kind") == "dungeon" and W.dun and int(W.dunFloor) >= int(W.dun.floors):
			var first := not dun_cleared_on(W.dun.id)
			if typeof(P.bountyDun) != TYPE_DICTIONARY:
				P.bountyDun = {}
			P.bountyDun[str(W.dun.id)] = int(P.bountyDun.get(str(W.dun.id), 0)) + 1
			mark_dun_clear(W.dun.id)
			if first:
				var rw := roll_set_item(int(W.dun.lvl) + 3)
				if rw.is_empty():
					rw = roll_item(int(W.dun.lvl) + 3, true)
				add_to_bag(rw)
				note_loot(rw)
				P.gold += int(W.dun.lvl) * 180
				bump_gold(int(W.dun.lvl) * 180)
				say("首次通关 %s（%s）！获得 %s 与 %d 金币。" % [W.dun.n, diff_now().n, rw.name, int(W.dun.lvl) * 180])
				Sfx.quest()
				maybe_chapter_cine(W.dun.id)
			hint("副本已通关 · 出口开启")
			WorldState.open_dungeon_exit()
			drop_chapter_uniques(e)
	if tal_rank("wf6"):
		heal_player(P.hpMax * 0.05)
	var st := p_stats()
	if st.killhp:
		heal_player(P.hpMax * st.killhp / 100.0)
	if st.killmp:
		P.mp = clampf(P.mp + P.mpMax * st.killmp / 100.0, 0, P.mpMax)
	if set_on("rift", 4):
		P.mp = clampf(P.mp + P.mpMax * 0.04, 0, P.mpMax)
	var wh := cpwr("c_whistle")
	if not wh.is_empty():
		P.mp = clampf(P.mp + float(wh.get("mp", 4)), 0, P.mpMax)
	var clod := cpwr("c_clod")
	if not clod.is_empty():
		heal_player(P.hpMax * float(clod.get("h", 2)) / 100.0)
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	if not pwr("u_names").is_empty():
		P.up.names = mini(11, int(P.up.get("names", 0)) + 1)
	if P.up.get("unfin"):
		P.up.unfinKills = int(P.up.get("unfinKills", 0)) + 1
	if P.up.get("delayHit"):
		P.up.delayHit = null
		float_at(P.x, 2.5, P.z, "取消", Color(0.89, 0.77, 0.5), 14)
	if phrase_on("enough"):
		var n := mini(3, int((P.buffs.get("enough", {}) as Dictionary).get("n", 0)) + 1)
		P.buffs.enough = {"t": 2.0, "v": 40 * n, "n": n}
		float_at(P.x, 2.5, P.z, "够了吗 ×%d" % n, Color(0.78, 0.64, 1), 14)
	if st.killburst and not P.get("_bursting"):
		P._bursting = true
		var nova: float = Cfg.rf(st.dmgMin, st.dmgMax) * st.killburst / 100.0
		for o in WorldState.W.enemies:
			if o == e or o.get("dead"):
				continue
			if Cfg.dist2(o.x, o.z, e.x, e.z) < 3.4 * 3.4:
				deal_to_enemy(o, nova, false, Color(0.89, 0.77, 0.5), true)
		P._bursting = false
	unlock_quests()
	EventBus.quest_changed.emit()
	ach_check()
	ui_refresh.emit()
	save_soon()


func heal_player(n: float) -> float:
	if n <= 0:
		return 0.0
	if typeof(P.up) == TYPE_DICTIONARY and P.up.get("unfin"):
		return 0.0
	if rift_has("wane"):
		n *= 0.5
	var cap: float = float(P.hpMax)
	if not pwr("u_law").is_empty() or phrase_on("notyou"):
		cap = float(P.hpMax) * 0.8
	var before: float = float(P.hp)
	P.hp = clampf(P.hp + n, 0, cap)
	return P.hp - before


func hurt_player(amount: float, src: Dictionary = {}, aoe: bool = false) -> void:
	if not P.alive or P.invuln > 0:
		return
	if P.buffs.has("greed"):
		amount *= 1.25
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	if P.up.get("unfin"):
		amount = minf(amount, maxf(0.0, float(P.hp) - 1.0))
	if not pwr("u_breath").is_empty() and P.up.get("beatOn") and aoe:
		float_at(P.x, 2.5, P.z, "换气", Color(0.89, 0.77, 0.5), 14)
		return
	var s := p_stats()
	if float(s.get("dodge", 0)) > 0 and Cfg._rng.randf() * 100.0 < s.dodge:
		float_at(P.x, 2.4, P.z, "闪避", Color(0.78, 0.85, 1), 15)
		return
	if set_on("watch", 2) and Cfg._rng.randf() < 0.15:
		P.buffs.setdr = {"t": 3.0, "v": 20}
		float_at(P.x, 2.5, P.z, "守望", Color(0.12, 1, 0), 15)
	var pin := cpwr("c_pin")
	if not pin.is_empty() and Cfg._rng.randf() * 100.0 < float(pin.get("p", 5)):
		float_at(P.x, 2.5, P.z, "顶针", Color(0.78, 0.63, 0.38), 15)
		return
	var tic := cpwr("c_ticket")
	if not tic.is_empty() and float(P.up.get("ticketCd", 0)) <= 0:
		P.up.ticketCd = float(tic.get("cd", 20))
		float_at(P.x, 2.5, P.z, "弃权", Color(0.78, 0.75, 1), 15)
		return
	var elem := Data.type_elem(str(src.get("type", ""))) if not src.is_empty() else "phys"
	var pr := float(s.get(res_key(elem), 0))
	amount *= (1.0 - pr / 100.0)
	var dmg := maxf(1.0, round(amount * (100.0 / (100.0 + s.armor))))
	if s.dr:
		dmg = maxf(1.0, round(dmg * (1.0 - minf(90.0, s.dr) / 100.0)))
	var abst := pwr("u_abstain")
	if not abst.is_empty() and Cfg._rng.randf() * 100.0 < float(abst.get("p", 10)):
		P.up.missNext = true
		float_at(P.x, 2.5, P.z, "弃权", Color(0.78, 0.75, 1), 16)
		return
	if not pwr("u_thimble").is_empty() and float(P.up.get("thimbleCd", 0)) <= 0:
		P.up.thimbleCd = 10.0
		spawn_stone_wall(float(P.x), float(P.z))
		float_at(P.x, 2.5, P.z, "格挡", Color(0.78, 0.63, 0.38), 16)
		return
	if not pwr("u_hammer").is_empty() and float(P.up.get("dashGrace", 0)) > 0 and typeof(P.up.get("delayHit")) != TYPE_DICTIONARY:
		P.up.dashGrace = 0
		P.up.delayHit = {"t": 2.0, "dmg": dmg}
		float_at(P.x, 2.5, P.z, "延迟", Color(0.89, 0.77, 0.5), 14)
		return
	if P.shield > 0:
		var absorb: float = minf(P.shield, dmg)
		P.shield -= absorb
		dmg -= absorb
		if P.shield <= 0:
			P.buffs.erase("shield")
			P.buffs.erase("potsh")
			say("护盾碎裂。")
			if tal_rank("wb6"):
				var burst: float = Cfg.rf(s.dmgMin, s.dmgMax) * 1.5
				for e in WorldState.W.enemies:
					if e.get("dead") or e.get("ally"):
						continue
					if Cfg.dist2(float(e.x), float(e.z), float(P.x), float(P.z)) > 25.0:
						continue
					deal_to_enemy(e, burst, false, Color(0.78, 0.85, 1))
					e.stun = maxf(float(e.stun), 1.5)
		if absorb > 0 and sk_rune("fortify") == "thorns":
			WorldState.aoe_player(float(P.x), float(P.z), 3.2, Cfg.rf(s.dmgMin, s.dmgMax) * 0.35, "phys")
	if dmg > 0:
		if P.up.get("unfin"):
			P.hp = maxf(1.0, float(P.hp) - dmg)
		else:
			P.hp -= dmg
		float_at(P.x, 2.2, P.z, str(int(dmg)), Color(0.85, 0.28, 0.28), 18)
		if float(feel.get("stopCd", 0)) <= 0:
			feel.stop = maxf(float(feel.get("stop", 0)), 0.028)
			feel.stopCd = 0.12
		var log: Array = P.up.get("hurtLog", [])
		if typeof(log) != TYPE_ARRAY:
			log = []
		log.append({"t": 10.0, "d": dmg})
		P.up.hurtLog = log
		P.enough = float(P.get("enough", 0)) + dmg
		var need := pwr("u_enough")
		if not need.is_empty() and float(P.enough) >= float(need.get("need", 8000)):
			P.enough = 0
			P.hp = float(P.hpMax) * (0.8 if not pwr("u_law").is_empty() else 1.0)
			for k in P.cds.keys():
				P.cds[k] = 0
			for e in WorldState.W.enemies:
				if e.get("dead"):
					continue
				if Cfg.dist2(float(e.x), float(e.z), float(P.x), float(P.z)) < 144.0:
					e.stun = maxf(float(e.stun), 3.0)
			say("够了吗。")
			hint("够了吗")
		if not pwr("u_shoe").is_empty() and P.hp <= P.hpMax * 0.25 and not P.up.get("shoeArmed") and near_enemies(8) <= 1:
			P.up.shoeArmed = true
			heal_player(P.hpMax * 0.4)
			P.up.shoeLock = 1.5
			P.path = []
			hint("站住。")
			float_at(P.x, 2.6, P.z, "岸上", Color(0.89, 0.77, 0.5), 18)
		if P.hp > P.hpMax * 0.4:
			P.up.shoeArmed = false
		var names_n := int(P.up.get("names", 0))
		if not pwr("u_names").is_empty() and P.hp <= 0 and names_n >= 11:
			P.hp = 1
			P.up.names = 0
			float_at(P.x, 2.6, P.z, "十一个名字", Color(0.89, 0.77, 0.5), 18)
			say("你还记得他们。")
	Sfx.hurt()
	cam_shake = maxf(cam_shake, 0.22)
	if phrase_on("godown") and P.hp > 0 and P.hp <= P.hpMax * 0.35 and float(P.stats.get("godownCd", 0)) <= 0:
		P.shield = maxf(float(P.shield), (P.hpMax - P.hp) * 0.3)
		P.shieldT = 12
		P.stats.godownCd = 12
		float_at(P.x, 2.6, P.z, "我下去", Color(0.78, 0.64, 1), 14)
	interrupt_player("引导被打断")
	if P.hp <= 0:
		die()
		ach_check()


func die() -> void:
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	if not P.up.get("realDie") and not pwr("u_unfinished").is_empty() and float(P.up.get("unfinCd", 0)) <= 0 and not P.up.get("unfin"):
		P.alive = true
		P.hp = 1
		P.up.unfin = true
		P.up.unfinT = 8.0
		P.up.unfinKills = 0
		P.up.unfinCd = 300.0
		float_at(P.x, 2.8, P.z, "还没唱完", Color(0.78, 0.64, 1), 24)
		say("曲子还没完。八秒。")
		return
	P.up.realDie = 0
	P.alive = false
	P.hp = 0
	P.channel = null
	ensure_ach()
	P.stats.deaths = int(P.stats.get("deaths", 0)) + 1
	var lost := int(P.gold * 0.08)
	P.gold = maxi(0, P.gold - lost)
	say("你陨落于%s，失去 %d 金币。" % [WorldState.W.area.get("n", ""), lost])
	if diff_id() == "nightmare":
		P.nameLost = int(P.nameLost) + 1
		var cap := maxi(1, str(P.name).length() - 1)
		if P.nameLost >= cap:
			P.nameForgotten = true
		say("又掉了一个字。回桥头念。")
	died.emit()
	ui_refresh.emit()
	save_now()


func drink_spring() -> void:
	P.hp = P.hpMax
	P.mp = P.mpMax
	P.invuln = 0.6
	Sfx.potion()
	hint("井水还是温的")
	say("状态补满了。死了也会在这口井边醒。")
	ui_refresh.emit()


func revive() -> void:
	P.alive = true
	P.hp = P.hpMax
	P.mp = P.mpMax
	P.invuln = 2.0
	WorldState.W.arrive_mode = "well"
	WorldState.W.arrive_from = ""
	WorldState.enter_area(hub_id(), "well")
	ui_refresh.emit()


func recites_name() -> void:
	P.nameForgotten = false
	P.nameLost = 0
	ensure_ach()
	P.stats.recited = int(P.stats.get("recited", 0)) + 1
	hint("名字回来了")
	Sfx.quest()
	ach_check()
	save_now()
	ui_refresh.emit()


func hub_id() -> String:
	if Data.AREA.has(P.hub) and Data.AREA[P.hub].kind == "town":
		return P.hub
	return "town"


func gain_xp(n: int) -> void:
	P.xp += n
	var c: Dictionary = Data.CLASSES[P.cls]
	while P.xp >= P.xpNext:
		P.xp -= P.xpNext
		P.lvl += 1
		P.pts += 3
		P.skPts += 1
		P.xpNext = int(round(60 * pow(P.lvl, 1.55)))
		P.base.str += c.grow.str
		P.base.dex += c.grow.dex
		P.base.vit += c.grow.vit
		P.base.ene += c.grow.ene
		refresh_max(true)
		float_at(P.x, 2.6, P.z, "升级！", Color(1, 0.82, 0.34), 26)
		Sfx.level()
		var extra := "，+1 天赋点" if (P.lvl == 10 or P.lvl == 20) else ""
		say("晋升至 %d 级（+3 属性点，+1 技能点%s）" % [P.lvl, extra])
		if P.lvl == 10:
			say("天赋开了。按 C 或 K。两个，先点一个。")
		ach_check()
	save_soon()
	ui_refresh.emit()


func roll_item(lvl: int, force_rare: bool = false, cls_hint: String = "", force_type: String = "", crate: bool = false) -> Dictionary:
	var type: String
	if force_type == "weapon" or Data.BASES.has(force_type):
		type = force_type
	else:
		# 饰品/戒指更稀有：普通部位权重 3，amulet/ring 权重 1
		var _pool := ["weapon","weapon","weapon","armor","armor","armor","helm","helm","helm","offhand","offhand","offhand","belt","belt","belt","gloves","gloves","gloves","boots","boots","boots","amulet","ring"]
		type = str(Cfg.pick(_pool))
	var cls: String = cls_hint if cls_hint != "" else str(P.cls)
	var base: Dictionary
	if type == "weapon":
		base = Cfg.pick(Data.BASES.weapon[cls])
	else:
		base = Cfg.pick(Data.BASES[type])
	var D := diff_now()
	lvl = lvl + int(D.get("ilvl", 0))
	var roll := Cfg._rng.randf()
	var r := 0
	if force_rare:
		r = 4 if roll < 0.1 else (3 if roll < 0.5 else 2)
	elif crate:
		r = 0 if roll < 0.32 else (1 if roll < 0.62 else (2 if roll < 0.88 else (3 if roll < 0.975 else 4)))
	else:
		# 高品质装备更稀有：白62/魔26/稀9/史2.5/传0.5（boss/elite/su/hoard 走 force_rare，不受影响）
		r = 0 if roll < 0.62 else (1 if roll < 0.88 else (2 if roll < 0.97 else (3 if roll < 0.995 else 4)))
	if D.id == "hell" and r < 4 and Cfg._rng.randf() < 0.12:
		r += 1
	if D.id == "nightmare" and r < 4 and Cfg._rng.randf() < 0.22:
		r += 1
	if int(WorldState.W.get("shrineRare", 0)) != 0 or P.buffs.has("plenty"):
		r = mini(4, r + 1)
	var mf := magic_find()
	if mf > 0 and r < 4 and Cfg._rng.randf() * 100.0 < mf * 0.32:
		r = mini(4, r + 1)
	var sc := 1.0 + (lvl - 1) * 0.30
	item_seq += 1
	var it := {
		"id": item_seq, "type": type, "glyph": base.g, "rarity": r,
		"name": str(base.n), "ilvl": lvl,
		"dmgMin": 0, "dmgMax": 0, "armor": 0, "affixes": [], "spd": base.get("sp", 1.0),
		"cls": cls if type == "weapon" else "", "sockets": [], "reforged": 0
	}
	if type == "weapon":
		it.dmgMin = int(round(base.d[0] * sc + r * 1.7))
		it.dmgMax = int(round(base.d[1] * sc + r * 3.4))
	else:
		var a: Array = base.a
		it.armor = int(round(Cfg.rf(a[0], a[1]) * sc)) + r * 3
	roll_affixes(it)
	if r == 1:
		it.name = str(Cfg.pick(Data.PRE)) + str(it.name)
	elif r == 2 or r == 3:
		it.name = str(Cfg.pick(Data.PRE)) + str(it.name) + str(Cfg.pick(Data.SUF))
	elif r == 4:
		it.name = str(Cfg.pick(Data.UNIQUE_NAMES))
	return it


func sets_for_lvl(lvl: int, cls_hint: String = "") -> Array:
	var cls: String = cls_hint if cls_hint != "" else str(P.cls)
	var out: Array = []
	for s in LootData.SETS:
		var scls = s.get("cls")
		if scls != null and str(scls) != "" and str(scls) != cls:
			continue
		if lvl >= int(s.min) - 8 and lvl <= int(s.max) + 12:
			out.append(s)
	return out


func make_set_item(setd: Dictionary, piece: Dictionary, ilvl: int) -> Dictionary:
	ilvl = maxi(1, ilvl)
	var base_sc: float = 1.0 + (maxi(1, int(setd.min)) - 1) * 0.18
	var sc: float = (1.0 + (ilvl - 1) * 0.18) / base_sc
	var rolls: Array = []
	for a in piece.get("affixes", []):
		var t: float = 0.15 + Cfg._rng.randf() * 0.85
		var raw: float = float(a.min) + (float(a.max) - float(a.min)) * t
		rolls.append({"n": a.n, "k": a.k, "v": maxi(1, int(round(raw * sc)))})
	item_seq += 1
	var pcls = piece.get("cls")
	if pcls == null:
		pcls = ""
	if str(pcls) == "" and str(piece.type) == "weapon":
		pcls = setd.get("cls", "")
		if pcls == null:
			pcls = ""
	var it := {
		"id": item_seq, "set": setd.id, "sid": piece.id, "type": piece.type, "glyph": piece.g,
		"rarity": 3, "name": piece.n, "flavor": str(piece.get("flavor", setd.get("flavor", ""))),
		"ilvl": ilvl, "dmgMin": 0, "dmgMax": 0, "armor": 0, "affixes": rolls,
		"spd": float(piece.get("spd", 1)), "cls": str(pcls) if pcls != null else "",
		"sockets": [], "reforged": 0
	}
	if str(piece.type) == "weapon":
		var d0: float = float(piece.d[0]) if piece.get("d") else 6.0
		var d1: float = float(piece.d[1]) if piece.get("d") else 12.0
		it.dmgMin = maxi(1, int(round(d0 * sc * (1.0 + (ilvl - 1) * 0.12))))
		it.dmgMax = maxi(2, int(round(d1 * sc * (1.0 + (ilvl - 1) * 0.12))))
	else:
		it.armor = int(round(float(piece.get("armor", 8)) * sc))
	return it


func roll_set_item(lvl: int, cls_hint: String = "", force_set: String = "") -> Dictionary:
	var cls: String = cls_hint if cls_hint != "" else str(P.cls)
	var pool: Array = []
	if force_set != "":
		var s := LootData.set_by_id(force_set)
		if not s.is_empty():
			pool.append(s)
	else:
		pool = sets_for_lvl(lvl, cls)
	if pool.is_empty():
		for s in LootData.SETS:
			var scls = s.get("cls")
			if scls == null or str(scls) == "" or str(scls) == cls:
				pool.append(s)
	if pool.is_empty():
		return {}
	var setd: Dictionary = Cfg.pick(pool)
	var piece: Dictionary = Cfg.pick(setd.pieces)
	return make_set_item(setd, piece, lvl)


func set_drop_chance(e: Dictionary) -> float:
	if e.is_empty():
		return 0.02
	if e.get("boss") or str(e.get("su", "")) != "" or e.get("hoard"):
		return 0.24
	if e.get("elite"):
		return 0.1
	return 0.02


func maybe_set_item(lvl: int, e: Dictionary, cls_hint: String = "") -> Dictionary:
	var mf := magic_find()
	if Cfg._rng.randf() >= minf(0.55, set_drop_chance(e) * (1.0 + mf / 180.0)):
		return {}
	return roll_set_item(lvl, cls_hint)


func roll_unique(def, ilvl: int = 1, quality: float = 0.0) -> Dictionary:
	if typeof(def) == TYPE_STRING:
		def = LootData.unique_by_id(str(def))
	if typeof(def) != TYPE_DICTIONARY or def.is_empty():
		return roll_item(maxi(1, ilvl), true)
	ilvl = maxi(1, ilvl)
	var lo: float = quality * 0.55
	var rolls: Array = []
	var tsum := 0.0
	for a in def.get("affixes", []):
		var t: float = lo + Cfg._rng.randf() * (1.0 - lo)
		var raw: float = float(a.min) + (float(a.max) - float(a.min)) * t
		var v = round(raw) if int(a.get("dec", 0)) == 0 else snapped(raw, pow(10, -int(a.dec)))
		rolls.append({"n": a.n, "k": a.k, "v": v, "t": t})
		tsum += t
	var wsum: float = maxf(1.0, float(def.get("affixes", []).size()))
	var perfect := int(round(tsum / wsum * 100.0))
	var pv := {}
	for p in def.get("pv", []):
		var t: float = lo + Cfg._rng.randf() * (1.0 - lo)
		var raw: float = float(p.min) + (float(p.max) - float(p.min)) * t
		pv[str(p.k)] = round(raw) if int(p.get("dec", 0)) == 0 else snapped(raw, pow(10, -int(p.dec)))
	var sc: float = 1.0 + (ilvl - 1) * 0.18
	item_seq += 1
	var title := ""
	if perfect >= 95 and str(def.get("title", "")) != "":
		title = " · " + str(def.title)
	var ucls = def.get("cls")
	if ucls == null:
		ucls = ""
	var it := {
		"id": item_seq, "uid": def.id, "unique": true, "type": def.type, "glyph": def.g,
		"rarity": int(def.get("rarity", 3)), "name": str(def.n) + title, "flavor": str(def.get("flavor", "")),
		"ilvl": ilvl, "dmgMin": 0, "dmgMax": 0, "armor": 0, "affixes": rolls,
		"spd": float(def.get("spd", 1)), "cls": str(ucls), "sockets": [], "reforged": 0,
		"perfect": perfect, "power": {"id": def.id, "v": pv}
	}
	if str(def.type) == "weapon":
		var d0: float = float(def.d[0]) if def.get("d") else 8.0
		var d1: float = float(def.d[1]) if def.get("d") else 16.0
		it.dmgMin = maxi(1, int(round(d0 * sc)))
		it.dmgMax = maxi(2, int(round(d1 * sc)))
	else:
		it.armor = int(round(float(def.get("armor", 8)) * sc))
	return it


func roll_unique_charm(def, ilvl: int = 1) -> Dictionary:
	if typeof(def) == TYPE_STRING:
		def = LootData.charm_unique_by_id(str(def))
	if typeof(def) != TYPE_DICTIONARY or def.is_empty():
		return roll_charm(maxi(1, ilvl))
	var rolls: Array = []
	var tsum := 0.0
	for a in def.get("affixes", []):
		var t: float = Cfg._rng.randf()
		var raw: float = float(a.min) + (float(a.max) - float(a.min)) * t
		rolls.append({"n": a.n, "k": a.k, "v": int(round(raw)), "t": t})
		tsum += t
	var perfect := int(round(tsum / maxf(1.0, float(rolls.size())) * 100.0))
	var pv := {}
	for p in def.get("pv", []):
		var t: float = Cfg._rng.randf()
		var raw: float = float(p.min) + (float(p.max) - float(p.min)) * t
		pv[str(p.k)] = round(raw) if int(p.get("dec", 0)) == 0 else snapped(raw, pow(10, -int(p.dec)))
	item_seq += 1
	return {
		"id": item_seq, "type": "charm", "cid": def.id, "sz": 3, "unique": true, "glyph": def.g,
		"rarity": 3, "name": def.n, "flavor": str(def.get("flavor", "")), "ilvl": ilvl,
		"dmgMin": 0, "dmgMax": 0, "armor": 0, "affixes": rolls, "sockets": [], "reforged": 0,
		"perfect": perfect, "power": {"id": def.id, "v": pv}
	}


func roll_charm(lvl: int = 1) -> Dictionary:
	lvl = maxi(1, lvl)
	if Cfg._rng.randf() < 0.08:
		return roll_unique_charm(Cfg.pick(LootData.CHARM_UNIQUES), lvl)
	var t: float = Cfg._rng.randf()
	var sz: int = 1 if t < 0.58 else (2 if t < 0.86 else 3)
	var rarity: int
	if sz == 1:
		rarity = 2 if Cfg._rng.randf() < 0.18 else 1
	elif sz == 2:
		rarity = 3 if Cfg._rng.randf() < 0.22 else 2
	else:
		rarity = 3 if Cfg._rng.randf() < 0.28 else 2
	var bases: Array = LootData.CHARM_BASE.get(str(sz), [])
	if bases.is_empty():
		bases = [{"n": "纽扣", "g": "🔘"}]
	var base: Dictionary = Cfg.pick(bases)
	item_seq += 1
	var it := {
		"id": item_seq, "type": "charm", "sz": sz, "glyph": base.g, "rarity": rarity, "name": str(base.n),
		"ilvl": lvl, "dmgMin": 0, "dmgMax": 0, "armor": 0, "affixes": [], "sockets": [], "reforged": 0
	}
	var need := 1 if sz == 1 else 2
	var used := {}
	var guard := 0
	while it.affixes.size() < need and guard < 40:
		guard += 1
		var a: Dictionary = Cfg.pick(LootData.CHARM_AFFIX)
		if used.has(a.k):
			continue
		used[a.k] = 1
		var rr: Array = a.r
		it.affixes.append({"n": a.n, "k": a.k, "v": int(round(Cfg.rf(rr[0], rr[1]) * (1.0 + (lvl - 1) * 0.16)))})
	if rarity == 1:
		it.name = str(Cfg.pick(Data.PRE)) + str(it.name)
	elif rarity >= 2:
		it.name = str(Cfg.pick(Data.PRE)) + str(it.name) + str(Cfg.pick(Data.SUF))
	return it


func drop_chapter_uniques(e: Dictionary) -> void:
	var W := WorldState.W
	if W.dun == null:
		return
	var bid := str(LootData.UNIQUE_DUN.get(str(W.dun.id), ""))
	if bid == "":
		return
	var ilvl: int = int(e.get("lvl", W.dun.get("lvl", P.lvl)))
	var legs: Array = LootData.unique_pool(bid, false)
	var arts: Array = LootData.unique_pool(bid, true)
	if legs.size():
		WorldState.drop_item(e.x + Cfg.rf(-1.4, 1.4), e.z + Cfg.rf(-1.4, 1.4), roll_unique(Cfg.pick(legs), ilvl, 0))
		if Cfg._rng.randf() < 0.22:
			WorldState.drop_item(e.x + Cfg.rf(-1.4, 1.4), e.z + Cfg.rf(-1.4, 1.4), roll_unique(Cfg.pick(legs), ilvl, 0))
		if Cfg._rng.randf() < 0.04:
			WorldState.drop_item(e.x + Cfg.rf(-1.4, 1.4), e.z + Cfg.rf(-1.4, 1.4), roll_unique(Cfg.pick(legs), ilvl, 0))
	if typeof(P.luck) != TYPE_DICTIONARY:
		P.luck = {}
	if typeof(P.tokens) != TYPE_DICTIONARY:
		P.tokens = {}
	P.tokens[bid] = int(P.tokens.get(bid, 0)) + 2 + int(floor(Cfg._rng.randf() * 3.0))
	if arts.size():
		var p: float = 0.04 + float(P.luck.get(bid, 0)) * 0.025
		if Cfg._rng.randf() < p or int(P.luck.get(bid, 0)) >= 19:
			WorldState.drop_item(e.x + Cfg.rf(-1.4, 1.4), e.z + Cfg.rf(-1.4, 1.4), roll_unique(arts[0], ilvl, 0.4))
			P.luck[bid] = 0
		else:
			P.luck[bid] = int(P.luck.get(bid, 0)) + 1
	say("地上多了专属件。信物「%s」×%d。" % [LootData.TOKEN_N.get(bid, bid), int(P.tokens[bid])])


func redeem_unique(id: String) -> void:
	var def := LootData.unique_by_id(id)
	if def.is_empty():
		return
	if typeof(P.tokens) != TYPE_DICTIONARY:
		P.tokens = {}
	var boss := str(def.boss)
	if int(P.tokens.get(boss, 0)) < 40:
		hint("信物不够")
		return
	var it := roll_unique(def, maxi(1, int(P.lvl)), 0.2)
	if not add_to_bag(it):
		hint("行囊已满")
		return
	P.tokens[boss] = int(P.tokens.get(boss, 0)) - 40
	note_loot(it)
	Sfx.quest()
	say("用信物换来 %s" % it.name)
	save_soon()
	ach_check()
	ui_refresh.emit()


func collect_relic(rel: Dictionary) -> void:
	if rel.is_empty():
		return
	if typeof(P.relics) != TYPE_ARRAY:
		P.relics = []
	if typeof(P.codex) != TYPE_ARRAY:
		P.codex = []
	var rid := str(rel.get("id", ""))
	if rid != "":
		for r in P.relics:
			if str(r.get("id", "")) == rid:
				return
	P.relics.append({"id": rel.get("id", ""), "n": rel.n, "d": rel.get("d", ""), "icon": rel.get("icon", "🕯")})
	if rel.get("codex"):
		P.codex.append({"n": rel.codex.get("n", "？？？"), "text": rel.codex.get("text", "")})
	Sfx.quest()
	say("得到遗物：%s" % rel.n)
	for ln in rel.get("lines", []):
		say(str(ln))
	save_soon()
	ui_refresh.emit()


func _on_su_kill(e: Dictionary, def: Dictionary) -> void:
	if typeof(P.flags) != TYPE_DICTIONARY:
		P.flags = {}
	var su_map: Dictionary = {}
	if typeof(P.flags.get("su", {})) == TYPE_DICTIONARY:
		su_map = P.flags.get("su", {})
	var sid := str(e.su)
	var first: bool = not su_map.has(sid)
	if not first:
		say("%s 倒下了。" % e.name)
		return
	su_map[sid] = true
	P.flags.su = su_map
	P.suKills = su_map.size()
	if not def.is_empty() and str(def.get("relic", "")) == "halfpaper" and not P.flags.get("halfPaper"):
		P.flags.halfPaper = true
		WorldState.drop_at(e.x, e.z, {"kind": "relic", "relic": LootData.RELIC_HALFPAPER})
	if not def.is_empty() and def.get("codex"):
		if typeof(P.codex) != TYPE_ARRAY:
			P.codex = []
		var cn := str(def.codex.get("n", ""))
		var has := false
		for c in P.codex:
			if str(c.get("n", "")) == cn:
				has = true
				break
		if not has:
			P.codex.append({"n": cn, "text": str(def.codex.get("text", ""))})


func is_underground() -> bool:
	var k := str(WorldState.W.area.get("kind", ""))
	return k == "dungeon" or k == "rift"


func take_ground(obj: Dictionary) -> bool:
	var kind := str(obj.get("kind", ""))
	if kind == "gold":
		P.gold += int(obj.amt)
		bump_gold(int(obj.amt))
		Sfx.gold()
		float_at(obj.x, 1.6, obj.z, "+%d" % int(obj.amt), Color(1, 0.85, 0.3), 14)
		ach_check()
		return true
	if kind == "potion":
		if str(obj.get("pot", "")) == "mp":
			P.potMp += 1
		else:
			P.potHp += 1
		Sfx.loot()
		return true
	if kind == "relic":
		var rel = obj.get("relic", {})
		if typeof(rel) == TYPE_DICTIONARY:
			collect_relic(rel)
		return true
	var g = obj.get("item")
	if typeof(g) != TYPE_DICTIONARY:
		return true
	if is_underground() and str(g.get("type", "")) != "rune":
		g.unknown = true
	if str(g.get("type", "")) == "charm":
		var where := "bag"
		if add_to_charms(g):
			where = "charm"
		elif P.bag.size() >= Cfg.BAG:
			hint("行囊已满")
			return false
		else:
			P.bag.append(g)
		Sfx.loot()
		if g.get("unknown"):
			float_at(obj.x, 1.4, obj.z, "想不起来的东西", Color(0.54, 0.5, 0.44), 15)
			say("拾取 想不起来的东西（%s）" % ("已进遗物袋" if where == "charm" else "遗物袋满了，先放行囊"))
		else:
			float_at(obj.x, 1.4, obj.z, str(g.name), Color(0.85, 0.76, 0.36), 16)
			if where == "charm":
				say("遗物生效：%s" % g.name)
			else:
				say("遗物袋满了，%s 先放进行囊，不生效" % g.name)
		refresh_max(false)
		save_soon()
		note_loot(g)
		ach_check()
		ui_refresh.emit()
		return true
	if add_to_bag(g):
		note_loot(g)
		ach_check()
		return true
	return false


func feel_chance(r: int) -> float:
	return 0.82 if r >= 4 else (0.55 if r >= 3 else (0.28 if r >= 2 else 0.0))


func roll_one_affix(it: Dictionary, used: Dictionary, from_feel: bool) -> Dictionary:
	var pool: Array = []
	var src: Array = Data.FEEL_AFFIX if from_feel else Data.AFFIX
	for a in src:
		if not used.has(a.k):
			pool.append(a)
	if pool.is_empty():
		return {}
	var a: Dictionary = Cfg.pick(pool)
	used[a.k] = 1
	var v := int(round(Cfg.rf(a.r[0], a.r[1]) * (1.0 + (maxi(1, int(it.ilvl)) - 1) * 0.18)))
	return {"n": a.n, "k": a.k, "v": v, "feel": int(a.get("feel", 0)) != 0}


func roll_affixes(it: Dictionary) -> void:
	it.affixes = []
	var used := {}
	var need: int = int(Data.RARITY[int(it.rarity)].af)
	var guard := 0
	while it.affixes.size() < need and guard < 48:
		guard += 1
		var a := roll_one_affix(it, used, false)
		if a.is_empty():
			break
		it.affixes.append(a)
	if Cfg._rng.randf() < feel_chance(int(it.rarity)):
		var a := roll_one_affix(it, used, true)
		if not a.is_empty():
			it.affixes.append(a)


func magic_find() -> float:
	return float(p_stats().get("mf", 0))


func gold_find_mul() -> float:
	var g: float = 2.5 if P.buffs.has("greed") else 1.0
	return g * (1.0 + float(p_stats().get("gf", 0)) / 100.0)


func make_rune_item(id: String, v = null, grade: int = 1) -> Dictionary:
	var def := Data.rune_by_id(id)
	if def.is_empty():
		def = Data.RUNES[0]
	var g := clampi(grade, 1, 3)
	var val: int = int(v) if v != null else Data.rune_val(def, g)
	item_seq += 1
	return {
		"id": item_seq, "type": "rune", "runeId": def.id, "glyph": def.g, "rarity": g, "grade": g,
		"name": Data.rune_name(def, g), "ilvl": 1, "dmgMin": 0, "dmgMax": 0, "armor": 0,
		"affixes": [], "k": def.k, "v": val, "n": def.n, "sockets": []
	}


func roll_rune(grade: int = -1) -> Dictionary:
	var w: Array = []
	for r in Data.RUNES:
		w.append(62 if r.tier == 1 else (28 if r.tier == 2 else 10))
	var total := 0
	for n in w:
		total += int(n)
	var t := Cfg._rng.randf() * total
	var def: Dictionary = Data.RUNES[0]
	for i in Data.RUNES.size():
		t -= float(w[i])
		if t <= 0:
			def = Data.RUNES[i]
			break
	if grade < 0:
		var D := diff_now()
		var r := Cfg._rng.randf()
		if D.id == "nightmare":
			grade = 3
		elif D.id == "hell":
			grade = 2 if r < 0.38 else 3
		else:
			grade = 1 if r < 0.72 else (2 if r < 0.94 else 3)
	return make_rune_item(def.id, null, clampi(grade, 1, 3))


func combine_rune(rune_id: String, grade: int) -> void:
	grade = maxi(1, grade)
	if grade >= 3:
		hint("已经是完整的了")
		return
	var idx: Array = []
	for i in P.bag.size():
		var it = P.bag[i]
		if it and it.get("type") == "rune" and it.get("runeId") == rune_id and int(it.get("grade", 1)) == grade:
			idx.append(i)
	if idx.size() < 3:
		hint("还差 %d 枚" % (3 - idx.size()))
		return
	var cost := 30 * grade
	if P.gold < cost:
		hint("金币不足")
		return
	P.gold -= cost
	idx = idx.slice(-3)
	idx.sort()
	idx.reverse()
	for i in idx:
		P.bag.remove_at(int(i))
	add_to_bag(make_rune_item(rune_id, null, grade + 1))
	Sfx.level()
	say("三枚合成了更高一阶。")
	save_soon()
	ui_refresh.emit()


func make_scrap(pid: String) -> Dictionary:
	var p := Data.phrase_by_id(pid)
	if p.is_empty():
		p = Data.PHRASES[0]
	var hide := Cfg._rng.randi_range(0, p.runes.size() - 1)
	var bits: PackedStringArray = []
	for i in p.runes.size():
		if i == hide:
			bits.append("？")
		else:
			bits.append(str(Data.rune_by_id(p.runes[i]).get("n", "?")))
	item_seq += 1
	return {
		"id": item_seq, "type": "scrap", "glyph": "📜", "rarity": 2, "name": "残句", "phrase": p.id,
		"ilvl": 1, "dmgMin": 0, "dmgMax": 0, "armor": 0, "affixes": [],
		"flavor": " · ".join(bits) + " · " + phrase_need(p), "unknown": false, "sockets": []
	}


func phrase_need(p: Dictionary) -> String:
	var names: PackedStringArray = []
	for t in p.types:
		names.append(Data.slot_name_of(str(t)))
	return "/".join(names)


func roll_scrap() -> Dictionary:
	var unknown: Array = []
	for p in Data.PHRASES:
		if not known_phrase(p.id):
			unknown.append(p)
	var p: Dictionary = Cfg.pick(unknown) if unknown.size() else Cfg.pick(Data.PHRASES)
	return make_scrap(p.id)


func learn_scrap(it: Dictionary) -> void:
	if it.get("type") != "scrap" or not it.get("phrase"):
		return
	unlock_phrase(str(it.phrase))


func identify_item(it: Dictionary) -> bool:
	if it and it.get("unknown"):
		it.unknown = false
		return true
	return false


func identify_all() -> int:
	var n := 0
	for it in P.bag:
		if identify_item(it):
			n += 1
	for it in P.get("charms", []):
		if identify_item(it):
			n += 1
	if n > 0:
		ensure_ach()
		P.stats.recalled = int(P.stats.get("recalled", 0)) + n
		refresh_max(false)
		ach_check()
	return n


func count_unknown() -> int:
	var n := 0
	for it in P.bag:
		if it.get("unknown"):
			n += 1
	for it in P.get("charms", []):
		if it.get("unknown"):
			n += 1
	return n


func crate_cost(type: String) -> int:
	return int(round((55 + maxi(1, int(P.lvl)) * 32) * float(Data.CRATE_MULT.get(type, 1))))


func roll_crate(type: String) -> Dictionary:
	var lvl := clampi(int(P.lvl) + Cfg.ri(-1, 1), 1, 99)
	var it := roll_item(lvl, false, P.cls, type, true)
	it.unknown = true
	return it


func buy_crate(type: String) -> void:
	var cost := crate_cost(type)
	if P.gold < cost:
		hint("金币不足")
		return
	if P.bag.size() >= Cfg.BAG:
		hint("行囊已满")
		return
	if not add_to_bag(roll_crate(type)):
		return
	P.gold -= cost
	note_shop_buy()
	Sfx.gold()
	say("拿走一只来路不明的箱子。去玛拉回想。")
	save_soon()
	ui_refresh.emit()


func make_basic_item(type: String, cls: String, lvl: int) -> Dictionary:
	var base: Dictionary
	if type == "weapon":
		base = Data.BASES.weapon[cls][0]
	elif type == "offhand":
		base = Data.BASES.offhand[2 if cls == "mage" else (3 if cls == "archer" else 0)]
	else:
		base = Data.BASES[type][0]
	var sc := 1.0 + (maxi(1, lvl) - 1) * 0.18
	item_seq += 1
	var it := {
		"id": item_seq, "type": type, "glyph": base.g, "rarity": 0, "name": "制式" + str(base.n),
		"ilvl": lvl, "dmgMin": 0, "dmgMax": 0, "armor": 0, "affixes": [], "spd": base.get("sp", 1.0),
		"cls": cls if type == "weapon" else "", "sockets": [], "reforged": 0
	}
	if type == "weapon":
		it.dmgMin = maxi(1, int(round(base.d[0] * sc)))
		it.dmgMax = maxi(2, int(round(base.d[1] * sc)))
	else:
		it.armor = int(round(Cfg.rf(base.a[0], base.a[1]) * sc))
	return it


func item_score(it: Dictionary) -> float:
	var s: float = float(it.get("dmgMin", 0)) + float(it.get("dmgMax", 0)) * 1.2 + float(it.get("armor", 0)) * 0.8
	for a in it.get("affixes", []):
		var mul := 2.4 if a.get("feel") else (3.0 if a.k == "dmg" else (4.0 if a.k == "crit" else (3.0 if a.k == "as" else (1.6 if a.k == "mf" or a.k == "gf" else 1.0))))
		s += float(a.v) * mul
	for r in it.get("sockets", []):
		if r:
			s += float(r.v) * (3.0 if r.k == "dmg" else (4.0 if r.k == "crit" else (3.0 if r.k == "as" else 1.0)))
	if it.get("set"):
		s += 90
	return s


func buy_price(it: Dictionary) -> int:
	return int(round((40 + item_score(it) * 7 + int(it.rarity) * 90) * (1.0 + int(it.ilvl) * 0.06)))


func sell_price(it: Dictionary) -> int:
	if it.get("unknown"):
		return maxi(12, int(round(18 + int(it.get("ilvl", 1)) * 4)))
	return maxi(8, int(round(buy_price(it) * 0.3)))


func gear_power() -> int:
	var t := 0.0
	for k in SLOT_KEYS:
		var it = P.equip.get(k)
		if it:
			t += float(it.get("ilvl", 1)) * 8.0 + float(it.get("rarity", 0)) * 14.0 + item_score(it) * 0.15
	return int(round(t))


func ch_now() -> int:
	if not WorldState.W.area.is_empty():
		return int(WorldState.W.area.get("ch", 1))
	return 1


func ch_open(n: int) -> bool:
	if n <= 1:
		return true
	var disc: Dictionary = WorldState.W.get("discovered", {})
	if typeof(disc) != TYPE_DICTIONARY:
		disc = {}
	if n == 2:
		return P.quests.get("q8", {}).get("state") == "done" or disc.get("rime") or disc.get("frost") or ch_now() >= 2
	if n == 3:
		return P.quests.get("q12", {}).get("state") == "done" or disc.get("harbor") or disc.get("shore") or ch_now() >= 3
	if n == 4:
		return P.quests.get("q15", {}).get("state") == "done" or disc.get("sink") or disc.get("sinkf") or ch_now() >= 4
	if n == 5:
		return P.quests.get("q18", {}).get("state") == "done" or disc.get("well") or disc.get("shaft") or ch_now() >= 5
	return true


func item_tip(it: Dictionary, cmp: bool = false) -> String:
	if it.is_empty():
		return ""
	if it.get("type") == "scrap":
		return "%s\n半张纸\n%s\n左键记进念法 · 右键丢弃" % [it.name, it.get("flavor", "")]
	if it.get("type") == "rune":
		return "%s\n碎屑 · +%d %s\n卡登处镶嵌或三合一 · 右键丢弃" % [it.name, int(it.get("v", 0)), str(Data.affix_by_k(str(it.get("k", ""))).get("n", it.get("k", "")))]
	if it.get("unknown") == true:
		return "想不起来的东西\n从地下带上来的\n回石桥镇找玛拉回想 · 右键丢弃"
	var lines: PackedStringArray = []
	lines.append(str(it.get("name", "?")))
	var rare: Dictionary = Data.RARITY[int(it.get("rarity", 0))]
	var kind := "套装" if it.get("set") else ("专属" if it.get("unique") else str(rare.n))
	lines.append("%s · 物品等级 %d" % [kind, int(it.get("ilvl", 1))])
	if it.get("dmgMax"):
		lines.append("伤害 %d - %d" % [int(it.dmgMin), int(it.dmgMax)])
	if it.get("armor"):
		lines.append("护甲 +%d" % int(it.armor))
	for a in it.get("affixes", []):
		lines.append("+%d %s%s" % [a.v, a.n, " · 记得的" if a.get("feel") else ""])
	if it.get("unique"):
		var def: Dictionary = LootData.unique_by_id(str(it.get("uid", "")))
		if not def.is_empty() and it.get("power"):
			lines.append(LootData.fmt_power(def, it.power.get("v", {})))
		lines.append("完美度 %d%%" % int(it.get("perfect", 0)))
	if it.get("set"):
		var sd: Dictionary = LootData.set_by_id(str(it.set))
		if not sd.is_empty():
			lines.append(str(sd.n))
	for s in it.get("sockets", []):
		if s:
			lines.append("孔 · %s（+%d %s）" % [s.get("n", ""), int(s.get("v", 0)), str(Data.affix_by_k(str(s.get("k", ""))).get("n", ""))])
		else:
			lines.append("空孔")
	if it.get("phrase"):
		var ph: Dictionary = Data.phrase_by_id(str(it.phrase))
		if not ph.is_empty():
			lines.append("「%s」  %s" % [ph.get("n", ""), ph.get("pw", "")])
	if it.get("cls") and str(it.cls) != P.cls:
		lines.append("你的职业无法使用")
	if cmp and it.get("type") != "charm":
		lines.append_array(_compare_lines(it))
		lines.append("左键装备 · 右键丢弃")
	elif it.get("type") == "charm":
		lines.append("占 %d 格 · 放进遗物袋才生效 · 右键丢弃" % int(it.get("sz", 1)))
	return "\n".join(lines)


func _slot_title(key: String) -> String:
	for s in Data.SLOTDEF:
		if str(s.k) == key or str(s.get("t", "")) == key:
			return str(s.n)
	return key


func _equip_peer(it: Dictionary):
	var key := str(it.get("type", ""))
	if key == "ring":
		var a = P.equip.get("ring1")
		var b = P.equip.get("ring2")
		if a == null:
			return {key="ring1", it=null}
		if b == null:
			return {key="ring2", it=null}
		if item_score(a) <= item_score(b):
			return {key="ring1", it=a}
		return {key="ring2", it=b}
	return {key=key, it=P.equip.get(key)}


func _affix_map(it) -> Dictionary:
	var o := {}
	if it == null or typeof(it) != TYPE_DICTIONARY:
		return o
	for a in it.get("affixes", []):
		var k := str(a.get("k", ""))
		o[k] = int(o.get(k, 0)) + int(a.get("v", 0))
	return o


func _diff_tag(d: int) -> String:
	if d > 0:
		return "[color=#5fba6a]↑ +%d[/color]" % d
	if d < 0:
		return "[color=#d45a4a]↓ %d[/color]" % d
	return "[color=#8a9aaa]＝[/color]"


func _compare_lines(it: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var peer: Dictionary = _equip_peer(it)
	var cur = peer.get("it")
	var slotn := _slot_title(str(peer.get("key", it.get("type", ""))))
	if cur == null or typeof(cur) != TYPE_DICTIONARY:
		out.append("[color=#8a9aaa]相对%s · 空槽[/color]" % slotn)
		out.append("售价 %d 金" % sell_price(it))
		return out
	out.append("[color=#8a9aaa]相对%s · %s[/color]" % [slotn, str(cur.get("name", "?"))])
	var ndmin := int(it.get("dmgMin", 0))
	var ndmax := int(it.get("dmgMax", 0))
	var odmin := int(cur.get("dmgMin", 0))
	var odmax := int(cur.get("dmgMax", 0))
	if ndmax > 0 or odmax > 0:
		out.append("伤害 %d-%d  %s / %s" % [ndmin, ndmax, _diff_tag(ndmin - odmin), _diff_tag(ndmax - odmax)])
	var na := int(it.get("armor", 0))
	var oa := int(cur.get("armor", 0))
	if na != 0 or oa != 0:
		out.append("护甲 +%d  %s" % [na, _diff_tag(na - oa)])
	var nm := _affix_map(it)
	var om := _affix_map(cur)
	var keys: Array = []
	for k in nm.keys():
		if not keys.has(k):
			keys.append(k)
	for k in om.keys():
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var nv := int(nm.get(k, 0))
		var ov := int(om.get(k, 0))
		var def := Data.affix_by_k(str(k))
		var n: String = str(def.get("n", k))
		out.append("+%d %s  %s" % [nv, n, _diff_tag(nv - ov)])
	var df := item_score(it) - item_score(cur)
	if df > 0:
		out.append("[color=#5fba6a]↑ 优于当前[/color] · 售价 %d 金" % sell_price(it))
	elif df < 0:
		out.append("[color=#d45a4a]↓ 劣于当前[/color] · 售价 %d 金" % sell_price(it))
	else:
		out.append("相当 · 售价 %d 金" % sell_price(it))
	return out


func discard_bag(i: int) -> void:
	if i < 0 or i >= P.bag.size():
		return
	var it: Dictionary = P.bag[i]
	P.bag.remove_at(i)
	say("丢掉了 %s" % ("想不起来的东西" if it.get("unknown") else str(it.get("name", "?"))))
	ui_refresh.emit()
	save_soon()


func unequip_slot(key: String) -> void:
	if not SLOT_KEYS.has(key):
		return
	var it = P.equip.get(key)
	if it == null:
		return
	if P.bag.size() >= Cfg.BAG:
		hint("行囊满了")
		return
	P.bag.append(it)
	P.equip[key] = null
	if key == "weapon":
		var _pn = WorldState.player_node()
		if _pn != null:
			var _prev = _pn.get_meta("wpn_attach", null)
			if _prev != null and _prev is Node:
				_prev.queue_free()
				_pn.remove_meta("wpn_attach")
	refresh_max(false)
	ui_refresh.emit()
	save_soon()


func set_track(qid: String) -> void:
	P.trackId = qid
	ui_refresh.emit()


func assign_bar(skill_id: String, slot: int) -> void:
	if slot < 0 or slot > 5:
		return
	P.barSkills[slot] = skill_id
	ui_refresh.emit()
	save_soon()


func export_save_text() -> String:
	save_now()
	if not FileAccess.file_exists(save_path()):
		return ""
	var f := FileAccess.open(save_path(), FileAccess.READ)
	var raw := f.get_as_text() if f else ""
	if raw == "":
		return ""
	return "----- GLOAMRIFT ARCHIVE -----\nGLOAM1." + Marshalls.utf8_to_base64(raw) + "\n----- END -----"


func slot_meta(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return {"name": str(d.get("name", "?")), "cls": str(d.get("cls", "")), "lvl": int(d.get("lvl", 1))}


func first_empty_slot() -> int:
	for i in 3:
		if not has_save(i):
			return i
	return -1


func parse_save_text(text: String) -> Dictionary:
	text = text.strip_edges()
	if text == "":
		return {}
	var raw := text
	var p := text.find("GLOAM1.")
	if p >= 0:
		var rest := text.substr(p + 7)
		var end := 0
		while end < rest.length():
			var ch := rest.substr(end, 1)
			var ok := (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "+" or ch == "/" or ch == "=" or ch == "-" or ch == "_"
			if not ok:
				break
			end += 1
		var b64 := rest.substr(0, end).replace("-", "+").replace("_", "/")
		while b64.length() % 4 != 0:
			b64 += "="
		raw = Marshalls.base64_to_utf8(b64)
	elif not text.begins_with("{"):
		return {}
	var d = JSON.parse_string(raw)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	if typeof(d.get("slots")) == TYPE_ARRAY:
		for s in d.slots:
			if typeof(s) == TYPE_DICTIONARY and str(s.get("cls", "")) != "":
				return s
		return {}
	if str(d.get("cls", "")) == "" or str(d.get("name", "")).strip_edges() == "":
		return {}
	return d


func import_save_text(text: String, slot: int) -> String:
	var d := parse_save_text(text)
	if d.is_empty():
		return "无法识别这段文字。需要以 GLOAM1. 开头的卷宗，或一份存档 JSON。"
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		return "写不进这个槽。"
	f.store_string(JSON.stringify(d))
	return ""


func shop_mul() -> float:
	return 0.7 if int(P.get("shopDisc", 0)) > 0 else 1.0


func shop_price(n: float) -> int:
	return maxi(1, int(round(n * shop_mul())))


func note_shop_buy() -> void:
	if int(P.get("shopDisc", 0)) > 0:
		P.shopDisc = int(P.shopDisc) - 1
		if int(P.shopDisc) <= 0:
			hint("商队谢礼用尽了")


func pot_price() -> int:
	return 35 + maxi(0, int(P.lvl) - 1) * 9


func is_locked_gear(it: Dictionary) -> bool:
	if it.get("unique"):
		return true
	if it.get("set"):
		return true
	return false


func max_sockets(it: Dictionary) -> int:
	if is_locked_gear(it):
		return 0
	var r := int(it.rarity)
	return 4 if r >= 4 else (3 if r >= 3 else (2 if r >= 2 else 0))


func reforge_cost(it: Dictionary) -> int:
	return int(round((70 + int(it.ilvl) * 22 + int(it.rarity) * 85) * (1.0 + int(it.get("reforged", 0)) * 0.65)))


func nudge_cost(it: Dictionary) -> int:
	return int(round((22 + int(it.ilvl) * 7 + int(it.rarity) * 24) * (1.0 + int(it.get("nudged", 0)) * 0.42)))


func punch_cost(it: Dictionary) -> int:
	return int(round((140 + int(it.ilvl) * 28 + int(it.rarity) * 110) * (1.0 + it.get("sockets", []).size() * 0.8)))


func ensure_gear(it: Dictionary) -> void:
	if not it.has("sockets"):
		it.sockets = []
	if not it.has("reforged"):
		it.reforged = 0


func smith_gear() -> Array:
	var out: Array = []
	for sd in Data.SLOTDEF:
		var it = P.equip.get(sd.k)
		if it:
			ensure_gear(it)
			out.append({"loc": "e" + str(sd.k), "it": it, "where": "已装备 · " + str(sd.n)})
	for i in P.bag.size():
		var it = P.bag[i]
		if it and it.get("type") != "rune" and it.get("type") != "charm" and it.get("type") != "scrap":
			ensure_gear(it)
			out.append({"loc": "b%d" % i, "it": it, "where": "行囊"})
	return out


func gear_at(loc: String) -> Dictionary:
	if loc == "":
		return {}
	if loc.begins_with("b"):
		var i := int(loc.substr(1))
		if i >= 0 and i < P.bag.size():
			return P.bag[i]
		return {}
	return P.equip.get(loc.substr(1), null) if P.equip.get(loc.substr(1)) else {}


func do_reforge(loc: String) -> bool:
	var it := gear_at(loc)
	if it.is_empty() or it.get("type") == "rune" or it.get("type") == "charm":
		return false
	if is_locked_gear(it):
		hint("套装与专属传奇不能重铸")
		return false
	if int(Data.RARITY[int(it.rarity)].af) <= 0:
		hint("普通装备没有词缀可重铸")
		return false
	var cost := reforge_cost(it)
	if P.gold < cost:
		hint("金币不足")
		return false
	P.gold -= cost
	roll_affixes(it)
	it.reforged = int(it.get("reforged", 0)) + 1
	P.stats.reforged = int(P.stats.get("reforged", 0)) + 1
	Sfx.level()
	say("重铸 %s" % it.name)
	refresh_max(false)
	save_soon()
	ach_check()
	ui_refresh.emit()
	return true


func do_nudge(loc: String, idx: int) -> bool:
	var it := gear_at(loc)
	if it.is_empty() or not it.get("affixes") or idx < 0 or idx >= it.affixes.size():
		return false
	if is_locked_gear(it):
		hint("套装与专属传奇不能改")
		return false
	var cost := nudge_cost(it)
	if P.gold < cost:
		hint("金币不足")
		return false
	var used := {}
	for i in it.affixes.size():
		if i != idx:
			used[it.affixes[i].k] = 1
	var neu := roll_one_affix(it, used, it.affixes[idx].get("feel", false) == true)
	if neu.is_empty():
		hint("改不出别的了")
		return false
	P.gold -= cost
	it.affixes[idx] = neu
	it.nudged = int(it.get("nudged", 0)) + 1
	P.stats.nudged = int(P.stats.get("nudged", 0)) + 1
	say("改成了 +%d %s" % [neu.v, neu.n])
	refresh_max(false)
	save_soon()
	ach_check()
	ui_refresh.emit()
	return true


func do_punch(loc: String) -> bool:
	var it := gear_at(loc)
	if it.is_empty() or it.get("type") == "rune":
		return false
	if is_locked_gear(it):
		hint("套装与专属传奇不能开孔")
		return false
	var mx := max_sockets(it)
	if it.get("sockets", []).size() >= mx:
		hint("不能再开孔了")
		return false
	var cost := punch_cost(it)
	if P.gold < cost:
		hint("金币不足")
		return false
	P.gold -= cost
	it.sockets = it.get("sockets", [])
	it.sockets.append(null)
	P.stats.punched = int(P.stats.get("punched", 0)) + 1
	Sfx.ui()
	say("给 %s 开了一孔。" % it.name)
	save_soon()
	ach_check()
	ui_refresh.emit()
	return true


func do_socket_in(loc: String, idx: int, bag_i: int) -> bool:
	var it := gear_at(loc)
	if bag_i < 0 or bag_i >= P.bag.size():
		return false
	var rune: Dictionary = P.bag[bag_i]
	if it.is_empty() or rune.get("type") != "rune":
		return false
	it.sockets = it.get("sockets", [])
	if idx < 0 or idx >= it.sockets.size():
		hint("没有这个孔")
		return false
	if it.sockets[idx]:
		hint("这个孔已经有符文了")
		return false
	it.sockets[idx] = {"id": rune.runeId, "n": rune.name, "k": rune.k, "v": rune.v, "g": rune.get("grade", 1)}
	P.bag.remove_at(bag_i)
	P.stats.socketed = int(P.stats.get("socketed", 0)) + 1
	Sfx.loot()
	say("镶入 %s" % rune.name)
	seal_phrase(it)
	refresh_max(false)
	save_soon()
	ach_check()
	ui_refresh.emit()
	return true


func do_socket_out(loc: String) -> bool:
	var it := gear_at(loc)
	if it.is_empty() or not it.get("sockets"):
		return false
	if it.get("phrase"):
		hint("已经念出来了，拆不开")
		return false
	var filled: Array = []
	for s in it.sockets:
		if s:
			filled.append(s)
	if filled.is_empty():
		return false
	if P.bag.size() + filled.size() > Cfg.BAG:
		hint("行囊装不下取出的碎屑")
		return false
	var neu: Array = []
	for s in it.sockets:
		if not s:
			neu.append(null)
			continue
		P.bag.append(make_rune_item(str(s.id), s.v, int(s.get("g", 1))))
		neu.append(null)
	it.sockets = neu
	Sfx.loot()
	say("碎屑已取出。")
	refresh_max(false)
	save_soon()
	ui_refresh.emit()
	return true


func sell_bag(i: int) -> void:
	if i < 0 or i >= P.bag.size():
		return
	var it: Dictionary = P.bag[i]
	P.gold += sell_price(it)
	P.bag.remove_at(i)
	Sfx.gold()
	save_soon()
	ui_refresh.emit()


func buy_basic(type: String) -> void:
	var it := make_basic_item(type, P.cls, maxi(1, int(P.lvl)))
	var c := shop_price(buy_price(it))
	if P.gold < c:
		hint("金币不足")
		item_seq -= 1
		return
	if not add_to_bag(it):
		item_seq -= 1
		return
	P.gold -= c
	note_shop_buy()
	Sfx.gold()
	say("买下 %s" % it.name)
	save_soon()
	ui_refresh.emit()


func buy_potion(k: String) -> void:
	if k == "note":
		var c := shop_price(60)
		if P.gold < c:
			hint("金币不足")
			return
		P.gold -= c
		P.recallNotes = int(P.get("recallNotes", 0)) + 1
		note_shop_buy()
		Sfx.gold()
		say("买了一张回想的纸条。")
		save_soon()
		ui_refresh.emit()
		return
	var one := pot_price()
	var n := 5 if k.ends_with("5") else 1
	var t := "mp" if k.begins_with("mp") else "hp"
	var cost := shop_price(one * n)
	if P.gold < cost:
		hint("金币不足")
		return
	P.gold -= cost
	note_shop_buy()
	if t == "hp":
		P.potHp += n
	else:
		P.potMp += n
	Sfx.gold()
	save_soon()
	ui_refresh.emit()


func roll_drop(e: Dictionary) -> void:
	var L: int = int(e.lvl)
	var su: bool = str(e.get("su", "")) != ""
	var n: int = e.get("mods", []).size()
	var hoard: bool = e.get("hoard") == true
	var md: Dictionary = Data.MOB_DROP.get(str(e.get("type", "")), {})
	var itemMul: float = float(md.get("itemMul", 1.0))
	var charmMul: float = float(md.get("charmMul", 1.0))
	var fopts: Array = md.get("force", [])
	var fforce: String = ""
	if fopts.size():
		fforce = str(Cfg.pick(fopts))
	var lm: float = maxf(2.2, rift_loot_mul() * 1.8) if hoard else rift_loot_mul()
	if Cfg._rng.randf() < (1.0 if (e.get("boss") or su or hoard) else 0.55):
		var amt := int(round(Cfg.rf(6, 20) * L * (6.0 if hoard else (3.4 if su else (2.2 if e.get("elite") else 1.0))) * (10.0 if e.get("boss") else 1.0) * (1.0 + 0.12 * n) * lm * gold_find_mul()))
		WorldState.drop_gold(e.x + Cfg.rf(-0.5, 0.5), e.z + Cfg.rf(-0.5, 0.5), amt)
	var ch := minf(1.0, (1.0 if (e.get("boss") or su or hoard) else (1.0 if n >= 3 else (0.88 if n >= 2 else (0.75 if e.get("elite") else 0.2)))) * lm * itemMul)
	if Cfg._rng.randf() < ch:
		var it := maybe_set_item(L, e)
		if it.is_empty():
			it = roll_item(L, e.get("boss") or e.get("elite") or su or hoard or n >= 2, "", fforce)
		if not it.get("set") and (su or hoard or (e.get("elite") and n >= 3)) and int(it.rarity) < 3:
			it = maybe_set_item(L, e)
			if it.is_empty():
				it = roll_item(L, true, "", fforce)
			if int(it.rarity) < 3:
				it.rarity = 3
				roll_affixes(it)
				it.name = str(Cfg.pick(Data.PRE)) + str(Data.ETYPES.get(e.type, {}).get("n", it.name)) + str(Cfg.pick(Data.SUF))
		WorldState.drop_item(e.x + Cfg.rf(-0.8, 0.8), e.z + Cfg.rf(-0.8, 0.8), it)
	if e.get("boss"):
		for _i in 2:
			WorldState.drop_item(e.x + Cfg.rf(-1.6, 1.6), e.z + Cfg.rf(-1.6, 1.6), roll_item(L, true, "", fforce))
	if su:
		WorldState.drop_item(e.x + Cfg.rf(-1.2, 1.2), e.z + Cfg.rf(-1.2, 1.2), roll_item(L, true, "", fforce))
	if hoard:
		WorldState.drop_item(e.x + Cfg.rf(-1.2, 1.2), e.z + Cfg.rf(-1.2, 1.2), roll_item(L, true, "", fforce))
		WorldState.drop_item(e.x + Cfg.rf(-1.2, 1.2), e.z + Cfg.rf(-1.2, 1.2), roll_rune(2))
	var mrunes: Array = md.get("runes", [])
	if mrunes.size() and Cfg._rng.randf() < float(md.get("runeCh", 0)):
		var rid: String = str(Cfg.pick(mrunes))
		WorldState.drop_item(e.x + Cfg.rf(-1, 1), e.z + Cfg.rf(-1, 1), make_rune_item(rid, null, 1))
	if Cfg._rng.randf() < (0.12 if e.get("boss") else (0.16 if su else (0.4 if hoard else 0.05))):
		WorldState.drop_item(e.x + Cfg.rf(-1, 1), e.z + Cfg.rf(-1, 1), roll_rune(1))
	if (e.get("elite") or e.get("boss")) and Cfg._rng.randf() < (0.62 if e.get("boss") else (0.48 if su else 0.2 + n * 0.06)):
		WorldState.drop_item(e.x + Cfg.rf(-1, 1), e.z + Cfg.rf(-1, 1), roll_rune(3 if (e.get("boss") or su) and Cfg._rng.randf() < 0.4 else (2 if e.get("boss") or su else -1)))
	if (e.get("elite") or e.get("boss") or su) and Cfg._rng.randf() < (0.4 if e.get("boss") else (0.32 if su else 0.12)):
		WorldState.drop_item(e.x + Cfg.rf(-1, 1), e.z + Cfg.rf(-1, 1), roll_scrap())
	var cch: float = minf(1.0, (0.55 if e.get("boss") else (0.42 if su else (0.5 if hoard else (0.28 if e.get("elite") else 0.14)))) * charmMul)
	if Cfg._rng.randf() < cch:
		WorldState.drop_item(e.x + Cfg.rf(-1, 1), e.z + Cfg.rf(-1, 1), roll_charm(L))
	if Cfg._rng.randf() < (0.38 if (su or hoard) else 0.22):
		WorldState.drop_potion(e.x, e.z, "hp" if Cfg._rng.randf() < 0.65 else "mp")


func add_to_bag(it: Dictionary) -> bool:
	if P.bag.size() >= Cfg.BAG:
		hint("背包满了")
		return false
	P.bag.append(it)
	Sfx.loot()
	return true


func equip_from_bag(i: int) -> void:
	if i < 0 or i >= P.bag.size():
		return
	var it: Dictionary = P.bag[i]
	if it.get("unknown"):
		recall_from_bag(i)
		return
	if it.get("type") == "rune" or it.get("type") == "scrap" or it.get("type") == "charm":
		if it.get("type") == "scrap":
			learn_scrap(it)
			P.bag.remove_at(i)
			ui_refresh.emit()
		elif it.get("type") == "charm":
			if add_to_charms(it):
				P.bag.remove_at(i)
				refresh_max(false)
				say("遗物生效：%s" % it.name)
				ui_refresh.emit()
				save_soon()
			else:
				hint("遗物袋满了")
		return
	var key := str(it.type)
	if key == "ring":
		key = "ring1" if P.equip.ring1 == null else "ring2"
	if not SLOT_KEYS.has(key):
		return
	var old = P.equip[key]
	P.equip[key] = it
	P.bag.remove_at(i)
	if old != null:
		P.bag.append(old)
	refresh_max(false)
	Sfx.loot()
	say("装备 %s" % it.name)
	if key == "weapon":
		WorldState._refresh_player_weapon()
	ui_refresh.emit()
	save_soon()


func drink_hp() -> void:
	if P.potCd > 0 or int(P.potHp) <= 0:
		return
	P.potHp -= 1
	P.potCd = 6.0
	var amt: float = 40.0 + float(P.lvl) * 8.0
	var green := pwr("u_green")
	var son := pwr("u_son")
	if not green.is_empty():
		var tot: float = amt * (1.0 + float(green.get("h", 60)) / 100.0)
		P.up = P.up if typeof(P.up) == TYPE_DICTIONARY else {}
		P.up.potHot = {"t": 6.0, "acc": 0.0, "tick": tot / 12.0}
		float_at(P.x, 2.3, P.z, "青的", Color(0.54, 0.87, 0.35), 16)
	elif not son.is_empty():
		P.shield = maxf(float(P.shield), amt)
		P.shieldT = 8.0
		P.buffs.potsh = {"t": 8.0, "v": float(son.get("d", 12))}
		float_at(P.x, 2.3, P.z, "护盾", Color(0.63, 0.78, 1), 16)
	else:
		heal_player(amt)
	if str(WorldState.W.area.get("kind", "")) == "rift":
		WorldState.W.usedPot = true
	Sfx.potion()
	save_soon()
	ui_refresh.emit()


func drink_mp() -> void:
	if P.potCd > 0 or int(P.potMp) <= 0:
		return
	P.potMp -= 1
	P.potCd = 6.0
	P.mp = minf(P.mpMax, P.mp + 35 + P.lvl * 5)
	if str(WorldState.W.area.get("kind", "")) == "rift":
		WorldState.W.usedPot = true
	Sfx.potion()
	save_soon()
	ui_refresh.emit()


func spend_stat(k: String) -> void:
	if int(P.pts) <= 0:
		return
	if not P.base.has(k):
		return
	P.base[k] += 1
	P.pts -= 1
	refresh_max(false)
	ui_refresh.emit()
	save_soon()


func learn_skill(id: String) -> void:
	var sk := Data.sk_by_id(id)
	if sk.is_empty() or int(P.skPts) <= 0:
		return
	if P.lvl < int(sk.req):
		hint("等级不够")
		return
	if sk.cls != P.cls:
		return
	P.ranks[id] = int(P.ranks.get(id, 0)) + 1
	P.skPts -= 1
	if not P.barSkills.has(id):
		for i in 6:
			if P.barSkills[i] == "":
				P.barSkills[i] = id
				break
	ui_refresh.emit()
	save_soon()


func _qprog(type: String, t: String, need: int) -> int:
	if type == "killtype":
		return mini(int(P.killByType.get(t, 0)), need)
	if type == "elite":
		return mini(int(P.eliteKills), need)
	if type == "dungeon":
		return 1 if P.cleared.get(t, false) else 0
	if type == "rift":
		return mini(int(WorldState.W.get("riftDeepest", 0)), need)
	return 0


func quest_prog(q: Dictionary) -> int:
	return _qprog(str(q.type), str(q.get("t", "")), int(q.need))


## 步骤式任务目标（可选）：任务 dict 含 steps:[{n, type, t, need}] 时返回每步进度。
## 现有单目标任务无 steps 字段，返回空数组，调用方回落到单行显示，零回归。
func quest_steps(q: Dictionary) -> Array:
	if not q.has("steps"):
		return []
	var out: Array = []
	for s in q.steps:
		var sd: Dictionary = s
		var need := int(sd.get("need", 1))
		var cur := _qprog(str(sd.get("type", q.type)), str(sd.get("t", q.get("t", ""))), need)
		out.append({"n": str(sd.get("n", "")), "cur": cur, "need": need, "done": cur >= need})
	return out


func quest_done(q: Dictionary) -> bool:
	return quest_prog(q) >= int(q.need)


func unlock_quests() -> void:
	for q in Data.QUESTS:
		var st: Dictionary = P.quests.get(q.id, {"state": "locked"})
		if st.state == "locked" and str(q.req) != "" and P.quests.get(q.req, {}).get("state") == "done":
			P.quests[q.id] = {"state": "open"}


func turn_in(qid: String) -> void:
	var q: Dictionary
	for x in Data.QUESTS:
		if x.id == qid:
			q = x
			break
	if q.is_empty() or not quest_done(q):
		return
	P.quests[qid] = {"state": "done"}
	P.gold += int(q.gold)
	bump_gold(int(q.gold))
	gain_xp(int(q.xp))
	if q.get("item", false):
		var it := roll_item(maxi(1, P.lvl), true)
		add_to_bag(it)
		note_loot(it)
		say("奖励：%s" % it.name)
	Sfx.quest()
	say("完成委托：%s（+%d 金币，+%d 经验）" % [q.n, int(q.gold), int(q.xp)])
	if qid == "q3" and not P.flags.get("selinForgot"):
		P.flags.selinForgot = true
		P.nameForgotten = true
		say("塞琳：\"塞克拉死了？好。你叫……算了。裂口又偷名字了。\"")
		say("去桥头念一遍。北面林地开了。蜘蛛、弓手，比荒原狠。去清。")
	unlock_quests()
	EventBus.quest_changed.emit()
	ach_check()
	ui_refresh.emit()
	save_soon()


func active_quest() -> Dictionary:
	if P.trackId:
		for q in Data.QUESTS:
			if q.id == P.trackId and P.quests.get(q.id, {}).get("state") == "open":
				return q
	for q in Data.QUESTS:
		if P.quests.get(q.id, {}).get("state") == "open" and not quest_done(q):
			return q
	return {}


func auto_attack(target: Dictionary) -> void:
	var c: Dictionary = Data.CLASSES[P.cls]
	var s := p_stats()
	P.lastSkill = "aa"
	var crit: bool = Cfg._rng.randf() * 100.0 < float(s.crit)
	var dmg := Cfg.rf(s.dmgMin, s.dmgMax) * crit_x(s, crit)
	if c.atk == "melee":
		Sfx.swing()
		deal_to_enemy(target, dmg, crit)
	else:
		WorldState.shoot_player(target, dmg, crit, c.proj)
		if P.cls == "archer":
			Sfx.bow()
		else:
			Sfx.cast()


func cast_skill(i: int) -> void:
	if i < 0 or i >= P.barSkills.size():
		return
	cast_skill_id(str(P.barSkills[i]))


func cast_skill_id(id: String) -> void:
	if not P.alive or WorldState.W.area.get("kind") == "town":
		return
	if story.size() > 0 or cine_boss.size() > 0:
		return
	if id == "":
		return
	var sk := Data.sk_by_id(id)
	if sk.is_empty():
		return
	var r := int(P.ranks.get(id, 1))
	if float(P.cds.get(id, 0)) > 0:
		return
	P.lastSkill = id
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	P.anim.atk = 0.34
	P.anim.atkDone = true
	var s := p_stats()
	var cost := float(sk.mp)
	if P.up.get("freeMp"):
		cost = 0
		P.up.freeMp = false
		P.up.freeUsed = true
	if not pwr("u_rule").is_empty():
		if str(P.up.get("lastSk", "")) != "" and str(P.up.lastSk) != id:
			P.up.ruleN = mini(4, int(P.up.get("ruleN", 0)) + 1)
		elif str(P.up.get("lastSk", "")) == id:
			P.up.ruleN = 0
		cost *= 1.0 - 0.25 * float(P.up.get("ruleN", 0))
		P.up.lastSk = id
	elif not pwr("u_custom").is_empty():
		if str(P.up.get("lastSk", "")) == id:
			P.up.sameSk = mini(6, int(P.up.get("sameSk", 1)) + 1)
		else:
			P.up.sameSk = 1
		P.up.lastSk = id
		cost *= 1.0 - 0.08 * maxf(0.0, float(P.up.get("sameSk", 1)) - 1.0)
	cost = maxf(0.0, round(cost))
	if P.mp < cost:
		hint("法力不足")
		return
	P.mp -= cost
	var cdr := 1.0 - float(s.get("cdr", 0)) / 100.0
	var cd: float = float(sk.cd)
	var ham := pwr("u_hammer")
	if not ham.is_empty() and (id == "charge" or id == "blink" or id == "roll"):
		cd *= 1.0 - float(ham.get("dash", 25)) / 100.0
	if id == "charge" and float(P.up.get("chargeEcho", 0)) > 0:
		cd = 0.12
		P.up.chargeEcho = 0
	if id == "blink" and float(P.up.get("blinkEcho", 0)) > 0:
		cd = 0.12
		P.up.blinkEcho = 0
	P.cds[id] = maxf(0.35, cd * cdr * rift_cd_mul())
	var boom: bool = P.up.get("voiceBoom") == true
	var pct := (float(sk.get("pct", 100)) + float(sk.get("grow", 0)) * r) / 100.0
	var dmg := sk_dmg(s, Cfg.rf(s.dmgMin, s.dmgMax) * pct, id)
	var kind: String = sk.get("kind", "aoe")
	var aim := last_cursor
	var adx: float = aim.x - float(P.x)
	var adz: float = aim.z - float(P.z)
	if Cfg.hypot(adx, adz) > 0.15:
		P.dir = atan2(adx, adz)
	match kind:
		"aoe":
			if id == "nova":
				_cast_nova(dmg, float(sk.get("slow", 4)))
			elif id == "quake" and sk_rune("quake") == "fissure":
				WorldState.line_aoe(aim, 9.5, 1.35, dmg, sk.elem, float(sk.get("stun", 0)))
			elif id == "cleave" and sk_rune("cleave") == "sweep":
				WorldState.cone_player(float(P.dir), skill_rad(float(sk.get("rad", 4))) * 1.2, 1.05, dmg, sk.elem)
			else:
				var rad := skill_rad(float(sk.get("rad", 4)))
				var hits := WorldState.aoe_player(P.x, P.z, rad, dmg, sk.elem, float(sk.get("stun", 0)), float(sk.get("slow", 0)))
				if sk.get("knock", false) and sk_rune("cleave") != "shock":
					WorldState.knock_around(P.x, P.z, rad, 2.4)
				if id == "cleave" and sk_rune("cleave") == "shock" and hits > 0:
					P.cds[id] = maxf(0.35, float(P.cds[id]) - 0.4 * float(hits))
				if id == "quake" and sk_rune("quake") == "aftershock":
					P.up.aftershock = {"t": 1.5, "x": P.x, "z": P.z, "dmg": dmg * 0.5, "rad": rad, "stun": float(sk.get("stun", 0))}
			Sfx.boom()
		"dash":
			var hit := WorldState.dash_player(aim, dmg, sk_rune("charge") == "slam")
			if hit and sk_rune("charge") == "breach":
				P.up.chargeEcho = maxf(float(P.up.get("chargeEcho", 0)), 2.0)
			Sfx.swing()
		"channel":
			var wrad := skill_rad(float(sk.rad))
			var walk: bool = set_on("watch", 4)
			if sk_rune("whirl") == "anchor":
				walk = false
				wrad *= 1.35
			P.channel = {"id": id, "t": 2.0, "acc": 0.0, "rad": wrad, "dmg": pct, "walk": walk, "pull": sk_rune("whirl") == "blade"}
			Sfx.swing()
		"buff":
			if tal_rank("wf6") and id == "shout":
				heal_player(P.hpMax * 0.25)
			elif sk_rune("shout") == "taunt":
				WorldState.pull_around(P.x, P.z, 8.0, 2.8)
				WorldState.aoe_player(P.x, P.z, 8.0, 0.0, "phys", 0.0, 2.4)
			else:
				P.buffs.dmg = {"t": 12.0, "v": 20 + 8 * r}
			if sk_rune("shout") == "echo":
				P.buffs.shoutEcho = {"t": 12.0, "acc": 0.0}
			Sfx.cast()
		"shield":
			if sk_rune("fortify") == "wall":
				var fx := sin(float(P.dir)) * 2.2
				var fz := cos(float(P.dir)) * 2.2
				spawn_stone_wall(float(P.x) + fx, float(P.z) + fz)
			else:
				P.shield = 90 + 55 * r
				P.shieldT = 14.0
				P.buffs.shield = {"t": 14.0}
				P.up.shieldMax = P.shield
			Sfx.cast()
		"bolt", "poison":
			if id == "fire":
				_cast_fire(aim, dmg)
			else:
				var pop := {"poison": kind == "poison", "dot": 40 + 14 * r if kind == "poison" else 0.0}
				if sk_rune("poison") == "cloud":
					pop.cloud = true
				if sk_rune("poison") == "vine":
					pop.vine = true
					pop.spd = 11.0
				WorldState.shoot_dir(aim.x - float(P.x), aim.z - float(P.z), dmg, sk.elem, pop)
			Sfx.cast()
		"blink":
			WorldState.blink_player(aim, dmg)
			Sfx.cast()
		"missiles":
			var n := 2 + int(r / 2) + (2 if set_on("silk", 4) else 0)
			var mopt := {}
			if sk_rune("arcane") == "burst":
				n = maxi(1, int(ceil(float(n) / 2.0)))
				mopt.splash = 2.2
			if sk_rune("arcane") == "seek":
				mopt.pierce = true
				mopt.spd = 12.0
			WorldState.missiles(n, dmg, sk.elem, mopt)
			Sfx.cast()
		"drain":
			var hn := 2 if sk_rune("drain") == "link" else 1
			var hr := 0.3 if sk_rune("drain") == "link" else 0.6
			if sk_rune("drain") == "siphon":
				hr = 0.0
			var got: Array = WorldState.drain_nearest(dmg, hr, hn)
			if sk_rune("drain") == "siphon":
				for t in got:
					WorldState.add_zone(float(t.x), float(t.z), 2.4, 3.0, 0.0, "enemy", {"slow": 2.5, "tick": 0.3, "elem": "shadow"})
			Sfx.cast()
		"cursor_aoe":
			var mrad := skill_rad(float(sk.get("rad", 5)))
			if sk_rune("meteor") == "core":
				mrad *= 0.55
				WorldState.aoe_player(aim.x, aim.z, mrad, dmg, sk.elem, 1.2)
			elif sk_rune("meteor") == "shower":
				for off in [Vector2(0, 0), Vector2(1.8, 0.9), Vector2(-1.6, 1.1)]:
					WorldState.aoe_player(aim.x + off.x, aim.z + off.y, mrad * 0.7, dmg / 3.0, sk.elem)
			else:
				WorldState.aoe_player(aim.x, aim.z, mrad, dmg, sk.elem)
			Sfx.boom()
		"rain":
			var rrad := skill_rad(float(sk.get("rad", 4.6)))
			var rdur := float(sk.get("dur", 2))
			if sk_rune("arrowrain") == "hail":
				rrad *= 0.65
				rdur *= 1.8
			if sk_rune("arrowrain") == "volley":
				for _v in 3:
					WorldState.aoe_player(aim.x, aim.z, rrad, dmg / 3.0, sk.elem)
			else:
				WorldState.add_zone(aim.x, aim.z, rrad, rdur, dmg / 7.0, "enemy", {"rain": true, "tick": 0.28, "elem": "phys"})
			Sfx.bow()
		"fan":
			var fn := 4 + r + (2 if set_on("fleet", 2) else 0)
			var fmul := 1.0
			var spread := 0.18
			var fpierce := false
			if sk_rune("multishot") == "focus":
				fn = maxi(2, int(ceil(float(fn) / 2.0)))
				fmul = 2.0
				spread = 0.08
			if sk_rune("multishot") == "through":
				fpierce = true
				spread = 0.24
			WorldState.fan_shots(fn, dmg * fmul, spread, fpierce)
			Sfx.bow()
		"line":
			WorldState.line_shot(aim, dmg, tal_rank("ap6") > 0, sk_rune("pierce") == "wide", sk_rune("pierce") == "ricochet")
			Sfx.bow()
		"roll":
			WorldState.roll_player(aim, 0.5 + 0.06 * r)
			if sk_rune("roll") == "stab":
				WorldState.aoe_player(P.x, P.z, 2.2, dmg * 0.55, "phys")
			if tal_rank("ag6"):
				P.buffs.shadow = {"t": 1.5, "v": 50}
			if set_on("dusk", 2):
				P.buffs.setas = {"t": 2.0, "v": 30}
			if not pwr("u_erl").is_empty():
				var base := atan2(aim.x - float(P.x), aim.z - float(P.z))
				var ad := sk_dmg(s, Cfg.rf(s.dmgMin, s.dmgMax) * 0.55, id)
				for k in 3:
					var a: float = base + (k - 1) * 0.22
					WorldState.shoot_dir(sin(a), cos(a), ad, "phys", {"life": 1.6, "spd": 30.0})
			Sfx.swing()
		"hawk":
			if sk_rune("hawkeye") == "mark":
				var t = P.target if P.target != null else WorldState.nearest_enemy(14)
				if typeof(t) == TYPE_DICTIONARY and not t.is_empty():
					P.buffs.hawkmark = {"t": 12.0, "id": t.id}
					float_at(float(t.x), 2.8, float(t.z), "标记", Color(1, 0.82, 0.34), 16)
			elif sk_rune("hawkeye") == "keen":
				P.buffs.keen = {"t": 12.0}
			else:
				P.buffs.crit = {"t": 12.0, "v": 10 + 4 * r}
				P.buffs.as = {"t": 12.0, "v": 15 + 5 * r}
			Sfx.cast()
	if boom:
		P.up.voiceBoom = false
	ui_refresh.emit()


func _cast_fire(aim: Vector3, dmg: float) -> void:
	var pierce := tal_rank("mfl6") > 0
	if pierce:
		dmg *= 0.8
	var rune := sk_rune("fire")
	var opt := {"pierce": pierce, "life": 1.4 if pierce else 2.6, "spd": 10.0 if rune == "linger" else 20.0, "linger": rune == "linger"}
	var dx: float = aim.x - float(P.x)
	var dz: float = aim.z - float(P.z)
	if rune == "split":
		var a0 := atan2(dx, dz)
		for off in [-0.32, 0.0, 0.32]:
			var a: float = a0 + off
			WorldState.shoot_dir(sin(a), cos(a), dmg / 3.0, "fire", opt)
	elif not pwr("u_pitch").is_empty():
		var a0 := atan2(dx, dz)
		for off in [-0.28, 0.0, 0.28]:
			var a: float = a0 + off
			WorldState.shoot_dir(sin(a), cos(a), dmg, "fire", opt)
	else:
		WorldState.shoot_dir(dx, dz, dmg, "fire", opt)


func _cast_nova(dmg: float, slow_t: float) -> void:
	if sk_rune("nova") == "shard":
		for i in 8:
			var a: float = TAU * float(i) / 8.0
			WorldState.shoot_dir(sin(a), cos(a), dmg * 0.45, "ice", {"spd": 16.0, "life": 1.1, "stun": 0.0})
		return
	var nrad := skill_rad(6.2)
	if tal_rank("mfr6"):
		nrad *= 0.8
	if sk_rune("nova") == "winter":
		nrad *= 0.7
	for e in WorldState.W.enemies:
		if e.get("dead") or e.get("ally"):
			continue
		if Cfg.dist2(float(e.x), float(e.z), float(P.x), float(P.z)) > nrad * nrad:
			continue
		var was_slow: bool = float(e.get("slow", 0)) > 0 or float(e.get("frozen", 0)) > 0
		var nd: float = dmg
		if sk_rune("nova") == "winter" and was_slow:
			nd *= 1.8
		deal_to_enemy(e, nd, false, Color(0.66, 0.88, 1), false, true, "ice")
		e.slow = maxf(float(e.slow), slow_t)
		if was_slow:
			e.frozen = maxf(float(e.frozen), 2.0)
		elif tal_rank("mfr6") and Cfg._rng.randf() < 0.25:
			e.frozen = maxf(float(e.frozen), 1.6)


func on_dash_land(tx: float, tz: float) -> void:
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	P.up.dashGrace = 3.0
	var down := pwr("u_down")
	if not down.is_empty():
		var s := p_stats()
		var mul: float = float(down.get("d", 200)) / 100.0
		for e in WorldState.W.enemies:
			if e.get("dead"):
				continue
			if Cfg.dist2(float(e.x), float(e.z), tx, tz) < 36.0:
				deal_to_enemy(e, Cfg.rf(s.dmgMin, s.dmgMax) * mul, false, Color(0.78, 0.63, 0.38))
		P.buffs.downdr = {"t": 3.0, "v": 30}
	if not pwr("u_hammer").is_empty():
		P.up.chargeEcho = maxf(float(P.up.get("chargeEcho", 0)), 1.5)


func player_locked() -> bool:
	return float(P.stun) > 0 or float(P.frozen) > 0 or story.size() > 0 or cine_boss.size() > 0


func tick_player(dt: float) -> void:
	if not P.alive:
		return
	update_unique(dt)
	if not P.alive:
		return
	var s := p_stats()
	P.potCd = maxf(0, P.potCd - dt)
	P.atkCd = maxf(0, P.atkCd - dt)
	P.invuln = maxf(0, P.invuln - dt)
	P.stun = maxf(0, P.stun - dt)
	P.chill = maxf(0, P.chill - dt)
	P.frozen = maxf(0, P.frozen - dt)
	P.stats.godownCd = maxf(0, float(P.stats.get("godownCd", 0)) - dt)
	if typeof(P.up) != TYPE_DICTIONARY:
		P.up = {}
	for k in P.cds.keys():
		P.cds[k] = maxf(0, float(P.cds[k]) - dt)
	var dead_buffs: Array = []
	for k in P.buffs:
		P.buffs[k].t = float(P.buffs[k].t) - dt
		if P.buffs[k].t <= 0:
			dead_buffs.append(k)
	for k in dead_buffs:
		P.buffs.erase(k)
	if P.shield > 0:
		P.shieldT -= dt
		if P.shieldT <= 0:
			P.shield = 0
			P.buffs.erase("shield")
	var in_town: bool = str(WorldState.W.area.get("kind", "")) == "town"
	var gx := Cfg.tx(P.x)
	var gz := Cfg.tz(P.z)
	var tp := WorldState.paint_at(gx, gz)
	if WorldState.W.area.get("hz") == "ice" and tp == 5:
		WorldState.W.hzAcc = float(WorldState.W.get("hzAcc", 0)) + dt
		if WorldState.W.hzAcc > 0.45:
			WorldState.W.hzAcc = 0
			P.hp = maxf(1, P.hp - 5)
			float_at(P.x, 2.2, P.z, "薄冰", Color(0.62, 0.83, 1), 12)
	else:
		WorldState.W.hzAcc = 0
	var cap: float = float(P.hpMax)
	if not pwr("u_law").is_empty() or phrase_on("notyou"):
		cap = float(P.hpMax) * 0.8
	P.hp = clampf(P.hp + dt * (0.6 + P.lvl * 0.14) * (8.0 if in_town else 1.0), 0, cap)
	P.mp = clampf(P.mp + dt * (1.4 + s.ene * 0.09) * (8.0 if in_town else 1.0), 0, P.mpMax)
	if P.casting == "town":
		P.castT += dt
		if P.castT >= 2.5:
			P.casting = ""
			WorldState.W.arrive_mode = "well"
			WorldState.enter_area(hub_id(), "well")
			return
	if P.casting == "well":
		P.castT += dt
		if P.castT >= 2.2:
			P.casting = ""
			WorldState.close_rift_well()
			return
	if P.channel:
		P.channel.t -= dt
		P.channel.acc += dt
		if P.channel.acc >= 0.35:
			P.channel.acc = 0
			WorldState.aoe_player(P.x, P.z, float(P.channel.rad), sk_dmg(s, Cfg.rf(s.dmgMin, s.dmgMax) * float(P.channel.dmg), "whirl"), "phys")
			if P.channel.get("pull"):
				WorldState.pull_around(P.x, P.z, float(P.channel.rad), 1.1)
		if P.channel.t <= 0:
			P.channel = null
	var ashot = P.up.get("aftershock")
	if typeof(ashot) == TYPE_DICTIONARY:
		ashot.t = float(ashot.t) - dt
		if float(ashot.t) <= 0:
			WorldState.aoe_player(float(ashot.x), float(ashot.z), float(ashot.rad), float(ashot.dmg), "phys", float(ashot.get("stun", 0)))
			P.up.aftershock = null
	if P.buffs.has("shoutEcho"):
		P.buffs.shoutEcho.acc = float(P.buffs.shoutEcho.get("acc", 0)) + dt
		if float(P.buffs.shoutEcho.acc) >= 4.0:
			P.buffs.shoutEcho.acc = 0
			WorldState.aoe_player(P.x, P.z, 5.0, 0.0, "phys", 0.0, 1.6)
	if P.target != null and P.target.get("dead", false):
		P.target = null
	var locked := player_locked()
	if locked:
		P.path = []
		P.channel = null
	if P.holdStand:
		P.path = []
	var cls: Dictionary = Data.CLASSES[P.cls]
	if P.target != null and P.channel == null and not locked:
		var d := sqrt(Cfg.dist2(P.target.x, P.target.z, P.x, P.z))
		if d > cls.range:
			if not P.holdStand:
				WorldState.walk_to(P.target.x, P.target.z)
		else:
			P.path = []
			P.dir = atan2(P.target.x - P.x, P.target.z - P.z)
			var left_sk := mouse_skill(0)
			if left_sk != "":
				try_cast_id(left_sk)
			elif P.atkCd <= 0:
				P.atkCd = s.atkTime
				P.anim.atk = 0.30
				P.anim.atkDone = false
	if float(P.anim.atk) > 0:
		P.anim.atk -= dt
		if not P.anim.atkDone and P.anim.atk < 0.16:
			P.anim.atkDone = true
			if not locked and P.target != null and not P.target.get("dead", false):
				if Cfg.dist2(P.target.x, P.target.z, P.x, P.z) < pow(cls.range + 0.6, 2):
					auto_attack(P.target)
	if P.path.size() and (P.channel == null or P.channel.get("walk", false)) and not locked and not P.holdStand:
		var n: Dictionary = P.path[0]
		var dx: float = n.x - P.x
		var dz: float = n.z - P.z
		var dd: float = Cfg.hypot(dx, dz)
		if dd < 0.28:
			P.path.remove_at(0)
		else:
			var sp: float = float(s.speed) * dt * (0.64 if tp == 5 else 1.0) * (0.55 if float(P.chill) > 0.0 else 1.0)
			WorldState.move_entity(P, P.x + dx / dd * sp, P.z + dz / dd * sp)
			P.dir = atan2(dx, dz)
			P.anim.walk += dt * 10
	else:
		P.anim.walk = lerpf(P.anim.walk, 0, dt * 8)
	if P.npcTarget != "":
		var npc := WorldState.npc_by_id(P.npcTarget)
		if not npc.is_empty() and Cfg.dist2(npc.x, npc.z, P.x, P.z) < 3.4 * 3.4:
			npc_open.emit(P.npcTarget)
			P.npcTarget = ""
			P.path = []
	WorldState.try_pickups()
	WorldState.try_marks()
	flush_skill_queue()


func maybe_intro_cine() -> void:
	P.flags = P.flags if typeof(P.flags) == TYPE_DICTIONARY else {}
	if P.flags.get("seenIntro", false):
		return
	P.flags.seenIntro = 1
	play_story("intro", {"k": "石桥镇", "n": "裂口上面", "d": "镇子建在一道裂口上。桥头把名字刻上了木牌。裂口爱偷这个。去广场北面找塞琳领活。"})


func maybe_door_cine(id: String) -> void:
	if booting or Data.dun_by_id(id).is_empty():
		return
	P.flags = P.flags if typeof(P.flags) == TYPE_DICTIONARY else {}
	var seen: Dictionary = P.flags.get("seenDoor", {})
	if seen.get(id, false):
		return
	seen[id] = 1
	P.flags.seenDoor = seen
	var d := Data.dun_by_id(id)
	play_story("door", {"k": "进门" if diff_id() == "normal" else diff_now().n, "n": d.n, "d": Data.DOOR_LINE.get(id, d.desc)})


func maybe_chapter_cine(dun_id: String) -> void:
	ensure_diff()
	var key: Dictionary = {}
	for c in Data.CH_KEYS:
		if c.dun == dun_id:
			key = c
			break
	if not key.is_empty():
		var flag := "chcine_%s_%d" % [diff_id(), int(key.ch)]
		if P.flags.get(flag, false):
			return
		P.flags[flag] = 1
		if int(key.ch) == 5:
			play_story("ending", Data.END_CINE[diff_id()])
		else:
			play_story("chboss", {"k": key.k, "n": key.title, "d": key.d})
		save_soon()
		return
	var d := Data.dun_by_id(dun_id)
	if d.is_empty():
		return
	var flag2 := "duncine_%s_%s" % [diff_id(), dun_id]
	if P.flags.get(flag2, false):
		return
	P.flags[flag2] = 1
	play_story("chboss", {"k": "通关", "n": d.n, "d": d.desc})


func play_story(kind: String, meta: Dictionary) -> void:
	story = {"kind": kind, "t": 0.0, "dur": 10.0 if kind == "ending" else (7.0 if kind == "chboss" else 5.2), "meta": meta}
	Sfx.level()
	cine.emit(kind, meta)


func end_story() -> void:
	story = {}
	cine.emit("", {})


func start_boss_intro(e: Dictionary) -> void:
	if e.is_empty() or e.get("dead") or e.get("seenIntro") or story.size() > 0:
		return
	e.seenIntro = true
	cine_boss = {"e": e, "t": 0.0, "dur": 3.2}
	cine.emit("boss", {"n": e.name, "d": "靠近了。"})


func go_place(kind: String, id: String, diff: String = "", arrive: String = "") -> void:
	if diff != "" and not set_diff(diff):
		hint("这个难度还没开")
		return
	WorldState.W.diff = diff_id()
	WorldState.W.arrive_from = str(WorldState.W.area.get("id", ""))
	if arrive != "":
		WorldState.W.arrive_mode = arrive
	elif kind == "area" and Data.AREA.get(id, {}).get("kind") == "town":
		WorldState.W.arrive_mode = "gate"
	if kind == "area":
		WorldState.enter_area(id)
	elif kind == "dungeon":
		WorldState.enter_dungeon(id, 1)
		maybe_door_cine(id)


var _save_t := 0.0
func save_soon() -> void:
	_save_t = 1.2


func stash_path() -> String:
	return "user://gloam_stash.json"


func stash_items() -> Array:
	if not FileAccess.file_exists(stash_path()):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(stash_path()))
	if typeof(d) != TYPE_ARRAY:
		return []
	return d


func write_stash(arr: Array) -> void:
	if arr.size() > Cfg.STASH:
		arr = arr.slice(0, Cfg.STASH)
	var f := FileAccess.open(stash_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(arr))
	save_soon()


func stash_put(bag_i: int) -> bool:
	if bag_i < 0 or bag_i >= P.bag.size():
		return false
	var st := stash_items()
	if st.size() >= Cfg.STASH:
		hint("银行已满")
		return false
	st.append(P.bag[bag_i])
	P.bag.remove_at(bag_i)
	write_stash(st)
	Sfx.loot()
	ui_refresh.emit()
	return true


func stash_take(i: int) -> bool:
	var st := stash_items()
	if i < 0 or i >= st.size():
		return false
	var it: Dictionary = st[i]
	if not add_to_bag(it):
		hint("行囊已满")
		return false
	st.remove_at(i)
	write_stash(st)
	ui_refresh.emit()
	return true


func ensure_bounties() -> void:
	var day := Cfg.today_key()
	if str(P.get("bountyDay", "")) == day and typeof(P.get("bountyList")) == TYPE_ARRAY and P.bountyList.size():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = (Cfg.hash_str(day) ^ 0xb0a7d00d) & 0xFFFFFFFF
	var pool: Array = []
	for src in LootData.BOUNTY_POOL:
		pool.append(src.duplicate(true))
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var picked: Array = []
	var dun_map = P.get("bountyDun", {})
	if typeof(dun_map) != TYPE_DICTIONARY:
		dun_map = {}
	for i in mini(5, pool.size()):
		var b: Dictionary = pool[i]
		if str(b.type) == "rift":
			b.need = maxi(2, int(WorldState.W.get("riftDeepest", 1)) + rng.randi_range(1, 2))
			b.d = "到达裂隙第 %s 层。" % Cfg.roman(int(b.need))
		b.snap = {
			"kills": int(P.killByType.get(str(b.get("t", "")), 0)),
			"elite": int(P.eliteKills),
			"rift": int(WorldState.W.get("riftDeepest", 1)),
			"dun": int(dun_map.get(str(b.get("t", "")), 0)),
			"potless": int(P.get("bountyPotless", 0))
		}
		picked.append(b)
	P.bountyDay = day
	P.bountyList = picked
	P.bountyClaimed = {}
	P.bountyChest = false


func bounty_prog(b: Dictionary) -> int:
	var s: Dictionary = b.get("snap", {})
	if typeof(s) != TYPE_DICTIONARY:
		s = {}
	var typ := str(b.get("type", ""))
	if typ == "killtype":
		return mini(int(b.need), maxi(0, int(P.killByType.get(str(b.get("t", "")), 0)) - int(s.get("kills", 0))))
	if typ == "elite":
		return mini(int(b.need), maxi(0, int(P.eliteKills) - int(s.get("elite", 0))))
	if typ == "dungeon":
		var dun_map = P.get("bountyDun", {})
		if typeof(dun_map) != TYPE_DICTIONARY:
			dun_map = {}
		return mini(int(b.need), maxi(0, int(dun_map.get(str(b.get("t", "")), 0)) - int(s.get("dun", 0))))
	if typ == "rift":
		return 1 if int(WorldState.W.get("riftDeepest", 1)) >= int(b.need) else 0
	if typ == "potless":
		return mini(int(b.need), maxi(0, int(P.get("bountyPotless", 0)) - int(s.get("potless", 0))))
	return 0


func bounty_need(b: Dictionary) -> int:
	return 1 if str(b.get("type", "")) == "rift" else int(b.need)


func bounty_done(b: Dictionary) -> bool:
	return bounty_prog(b) >= bounty_need(b)


func claimed_count() -> int:
	ensure_bounties()
	var n := 0
	var claimed = P.get("bountyClaimed", {})
	if typeof(claimed) != TYPE_DICTIONARY:
		return 0
	for b in P.bountyList:
		if claimed.get(str(b.id)):
			n += 1
	return n


func claim_bounty(id: String) -> void:
	ensure_bounties()
	if typeof(P.bountyClaimed) != TYPE_DICTIONARY:
		P.bountyClaimed = {}
	for b in P.bountyList:
		if str(b.id) != id:
			continue
		if not bounty_done(b) or P.bountyClaimed.get(id):
			return
		P.bountyClaimed[id] = true
		P.gold += int(b.gold)
		bump_gold(int(b.gold))
		gain_xp(int(b.xp))
		P.stats.bounties = int(P.stats.get("bounties", 0)) + 1
		Sfx.quest()
		say("悬赏完成：%s" % b.n)
		save_soon()
		ach_check()
		ui_refresh.emit()
		return


func claim_bounty_chest() -> void:
	ensure_bounties()
	if claimed_count() < 3 or P.get("bountyChest"):
		return
	P.bountyChest = true
	var it := {}
	if Cfg._rng.randf() < 0.4:
		it = roll_set_item(maxi(4, int(P.lvl) + 2))
	if it.is_empty():
		it = roll_item(maxi(4, int(P.lvl) + 2), true)
	var g: int = 220 + int(P.lvl) * 18
	P.gold += g
	bump_gold(g)
	note_loot(it)
	if add_to_bag(it):
		say("日俸：%s 与金币。" % it.name)
	else:
		var st := stash_items()
		if st.size() < Cfg.STASH:
			st.append(it)
			write_stash(st)
			say("行囊已满，日俸 %s 放进了银行。" % it.name)
		else:
			P.gold += sell_price(it)
			say("箱子和行囊都满了，东西折成了金币。")
	Sfx.level()
	save_soon()
	ach_check()
	ui_refresh.emit()


func _process(dt: float) -> void:
	if story.size() > 0:
		story.t += dt
		if story.t >= story.dur:
			end_story()
	if cine_boss.size() > 0:
		cine_boss.t += dt
		if cine_boss.t >= cine_boss.dur:
			cine_boss = {}
			cine.emit("", {})
	if _save_t > 0:
		_save_t -= dt
		if _save_t <= 0:
			save_now()


func save_path(slot: int = -1) -> String:
	if slot < 0:
		slot = save_slot
	return "user://gloam_slot_%d.json" % slot


func save_now() -> void:
	var data := {
		"name": P.name, "cls": P.cls, "lvl": P.lvl, "xp": P.xp, "xpNext": P.xpNext,
		"gold": P.gold, "pts": P.pts, "skPts": P.skPts, "base": P.base,
		"hp": P.hp, "mp": P.mp, "equip": P.equip, "bag": P.bag,
		"potHp": P.potHp, "potMp": P.potMp, "ranks": P.ranks, "barSkills": P.barSkills,
		"mouseSkills": P.get("mouseSkills", ["", ""]),
		"kills": P.kills, "eliteKills": P.eliteKills, "bossKills": P.bossKills,
		"killByType": P.killByType, "cleared": P.cleared, "hub": P.hub,
		"trackId": P.trackId, "talents": P.talents, "flags": P.flags,
		"diff": diff_id(), "diffMax": diff_max_id(), "clearedDiff": P.clearedDiff,
		"nameLost": P.nameLost, "nameForgotten": P.nameForgotten,
		"quests": P.quests, "discovered": WorldState.W.discovered,
		"riftDeepest": WorldState.W.get("riftDeepest", 0),
		"charms": P.get("charms", []), "relics": P.get("relics", []), "codex": P.get("codex", []),
		"tokens": P.get("tokens", {}), "luck": P.get("luck", {}),
		"shopDisc": int(P.get("shopDisc", 0)), "recallNotes": int(P.get("recallNotes", 0)),
		"suKills": int(P.get("suKills", 0)), "knownPhrases": P.get("knownPhrases", {}),
		"bountyDay": str(P.get("bountyDay", "")), "bountyList": P.get("bountyList", []),
		"bountyClaimed": P.get("bountyClaimed", {}), "bountyChest": P.get("bountyChest", false),
		"bountyPotless": int(P.get("bountyPotless", 0)), "bountyDun": P.get("bountyDun", {}),
		"itemSeq": item_seq, "skRunes": P.get("skRunes", {}),
		"ach": P.get("ach", {}), "stats": P.get("stats", {}),
		"enough": float(P.get("enough", 0)), "v": 1
	}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists("user://gloam_slot_%d.json" % slot)


func load_slot(slot: int) -> bool:
	save_slot = slot
	var p := save_path(slot)
	if not FileAccess.file_exists(p):
		return false
	var raw := FileAccess.get_file_as_string(p)
	var d = JSON.parse_string(raw)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	reset_blank()
	for k in ["name", "cls", "lvl", "xp", "xpNext", "gold", "pts", "skPts", "hp", "mp",
			"potHp", "potMp", "kills", "eliteKills", "bossKills", "hub", "trackId",
			"nameLost", "nameForgotten"]:
		if d.has(k):
			P[k] = d[k]
	if typeof(d.get("base")) == TYPE_DICTIONARY:
		P.base = d.base
	if typeof(d.get("equip")) == TYPE_DICTIONARY:
		P.equip = d.equip
	if typeof(d.get("bag")) == TYPE_ARRAY:
		P.bag = d.bag
	if typeof(d.get("ranks")) == TYPE_DICTIONARY:
		P.ranks = d.ranks
	if typeof(d.get("barSkills")) == TYPE_ARRAY:
		P.barSkills = d.barSkills
	if typeof(d.get("mouseSkills")) == TYPE_ARRAY and d.mouseSkills.size() >= 2:
		P.mouseSkills = [str(d.mouseSkills[0]), str(d.mouseSkills[1])]
	elif typeof(P.barSkills) == TYPE_ARRAY and P.barSkills.size() and str(P.barSkills[0]) != "":
		P.mouseSkills = ["", str(P.barSkills[0])]
	if typeof(d.get("killByType")) == TYPE_DICTIONARY:
		P.killByType = d.killByType
	if typeof(d.get("cleared")) == TYPE_DICTIONARY:
		P.cleared = d.cleared
	if typeof(d.get("talents")) == TYPE_DICTIONARY:
		P.talents = d.talents
	if typeof(d.get("flags")) == TYPE_DICTIONARY:
		P.flags = d.flags
	if typeof(d.get("quests")) == TYPE_DICTIONARY:
		P.quests = d.quests
	for k in ["charms", "relics", "codex", "bountyList"]:
		if typeof(d.get(k)) == TYPE_ARRAY:
			P[k] = d[k]
	for k in ["tokens", "luck", "knownPhrases", "bountyClaimed", "bountyDun", "skRunes", "ach"]:
		if typeof(d.get(k)) == TYPE_DICTIONARY:
			P[k] = d[k]
	if typeof(d.get("stats")) == TYPE_DICTIONARY:
		ensure_ach()
		for sk in d.stats.keys():
			P.stats[sk] = d.stats[sk]
	if d.has("shopDisc"):
		P.shopDisc = int(d.shopDisc)
	if d.has("recallNotes"):
		P.recallNotes = int(d.recallNotes)
	if d.has("enough"):
		P.enough = float(d.enough)
	if d.has("suKills"):
		P.suKills = int(d.suKills)
	if d.has("bountyDay"):
		P.bountyDay = str(d.bountyDay)
	P.bountyChest = d.get("bountyChest", false) == true
	if d.has("bountyPotless"):
		P.bountyPotless = int(d.bountyPotless)
	if d.has("itemSeq"):
		item_seq = maxi(item_seq, int(d.itemSeq))
	P.diff = d.diff if Data.DIFF.has(d.get("diff", "")) else "normal"
	P.diffMax = d.diffMax if Data.DIFF.has(d.get("diffMax", "")) else "normal"
	if typeof(d.get("clearedDiff")) == TYPE_DICTIONARY:
		P.clearedDiff = d.clearedDiff
	ensure_diff()
	if typeof(d.get("discovered")) == TYPE_DICTIONARY:
		WorldState.W.discovered = d.discovered
	WorldState.W.riftDeepest = int(d.get("riftDeepest", 0))
	ensure_ach()
	refresh_max(false)
	P.alive = true
	if P.hp <= 0:
		P.hp = P.hpMax
		P.mp = P.mpMax
	pending_enter = hub_id()
	pending_intro = false
	WorldState.W.arrive_mode = "well"
	ach_check(true)
	return true
