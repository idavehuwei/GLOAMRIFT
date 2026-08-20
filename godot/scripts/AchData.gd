extends Node
## 网页版 ACH[] / ensureAch / achCheck / unlockAch。

signal toast_show(a: Dictionary)
signal toast_hide

const LIST: Array = [
	{id="kill1", cat="杀戮", n="第一滴血", d="砍死第一只从裂口爬出来的东西。", need=1, gold=20, prog="kills"},
	{id="kill100", cat="杀戮", n="百人斩", d="击杀 100 只怪物。", need=100, gold=80, prog="kills"},
	{id="kill500", cat="杀戮", n="尸山", d="击杀 500 只怪物。", need=500, gold=200, prog="kills"},
	{id="elite10", cat="杀戮", n="专打头目", d="击杀 10 只精英。", need=10, gold=60, prog="elite"},
	{id="elite50", cat="杀戮", n="头目克星", d="击杀 50 只精英。", need=50, gold=150, prog="elite"},
	{id="su1", cat="杀戮", n="记得住的", d="砍死一只名字还粘在地上的头目。", need=1, gold=50, prog="su"},
	{id="su7", cat="杀戮", n="七个名字", d="砍完七张野外图上那些不肯散的名字。", need=7, gold=220, prog="su"},
	{id="wolf20", cat="杀戮", n="荒原清场", d="砍死 20 只灰狼。", need=20, gold=40, prog="wolf"},
	{id="sekhra", cat="杀戮", n="白骨女王", d="砍死塞克拉。", need=1, gold=80, prog="crypt"},
	{id="arak", cat="杀戮", n="烧尽蛛巢", d="杀掉织母阿拉卡。", need=1, gold=100, prog="nest"},
	{id="varak", cat="杀戮", n="恐惧领主", d="斩杀瓦拉克。", need=1, gold=150, prog="fort"},
	{id="boss5", cat="杀戮", n="五个头", d="击杀 5 个首领。", need=5, gold=120, prog="boss"},
	{id="rift1", cat="下潜", n="进裂口", d="第一次走进镇子下面的裂口。", need=1, gold=30, prog="rift_enter"},
	{id="rift3", cat="下潜", n="三层之下", d="下到裂口第 3 层。", need=3, gold=50, prog="rift_deep"},
	{id="rift10", cat="下潜", n="没人回来过", d="下到裂口第 10 层。", need=10, gold=120, prog="rift_deep"},
	{id="rift20", cat="下潜", n="更深", d="下到裂口第 20 层。", need=20, gold=200, prog="rift_deep"},
	{id="lvl10", cat="下潜", n="站稳了", d="升到 10 级。", need=10, gold=40, prog="lvl"},
	{id="lvl20", cat="下潜", n="还能打", d="升到 20 级。", need=20, gold=80, prog="lvl"},
	{id="talent", cat="下潜", n="分叉", d="点亮第一个天赋。", need=1, gold=40, prog="talent"},
	{id="q1", cat="石桥", n="第一份活", d="完成塞琳的第一份委托。", need=1, gold=20, prog="q1"},
	{id="q3", cat="石桥", n="交差", d="把塞克拉的头提回来。", need=1, gold=60, prog="q3"},
	{id="allq", cat="石桥", n="板上清空", d="完成全部主线委托。", need=19, gold=400, prog="quests"},
	{id="recite", cat="石桥", n="念一遍", d="在桥头念出自己的名字。", need=1, gold=30, prog="recited"},
	{id="forgotten", cat="石桥", n="被偷过", d="裂口偷走过你的名字。", need=1, gold=40, hidden=true, prog="forgot"},
	{id="bounty3", cat="石桥", n="今日三成", d="领过一次悬赏日俸。", need=1, gold=50, prog="chest"},
	{id="gold1k", cat="搜刮", n="口袋沉了", d="累计搜刮 1000 金币。", need=1000, gold=40, prog="gold"},
	{id="gold5k", cat="搜刮", n="满袋", d="累计搜刮 5000 金币。", need=5000, gold=100, prog="gold"},
	{id="rare", cat="搜刮", n="稀有货", d="捡到一件稀有以上装备。", need=2, gold=40, prog="rarity"},
	{id="legend", cat="搜刮", n="传奇", d="捡到一件传奇装备。", need=3, gold=80, prog="rarity"},
	{id="set1", cat="搜刮", n="绿色的", d="捡到一件套装。", need=1, gold=50, prog="setloot"},
	{id="set4", cat="搜刮", n="成套", d="同时穿上同一套的 4 件。", need=4, gold=140, prog="setworn"},
	{id="relic", cat="搜刮", n="半张纸", d="替那个忘了名字的人记一下。", need=1, gold=30, hidden=true, prog="paper"},
	{id="recall", cat="手艺", n="想起来了", d="回想一件想不起来的装备。", need=1, gold=20, prog="recalled"},
	{id="reforge", cat="手艺", n="重铸一次", d="在卡登处重铸词缀。", need=1, gold=30, prog="reforged"},
	{id="nudge", cat="手艺", n="改一句", d="在卡登处改过一条词缀。", need=1, gold=25, prog="nudged"},
	{id="punch", cat="手艺", n="开孔", d="给一件装备打孔。", need=1, gold=30, prog="punched"},
	{id="rune", cat="手艺", n="镶进去", d="把符文镶进孔里。", need=1, gold=40, prog="socketed"},
	{id="phrase1", cat="手艺", n="念出来", d="把一句话嵌成型。", need=1, gold=80, prog="phrases"},
	{id="skrune", cat="手艺", n="改形态", d="给一个技能装上符文。", need=1, gold=50, prog="skrune"},
	{id="death1", cat="下潜", n="陨落", d="死过一次，还爬起来了。", need=1, gold=10, hidden=true, prog="deaths"},
	{id="lands", cat="下潜", n="走出石桥", d="探明五章的城镇与野外。", need=11, gold=120, prog="lands"},
	{id="hell1", cat="下潜", n="你回来了", d="五章打完，地狱开了。", need=1, gold=160, prog="hell"},
	{id="night1", cat="下潜", n="名字开始掉", d="地狱五章再走完，噩梦开了。", need=1, gold=240, prog="night"},
	{id="end1", cat="下潜", n="够了吗", d="在噩梦里把柯尔按回去。", need=1, gold=400, hidden=true, prog="end"},
]

