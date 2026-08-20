extends Node
## 暗金 MMO 面板：对齐网页 plate / 格子，并参考 RPGUI framed-golden、常见背包凹槽。

var _ui_font: Font = null
var _tex := {}

const GLYPH_ICON := {
	"🗡": "dagger", "⚔": "sword", "🪓": "axe", "🔨": "hammer",
	"🪄": "staff", "🔱": "trident", "💠": "crystal", "🏹": "bow",
	"🎯": "target", "⚙": "crossbow", "🥋": "leather", "🛡": "shield",
	"🦺": "plate", "🎩": "hood", "⛑": "helm", "👑": "horned",
	"🔰": "tower", "📖": "book", "🎒": "quiver", "🎗": "belt",
	"🧶": "chain", "🧤": "gloves", "✋": "gauntlet", "🥾": "boots",
	"👢": "greaves", "📿": "amulet", "🔮": "orb", "💍": "ring",
	"💎": "gem", "🔥": "ember", "❄": "frost", "❤": "heart",
	"🪶": "feather", "💨": "wind", "🩸": "blood", "🔘": "button",
	"📜": "scroll", "📌": "pin", "🦷": "fang", "🧵": "thread",
	"⌚": "ring", "🔑": "key", "🎀": "ribbon", "🪵": "wood",
	"📦": "crate", "📓": "journal", "⚱": "urn", "🪡": "needle",
	"🎵": "music", "🪢": "knot", "🎟": "ticket", "🪨": "stone",
	"🧪": "flask", "🔵": "potion-mp", "🧰": "crate", "🕯": "candle",
	"❔": "unknown", "？": "unknown", "✦": "spark", "💥": "boom",
	"⚡": "bolt", "🌀": "tornado", "📣": "horn", "🌋": "volcano",
	"✨": "spark", "🌟": "star", "☄": "meteor", "🍃": "vines",
	"👁": "eye", "🌧": "rain", "🤸": "roll", "📄": "scroll",
	"▣": "nav-bag", "⚜": "nav-talents", "✉": "nav-quests", "◆": "nav-achs"
}


func ui_font() -> Font:
	if _ui_font != null:
		return _ui_font
	var f = load("res://fonts/NotoSansSC-Regular.ttf")
	_ui_font = f
	return _ui_font


func tex(id: String) -> Texture2D:
	if id == "":
		return null
	if _tex.has(id):
		return _tex[id]
	var path := "res://icons/%s.svg" % id
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex[id] = t
	return t


func icon_for_glyph(g: String) -> String:
	if g == "":
		return "loot"
	if GLYPH_ICON.has(g):
		return str(GLYPH_ICON[g])
	if ResourceLoader.exists("res://icons/%s.svg" % g):
		return g
	return "loot"


func icon_for_skill(sid: String) -> String:
	if sid != "" and ResourceLoader.exists("res://icons/%s.svg" % sid):
		return sid
	return "spark"


func icon_for_slot(k: String) -> String:
	var m := {
		"helm": "helm", "amulet": "amulet", "ring1": "ring", "ring2": "ring",
		"belt": "belt", "weapon": "sword", "armor": "plate", "offhand": "shield",
		"gloves": "gloves", "boots": "boots"
	}
	return str(m.get(k, "loot"))


func icon_for_item(it: Dictionary) -> String:
	if it.is_empty():
		return "loot"
	if it.get("unknown") == true:
		return "unknown"
	var kind := str(it.get("type", ""))
	if kind == "rune":
		var rid := str(it.get("runeId", ""))
		if rid == "rune_ember":
			return "ember"
		if rid == "rune_frost":
			return "frost"
		if rid == "rune_vita":
			return "heart"
		if rid == "rune_hawk":
			return "feather"
		if rid == "rune_gale":
			return "wind"
		if rid == "rune_leech":
			return "blood"
		return "stone"
	if kind == "charm":
		return "ribbon"
	if kind == "scrap":
		return "scroll"
	return icon_for_glyph(str(it.get("glyph", it.get("g", it.get("icon", "")))))


func stamp_btn(b: Button, icon_id: String, caption: String, icon_px: int = 32, left: bool = false) -> void:
	var t := tex(icon_id)
	b.icon = t
	if t != null:
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", icon_px)
		if left:
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		else:
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.text = caption


