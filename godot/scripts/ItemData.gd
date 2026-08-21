class_name ItemData
extends Resource
## 物品数据资源：将物品定义从运行时 dict 提升为可序列化 Resource，
## 便于编辑器创作、版本管理与多人协作（参考 P0nni / jame581 的 Resource 化思路）。
##
## 注意：本类为「增量」引入，当前运行时(背包/掉落)仍以 dict 为主；
## 通过 from_dict / to_dict 与既有 Game.bag / LootData 桥接，不改动现有逻辑。
## 编辑器 Dock 生成器为后续步骤（需 @tool 且在编辑器内验证）。

@export var id: String = ""
@export var name: String = ""
@export var type: String = ""          # weapon/armor/helm/offhand/belt/gloves/boots/amulet/ring/rune/charm/scrap
@export var rarity: String = "common"  # common/uncommon/rare/epic/legendary
@export var qty: int = 1
@export var icon: String = ""
@export var hex: Color = Color(0.5, 0.5, 0.5)
@export var stats: Dictionary = {}
@export var desc: String = ""
@export var grade: int = 1


func from_dict(d: Dictionary) -> ItemData:
	id = str(d.get("id", ""))
	name = str(d.get("name", ""))
	type = str(d.get("type", ""))
	rarity = str(d.get("rarity", "common"))
	qty = int(d.get("qty", 1))
	icon = str(d.get("icon", ""))
	hex = Color(d.get("hex", Color(0.5, 0.5, 0.5)))
	stats = d.get("stats", {})
	desc = str(d.get("desc", ""))
	grade = int(d.get("grade", 1))
	return self


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "type": type, "rarity": rarity, "qty": qty,
		"icon": icon, "hex": hex, "stats": stats, "desc": desc, "grade": grade,
	}
