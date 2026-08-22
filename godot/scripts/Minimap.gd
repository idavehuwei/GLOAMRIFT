extends Control
## 网页版 drawMinimap：168²、半径 28 格、只画已探。

const S := 168
const R := 28
var _lx := 0.0
var _lz := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(S, S)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var W: Dictionary = WorldState.W
	draw_rect(Rect2(Vector2.ZERO, Vector2(S, S)), Color(0.027, 0.024, 0.039), true)
	if W.is_empty() or not W.has("grid"):
		return
	var explored: PackedByteArray = W.get("explored", PackedByteArray())
	if explored.is_empty():
		return
	var px := Cfg.tx(Game.P.x)
	var pz := Cfg.tz(Game.P.z)
	var cell := float(S) / float(R * 2)
	var kind := str(W.area.get("kind", ""))
	var floor_col := Color(0.18, 0.16, 0.14)
	if kind == "town":
		floor_col = Color(0.29, 0.255, 0.196)
	elif kind == "field":
		floor_col = Color(0.224, 0.259, 0.18)
	for y in range(-R, R):
		for x in range(-R, R):
			var gx := px + x
			var gy := pz + y
			if gx < 0 or gy < 0 or gx >= Cfg.MAP or gy >= Cfg.MAP:
				continue
			var gi := Cfg.gi(gx, gy)
			if gi < 0 or gi >= explored.size() or explored[gi] == 0:
				continue
			var cell_g := int(W.grid[gi])
			var p := WorldState.paint_at(gx, gy)
			if cell_g != 1 and p != 9 and p != 10 and p != 11:
				continue
			var col := floor_col
			match p:
				9:
					col = Color(0.102, 0.251, 0.345)
				10:
					col = Color(0.753, 0.251, 0.094)
				11:
					col = Color(0.557, 0.706, 0.784)
				2:
					col = Color(0.353, 0.325, 0.267)
				3:
					col = Color(0.416, 0.392, 0.345)
				4:
					col = Color(0.165, 0.227, 0.141)
				5:
					col = Color(0.608, 0.722, 0.784)
				6:
					col = Color(0.29, 0.165, 0.133)
				7:
					col = Color(0.541, 0.478, 0.322)
			draw_rect(Rect2((x + R) * cell, (y + R) * cell, cell + 0.6, cell + 0.6), col, true)
	for it in W.get("items", []):
		var ic := Color(0.96, 0.77, 0.32)
		var k := str(it.get("kind", ""))
		if k == "potion":
			ic = Color(0.753, 0.251, 0.188)
		elif k == "relic":
			ic = Color(0.925, 0.827, 0.604)
		elif k == "item":
			var g = it.get("item")
			if typeof(g) == TYPE_DICTIONARY:
				ic = Cfg.hex_color(LootData.item_hex(g))
		_dot(it.x, it.z, px, pz, cell, ic, 3.0)
	for n in W.get("npcs", []):
		_dot(n.x, n.z, px, pz, cell, Color(0.494, 0.784, 1), 5.0)
	var boss_alive := false
	var boss = W.get("boss")
	if typeof(boss) == TYPE_DICTIONARY and not boss.get("dead"):
		boss_alive = true
	for m in W.get("marks", []):
		if m.get("off"):
			continue
		if str(m.get("kind", "")) == "next" and boss_alive:
			continue
		var mk := str(m.get("kind", ""))
		var mc := Color(0.627, 0.416, 1)
		var sz := 6.0
		match mk:
			"travel":
				mc = Color(0.847, 0.757, 0.361)
			"exit":
				mc = Color(0.353, 0.847, 0.541)
			"shrine":
				mc = Color(0.541, 0.416, 0.816)
			"cage":
				mc = Color(0.784, 0.627, 0.376)
			"event":
				mc = Color(0.886, 0.627, 0.29)
				sz = 7.0
		_dot(m.x, m.z, px, pz, cell, mc, sz)
	for e in W.get("enemies", []):
		if e.get("dead"):
			continue
		var ec := Color(0.651, 0.227, 0.165)
		var esz := 3.0
		if e.get("boss"):
			ec = Color(1, 0.184, 0.184)
			esz = 6.0
		elif e.get("ally"):
			ec = Color(0.494, 0.784, 0.478)
			esz = 5.0
		elif e.get("su") or e.get("hoard"):
			ec = Color(0.886, 0.769, 0.498)
			esz = 5.0
		elif e.get("elite"):
			ec = Color(1, 0.627, 0.188)
		_dot(e.x, e.z, px, pz, cell, ec, esz)
	draw_rect(Rect2(1.5, 1.5, S - 3, S - 3), Color(0.69, 0.55, 0.31, 0.5), false, 1.5)
	var pcx := Cfg.tx(Game.P.x)
	var pcz := Cfg.tz(Game.P.z)
	var dir := Vector2(pcx - _lx, pcz - _lz)
	if _lx == 0.0 and _lz == 0.0:
		_lx = pcx
		_lz = pcz
		dir = Vector2(0, -1)
	elif dir.length_squared() > 0.02:
		dir = dir.normalized()
	else:
		dir = Vector2(0, -1)
	_lx = pcx
	_lz = pcz
	var ctr := Vector2(S * 0.5, S * 0.5)
	var tip := ctr + dir * 9.0
	var lft := ctr + dir.rotated(2.4) * 4.5
	var rgt := ctr + dir.rotated(-2.4) * 4.5
	var pts := PackedVector2Array([tip, lft, rgt])
	var col := Color(0.97, 0.9, 0.74, 1)
	var cols := PackedColorArray([col, col, col])
	draw_polygon(pts, cols)
	draw_circle(ctr, 3.4, Color(0.941, 0.878, 0.722))
	draw_line(Vector2(S * 0.5, 0), Vector2(S * 0.5, S), Color(0.69, 0.55, 0.31, 0.18), 1.0)
	draw_line(Vector2(0, S * 0.5), Vector2(S, S * 0.5), Color(0.69, 0.55, 0.31, 0.18), 1.0)


func _dot(wx: float, wz: float, px: int, pz: int, cell: float, col: Color, sz: float) -> void:
	var dx := (Cfg.tx(wx) - px + R) * cell
	var dy := (Cfg.tz(wz) - pz + R) * cell
	if dx < 0 or dy < 0 or dx > S or dy > S:
		return
	draw_rect(Rect2(dx - sz * 0.5, dy - sz * 0.5, sz, sz), col, true)