func icon_rect(id: String, px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex(id)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tr


func ink() -> Color:
	return Color(0.047, 0.039, 0.031)


func panel() -> Color:
	return Color(0.063, 0.051, 0.039)


func brass() -> Color:
	return Color(0.69, 0.55, 0.31)


func brass_hi() -> Color:
	return Color(0.886, 0.769, 0.498)


func bone() -> Color:
	return Color(0.839, 0.788, 0.682)


func ash() -> Color:
	return Color(0.541, 0.498, 0.439)


func dim() -> Color:
	return Color(0.54, 0.5, 0.44)


func gold() -> Color:
	return Color(0.961, 0.769, 0.318)


func _flat(bg: Color, border: Color, bw: int, pad: int, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0, 0, 0, 0.62)
	sb.shadow_size = 10
	sb.anti_aliasing = true
	return sb


func plate() -> StyleBoxFlat:
	var sb := _flat(Color(0.063, 0.051, 0.039, 0.97), Color(0.42, 0.341, 0.192), 1, 16, 3)
	sb.shadow_size = 18
	sb.expand_margin_left = 1
	sb.expand_margin_right = 1
	sb.expand_margin_top = 1
	sb.expand_margin_bottom = 1
	return sb


func plate_inner() -> StyleBoxFlat:
	var sb := _flat(Color(0, 0, 0, 0), Color(0.69, 0.55, 0.31, 0.22), 1, 8, 2)
	sb.shadow_size = 0
	sb.draw_center = false
	return sb


func cell(hex: int = 0x3d3122) -> StyleBoxFlat:
	var sb := _flat(Color(0.078, 0.067, 0.051, 0.96), Cfg.hex_color(hex), 1, 4, 3)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 1)
	return sb


func cell_empty() -> StyleBoxFlat:
	var sb := _flat(Color(0.047, 0.039, 0.031, 0.9), Color(0.24, 0.192, 0.133), 1, 4, 3)
	sb.shadow_size = 0
	return sb


func cell_hover(hex: int = 0xb08d4f) -> StyleBoxFlat:
	var sb := cell(hex)
	sb.border_color = brass_hi()
	sb.shadow_color = Color(0.69, 0.55, 0.31, 0.35)
	sb.shadow_size = 8
	return sb


func slot() -> StyleBoxFlat:
	return _flat(Color(0.086, 0.067, 0.047), Color(0.353, 0.275, 0.157), 1, 4, 4)


func slot_hover() -> StyleBoxFlat:
	var sb := slot()
	sb.border_color = brass_hi()
	sb.shadow_color = Color(0.69, 0.55, 0.31, 0.32)
	sb.shadow_size = 10
	return sb


func nav() -> StyleBoxFlat:
	var sb := _flat(Color(0.102, 0.082, 0.063), Color(0.24, 0.192, 0.133), 1, 6, 3)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 7
	return sb


func nav_on() -> StyleBoxFlat:
	var sb := nav()
	sb.border_color = brass()
	sb.bg_color = Color(0.165, 0.129, 0.094)
	sb.shadow_color = Color(0.69, 0.55, 0.31, 0.22)
	sb.shadow_size = 8
	return sb


func btn() -> StyleBoxFlat:
	return _flat(Color(0.114, 0.094, 0.071), Color(0.42, 0.341, 0.192), 1, 10, 3)


func btn_hover() -> StyleBoxFlat:
	var sb := btn()
	sb.bg_color = Color(0.165, 0.129, 0.086)
	sb.border_color = brass_hi()
	return sb


func btn_pressed() -> StyleBoxFlat:
	var sb := btn()
	sb.bg_color = Color(0.086, 0.067, 0.047)
	return sb


func btn_disabled() -> StyleBoxFlat:
	var sb := btn()
	sb.bg_color = Color(0.063, 0.051, 0.039, 0.7)
	sb.border_color = Color(0.227, 0.188, 0.133)
	return sb


func tab() -> StyleBoxFlat:
	var sb := _flat(Color(0.063, 0.051, 0.039, 0), Color(0, 0, 0, 0), 1, 10, 2)
	sb.shadow_size = 0
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


func tab_on() -> StyleBoxFlat:
	var sb := _flat(Color(0.114, 0.094, 0.071), Color(0.42, 0.341, 0.192), 1, 10, 2)
	sb.shadow_size = 0
	sb.border_width_bottom = 0
	return sb


func tip() -> StyleBoxFlat:
	var sb := _flat(Color(0.055, 0.043, 0.035, 0.97), brass(), 1, 12, 3)
	sb.shadow_size = 14
	return sb