const LANDS := ["waste", "wood", "ash", "rime", "frost", "harbor", "shore", "sink", "sinkf", "well", "shaft"]

var _queue: Array = []
var _toast_t := 0.0
var _gap := 0.0
var _showing := false


func by_id(id: String) -> Dictionary:
	for a in LIST:
		if str(a.id) == id:
			return a
	return {}


func on(id: String) -> bool:
	var ach = Game.P.get("ach", {})
	return typeof(ach) == TYPE_DICTIONARY and ach.has(id)


func done_n() -> int:
	var n := 0
	for a in LIST:
		if on(str(a.id)):
			n += 1
	return n


func cats() -> Array:
	var out: Array = []
	for a in LIST:
		var c := str(a.cat)
		if not out.has(c):
			out.append(c)
	return out


func su_kill_n() -> int:
	var su = Game.P.flags.get("su")
	if typeof(su) == TYPE_DICTIONARY:
		return su.size()
	return int(Game.P.get("suKills", 0))


func prog(a: Dictionary) -> int:
	var st: Dictionary = Game.P.get("stats", {})
	if typeof(st) != TYPE_DICTIONARY:
		st = {}
	match str(a.get("prog", "")):
		"kills":
			return int(Game.P.kills)
		"elite":
			return int(Game.P.eliteKills)
		"su":
			return su_kill_n()
		"wolf":
			return int(Game.P.killByType.get("wolf", 0))
		"crypt":
			return 1 if Game.P.cleared.get("crypt") else 0
		"nest":
			return 1 if Game.P.cleared.get("nest") else 0
		"fort":
			return 1 if Game.P.cleared.get("fort") else 0
		"boss":
			return int(Game.P.bossKills)
		"rift_enter":
			return 1 if Game.P.flags.get("enteredRift") else 0
		"rift_deep":
			return int(WorldState.W.get("riftDeepest", 0)) if Game.P.flags.get("enteredRift") else 0
		"lvl":
			return int(Game.P.lvl)
		"talent":
			return Game.tal_spent()
		"q1":
			return 1 if str(Game.P.quests.get("q1", {}).get("state", "")) == "done" else 0
		"q3":
			return 1 if str(Game.P.quests.get("q3", {}).get("state", "")) == "done" else 0
		"quests":
			var n := 0
			for q in Data.QUESTS:
				if str(Game.P.quests.get(q.id, {}).get("state", "")) == "done":
					n += 1
			return n
		"recited":
			return int(st.get("recited", 0))
		"forgot":
			return 1 if Game.P.flags.get("selinForgot") else 0
		"chest":
			return 1 if Game.P.get("bountyChest") else 0
		"gold":
			return int(st.get("goldLooted", 0))
		"rarity":
			return int(st.get("maxRarity", 0))
		"setloot":
			return int(st.get("setLoot", 0))
		"setworn":
			var m := 0
			for v in Game.worn_sets().values():
				m = maxi(m, int(v))
			return m
		"paper":
			return 1 if Game.P.flags.get("halfPaper") else 0
		"recalled":
			return int(st.get("recalled", 0))
		"reforged":
			return int(st.get("reforged", 0))
		"nudged":
			return int(st.get("nudged", 0))
		"punched":
			return int(st.get("punched", 0))
		"socketed":
			return int(st.get("socketed", 0))
		"phrases":
			return int(st.get("phrases", 0))
		"skrune":
			var runes = Game.P.get("skRunes", {})
			return runes.size() if typeof(runes) == TYPE_DICTIONARY else 0
		"deaths":
			return int(st.get("deaths", 0))
		"lands":
			var n := 0
			var d = WorldState.W.get("discovered", {})
			if typeof(d) != TYPE_DICTIONARY:
				d = Game.P.get("discovered", {})
			for id in LANDS:
				if d.get(id):
					n += 1
			return n
		"hell":
			return 1 if Data.DIFF_ORDER.find(Game.diff_max_id()) >= 1 else 0
		"night":
			return 1 if Data.DIFF_ORDER.find(Game.diff_max_id()) >= 2 else 0
		"end":
			return 1 if Game.ch_beat_on("nightmare", 5) else 0
		_:
			return 0


