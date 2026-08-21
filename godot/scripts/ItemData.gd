class_name ItemData
extends Resource
## 物品数据资源：将物品定义从运行时 dict 提升为可序列化 Resource，
## 便于编辑器创作、版本管理与多人协作（参考 P0nni / jame581 的 Resource 化思路）。
##
## 注意：本类为「增量」引入，当前运行时(背包/掉落)仍以 dict 为主；
## 通过 from_dict / to_dict 与既有 Game.bag / LootData 桥接，不改动现有逻辑。
## 编辑器侧由 addons/item_dock 插件提供 Dock（浏览/新建/编辑/导入导出）。

@export var id: String = ""
@export var name: String = ""
@export_enum("weapon", "armor", "helm", "offhand", "belt", "gloves", "boots", "amulet", "ring", "rune", "charm", "scrap") var type: String = ""
@export_enum("common", "uncommon", "rare", "epic", "legendary") var rarity: String = "common"
@export var qty: int = 1
@export var icon: String = ""
@export var hex: Color = Color(0.5, 0.5, 0.5)
@export var stats: Dictionary = {}
@export_multiline var desc: String = ""
@export var grade: int = 1


func from_dict(d: Dictionary) -> ItemData:
	id = str(d.get("id", ""))
	name = str(d.get("name", ""))
	type = str(d.get("type", ""))
	rarity = str(d.get("rarity", "common"))
	qty = int(d.get("qty", 1))
	icon = str(d.get("icon", ""))
	hex = _parse_hex(d.get("hex", null))
	stats = d.get("stats", {})
	desc = str(d.get("desc", ""))
	grade = int(d.get("grade", 1))
	return self


## 容错解析颜色：兼容 Color / #rrggbb 字符串 / 缺失；不支持的类型回退灰。
func _parse_hex(v: Variant) -> Color:
	if v == null:
		return Color(0.5, 0.5, 0.5)
	if v is Color:
		return v
	if v is int or v is float:
		var iv: int = int(v)
		return Color.from_rgba8((iv >> 16) & 0xff, (iv >> 8) & 0xff, iv & 0xff)
	if v is String:
		return Color(v)
	return Color(0.5, 0.5, 0.5)


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "type": type, "rarity": rarity, "qty": qty,
		"icon": icon, "hex": hex, "stats": stats, "desc": desc, "grade": grade,
	}