func gcard() -> StyleBoxFlat:
	return _flat(Color(0.059, 0.047, 0.039), Color(0.165, 0.129, 0.094), 1, 12, 3)


func orb_ring() -> StyleBoxFlat:
	var sb := _flat(Color(0.043, 0.035, 0.031), Color(0.42, 0.341, 0.192), 3, 0, 54)
	sb.shadow_size = 16
	return sb


func bar_bg() -> StyleBoxFlat:
	var sb := _flat(Color(0.039, 0.031, 0.024), Color(0.227, 0.184, 0.122), 1, 0, 3)
	sb.shadow_size = 0
	return sb


func bar_fill(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(2)
	return sb


func hud_theme() -> Theme:
	var t := Theme.new()
	var f := ui_font()
	if f != null:
		t.default_font = f
	t.set_stylebox("normal", "Button", btn())
	t.set_stylebox("hover", "Button", btn_hover())
	t.set_stylebox("pressed", "Button", btn_pressed())
	t.set_stylebox("disabled", "Button", btn_disabled())
	t.set_stylebox("focus", "Button", btn_hover())
	t.set_color("font_color", "Button", bone())
	t.set_color("font_hover_color", "Button", brass_hi())
	t.set_color("font_pressed_color", "Button", brass_hi())
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.38, 0.33))
	t.set_color("font_color", "Label", bone())
	t.set_color("font_color", "RichTextLabel", bone())
	t.set_stylebox("panel", "PanelContainer", plate())
	t.set_stylebox("background", "ProgressBar", bar_bg())
	t.set_stylebox("fill", "ProgressBar", bar_fill(Color(0.69, 0.55, 0.31)))
	t.set_stylebox("normal", "LineEdit", cell())
	t.set_stylebox("focus", "LineEdit", cell_hover())
	t.set_stylebox("normal", "TextEdit", cell())
	t.set_stylebox("focus", "TextEdit", cell_hover())
	t.set_color("font_color", "LineEdit", bone())
	t.set_color("font_placeholder_color", "LineEdit", ash())
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	return t


func item_glyph(it: Dictionary) -> String:
	if it.is_empty():
		return "·"
	if it.get("unknown") == true:
		return "？"
	return str(it.get("g", it.get("glyph", it.get("icon", "·"))))


func rarity_color(it: Dictionary) -> Color:
	if it.is_empty():
		return dim()
	if it.get("unknown") == true:
		return Color(0.6, 0.56, 0.48)
	return Cfg.hex_color(LootData.item_hex(it))


func rule(parent: Control) -> void:
	var c := ColorRect.new()
	c.color = Color(0.165, 0.129, 0.094)
	c.custom_minimum_size = Vector2(0, 1)
	parent.add_child(c)


func slot_glyph(k: String) -> String:
	for s in Data.SLOTDEF:
		if str(s.k) == k:
			return str(s.g) + " " + str(s.n)
	return k


func slot_icon(k: String) -> String:
	for s in Data.SLOTDEF:
		if str(s.k) == k:
			return str(s.g)
	return "·"


func slot_name(k: String) -> String:
	for s in Data.SLOTDEF:
		if str(s.k) == k:
			return str(s.n)
	return k


func buff_name(k: String) -> String:
	var n := {
		"dmg": "伤害", "shield": "护盾", "swift": "迅捷", "shadow": "暗影",
		"setas": "攻速", "setdr": "减伤", "downdr": "减伤", "enough": "连斩",
		"crit": "暴击", "as": "攻速", "potsh": "药盾", "greed": "贪婪"
	}
	return str(n.get(k, k))


func header(parent: Control, title: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	row.add_child(_orn(false))
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", brass_hi())
	row.add_child(l)
	row.add_child(_orn(true))


func group(parent: Control, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", brass_hi())
	parent.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(0.165, 0.129, 0.094)
	rule.custom_minimum_size = Vector2(0, 1)
	parent.add_child(rule)


func _orn(rev: bool) -> ColorRect:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(48, 1)
	c.color = brass()
	c.modulate.a = 0.85 if not rev else 0.85
	return c


func stat_row(parent: Control, key: String, val: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", Color(0.62, 0.576, 0.498))
	row.add_child(k)
	var dots := Label.new()
	dots.text = " ················· "
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.add_theme_color_override("font_color", Color(0.69, 0.55, 0.31, 0.28))
	row.add_child(dots)
	var v := Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", brass_hi())
	row.add_child(v)