func unlock(a: Dictionary, silent: bool = false) -> void:
	Game.ensure_ach()
	if a.is_empty() or on(str(a.id)):
		return
	Game.P.ach[str(a.id)] = Time.get_unix_time_from_system()
	if silent:
		return
	var g := int(a.get("gold", 0))
	if g:
		Game.P.gold += g
	var extra := "（+%d 金）" % g if g else ""
	Game.say("功绩解锁：%s%s" % [a.n, extra])
	_queue.append(a)
	_pump()
	Game.save_soon()


func check(silent: bool = false) -> void:
	Game.ensure_ach()
	var again := true
	var guard := 0
	while again and guard < 48:
		guard += 1
		again = false
		for a in LIST:
			if on(str(a.id)):
				continue
			if prog(a) >= int(a.get("need", 1)):
				unlock(a, silent)
				again = true


func _pump() -> void:
	if _showing or _toast_t > 0 or _gap > 0:
		return
	if _queue.is_empty():
		return
	var a: Dictionary = _queue.pop_front()
	_showing = true
	_toast_t = 3.2
	Sfx.ach()
	toast_show.emit(a)


func _process(dt: float) -> void:
	if _toast_t > 0:
		_toast_t -= dt
		if _toast_t <= 0:
			_showing = false
			toast_hide.emit()
			if not _queue.is_empty():
				_gap = 0.28
	elif _gap > 0:
		_gap -= dt
		if _gap <= 0:
			_pump()
