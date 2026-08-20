extends Node
## 套装 / 传奇 / 遗物袋 / 悬赏表。数值来自网页版 `shadow-depths.html`。

const SET_COL := "#1eff00"
const SET_HEX := 0x1eff00

const UNIQUE_DUN := {
	"fort": "valak", "belfry": "singer", "hull": "grey", "chorus": "assembly", "nail": "kor"
}
const TOKEN_N := {
	"valak": "浇冷的石浆", "singer": "沉钟的碎片", "grey": "刮痕",
	"assembly": "一张选票", "kor": "第一根的碎屑"
}
const TOKEN_ORDER := ["valak", "singer", "grey", "assembly", "kor"]

const RELIC_HALFPAPER := {
	"id": "halfpaper", "n": "半张纸", "icon": "📄", "d": "某个忘了自己名字的人",
	"codex": {"n": "（空白名字）", "text": "半张纸上只剩一个模糊的字头"},
	"lines": ["纸上写着半个名字，墨迹被汗浸开了。你替他记着——就一下。"]
}
const RELIC_THIMBLE := {
	"id": "thimble", "n": "孩子的顶针", "icon": "🪡", "d": "塞克拉一直在找的东西",
	"codex": {"n": "莉赛尔", "text": "塞克拉要找的孩子的名字"},
	"lines": ["一枚磨得发亮的顶针。它太小了，本不该出现在这么深的地方。"]
}

var UNIQUES: Array = []
var SETS: Array = []
var CHARM_UNIQUES: Array = []
var CHARM_BASE: Dictionary = {}
var CHARM_AFFIX: Array = []
var BOUNTY_POOL: Array = []


func _ready() -> void:
	var raw := FileAccess.get_file_as_string("res://data/loot.json")
	var d = JSON.parse_string(raw)
	if typeof(d) != TYPE_DICTIONARY:
		push_error("LootData: loot.json 读失败")
		return
	UNIQUES = d.get("UNIQUES", [])
	SETS = d.get("SETS", [])
	CHARM_UNIQUES = d.get("CHARM_UNIQUES", [])
	CHARM_BASE = d.get("CHARM_BASE", {})
	CHARM_AFFIX = d.get("CHARM_AFFIX", [])
	BOUNTY_POOL = d.get("BOUNTY_POOL", [])


func unique_by_id(id: String) -> Dictionary:
	for u in UNIQUES:
		if str(u.id) == id:
			return u
	return {}


func unique_pool(boss: String, art: bool) -> Array:
	var out: Array = []
	for u in UNIQUES:
		if str(u.get("boss", "")) != boss:
			continue
		if art:
			if int(u.get("rarity", 0)) >= 4:
				out.append(u)
		elif int(u.get("rarity", 0)) < 4:
			out.append(u)
	return out


func set_by_id(id: String) -> Dictionary:
	for s in SETS:
		if str(s.id) == id:
			return s
	return {}


func charm_unique_by_id(id: String) -> Dictionary:
	for c in CHARM_UNIQUES:
		if str(c.id) == id:
			return c
	return {}


func fmt_power(def: Dictionary, v: Dictionary) -> String:
	var pw := str(def.get("pw", ""))
	if pw == "":
		return ""
	var i := 0
	while i < pw.length():
		var a := pw.find("{", i)
		if a < 0:
			break
		var b := pw.find("}", a + 1)
		if b < 0:
			break
		var k := pw.substr(a + 1, b - a - 1)
		var repl := str(v.get(k, "?"))
		pw = pw.substr(0, a) + repl + pw.substr(b + 1)
		i = a + repl.length()
	return pw


func item_hex(it: Dictionary) -> int:
	if it.get("set"):
		return SET_HEX
	var r := int(it.get("rarity", 0))
	if r < 0 or r >= Data.RARITY.size():
		r = 0
	return int(Data.RARITY[r].hex)
