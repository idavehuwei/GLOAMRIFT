extends Node
## 地图生成、寻路、敌人、投射物。网格与网页版相同，不迁就建筑改碰撞。

var W: Dictionary = {}
var world_root: Node3D
var actors_root: Node3D
var nseed := 0
var ent_seq := 0
var _floor_mm: MultiMeshInstance3D
var _wall_mm: MultiMeshInstance3D
var _marks_nodes: Array = []
var _proj: Array = []
var _zones: Array = []
var _torch_lights: Array = []
var _torch_t := 0.0


func _ready() -> void:
	reset_world()


func reset_world() -> void:
	W = {
		"grid": PackedByteArray(), "paint": PackedByteArray(),
		"area": {}, "dun": null, "dunFloor": 0, "rooms": [],
		"enemies": [], "npcs": [], "marks": [], "items": [],
		"discovered": {"town": true}, "riftDepth": 0, "riftDeepest": 0,
		"diff": "normal", "boss": null, "hzAcc": 0.0, "group": null,
		"event": null, "usedPot": false, "riftMods": [], "riftOffer": null,
		"shrine": null, "shrineRare": 0, "traps": [], "roomTags": [],
		"explored": PackedByteArray(), "walls": [], "torches": [], "dark": false,
		"arrive_mode": "gate", "arrive_from": ""
	}
	W.grid.resize(Cfg.MAP * Cfg.MAP)
	W.paint.resize(Cfg.MAP * Cfg.MAP)
	reset_explored(0)


func bind(world: Node3D, actors: Node3D) -> void:
	world_root = world
	actors_root = actors


func walk(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= Cfg.MAP or y >= Cfg.MAP:
		return false
	return W.grid[Cfg.gi(x, y)] == 1


func can_stand(x: float, z: float, r: float = 0.5) -> bool:
	return walk(Cfg.tx(x - r), Cfg.tz(z - r)) and walk(Cfg.tx(x + r), Cfg.tz(z - r)) \
		and walk(Cfg.tx(x - r), Cfg.tz(z + r)) and walk(Cfg.tx(x + r), Cfg.tz(z + r))


func reset_explored(fill: int = 0) -> void:
	W.explored = PackedByteArray()
	W.explored.resize(Cfg.MAP * Cfg.MAP)
	if fill != 0:
		W.explored.fill(fill)


func reveal_around_player() -> void:
	var ex: PackedByteArray = W.get("explored", PackedByteArray())
	if ex.is_empty():
		reset_explored(0)
		ex = W.explored
	var px := Cfg.tx(Game.P.x)
	var pz := Cfg.tz(Game.P.z)
	for y in range(pz - 9, pz + 10):
		for x in range(px - 9, px + 10):
			if x < 0 or y < 0 or x >= Cfg.MAP or y >= Cfg.MAP:
				continue
			if (x - px) * (x - px) + (y - pz) * (y - pz) <= 81:
				ex[Cfg.gi(x, y)] = 1
	W.explored = ex


func paint_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= Cfg.MAP or y >= Cfg.MAP:
		return 0
	return int(W.paint[Cfg.gi(x, y)])


func blocked_tiles() -> Array:
	var M := Cfg.MAP
	var out: Array = []
	for y in range(1, M - 1):
		for x in range(1, M - 1):
			if W.grid[Cfg.gi(x, y)] != 0:
				continue
			var p := paint_at(x, y)
			if p == 9 or p == 10 or p == 11:
				continue
			var near := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if walk(x + dx, y + dy):
						near = true
						break
				if near:
					break
			if near:
				out.append(Vector2i(x, y))
	return out


func has_mod(e: Dictionary, id: String) -> bool:
	return e.get("mods", []).has(id)


func n2(x: float, y: float) -> float:
	var s := sin((x + nseed) * 12.9898 + (y - nseed) * 78.233) * 43758.5453
	return s - floor(s)


func move_entity(ent: Dictionary, x: float, z: float) -> void:
	if ent != Game.P:
		if wall_block(x, float(ent.z)):
			x = float(ent.x)
		if wall_block(float(ent.x), z):
			z = float(ent.z)
	if can_stand(x, z, 0.45):
		ent.x = x
		ent.z = z
	elif can_stand(x, ent.z, 0.45):
		ent.x = x
	elif can_stand(ent.x, z, 0.45):
		ent.z = z


func wall_block(x: float, z: float) -> bool:
	var walls = W.get("walls", [])
	if typeof(walls) != TYPE_ARRAY:
		return false
	for w in walls:
		if Cfg.dist2(x, z, float(w.x), float(w.z)) < float(w.r) * float(w.r):
			return true
	return false


func place_player(x: float, z: float) -> void:
	Game.P.x = x
	Game.P.z = z
	Game.P.path = []
	Game.P.target = null


func place_stand(x: float, z: float) -> void:
	if can_stand(x, z, 0.45):
		place_player(x, z)
		return
	for r in range(1, 8):
		var found := false
		for a in 8:
			var ang := float(a) * TAU / 8.0
			var nx := x + cos(ang) * float(r) * 1.2
			var nz := z + sin(ang) * float(r) * 1.2
			if can_stand(nx, nz, 0.45):
				place_player(nx, nz)
				found = true
				break
		if found:
			return
	place_player(x, z)


func town_well_pos() -> Vector2:
	return Vector2(-6.0, 6.0)


func town_story_from(id: String) -> String:
	match id:
		"town":
			return "waste"
		"rime":
			return "ash"
		"harbor":
			return "rime"
		"sink":
			return "harbor"
		"well":
			return "sink"
		_:
			return ""


func town_gate_for(area: Dictionary, from_id: String) -> Vector2:
	var want := from_id
	if want == "":
		want = town_story_from(str(area.get("id", "")))
	var fallback := Vector2.ZERO
	for ex in area.get("exits", []):
		if str(ex.get("kind", "")) == "rift":
			continue
		var gx := float(ex.get("x", 0))
		var gz := float(ex.get("z", 0))
		if gx == 0.0 and gz == 0.0:
			continue
		if fallback == Vector2.ZERO:
			fallback = Vector2(gx, gz)
		if str(ex.get("to", "")) == want:
			return Vector2(gx, gz)
	if fallback != Vector2.ZERO:
		return fallback
	return Vector2(34, 6)


func town_gate_spawn(gate: Vector2) -> Vector2:
	if gate.length() < 1.0:
		return Vector2(0, 8)
	return gate - gate.normalized() * 6.0


func find_path(sx: int, sy: int, gx: int, gy: int, limit: int = 4500) -> Variant:
	if not walk(gx, gy):
		var best: Vector2i
		var found := false
		var bd := 1e9
		for r in range(1, 5):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var nx := gx + dx
					var ny := gy + dy
					if not walk(nx, ny):
						continue
					var d := dx * dx + dy * dy
					if d < bd:
						bd = d
						best = Vector2i(nx, ny)
						found = true
			if found:
				break
		if not found:
			return null
		gx = best.x
		gy = best.y
	if sx == gx and sy == gy:
		return []
	var M := Cfg.MAP
	var open: Array = []
	var came := {}
	var gs := {}
	var key := func(x: int, y: int) -> int: return y * M + x
	gs[key.call(sx, sy)] = 0.0
	open.append({"x": sx, "y": sy, "f": Cfg.hypot(sx - gx, sy - gy)})
	var cnt := 0
	var dirs := [[1, 0, 1.0], [-1, 0, 1.0], [0, 1, 1.0], [0, -1, 1.0], [1, 1, 1.414], [1, -1, 1.414], [-1, 1, 1.414], [-1, -1, 1.414]]
	while open.size():
		var bi := 0
		for i in range(1, open.size()):
			if open[i].f < open[bi].f:
				bi = i
		var cur: Dictionary = open[bi]
		open.remove_at(bi)
		cnt += 1
		if cnt > limit:
			return null
		if cur.x == gx and cur.y == gy:
			var path: Array = []
			var k: int = key.call(cur.x, cur.y)
			var cx: int = cur.x
			var cy: int = cur.y
			while came.has(k):
				path.append(Vector2i(cx, cy))
				var p: Vector2i = came[k]
				cx = p.x
				cy = p.y
				k = key.call(cx, cy)
			path.reverse()
			return path
		var ck: int = key.call(cur.x, cur.y)
		var cg: float = gs.get(ck, -1.0)
		if cg < 0:
			continue
		for d in dirs:
			var nx: int = cur.x + int(d[0])
			var ny: int = cur.y + int(d[1])
			if not walk(nx, ny):
				continue
			if int(d[0]) != 0 and int(d[1]) != 0 and (not walk(cur.x + int(d[0]), cur.y) or not walk(cur.x, cur.y + int(d[1]))):
				continue
			var nk: int = key.call(nx, ny)
			var ng: float = cg + float(d[2])
			if gs.has(nk) and float(gs[nk]) <= ng:
				continue
			gs[nk] = ng
			came[nk] = Vector2i(cur.x, cur.y)
			open.append({"x": nx, "y": ny, "f": ng + Cfg.hypot(nx - gx, ny - gy)})
	return null


func path_to_world(tiles) -> Array:
	if tiles == null:
		return []
	var pts: Array = []
	for t in tiles:
		pts.append({"x": Cfg.wx(t.x), "z": Cfg.wx(t.y)})
	var out: Array = []
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i:
			if los_free(pts[i].x, pts[i].z, pts[j].x, pts[j].z):
				break
			j -= 1
		out.append(pts[j])
		i = i + 1 if j == i else j
	return out


func los_free(ax: float, az: float, bx: float, bz: float) -> bool:
	var dx := bx - ax
	var dz := bz - az
	var d: float = Cfg.hypot(dx, dz)
	var n := int(ceil(d / 0.5))
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		if not can_stand(ax + dx * t, az + dz * t, 0.45):
			return false
	return true


func walk_to(x: float, z: float) -> void:
	var path = find_path(Cfg.tx(Game.P.x), Cfg.tz(Game.P.z), Cfg.tx(x), Cfg.tz(z))
	if path == null:
		return
	Game.P.path = path_to_world(path)
	if Game.P.path.is_empty() and can_stand(x, z, 0.45):
		Game.P.path = [{"x": x, "z": z}]


func gen_town(area: Dictionary) -> void:
	Cfg.seed_rng(int(area.get("seed", 99)))
	var houses: Array = area.get("houses", Data.TOWN_HOUSES)
	var M := Cfg.MAP
	var g := PackedByteArray()
	g.resize(M * M)
	var c := M >> 1
	var hw := 20
	var hh := 15
	for y in range(c - hh, c + hh + 1):
		for x in range(c - hw, c + hw + 1):
			var dx := float(x - c) / hw
			var dy := float(y - c) / hh
			if dx * dx + dy * dy < 1.08:
				g[Cfg.gi(x, y)] = 1
	for h in houses:
		for yy in range(c + int(h[1]), c + int(h[1]) + int(h[3])):
			for xx in range(c + int(h[0]), c + int(h[0]) + int(h[2])):
				if xx > 0 and yy > 0 and xx < M and yy < M:
					g[Cfg.gi(xx, yy)] = 0
	var paint := PackedByteArray()
	paint.resize(M * M)
	for y in M:
		for x in M:
			if g[Cfg.gi(x, y)]:
				paint[Cfg.gi(x, y)] = 1
	for x in range(c - 14, c + 15):
		for d in range(-1, 2):
			if g[Cfg.gi(x, c + d)]:
				paint[Cfg.gi(x, c + d)] = 2
	for y in range(c - 10, c + 11):
		for d in range(-1, 2):
			if g[Cfg.gi(c + d, y)]:
				paint[Cfg.gi(c + d, y)] = 2
	for y in range(c - 5, c + 6):
		for x in range(c - 5, c + 6):
			if g[Cfg.gi(x, y)]:
				paint[Cfg.gi(x, y)] = 3
	W.grid = g
	W.paint = paint
	W.rooms = [{"x": c - hw, "y": c - hh, "w": hw * 2, "h": hh * 2, "cx": c, "cy": c}]
	reset_explored(1)


func protect_marks(g: PackedByteArray, area: Dictionary, rad: int) -> Array:
	var M := Cfg.MAP
	var c := M >> 1
	var pts: Array = [Vector2i(c, c)]
	for m in area.get("marks", []):
		pts.append(Vector2i(Cfg.tx(m.x), Cfg.tz(m.z)))
	for p in pts:
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var xx: int = p.x + dx
				var yy: int = p.y + dy
				if xx > 0 and yy > 0 and xx < M - 1 and yy < M - 1:
					g[Cfg.gi(xx, yy)] = 1
	return pts


func carve_road(g: PackedByteArray, paint: PackedByteArray, x0: int, y0: int, x1: int, y1: int, code: int) -> void:
	var M := Cfg.MAP
	var x := x0
	var y := y0
	var guard := 0
	while guard < 480:
		guard += 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var xx := clampi(x + dx, 1, M - 2)
				var yy := clampi(y + dy, 1, M - 2)
				g[Cfg.gi(xx, yy)] = 1
				if (dx | dy) == 0 or abs(dx) + abs(dy) == 1:
					paint[Cfg.gi(xx, yy)] = code
		if x == x1 and y == y1:
			break
		if x != x1 and (y == y1 or ((x + y) & 1)):
			x += 1 if x1 > x else -1
		elif y != y1:
			y += 1 if y1 > y else -1
		else:
			x += 1 if x1 > x else -1


func punch_holes(g: PackedByteArray, keep: Array, n: int, rmin: int, rmax: int, safe: int) -> void:
	var M := Cfg.MAP
	for _i in n:
		var cx := Cfg.ri(6, M - 7)
		var cy := Cfg.ri(6, M - 7)
		var r := Cfg.ri(rmin, rmax)
		var skip := false
		for k in keep:
			if Cfg.hypot(cx - k.x, cy - k.y) < safe:
				skip = true
				break
		if skip:
			continue
		for y in range(cy - r, cy + r + 1):
			for x in range(cx - r, cx + r + 1):
				if x < 1 or y < 1 or x >= M - 1 or y >= M - 1:
					continue
				if Cfg.hypot(x - cx, y - cy) <= r + n2(x, y) * 0.6:
					g[Cfg.gi(x, y)] = 0


func gen_field(area: Dictionary) -> void:
	Cfg.seed_rng(int(area.seed) * 2654435761 & 0xFFFFFFFF)
	nseed = int(area.get("seed", 1))
	var M := Cfg.MAP
	var g := PackedByteArray()
	g.resize(M * M)
	var paint := PackedByteArray()
	paint.resize(M * M)
	var c := M >> 1
	var shape: String = area.get("shape", area.id)
	if shape == "wood":
		for y in range(4, M - 4):
			for x in range(4, M - 4):
				var dx := float(x - c) / (M / 2.0 - 5)
				var dy := float(y - c) / (M / 2.0 - 5)
				var blob := n2(x * 0.13, y * 0.13) * 0.24 + n2(x * 0.31, y * 0.27) * 0.1
				if dx * dx + dy * dy < 0.86 + blob:
					g[Cfg.gi(x, y)] = 1
	elif shape == "ash":
		for y in range(5, M - 5):
			for x in range(4, M - 4):
				var dx := float(x - c) / (M / 2.0 - 4)
				var dy := float(y - c) / (M / 2.0 - 7)
				var ridge: bool = absf(dy) > 0.52 + 0.1 * sin(x * 0.28)
				if dx * dx * 0.62 + dy * dy * 1.65 < 1.02 and not ridge:
					g[Cfg.gi(x, y)] = 1
	elif shape == "frost":
		for y in range(4, M - 4):
			for x in range(4, M - 4):
				var dx := float(x - c) / (M / 2.0 - 5)
				var dy := float(y - c) / (M / 2.0 - 5)
				var r2 := dx * dx + dy * dy
				var n := n2(x * 0.2, y * 0.2)
				if r2 < 1.02 + n * 0.05 and r2 > 0.26 + n * 0.04:
					g[Cfg.gi(x, y)] = 1
					paint[Cfg.gi(x, y)] = 1
				elif r2 <= 0.26 + n * 0.04 and r2 < 0.95:
					paint[Cfg.gi(x, y)] = 11
		for y in range(c - 14, c + 15):
			for x in range(c - 1, c + 2):
				g[Cfg.gi(x, y)] = 1
				paint[Cfg.gi(x, y)] = 5
	elif shape == "shore":
		for y in range(2, M - 2):
			for x in range(4, M - 4):
				var dx := float(x - c) / (M / 2.0 - 4)
				var dy := float(y - c) / (M / 2.0 - 4)
				var coast := c + 4 + int(round(sin(x * 0.21) * 6 + sin(x * 0.07) * 3 + n2(x, y) * 2))
				if y < coast and dx * dx + dy * dy * 1.2 < 1.14:
					g[Cfg.gi(x, y)] = 1
					paint[Cfg.gi(x, y)] = 7 if y > coast - 5 else 1
	elif shape == "sink":
		for y in range(5, M - 5):
			for x in range(5, M - 5):
				var dx := float(x - c) / (M / 2.0 - 6)
				var dy := float(y - c) / (M / 2.0 - 6)
				if dx * dx * 1.15 + dy * dy * 0.9 < 0.78 + n2(x * 0.17, y * 0.19) * 0.28:
					g[Cfg.gi(x, y)] = 1
	elif shape == "shaft":
		for y in range(4, M - 4):
			for x in range(c - 7, c + 8):
				var w := 3 + int(round(sin(y * 0.22) * 2 + n2(x, y) * 1.5))
				if abs(x - c) <= w:
					g[Cfg.gi(x, y)] = 1
	else:
		for y in range(4, M - 4):
			for x in range(4, M - 4):
				var dx := float(x - c) / (M / 2.0 - 4)
				var dy := float(y - c) / (M / 2.0 - 5)
				if dx * dx * 0.88 + dy * dy * 1.12 < 1.0 + n2(x * 0.16, y * 0.16) * 0.08:
					g[Cfg.gi(x, y)] = 1
	var keep := protect_marks(g, area, 4)
	if shape == "wood":
		punch_holes(g, keep, 200, 1, 3, 6)
	elif shape == "frost" or shape == "shore":
		punch_holes(g, keep, 50, 1, 2, 8)
	elif shape == "ash":
		punch_holes(g, keep, 40, 1, 2, 8)
	elif shape == "shaft":
		punch_holes(g, keep, 18, 1, 2, 7)
	elif shape == "sink":
		punch_holes(g, keep, 90, 1, 3, 6)
	else:
		punch_holes(g, keep, 90, 1, 3, 7)
	protect_marks(g, area, 3)
	for i in keep.size():
		var a: Vector2i = keep[i]
		var b: Vector2i = keep[(i + 1) % keep.size()]
		carve_road(g, paint, a.x, a.y, b.x, b.y, 2)
	for i in M:
		g[Cfg.gi(i, 0)] = 0
		g[Cfg.gi(i, M - 1)] = 0
		g[Cfg.gi(0, i)] = 0
		g[Cfg.gi(M - 1, i)] = 0
	for y in range(1, M - 1):
		for x in range(1, M - 1):
			if g[Cfg.gi(x, y)] == 0 or paint[Cfg.gi(x, y)]:
				continue
			if shape == "wood":
				paint[Cfg.gi(x, y)] = 4
			elif shape == "ash":
				paint[Cfg.gi(x, y)] = 6
			elif shape == "shaft":
				paint[Cfg.gi(x, y)] = 3
			else:
				paint[Cfg.gi(x, y)] = 4 if n2(x, y) > 0.72 else 1
	W.grid = g
	W.paint = paint
	W.rooms = [{"x": c - 10, "y": c - 10, "w": 20, "h": 20, "cx": c, "cy": c}]
	reset_explored(0)


func gen_rooms(seed: int) -> void:
	Cfg.seed_rng(seed)
	var M := Cfg.MAP
	var g := PackedByteArray()
	g.resize(M * M)
	var rooms: Array = []
	var a := 0
	while a < 420 and rooms.size() < 13:
		a += 1
		var w := Cfg.ri(7, 14)
		var h := Cfg.ri(7, 13)
		var x := Cfg.ri(3, M - w - 4)
		var y := Cfg.ri(3, M - h - 4)
		var ok := true
		for r in rooms:
			if abs(x + w * 0.5 - (r.x + r.w * 0.5)) < (w + r.w) * 0.5 + 1 and abs(y + h * 0.5 - (r.y + r.h * 0.5)) < (h + r.h) * 0.5 + 1:
				ok = false
				break
		if not ok:
			continue
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				g[Cfg.gi(xx, yy)] = 1
		rooms.append({"x": x, "y": y, "w": w, "h": h, "cx": x + int(w / 2), "cy": y + int(h / 2)})
	for i in range(1, rooms.size()):
		_corr(g, rooms[i - 1].cx, rooms[i - 1].cy, rooms[i].cx, rooms[i].cy)
	for i in M:
		g[Cfg.gi(i, 0)] = 0
		g[Cfg.gi(i, M - 1)] = 0
		g[Cfg.gi(0, i)] = 0
		g[Cfg.gi(M - 1, i)] = 0
	var paint := PackedByteArray()
	paint.resize(M * M)
	for y in M:
		for x in M:
			if g[Cfg.gi(x, y)] == 0:
				continue
			var in_room := false
			for r in rooms:
				if x >= r.x + 1 and x < r.x + r.w - 1 and y >= r.y + 1 and y < r.y + r.h - 1:
					in_room = true
					break
			paint[Cfg.gi(x, y)] = 3 if in_room else 1
	W.grid = g
	W.paint = paint
	W.rooms = rooms
	reset_explored(0)


func _corr(g: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> void:
	var M := Cfg.MAP
	var put := func(a: int, b: int):
		for dy in 2:
			for dx in 2:
				g[Cfg.gi(clampi(a + dx, 1, M - 2), clampi(b + dy, 1, M - 2))] = 1
	var x := x0
	var y := y0
	if Cfg._rng.randf() < 0.5:
		while x != x1:
			put.call(x, y)
			x += 1 if x1 > x else -1
		while y != y1:
			put.call(x, y)
			y += 1 if y1 > y else -1
	else:
		while y != y1:
			put.call(x, y)
			y += 1 if y1 > y else -1
		while x != x1:
			put.call(x, y)
			x += 1 if x1 > x else -1
	put.call(x1, y1)


func floor_depth() -> int:
	if str(W.area.get("kind", "")) == "rift":
		return int(W.get("riftDepth", 1))
	if W.dun:
		return int(W.get("dunFloor", 1)) + maxi(0, int(floor(float(W.dun.get("lvl", 1)) / 8.0)))
	return 1


func floor_lvl() -> int:
	if str(W.area.get("kind", "")) == "rift":
		return int(round(2.0 + float(W.get("riftDepth", 1)) * 1.7))
	if W.dun:
		return int(W.dun.lvl) + int(W.get("dunFloor", 1)) - 1
	return maxi(1, int(Game.P.lvl))


func in_room_tile(r: Dictionary, x: float, z: float) -> bool:
	var gx := Cfg.tx(x)
	var gz := Cfg.tz(z)
	return gx >= int(r.x) and gx < int(r.x) + int(r.w) and gz >= int(r.y) and gz < int(r.y) + int(r.h)


func clear_floor_buffs() -> void:
	var had: bool = Game.P.buffs.has("greed") or Game.P.buffs.has("swift") or Game.P.buffs.has("plenty")
	Game.P.buffs.erase("greed")
	Game.P.buffs.erase("swift")
	Game.P.buffs.erase("plenty")
	W.shrine = null
	W.shrineRare = 0
	W.traps = []
	W.roomTags = []
	_zones.clear()
	if had and str(Game.P.get("cls", "")) != "":
		Game.refresh_max(false)


func tag_special_rooms() -> void:
	W.roomTags = []
	W.traps = []
	W.shrine = null
	W.shrineRare = 0
	var rooms: Array = W.rooms
	if rooms.size() < 3:
		return
	var mid: Array = []
	for i in range(1, rooms.size() - 1):
		mid.append(i)
	if mid.is_empty():
		return
	var depth := floor_depth()
	var n: int = 2 if Cfg._rng.randf() < (0.2 + minf(0.48, float(depth) * 0.045)) else 1
	var kinds: Array = Data.ROOM_KINDS.duplicate()
	var k := 0
	while k < n and mid.size() and kinds.size():
		var ii := Cfg._rng.randi_range(0, mid.size() - 1)
		var idx: int = mid[ii]
		mid.remove_at(ii)
		var ki := Cfg._rng.randi_range(0, kinds.size() - 1)
		var kind: String = str(kinds[ki])
		kinds.remove_at(ki)
		rooms[idx].tag = kind
		W.roomTags.append({"i": idx, "kind": kind})
		k += 1


func decorate_room(r: Dictionary, lvl: int, mobs: Array) -> bool:
	if r.is_empty() or str(r.get("tag", "")) == "":
		return false
	var tag: String = str(r.tag)
	if tag == "vault":
		_fill_vault(r, lvl, mobs)
	elif tag == "shrine":
		_fill_shrine(r)
	elif tag == "cage":
		_fill_cage(r)
	elif tag == "trap":
		_fill_trap(r)
	return true


func _place_prop(id: String, x: float, z: float, fallback_hex: int = 0xb8943a) -> Node3D:
	var used_fallback := not Assets.has(id)
	var g: Node3D = Assets.make_prop(id)
	if g == null:
		g = Node3D.new()
	elif used_fallback:
		Assets.tint(g, fallback_hex)
	g.position.x = x
	g.position.z = z
	g.rotation.y = Cfg._rng.randf() * TAU
	if world_root:
		world_root.add_child(g)
	return g


func _fill_vault(r: Dictionary, lvl: int, mobs: Array) -> void:
	var cx := Cfg.wx(r.cx)
	var cz := Cfg.wx(r.cy)
	var ox: float = minf(3.2, (float(r.w) - 3.0) * Cfg.TILE * 0.35)
	var oz: float = minf(3.2, (float(r.h) - 3.0) * Cfg.TILE * 0.35)
	for d in [Vector2(-ox, -oz), Vector2(ox, -oz), Vector2(-ox, oz), Vector2(ox, oz)]:
		var x: float = cx + d.x
		var z: float = cz + d.y
		if can_stand(x, z, 0.5):
			_place_prop("prop_chest_gold", x, z)
		else:
			_place_prop("prop_chest_gold", cx + Cfg.rf(-1.2, 1.2), cz + Cfg.rf(-1.2, 1.2))
	var pack := Cfg.ri(3, 4)
	var pool: Array = mobs if mobs.size() else Data.RIFT_MOBS
	for i in pack:
		var x: float = cx + Cfg.rf(-2.2, 2.2)
		var z: float = cz + Cfg.rf(-2.2, 2.2)
		if not can_stand(x, z, 0.6):
			continue
		spawn_enemy(str(Cfg.pick(pool)), x, z, (lvl if lvl else floor_lvl()) + 1, i == 0)
	add_mark({"kind": "event", "label": "宝库", "x": cx, "z": cz, "color": 0xe2c47f, "use": false})


func _fill_shrine(r: Dictionary) -> void:
	var x := Cfg.wx(r.cx)
	var z := Cfg.wx(r.cy)
	_place_prop("prop_candelabrum", x, z, 0x8a6ad0)
	add_mark({"kind": "shrine", "label": "祭坛", "x": x, "z": z, "color": 0x8a6ad0})


func _fill_cage(r: Dictionary) -> void:
	var x := Cfg.wx(r.cx)
	var z := Cfg.wx(r.cy)
	_place_prop("prop_bars", x, z, 0xc8a060)
	add_mark({"kind": "cage", "label": "囚笼", "x": x, "z": z, "color": 0xc8a060})


func _fill_trap(r: Dictionary) -> void:
	r.trap = str(Cfg.pick(["spike", "rock", "fog"]))
	r.trapDone = false
	r.trapIn = 0.0
	r.trapTick = 0.0
	W.traps.append(r)
	var x := Cfg.wx(r.cx)
	var z := Cfg.wx(r.cy)
	for i in 4:
		var ang: float = float(i) * PI / 2.0 + 0.35
		var rad: float = minf(float(r.w), float(r.h)) * 0.5
		_place_prop("prop_rock%d" % (1 + i % 5), x + cos(ang) * rad, z + sin(ang) * rad, 0x8a7a62)
	add_mark({"kind": "event", "label": "陷阱厅", "x": x, "z": z, "color": 0xa83a2b, "use": false})


func pick_shrine(id: String, m: Dictionary) -> void:
	if str(W.get("shrine", "")) != "":
		Game.hint("这一层已经许过了")
		return
	var def: Dictionary = Data.shrine_pick_by_id(id)
	if def.is_empty():
		return
	W.shrine = id
	Game.P.buffs[id] = {"t": 1.0e9, "v": 1, "floor": 1}
	if id == "plenty":
		W.shrineRare = 1
		_shrine_plenty()
	if id == "swift":
		Game.refresh_max(false)
	if not m.is_empty():
		m.kind = "event"
		m.use = false
		m.label = "祭坛"
		if m.get("label_node"):
			m.label_node.text = "祭坛"
	Sfx.cast()
	Game.say("你许了：%s。这一层都算数。" % def.n)
	Game.hint(str(def.n))


func _shrine_plenty() -> void:
	var live := 0
	for e in W.enemies:
		if not e.get("dead") and not e.get("boss") and not e.get("ally") and not e.get("hoard"):
			live += 1
	var extra := maxi(4, int(round(float(live) * 0.5)))
	var rooms: Array = W.rooms.slice(1) if W.rooms.size() > 1 else W.rooms
	var mobs: Array = Data.RIFT_MOBS
	if str(W.area.get("kind", "")) != "rift" and W.dun:
		mobs = W.dun.mobs
	var L := floor_lvl()
	var n := 0
	var t := 0
	while t < 90 and n < extra:
		t += 1
		if rooms.is_empty():
			break
		var r: Dictionary = Cfg.pick(rooms)
		var x := Cfg.wx(Cfg.ri(int(r.x) + 1, int(r.x) + int(r.w) - 2)) + Cfg.rf(-0.6, 0.6)
		var z := Cfg.wx(Cfg.ri(int(r.y) + 1, int(r.y) + int(r.h) - 2)) + Cfg.rf(-0.6, 0.6)
		if not can_stand(x, z, 0.6):
			continue
		spawn_enemy(str(Cfg.pick(mobs)), x, z, L, false)
		n += 1
	Game.hint("又涌出来一批")


func release_cage(m: Dictionary) -> void:
	if m.is_empty() or m.get("used"):
		return
	for e in W.enemies:
		if e.get("ally") and not e.get("dead"):
			Game.hint("已经有人跟着你")
			return
	m.used = true
	m.kind = "event"
	m.use = false
	m.label = "空笼"
	if m.get("label_node"):
		m.label_node.text = "空笼"
	var L := floor_lvl()
	var x: float = float(m.x) + 1.2
	var z: float = float(m.z)
	if not can_stand(x, z, 0.6):
		x = float(m.x)
		z = float(m.z) + 1.2
	var e := spawn_enemy("bandit", x, z, L, false)
	e.ally = true
	e.name = str(Cfg.pick(["还记得路的", "不肯散的一个", "跟着走的"]))
	e.allyT = 60.0
	e.mods = []
	e.elite = false
	e.hpMax = round(e.hpMax * 1.9)
	e.hp = e.hpMax
	e.dmg = [round(e.dmg[0] * 1.25), round(e.dmg[1] * 1.25)]
	e.speed = float(e.speed) * 1.15
	e.range = 2.1
	e.ranged = false
	e.riftDr = 0
	_show_bar(e, true)
	Game.say("你替他记了名字。他跟着你，六十秒。")
	Game.hint("有人跟着你")
	Sfx.quest()


func ally_leave(e: Dictionary, txt: String = "忘了") -> void:
	if e.is_empty() or e.get("dead"):
		return
	e.dead = true
	e.dieT = 0.0
	e.escaped = true
	_show_bar(e, false)
	Game.float_at(e.x, 3.0, e.z, txt, Color(0.78, 0.63, 0.38), 16)
	Game.hint("跟着你的人散了")


func rift_hoard_escape(e: Dictionary) -> void:
	if e.is_empty() or e.get("dead"):
		return
	e.dead = true
	e.dieT = 0.0
	e.escaped = true
	_show_bar(e, false)
	Game.float_at(e.x, 3.0, e.z, "跑了", Color(0.89, 0.77, 0.5), 16)
	Game.hint("揣着东西的跑了")


func spawn_rift_hoard(lvl: int) -> void:
	var rooms: Array = []
	for i in range(1, maxi(1, W.rooms.size() - 1)):
		var r: Dictionary = W.rooms[i]
		if str(r.get("tag", "")) == "":
			rooms.append(r)
	var r: Dictionary = rooms[int(rooms.size() / 2)] if rooms.size() else (W.rooms[1] if W.rooms.size() > 1 else {})
	if r.is_empty():
		return
	var x := Cfg.wx(r.cx)
	var z := Cfg.wx(r.cy)
	var ok := can_stand(x, z, 0.6)
	if not ok:
		for _t in 24:
			x = Cfg.wx(Cfg.ri(int(r.x) + 1, int(r.x) + int(r.w) - 2))
			z = Cfg.wx(Cfg.ri(int(r.y) + 1, int(r.y) + int(r.h) - 2))
			ok = can_stand(x, z, 0.6)
			if ok:
				break
	if not ok:
		return
	var e := spawn_enemy("imp", x, z, lvl + 2, false)
	e.hoard = true
	e.hoardX = x
	e.hoardZ = z
	e.riftDr = 0
	e.name = "揣着东西的"
	e.speed = float(e.speed) * 1.72
	e.hpMax = round(e.hpMax * 2.4)
	e.hp = e.hpMax
	e.range = 0.15
	e.ranged = false
	_show_bar(e, true)
	Game.hint("有人揣着东西在跑")


func clear_actors() -> void:
	if actors_root:
		for c in actors_root.get_children():
			c.queue_free()
	W.enemies.clear()
	W.npcs.clear()
	W.marks.clear()
	W.items.clear()
	W.boss = null
	W.event = null
	_proj.clear()
	_marks_nodes.clear()
	_clear_fx_props()


func _clear_fx_props() -> void:
	var walls = W.get("walls", [])
	if typeof(walls) == TYPE_ARRAY:
		for w in walls:
			if w.get("mesh"):
				w.mesh.queue_free()
	W.walls = []
	W.torches = []
	_zones.clear()
	if typeof(Game.P.get("up")) == TYPE_DICTIONARY:
		var nails = Game.P.up.get("nails")
		if typeof(nails) == TYPE_ARRAY:
			for n in nails:
				if n.get("mesh"):
					n.mesh.queue_free()
		Game.P.up.nails = []


func enter_area(id: String, arrive: String = "") -> void:
	var a: Dictionary = Data.AREA.get(id, {})
	if a.is_empty():
		Game.hint("没有这条路")
		return
	var from_id := str(W.get("arrive_from", ""))
	if from_id == "":
		from_id = str(W.area.get("id", ""))
	var mode := arrive if arrive != "" else str(W.get("arrive_mode", "gate"))
	W.arrive_mode = "gate"
	W.arrive_from = ""
	clear_floor_buffs()
	clear_actors()
	W.area = a
	W.dun = null
	var first_gate: bool = a.kind == "town" and mode == "gate" and Game.P.flags.get("seenGate_" + id, false) != true
	W.discovered[id] = true
	var pal: Dictionary = Game.pal_for_diff(a.pal)
	if a.kind == "town":
		Game.P.hub = a.id
		gen_town(a)
		rebuild_meshes(pal, false)
		_build_town_props(a)
		spawn_npcs()
		for ex in a.get("exits", []):
			if str(ex.get("kind", "")) == "rift":
				var rx := float(ex.get("x", -8.0))
				var rz := float(ex.get("z", 22.0))
				add_mark({"kind": "rift", "label": ex.label, "x": rx, "z": rz})
			else:
				var gx := float(ex.get("x", 34.0))
				var gz := float(ex.get("z", 6.0))
				add_mark({"kind": "travel", "to": ex.to, "label": ex.label, "x": gx, "z": gz})
				_build_gate_posts(gx, gz)
		if mode == "well":
			var well := town_well_pos()
			place_stand(well.x + 2.4, well.y)
		else:
			var gate := town_gate_for(a, from_id)
			var sp := town_gate_spawn(gate)
			place_stand(sp.x, sp.y)
		Game.refresh_stock()
		Game.zone_changed.emit(a.n, "安全区 · 第 %d 章据点" % int(a.get("ch", 1)))
		if first_gate:
			Game.P.flags["seenGate_" + id] = true
			Game.say(_town_gate_line(str(a.id), a.n))
		elif mode == "well":
			Game.say("你在%s的井边醒来。" % a.n)
		else:
			Game.say("你到了%s。" % a.n)
	else:
		gen_field(a)
		rebuild_meshes(pal, false)
		for m in a.get("marks", []):
			add_mark(m.duplicate())
		populate_field(a)
		var back: Dictionary = {}
		for m in a.get("marks", []):
			if m.kind == "travel" and (from_id == "" or str(m.get("to", "")) == from_id):
				back = m
				break
		if back.is_empty():
			for m in a.get("marks", []):
				if m.kind == "travel":
					back = m
					break
		place_player((back.x + 3) if not back.is_empty() else 0.0, (back.z - 3) if not back.is_empty() else 0.0)
		Game.zone_changed.emit(a.n, "野外 · 推荐等级 %d" % int(a.lvl))
		Game.say("你进入了%s。" % a.n)
		maybe_field_event()
	_spawn_player_view()
	Game.hint(a.n)
	Game.save_soon()
	Game.ach_check()
	Game.ui_refresh.emit()


func enter_dungeon(id: String, floor: int = 1) -> void:
	var d := Data.dun_by_id(id)
	if d.is_empty():
		return
	Game.clear_rift_mods()
	clear_floor_buffs()
	clear_actors()
	W.dun = d
	W.dunFloor = floor
	W.area = {"id": id, "n": d.n, "kind": "dungeon", "lvl": d.lvl, "ch": Data.AREA.get(d.from, {}).get("ch", 1)}
	W.discovered[id] = true
	gen_rooms(int(0xa11ce ^ (id.length() * 7919) ^ (floor * 2654435761)))
	tag_special_rooms()
	var pal_key: String = d.get("pal", "")
	var pal: Dictionary = Data.DUN_PAL[pal_key] if Data.DUN_PAL.has(pal_key) else Data.RIFT_PAL
	rebuild_meshes(Game.pal_for_diff(pal), true)
	var lvl := int(d.lvl) + floor - 1
	var is_last: bool = floor >= int(d.floors)
	if W.rooms.size():
		place_player(Cfg.wx(W.rooms[0].cx), Cfg.wx(W.rooms[0].cy))
	else:
		place_player(0, 0)
	for i in range(1, W.rooms.size()):
		var r: Dictionary = W.rooms[i]
		if decorate_room(r, lvl, d.mobs):
			continue
		var n := Cfg.ri(3, 6)
		for _j in n:
			var x := Cfg.wx(Cfg.ri(int(r.x) + 1, int(r.x) + int(r.w) - 2)) + Cfg.rf(-0.6, 0.6)
			var z := Cfg.wx(Cfg.ri(int(r.y) + 1, int(r.y) + int(r.h) - 2)) + Cfg.rf(-0.6, 0.6)
			if not can_stand(x, z, 0.6):
				continue
			spawn_enemy(str(Cfg.pick(d.mobs)), x, z, lvl, Cfg._rng.randf() < Game.elite_chance(floor))
	var last: Dictionary = W.rooms[W.rooms.size() - 1] if W.rooms.size() else {"cx": Cfg.MAP >> 1, "cy": Cfg.MAP >> 1}
	if is_last:
		var boss := spawn_enemy(d.boss, Cfg.wx(last.cx) + 3, Cfg.wx(last.cy) + 3, lvl + 2, false)
		if str(d.id) == "crypt" and not boss.is_empty():
			boss.sekhra = true
			boss.phase = 1
			boss.shout = true
			boss.callName = "孩子"
			boss.childName = "莉赛尔"
			boss.shoutCd = 3.0
			boss.name = "白骨女王 · 塞克拉"
			boss.skill = "slam"
			boss.ranged = false
			boss.range = 3.0
			boss.speed = 2.3
	else:
		add_mark({"kind": "next", "label": "下一层", "x": Cfg.wx(last.cx), "z": Cfg.wx(last.cy)})
	var first: Dictionary = W.rooms[0] if W.rooms.size() else last
	add_mark({"kind": "exit", "label": "离开副本", "x": Cfg.wx(first.cx) + 3, "z": Cfg.wx(first.cy) + 3})
	if is_last:
		add_mark({"kind": "exit", "label": "离开副本", "x": Cfg.wx(last.cx) - 4, "z": Cfg.wx(last.cy) - 4})
	_spawn_player_view()
	Game.zone_changed.emit(d.n, "副本 %d / %d 层 · 怪物等级 %d" % [floor, int(d.floors), lvl])
	Game.say("你进入了%s。" % d.n)
	if W.roomTags.size():
		Game.say("这一层有房间不对劲。")
	Sfx.portal()
	Game.ui_refresh.emit()
	Game.save_soon()


func enter_rift(depth: int) -> void:
	Game.take_rift_offer(depth)
	clear_floor_buffs()
	clear_actors()
	W.usedPot = false
	if typeof(Game.P.flags) != TYPE_DICTIONARY:
		Game.P.flags = {}
	Game.P.flags.enteredRift = true
	W.riftDepth = depth
	W.riftDeepest = maxi(int(W.get("riftDeepest", 0)), depth)
	Game.ach_check()
	W.dun = null
	W.area = {"id": "rift", "n": "裂隙 第 %s 层" % Cfg.roman(depth), "kind": "rift", "lvl": int(round(2.0 + float(depth) * 1.7))}
	gen_rooms(int(0x5f3a ^ (depth * 2654435761)))
	tag_special_rooms()
	rebuild_meshes(Game.pal_for_diff(Data.RIFT_PAL), true)
	var lvl := int(round(2.0 + float(depth) * 1.7))
	for i in range(1, W.rooms.size()):
		var r: Dictionary = W.rooms[i]
		if decorate_room(r, lvl, Data.RIFT_MOBS):
			continue
		var n := Cfg.ri(2, 4 + mini(4, depth))
		if Game.rift_has("swarm"):
			n = maxi(1, int(round(float(n) * 1.6)))
		for _j in n:
			var x := Cfg.wx(Cfg.ri(int(r.x) + 1, int(r.x) + int(r.w) - 2)) + Cfg.rf(-0.6, 0.6)
			var z := Cfg.wx(Cfg.ri(int(r.y) + 1, int(r.y) + int(r.h) - 2)) + Cfg.rf(-0.6, 0.6)
			if not can_stand(x, z, 0.6):
				continue
			spawn_enemy(str(Cfg.pick(Data.RIFT_MOBS)), x, z, lvl, Cfg._rng.randf() < Game.elite_chance(depth))
	if depth % 3 == 0 and W.rooms.size():
		var r: Dictionary = W.rooms[W.rooms.size() - 1]
		var bi: int = (int(floor(float(depth) / 3.0)) - 1) % Data.RIFT_BOSSES.size()
		spawn_enemy(str(Data.RIFT_BOSSES[bi]), Cfg.wx(r.cx) + 3, Cfg.wx(r.cy) + 3, lvl + 2, false)
	if Game.rift_has("hoard"):
		spawn_rift_hoard(lvl)
	if W.rooms.size():
		place_player(Cfg.wx(W.rooms[0].cx), Cfg.wx(W.rooms[0].cy))
		var last: Dictionary = W.rooms[W.rooms.size() - 1]
		add_mark({"kind": "next", "label": "通往第 %s 层" % Cfg.roman(depth + 1), "x": Cfg.wx(last.cx), "z": Cfg.wx(last.cy)})
		var first: Dictionary = W.rooms[0]
		add_mark({"kind": "exit", "label": "回镇", "x": Cfg.wx(first.cx) + 3, "z": Cfg.wx(first.cy) + 3})
	_spawn_player_view()
	if Game.set_on("rift", 5):
		Game.P.buffs.setdr = {"t": 8.0, "v": 25}
		Game.float_at(Game.P.x, 2.6, Game.P.z, "行者", Color(0.12, 1, 0), 16)
	var tags: PackedStringArray = []
	for rid in W.get("riftMods", []):
		var a: Dictionary = Data.rift_affix_by_id(str(rid))
		if not a.is_empty():
			tags.append(str(a.n))
	var loot := Game.rift_loot_of(W.get("riftMods", []))
	var sub := "无限地下层 · 怪物等级 %d" % lvl
	if tags.size():
		sub = " · ".join(tags) + " · 掉落 +%d%%" % loot
	Game.zone_changed.emit(W.area.n, sub)
	Game.hint("裂隙 第 %s 层%s" % [Cfg.roman(depth), (" · " + "、".join(tags)) if tags.size() else ""])
	if tags.size():
		Game.say("这一层带着：%s。掉落 +%d%%。" % [" · ".join(tags), loot])
	elif depth % 3 == 0:
		Game.say("这一层有东西在等你。")
	else:
		Game.say("你下到裂隙第 %d 层。" % depth)
	if W.roomTags.size():
		Game.say("这一层有房间不对劲。")
	Sfx.portal()
	Game.ui_refresh.emit()
	Game.save_soon()


func populate_field(a: Dictionary) -> void:
	var made := 0
	var i := 0
	while i < 280 and made < 32:
		i += 1
		var x := Cfg.rf(-52, 52)
		var z := Cfg.rf(-52, 52)
		if not can_stand(x, z, 0.7):
			continue
		var near_mark := false
		for m in W.marks:
			if Cfg.dist2(m.x, m.z, x, z) < 81:
				near_mark = true
				break
		if near_mark:
			continue
		spawn_enemy(str(Cfg.pick(a.mobs)), x, z, maxi(1, int(a.lvl) + Cfg.ri(-1, 2)), Cfg._rng.randf() < Game.elite_chance(0))
		made += 1
	for _c in 7:
		var cx := 0.0
		var cz := 0.0
		var ok := false
		for _t in 40:
			cx = Cfg.rf(-46, 46)
			cz = Cfg.rf(-46, 46)
			ok = can_stand(cx, cz, 1.2)
			if ok:
				break
		if not ok:
			continue
		var n := Cfg.ri(4, 6)
		for j in n:
			var x := cx + Cfg.rf(-3.2, 3.2)
			var z := cz + Cfg.rf(-3.2, 3.2)
			if can_stand(x, z, 0.7):
				spawn_enemy(str(Cfg.pick(a.mobs)), x, z, maxi(1, int(a.lvl) + Cfg.ri(0, 2)), j == 0, [], {"noPack": true})
	spawn_field_uniques(a)


func spawn_enemy(type: String, x: float, z: float, lvl: int, elite: bool, force_mods = null, opt = null) -> Dictionary:
	var t: Dictionary = Data.ETYPES.get(type, {})
	if t.is_empty():
		return {}
	if opt == null:
		opt = {}
	if force_mods == null:
		force_mods = []
	ent_seq += 1
	var gold: bool = str(opt.get("su", "")) != ""
	var look := t.duplicate()
	look.scale = float(t.get("scale", 1)) * (1.38 if gold else (1.22 if elite else 1.0)) * (2.0 if t.get("boss", false) else 1.0)
	if gold:
		look.aura = 0xe2c47f
		look.horn = true
	elif elite:
		look.aura = 0xffb03a
	var aid: String = Data.ENEMY_ASSET.get(type, "")
	var node := Assets.make_actor(aid, look, "beast" if t.get("form") == "beast" else "human")
	node.name = "e_%d" % ent_seq
	if actors_root:
		actors_root.add_child(node)
	node.position = Vector3(x, 0, z)
	var mult := 1.0 + (lvl - 1) * 0.34
	var e := {
		"id": ent_seq, "type": type, "name": ("精英 " if elite else "") + str(t.n),
		"node": node, "boss": t.get("boss", false) == true, "elite": elite,
		"x": x, "z": z, "dir": 0.0, "lvl": lvl,
		"hpMax": round(t.hp * mult * (2.4 if elite else 1.0)),
		"hp": 0.0, "dmg": [round(t.dmg[0] * mult * (1.35 if elite else 1.0)), round(t.dmg[1] * mult * (1.35 if elite else 1.0))],
		"speed": float(t.speed) * (1.1 if elite else 1.0), "range": float(t.range),
		"ranged": t.get("ranged", false) == true, "xp": round(t.xp * mult * (2.6 if elite else 1.0)),
		"atkCd": 0.0, "atkSpeed": float(t.atkCd), "dead": false, "dieT": 0.0,
		"slow": 0.0, "stun": 0.0, "frozen": 0.0, "hitFlash": 0.0, "res": {}, "imm": "",
		"skill": t.get("skill", ""), "seenIntro": false, "mods": [], "su": opt.get("su", ""),
		"shout": false, "shoutCd": 0.0, "countT": -1.0, "risen": false, "didSplit": false,
		"skillCd": 2.4, "woke": 0.0, "riftDr": 0.0,
		"anim": {"walk": 0.0, "atk": 0.0}
	}
	e.hp = e.hpMax
	var D := Game.diff_now()
	if D.hp != 1:
		e.hpMax = round(e.hpMax * D.hp)
		e.hp = e.hpMax
	if D.dmg != 1:
		e.dmg = [round(e.dmg[0] * D.dmg), round(e.dmg[1] * D.dmg)]
	if D.xp != 1:
		e.xp = round(e.xp * D.xp)
	if t.get("boss", false):
		W.boss = e
	_attach_bar(e)
	W.enemies.append(e)
	if elite and not e.boss:
		apply_elite_mods(e, force_mods, opt)
	_apply_rift_to_enemy(e)
	return e


func _apply_rift_to_enemy(e: Dictionary) -> void:
	if e.is_empty() or e.get("hoard") or e.get("ally"):
		return
	if str(W.area.get("kind", "")) != "rift":
		return
	var mods = W.get("riftMods", [])
	if typeof(mods) != TYPE_ARRAY or mods.is_empty():
		return
	if Game.rift_has("rage"):
		e.atkSpeed = float(e.atkSpeed) / 1.4
	if Game.rift_has("hard"):
		e.riftDr = 0.375
	if Game.rift_has("swarm") and not e.get("boss") and not e.get("su"):
		e.hpMax = maxf(1, round(float(e.hpMax) * 0.75))
		e.hp = e.hpMax


func find_stand_near(x: float, z: float) -> Vector2:
	var ok := func(nx: float, nz: float) -> bool:
		if not can_stand(nx, nz, 1.1):
			return false
		for m in W.marks:
			if Cfg.dist2(m.x, m.z, nx, nz) < 100:
				return false
		return true
	if ok.call(x, z):
		return Vector2(x, z)
	for r in range(2, 21):
		for i in 12:
			var a := i / 12.0 * TAU
			var nx := x + cos(a) * r
			var nz := z + sin(a) * r
			if ok.call(nx, nz):
				return Vector2(nx, nz)
	if can_stand(x, z, 0.7):
		return Vector2(x, z)
	return Vector2.ZERO


func spawn_super_unique(def: Dictionary, a: Dictionary) -> Dictionary:
	if def.is_empty() or not Data.ETYPES.has(def.type):
		return {}
	var pos := find_stand_near(float(def.x), float(def.z))
	if pos == Vector2.ZERO:
		return {}
	var e := spawn_enemy(str(def.type), pos.x, pos.y, maxi(1, int(a.get("lvl", Game.P.lvl)) + 2), true, def.mods, {"su": def.id, "noPack": true, "noNote": true, "forceAll": true})
	if e.is_empty():
		return {}
	e.su = def.id
	e.name = def.n
	e.combo = def.n
	if def.get("callName", "") != "":
		e.callName = def.callName
		e.shout = true
		e.shoutCd = 2.2
	e.hpMax = round(e.hpMax * float(def.get("hp", 1.5)))
	e.hp = e.hpMax
	e.xp = round(e.xp * 1.85)
	var dm: float = float(def.get("dmg", 1.18))
	e.dmg = [round(e.dmg[0] * dm), round(e.dmg[1] * dm)]
	_show_bar(e, true)
	var pack_n: int = int(def.get("pack", 3))
	for i in pack_n:
		var ang := i / float(pack_n) * TAU
		var x: float = e.x + cos(ang) * 2.4
		var z: float = e.z + sin(ang) * 2.4
		if not can_stand(x, z, 0.5):
			continue
		var m := spawn_enemy(str(def.type), x, z, maxi(1, int(e.lvl) - 1), false)
		m.packOf = e.id
		m.name = "跟着 " + str(def.n)
		m.hpMax = maxf(8, round(m.hpMax * 0.75))
		m.hp = m.hpMax
		if m.node:
			m.node.scale *= 0.9
	return e


func spawn_field_uniques(a: Dictionary) -> void:
	for def in Data.SUPER_UNIQUES:
		if def.area != a.id:
			continue
		if not spawn_super_unique(def, a).is_empty():
			W.suHint = def.hint
			Game.hint(str(def.hint))


func elite_mod_cap() -> int:
	var ch: int = int(W.area.get("ch", 1))
	var depth: int = int(W.get("riftDepth", 0))
	if depth >= 9 or ch >= 4:
		return 3
	return 2


func mods_conflict(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return true
	var da := Data.elite_mod_by_id(a)
	var db := Data.elite_mod_by_id(b)
	return (da.get("mute", []) as Array).has(b) or (db.get("mute", []) as Array).has(a)


func can_add_mod(e: Dictionary, id: String) -> bool:
	if id == "" or has_mod(e, id):
		return false
	var def := Data.elite_mod_by_id(id)
	if def.is_empty():
		return false
	for m in def.get("mute", []):
		if has_mod(e, str(m)):
			return false
	for have in e.get("mods", []):
		if mods_conflict(str(have), id):
			return false
	return true


func roll_elite_combo(cap: int) -> Array:
	var r := Cfg._rng.randf()
	var need := 1
	if cap >= 3 and r < 0.22:
		need = 3
	elif r >= 0.3:
		need = mini(2, cap)
	var mods: Array = []
	if need >= 2 and Cfg._rng.randf() < 0.58:
		var named: Dictionary = Cfg.pick(Data.ELITE_COMBOS)
		if not named.is_empty() and named.ids.size() <= need:
			for id in named.ids:
				if not mods.has(id):
					mods.append(id)
	var ids: Array = []
	for m in Data.ELITE_MODS:
		ids.append(m.id)
	var g := 0
	while mods.size() < need and g < 48:
		g += 1
		var id: String = str(Cfg.pick(ids))
		var bad := mods.has(id)
		if not bad:
			for h in mods:
				if mods_conflict(str(h), id):
					bad = true
					break
		if bad:
			continue
		mods.append(id)
	if mods.is_empty():
		mods.append("wake")
	return mods.slice(0, cap)


func stamp_elite_mods(e: Dictionary) -> void:
	var t: Dictionary = Data.ETYPES[e.type]
	var named := Data.named_combo(e.get("mods", []))
	var ph: PackedStringArray = []
	for id in e.get("mods", []):
		var m := Data.elite_mod_by_id(str(id))
		if not m.is_empty():
			ph.append(str(m.n))
	if not e.get("su"):
		e.combo = named.n if not named.is_empty() else ""
		e.name = ("精英 " if e.elite else "") + str(t.n)
		if not named.is_empty():
			e.name += " · " + str(named.n)
		elif ph.size():
			e.name += " · " + " · ".join(ph)
	if has_mod(e, "wake"):
		e.shout = true
		if str(e.get("callName", "")) == "":
			e.callName = str(Cfg.pick(["谁来着", "等等", "我的", "回来"]))
		if float(e.get("shoutCd", 0)) <= 0:
			e.shoutCd = Cfg.rf(1.6, 3.4)
	if has_mod(e, "rush") and not e.get("rushSpd"):
		e.rushSpd = true
		e.speed = float(e.speed) * 1.48
	if has_mod(e, "count") and float(e.get("countT", -1)) < 0:
		e.countT = Cfg.rf(6, 10)
	var n: int = e.get("mods", []).size()
	if n > 1:
		e.hpMax = round(e.hpMax * (1.0 + 0.14 * (n - 1)))
		e.hp = e.hpMax
		e.xp = round(e.xp * (1.0 + 0.22 * (n - 1)))
	_name_label(e)


func apply_elite_mods(e: Dictionary, force, opt: Dictionary) -> void:
	if not e or not e.get("elite") or e.get("boss"):
		return
	var cap := elite_mod_cap()
	if force is Array and force.size():
		e.mods = []
		for id in force:
			var sid := str(id)
			if opt.get("forceAll") and not Data.elite_mod_by_id(sid).is_empty() and not e.mods.has(sid):
				e.mods.append(sid)
			elif can_add_mod(e, sid):
				e.mods.append(sid)
		if e.mods.is_empty():
			e.mods.append("wake")
	else:
		e.mods = roll_elite_combo(cap)
	stamp_elite_mods(e)
	if has_mod(e, "child") and not opt.get("noChild"):
		spawn_elite_child(e)
	if opt.get("noPack"):
		return
	if not has_mod(e, "child"):
		var n := Cfg.ri(3, 5) if (has_mod(e, "choir") or has_mod(e, "guard")) else Cfg.ri(2, 4)
		spawn_elite_pack(e, n)


func spawn_elite_child(parent: Dictionary) -> void:
	var x: float = parent.x + 1.5
	var z: float = parent.z + 1.1
	if not can_stand(x, z, 0.5):
		x = parent.x - 1.4
		z = parent.z - 1.1
	var c := spawn_enemy(str(parent.type), x, z, maxi(1, int(parent.lvl) - 1), false)
	c.childOf = parent.id
	c.packOf = parent.id
	c.name = "跟着的" + str(Data.ETYPES[c.type].n)
	c.hpMax = maxf(8, round(c.hpMax * 0.55))
	c.hp = c.hpMax
	if c.node:
		c.node.scale *= 0.72
	parent.childId = c.id


func spawn_elite_pack(e: Dictionary, n: int) -> void:
	var near := 0
	for o in W.enemies:
		if o != e and not o.get("dead") and Cfg.dist2(o.x, o.z, e.x, e.z) < 36:
			near += 1
	if near >= 6:
		return
	for i in n:
		var ang := Cfg._rng.randf() * TAU
		var rad := 1.6 + i * 0.7
		var x: float = e.x + cos(ang) * rad
		var z: float = e.z + sin(ang) * rad
		if not can_stand(x, z, 0.5):
			continue
		var m := spawn_enemy(str(e.type), x, z, maxi(1, int(e.lvl) - 1), false)
		m.packOf = e.id
		m.name = "跟着的" + str(Data.ETYPES[m.type].n)
		m.hpMax = maxf(8, round(m.hpMax * 0.7))
		m.hp = m.hpMax
		if m.node:
			m.node.scale *= 0.88


func spawn_splits(e: Dictionary) -> void:
	for i in 2:
		var a := 1.3 if i else -1.3
		var x: float = e.x + a + Cfg.rf(-0.3, 0.3)
		var z: float = e.z + Cfg.rf(-1, 1)
		if not can_stand(x, z, 0.5):
			x = e.x + Cfg.rf(-1.4, 1.4)
			z = e.z + Cfg.rf(-1.4, 1.4)
		var s := spawn_enemy(str(e.type), x, z, int(e.lvl), false)
		s.splitling = true
		s.name = "裂开的" + str(Data.ETYPES[s.type].n)
		s.hpMax = maxf(8, round(e.hpMax * 0.5))
		s.hp = s.hpMax
		if s.node:
			s.node.scale *= 0.82
	Game.float_at(e.x, 3.2, e.z, "数不清", Color(0.89, 0.77, 0.5), 18)


func choir_src(e: Dictionary) -> Dictionary:
	if e.is_empty() or e.get("dead") or e.get("elite") or e.get("boss") or e.get("su"):
		return {}
	for o in W.enemies:
		if o == e or o.get("dead") or not has_mod(o, "choir"):
			continue
		if float(o.get("stun", 0)) > 0 or float(o.get("frozen", 0)) > 0:
			continue
		if Cfg.dist2(o.x, o.z, e.x, e.z) < 64:
			return o
	return {}


func _attach_bar(e: Dictionary) -> void:
	if e.node == null:
		return
	var width := 1.9 if e.get("boss") else (1.6 if e.get("su") else (1.35 if e.elite else 1.0))
	var col := Color(1, 0.18, 0.18) if e.get("boss") else (Color(0.89, 0.77, 0.5) if e.get("su") else (Color(1, 0.63, 0.19) if e.elite else Color(0.85, 0.27, 0.19)))
	var g := Node3D.new()
	g.name = "bar"
	var y := 4.6 if e.get("boss") else (3.7 if e.get("su") else (3.2 if e.elite else 2.6))
	g.position.y = y
	var bg := MeshInstance3D.new()
	var bgm := PlaneMesh.new()
	bgm.size = Vector2(width, 0.11)
	bg.mesh = bgm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.07, 0.04, 0.04)
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg.material_override = bm
	g.add_child(bg)
	var fill := MeshInstance3D.new()
	fill.name = "fill"
	var fm := PlaneMesh.new()
	fm.size = Vector2(width, 0.085)
	fill.mesh = fm
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = col
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill.material_override = tm
	g.add_child(fill)
	g.visible = e.get("boss") == true or str(e.get("su", "")) != ""
	e.node.add_child(g)
	e.bar = g
	e.barFill = fill
	e.barW = width
	if e.elite or e.get("boss") or e.get("su"):
		_name_label(e)


func _name_label(e: Dictionary) -> void:
	if e.node == null:
		return
	var old: Node = e.node.get_node_or_null("ename")
	if old:
		old.queue_free()
	var lab := Label3D.new()
	lab.name = "ename"
	lab.text = str(e.get("name", ""))
	lab.font = UiKit.ui_font()
	lab.font_size = 28 if e.get("su") else 22
	lab.position.y = 5.1 if e.get("boss") else (4.2 if e.get("su") else 3.65)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.89, 0.77, 0.5) if e.get("su") else (Color(1, 0.69, 0.19) if e.elite else Color(0.91, 0.81, 0.58))
	lab.visible = e.elite or e.get("boss") == true or str(e.get("su", "")) != ""
	e.node.add_child(lab)


func _show_bar(e: Dictionary, on: bool) -> void:
	if e.get("bar"):
		e.bar.visible = on
	_sync_bar(e)


func _sync_bar(e: Dictionary) -> void:
	if not e.get("barFill"):
		return
	var r: float = clampf(float(e.hp) / maxf(1.0, float(e.hpMax)), 0, 1)
	e.barFill.scale.x = maxf(0.02, r)


func spawn_npcs() -> void:
	var c := Cfg.MAP >> 1
	for d in Data.NPCDEF:
		var only: Array = d.get("only", [])
		if only.size() and not only.has(W.area.id):
			continue
		var x: float
		var z: float
		if d.has("x"):
			x = float(d.x)
			z = float(d.z)
		else:
			x = Cfg.wx(c + int(d.dx))
			z = Cfg.wx(c + int(d.dz))
		var node: Node3D
		if d.get("kind", "") != "":
			node = _service_prop(str(d.kind))
		else:
			node = Assets.make_actor(str(d.get("asset", "")), {"body": 0x5a4a3a, "skin": 0xc39a72, "leg": 0x3a2a20}, "human")
		if actors_root:
			actors_root.add_child(node)
		node.position = Vector3(x, 0, z)
		var lab := Label3D.new()
		lab.text = str(d.n)
		lab.font = UiKit.ui_font()
		lab.font_size = 36
		lab.position.y = float(d.get("labelY", 2.6))
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.modulate = Color(0.91, 0.81, 0.58)
		node.add_child(lab)
		W.npcs.append({"id": d.id, "name": d.n, "x": x, "z": z, "node": node, "verb": d.get("verb", "交谈"), "kind": d.get("kind", "")})


func npc_by_id(id: String) -> Dictionary:
	for n in W.npcs:
		if n.id == id:
			return n
	return {}


func add_mark(m: Dictionary) -> void:
	W.marks.append(m)
	if world_root == null:
		return
	var col_hex: int = int(m.get("color", 0xd8c15c))
	var mi := Assets.spawn("fx_mark")
	if mi:
		Assets.tint(mi, col_hex, 0.8)
		mi.position = Vector3(m.x, 0, m.z)
		world_root.add_child(mi)
		m.node = mi
	var lab := Label3D.new()
	lab.text = str(m.get("label", ""))
	lab.font = UiKit.ui_font()
	lab.font_size = 42
	lab.position = Vector3(m.x, 2.2, m.z)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.91, 0.81, 0.58)
	world_root.add_child(lab)
	m.label_node = lab


func open_dungeon_exit() -> void:
	for m in W.marks:
		if m.kind == "exit":
			return
	add_mark({"kind": "exit", "label": "离开", "x": Game.P.x + 2, "z": Game.P.z})


func drop_at(x: float, z: float, obj: Dictionary) -> void:
	obj.x = x
	obj.z = z
	obj.t = Cfg._rng.randf() * TAU
	obj.mesh = _loot_mesh(obj)
	if obj.mesh and world_root:
		obj.mesh.position = Vector3(x, 0, z)
		world_root.add_child(obj.mesh)
	_stamp_loot(obj)
	W.items.append(obj)


func drop_gold(x: float, z: float, amt: int) -> void:
	drop_at(x + Cfg.rf(-0.4, 0.4), z + Cfg.rf(-0.4, 0.4), {"kind": "gold", "amt": amt})


func drop_item(x: float, z: float, it: Dictionary) -> void:
	drop_at(x + Cfg.rf(-0.5, 0.5), z + Cfg.rf(-0.5, 0.5), {"kind": "item", "item": it})
	var r := int(it.get("rarity", 0))
	if it.get("unique") or it.get("set") or r >= 3:
		Sfx.legend()


func drop_potion(x: float, z: float, pot: String) -> void:
	drop_at(x + Cfg.rf(-0.5, 0.5), z + Cfg.rf(-0.5, 0.5), {"kind": "potion", "pot": pot})


func _loot_mesh(obj: Dictionary) -> Node3D:
	var g: Node3D
	if obj.kind == "gold":
		g = Assets.spawn("fx_loot_gold")
	elif obj.kind == "potion":
		g = Assets.spawn("fx_loot_potion")
		if g and str(obj.get("pot", "")) != "hp":
			Assets.tint(g, 0x3A7FE0)
	else:
		g = Assets.spawn("fx_loot_item")
		var hex: int = 0xC8C0AD
		if obj.kind == "item" and obj.get("item"):
			hex = LootData.item_hex(obj.item)
		elif obj.kind == "relic":
			hex = 0xC8A24A
		if g:
			Assets.tint(g, hex, 0.35)
	if g == null:
		g = Node3D.new()
	return g


func _loot_name(obj: Dictionary) -> String:
	var k := str(obj.get("kind", ""))
	if k == "gold":
		return "%d 金币" % int(obj.get("amt", 0))
	if k == "potion":
		return "法力药水" if str(obj.get("pot", "")) == "mp" else "生命药水"
	if k == "relic":
		var rel = obj.get("relic", {})
		if typeof(rel) == TYPE_DICTIONARY:
			return str(rel.get("n", "遗物"))
		return "遗物"
	var g = obj.get("item")
	if typeof(g) != TYPE_DICTIONARY:
		return "掉落"
	if g.get("unknown") == true:
		return "想不起来的东西"
	return str(g.get("name", "装备"))


func _loot_color(obj: Dictionary) -> Color:
	var k := str(obj.get("kind", ""))
	if k == "gold":
		return Cfg.hex_color(0xffd24a)
	if k == "potion":
		return Cfg.hex_color(0x3a7fe0) if str(obj.get("pot", "")) == "mp" else Cfg.hex_color(0xd45a4a)
	if k == "relic":
		return Cfg.hex_color(0xc8a24a)
	var g = obj.get("item")
	if typeof(g) == TYPE_DICTIONARY:
		return Cfg.hex_color(LootData.item_hex(g))
	return Cfg.hex_color(0xc8c0ad)


func loot_is_white(obj: Dictionary) -> bool:
	if str(obj.get("kind", "")) != "item":
		return false
	var g = obj.get("item")
	if typeof(g) != TYPE_DICTIONARY:
		return false
	if g.get("unique") or g.get("set"):
		return false
	return int(g.get("rarity", 0)) <= 0


func loot_name_on(obj: Dictionary) -> bool:
	if str(obj.get("kind", "")) == "gold":
		return false
	if Game.alt_loot():
		return true
	if loot_is_white(obj) and not Game.show_white_loot():
		return false
	return true


func _stamp_loot(obj: Dictionary) -> void:
	if obj.get("mesh") == null:
		return
	var mesh: Node3D = obj.mesh
	var lab := Label3D.new()
	lab.name = "lname"
	lab.text = _loot_name(obj)
	lab.font = UiKit.ui_font()
	lab.font_size = 22
	lab.position.y = 1.55
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.modulate = _loot_color(obj)
	lab.outline_modulate = Color(0.04, 0.03, 0.02, 0.9)
	lab.outline_size = 6
	lab.visible = loot_name_on(obj)
	mesh.add_child(lab)
	var g = obj.get("item")
	var rare := false
	if typeof(g) == TYPE_DICTIONARY:
		rare = g.get("unique") == true or g.get("set") == true or int(g.get("rarity", 0)) >= 3
	if rare:
		var beam := MeshInstance3D.new()
		beam.name = "beam"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.16
		cyl.height = 7.2
		cyl.radial_segments = 8
		beam.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var col := _loot_color(obj)
		mat.albedo_color = Color(col.r, col.g, col.b, 0.42)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.4
		beam.material_override = mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position.y = 3.6
		mesh.add_child(beam)


func loot_under(x: float, z: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1.7 * 1.7
	for it in W.items:
		if str(it.get("kind", "")) == "gold":
			continue
		if not loot_name_on(it):
			continue
		var d: float = Cfg.dist2(float(it.x), float(it.z), x, z)
		if d < bd:
			bd = d
			best = it
	return best


func _remove_ground(it: Dictionary) -> void:
	if it.get("mesh"):
		it.mesh.queue_free()
	var pt = Game.P.get("pickupTarget")
	if typeof(pt) == TYPE_DICTIONARY and pt.get("mesh") == it.get("mesh"):
		Game.P.pickupTarget = null
	W.items.erase(it)
	Game.ui_refresh.emit()


func try_pickups() -> void:
	var i: int = W.items.size() - 1
	while i >= 0:
		var it: Dictionary = W.items[i]
		var d2: float = Cfg.dist2(it.x, it.z, Game.P.x, Game.P.z)
		var gold: bool = str(it.get("kind", "")) == "gold"
		var want := gold and d2 < 5.2 * 5.2
		if not want:
			var pt = Game.P.get("pickupTarget")
			if typeof(pt) == TYPE_DICTIONARY and pt.get("mesh") == it.get("mesh") and d2 < 1.7 * 1.7:
				want = true
		if not want:
			i -= 1
			continue
		if not Game.take_ground(it):
			i -= 1
			continue
		_remove_ground(it)
		i -= 1


func try_marks() -> void:
	for m in W.marks:
		if m.get("off"):
			continue
		if Cfg.dist2(m.x, m.z, Game.P.x, Game.P.z) < 2.3 * 2.3:
			if Game.P.onMark != m:
				Game.P.onMark = m
				var extra := "  ·  再点一次进入"
				if str(m.get("kind", "")) == "event":
					extra = "  ·  再点一次"
				Game.hint(str(m.get("label", "传送")) + extra)
			return
	Game.P.onMark = null


func use_mark(m: Dictionary) -> void:
	if m.get("off"):
		return
	if str(m.get("kind", "")) == "event":
		use_event_mark(m)
		return
	if m.kind == "shrine":
		Game.world_ui.emit("shrine", m)
		return
	if m.kind == "cage":
		release_cage(m)
		return
	if m.kind == "rift":
		Game.world_ui.emit("rift", {})
		return
	if m.kind == "next" and str(W.area.get("kind", "")) == "rift":
		Game.world_ui.emit("rift_go", {"depth": int(W.riftDepth) + 1, "fromNext": true})
		return
	Sfx.portal()
	if m.kind == "travel":
		Game.go_place("area", m.to, Game.diff_id())
	elif m.kind == "exit":
		var to := str(W.dun.from) if W.dun else Game.hub_id()
		if W.area.get("kind") == "rift":
			to = Game.hub_id()
		Game.go_place("area", to, Game.diff_id())
	elif m.kind == "dungeon":
		Game.world_ui.emit("dungeon", {"id": str(m.to)})
		return
	elif m.kind == "next":
		if W.dun:
			enter_dungeon(W.dun.id, int(W.dunFloor) + 1)


func spawn_player_again() -> void:
	_spawn_player_view()


func _spawn_player_view() -> void:
	if actors_root == null:
		return
	var old: Node = actors_root.get_node_or_null("Player")
	if old:
		old.queue_free()
	var aid: String = Data.CLASS_ASSET.get(Game.P.cls, "char_warrior")
	var look: Dictionary = Data.CLASSES[Game.P.cls].look.duplicate()
	var node := Assets.make_actor(aid, look, "human")
	node.name = "Player"
	actors_root.add_child(node)
	node.position = Vector3(Game.P.x, 0, Game.P.z)
	W.player_node = node


func player_node() -> Node3D:
	return W.get("player_node")


func rebuild_meshes(pal: Dictionary, dark: bool) -> void:
	if world_root == null:
		return
	W.dark = dark
	for c in world_root.get_children():
		c.queue_free()
	var M := Cfg.MAP
	var T := Cfg.TILE
	var under := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(M * T + 8, M * T + 8)
	under.mesh = plane
	under.rotation.x = -PI / 2
	under.position.y = -0.42
	var um := StandardMaterial3D.new()
	um.albedo_color = Cfg.hex_color(0x0a090c if dark else 0x1a1812)
	under.material_override = um
	world_root.add_child(under)
	var floor_pts: Array = []
	var edges: Array = []
	for y in M:
		for x in M:
			if W.grid[Cfg.gi(x, y)] != 1:
				continue
			floor_pts.append(Vector2i(x, y))
			if x <= 0 or y <= 0 or x >= M - 1 or y >= M - 1:
				continue
			if walk(x - 1, y) and walk(x + 1, y) and walk(x, y - 1) and walk(x, y + 1):
				continue
			edges.append(Vector2i(x, y))
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(T, 0.5, T)
	var fmm := MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.mesh = fmesh
	fmm.instance_count = floor_pts.size()
	var base: Vector3 = pal.get("floor", Vector3(0.44, 0.4, 0.28))
	for i in floor_pts.size():
		var p: Vector2i = floor_pts[i]
		var code := paint_at(p.x, p.y)
		var sy := 0.7 if code == 2 else (0.9 if code == 3 else (0.62 if code == 5 else 0.82))
		var xf := Transform3D()
		xf.origin = Vector3(Cfg.wx(p.x), -0.25 * sy, Cfg.wx(p.y))
		xf.basis = xf.basis.scaled(Vector3(0.98, sy, 0.98))
		fmm.set_instance_transform(i, xf)
		var tint := base
		if code == 2:
			tint *= 1.12
		elif code == 3:
			tint *= 1.2
		elif code == 5:
			tint = Vector3(0.7, 0.82, 0.9)
		elif code == 4:
			tint = Vector3(0.22, 0.34, 0.18)
		elif code == 6:
			tint = Vector3(0.4, 0.22, 0.16)
		fmm.set_instance_color(i, Color(tint.x, tint.y, tint.z))
	_floor_mm = MultiMeshInstance3D.new()
	_floor_mm.multimesh = fmm
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	_floor_mm.material_override = fm
	world_root.add_child(_floor_mm)
	if edges.size():
		var smesh := BoxMesh.new()
		smesh.size = Vector3(T * 1.04, 1.2, T * 1.04)
		var smm := MultiMesh.new()
		smm.transform_format = MultiMesh.TRANSFORM_3D
		smm.use_colors = true
		smm.mesh = smesh
		smm.instance_count = edges.size()
		for i in edges.size():
			var p: Vector2i = edges[i]
			var xf := Transform3D()
			xf.origin = Vector3(Cfg.wx(p.x), -0.78, Cfg.wx(p.y))
			smm.set_instance_transform(i, xf)
			var v := 0.26 + Cfg._rng.randf() * 0.14
			smm.set_instance_color(i, Color(base.x * v * 0.75, base.y * v * 0.72, base.z * v * 0.68))
		var skirt := MultiMeshInstance3D.new()
		skirt.multimesh = smm
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		skirt.material_override = sm
		world_root.add_child(skirt)
	var kind: String = str(W.area.get("kind", ""))
	if dark:
		_build_dungeon_walls()
		_build_dark_props()
	elif kind == "field":
		_build_field_blockers(str(W.area.get("block", "rock")))
		_build_field_landmarks(W.area)


func _build_town_props(area: Dictionary) -> void:
	if world_root == null:
		return
	var houses: Array = area.get("houses", Data.TOWN_HOUSES)
	var skin: String = str(area.get("skin", "stone"))
	var c := Cfg.MAP >> 1
	var idx := 0
	for h in houses:
		var px := Cfg.wx(c + float(h[0]) + float(h[2]) / 2.0 - 0.5)
		var pz := Cfg.wx(c + float(h[1]) + float(h[3]) / 2.0 - 0.5)
		_build_house(px, pz, float(h[2]) * Cfg.TILE * 0.92, float(h[3]) * Cfg.TILE * 0.92, idx, skin)
		idx += 1


func _build_house(px: float, pz: float, bw: float, bd: float, idx: int, skin: String) -> void:
	var n := Assets.spawn("world_house")
	if n == null:
		return
	n.position = Vector3(px, 0, pz)
	n.scale = Vector3(bw / 4.0, 1.0, bd / 4.0)
	if skin == "ice":
		Assets.tint(n, 0x9AA8B4)
	elif skin == "dock":
		Assets.tint(n, 0x7A6A58)
	elif skin == "ruin":
		Assets.tint(n, 0x4E403C)
	elif skin == "nail":
		Assets.tint(n, 0x6A5A4C)
	elif idx % 3 == 1:
		Assets.tint(n, 0x7A6A52)
	elif idx % 3 == 2:
		Assets.tint(n, 0x6E6458)
	world_root.add_child(n)


func _build_dungeon_walls() -> void:
	var wt: Array = blocked_tiles()
	if wt.is_empty():
		return
	for i in wt.size():
		var p: Vector2i = wt[i]
		var h := 4.1 + Cfg._rng.randf() * 0.7
		Assets.place("world_wall", world_root, Vector3(Cfg.wx(p.x), 0, Cfg.wx(p.y)), 0.0, Vector3(1, h / 4.4, 1))
		Assets.place("world_wall_cap", world_root, Vector3(Cfg.wx(p.x), h, Cfg.wx(p.y)))
		var n := walk(p.x, p.y - 1)
		var s := walk(p.x, p.y + 1)
		var e := walk(p.x + 1, p.y)
		var w := walk(p.x - 1, p.y)
		if (n or s) and (e or w) and Cfg._rng.randf() < 0.7:
			Assets.place("world_column", world_root, Vector3(Cfg.wx(p.x), 0, Cfg.wx(p.y)), 0.0, Vector3(1, h / 5.2, 1))


func _build_dark_props() -> void:
	W.torches = []
	var rift: bool = str(W.area.get("kind", "")) == "rift"
	for r in W.rooms:
		var spots: Array = [
			Vector2i(int(r.x), int(r.cy)),
			Vector2i(int(r.x) + int(r.w) - 1, int(r.cy)),
			Vector2i(int(r.cx), int(r.y)),
			Vector2i(int(r.cx), int(r.y) + int(r.h) - 1)
		]
		for t in spots:
			if Cfg._rng.randf() < (0.28 if rift else 0.4):
				continue
			var px := Cfg.wx(t.x)
			var pz := Cfg.wx(t.y)
			var yaw := atan2(Cfg.wx(r.cx) - px, Cfg.wx(r.cy) - pz)
			var n := Assets.place("prop_torch", world_root, Vector3(px, 0, pz), yaw)
			W.torches.append({"x": px, "z": pz, "y": 1.95 if n else 2.55, "ph": Cfg._rng.randf() * TAU})


func spawn_stone_wall(x: float, z: float) -> void:
	var g := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.6, 1.7, 0.42)
	g.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Cfg.hex_color(0x6a6258)
	g.material_override = mat
	g.position = Vector3(x, 0.85, z)
	if world_root:
		world_root.add_child(g)
	var walls: Array = W.get("walls", [])
	if typeof(walls) != TYPE_ARRAY:
		walls = []
	walls.append({"x": x, "z": z, "r": 1.5, "t": 4.0, "mesh": g})
	W.walls = walls


func tick_walls(dt: float) -> void:
	var walls: Array = W.get("walls", [])
	if typeof(walls) != TYPE_ARRAY:
		return
	var i := walls.size() - 1
	while i >= 0:
		walls[i].t = float(walls[i].t) - dt
		if float(walls[i].t) <= 0:
			if walls[i].get("mesh"):
				walls[i].mesh.queue_free()
			walls.remove_at(i)
		i -= 1
	W.walls = walls


func zone_count() -> int:
	return _zones.size()


func in_rain(x: float, z: float) -> bool:
	for z0 in _zones:
		if z0.get("rain") and Cfg.dist2(x, z, float(z0.x), float(z0.z)) < float(z0.r) * float(z0.r):
			return true
	return false


func _ensure_torch_lights() -> void:
	if _torch_lights.size() or world_root == null:
		return
	var host: Node = world_root.get_parent()
	if host == null:
		return
	for _i in 5:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.54, 0.24)
		l.omni_range = 15.0
		l.omni_attenuation = 2.0
		l.light_energy = 0.0
		host.add_child(l)
		_torch_lights.append(l)


func _tick_torch_lights(dt: float) -> void:
	_ensure_torch_lights()
	_torch_t += dt
	var cand: Array = []
	for t in W.get("torches", []):
		var d: float = Cfg.dist2(float(t.x), float(t.z), float(Game.P.x), float(Game.P.z))
		if d < 900.0:
			cand.append({"t": t, "d": d})
	cand.sort_custom(func(a, b): return float(a.d) < float(b.d))
	for i in _torch_lights.size():
		var l: OmniLight3D = _torch_lights[i]
		if i < cand.size():
			var t: Dictionary = cand[i].t
			l.global_position = Vector3(float(t.x), float(t.y) + 0.3, float(t.z))
			l.light_energy = 1.15 + sin(_torch_t * 11.0 + float(t.ph)) * 0.22
		else:
			l.light_energy = 0.0


func _build_field_blockers(style: String) -> void:
	var tiles: Array = blocked_tiles()
	if tiles.is_empty():
		return
	var n := tiles.size()
	if style == "tree":
		for i in n:
			var t: Vector2i = tiles[i]
			var px := Cfg.wx(t.x) + Cfg.rf(-0.25, 0.25)
			var pz := Cfg.wx(t.y) + Cfg.rf(-0.25, 0.25)
			var tall := 0.85 + Cfg._rng.randf() * 0.45
			Assets.place("world_tree", world_root, Vector3(px, 0, pz), Cfg._rng.randf() * TAU, Vector3(tall, tall, tall))
			if Cfg._rng.randf() < 0.28:
				Assets.place("world_bush", world_root, Vector3(px + Cfg.rf(-1.1, 1.1), 0, pz + Cfg.rf(-1.1, 1.1)), 0.0, 0.7 + Cfg._rng.randf() * 0.6)
		for _i in 8:
			var t: Vector2i = Cfg.pick(tiles)
			Assets.place("world_log", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-0.4, 0.4), 0, Cfg.wx(t.y) + Cfg.rf(-0.4, 0.4)), Cfg._rng.randf() * TAU)
	elif style == "spire":
		for i in n:
			var t: Vector2i = tiles[i]
			var h := 0.85 + Cfg._rng.randf() * 0.7
			Assets.place("world_spire", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-0.25, 0.25), 0, Cfg.wx(t.y) + Cfg.rf(-0.25, 0.25)), Cfg._rng.randf() * TAU, Vector3(1, h, 1))
			Assets.place("world_shard", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-0.9, 0.9), 0, Cfg.wx(t.y) + Cfg.rf(-0.9, 0.9)), 0.0, Vector3(1, 0.6 + Cfg._rng.randf() * 0.8, 1))
		for _i in 6:
			var t: Vector2i = Cfg.pick(tiles)
			Assets.place("world_glow", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-1.6, 1.6), 0, Cfg.wx(t.y) + Cfg.rf(-1.6, 1.6)), 0.0, Cfg.rf(0.7, 1.5))
	elif style == "pillar":
		for i in n:
			var t: Vector2i = tiles[i]
			var h := 0.8 + Cfg._rng.randf() * 0.7
			Assets.place("world_icicle", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-0.2, 0.2), 0, Cfg.wx(t.y) + Cfg.rf(-0.2, 0.2)), Cfg._rng.randf() * TAU, Vector3(1, h, 1))
	elif style == "wreck":
		for i in n:
			var t: Vector2i = tiles[i]
			Assets.place("world_wreck", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-0.3, 0.3), 0, Cfg.wx(t.y) + Cfg.rf(-0.3, 0.3)), Cfg._rng.randf() * TAU, Vector3(1, Cfg.rf(0.6, 1.3), Cfg.rf(0.7, 1.2)))
			if Cfg._rng.randf() < 0.28:
				Assets.place("world_mast", world_root, Vector3(Cfg.wx(t.x), 0, Cfg.wx(t.y)), 0.0)
	else:
		for i in n:
			var t: Vector2i = tiles[i]
			Assets.place("world_rock", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-0.25, 0.25), 0, Cfg.wx(t.y) + Cfg.rf(-0.25, 0.25)), Cfg._rng.randf() * TAU, Vector3(Cfg.rf(0.7, 1.15), Cfg.rf(0.55, 1.05), Cfg.rf(0.7, 1.2)))
			Assets.place("world_pebble", world_root, Vector3(Cfg.wx(t.x) + Cfg.rf(-1.1, 1.1), 0, Cfg.wx(t.y) + Cfg.rf(-1.1, 1.1)), 0.0, 0.5 + Cfg._rng.randf() * 0.7)
		var gsi := 0
		var tries := 0
		while tries < 280 and gsi < 160:
			tries += 1
			var x := Cfg.rf(-52, 52)
			var z := Cfg.rf(-52, 52)
			if not can_stand(x, z, 0.3):
				continue
			Assets.place("world_grass", world_root, Vector3(x, 0, z), Cfg._rng.randf() * TAU, Vector3(1, Cfg.rf(0.7, 1.5), 1))
			gsi += 1


func _build_field_landmarks(area: Dictionary) -> void:
	var tiles: Array = blocked_tiles()
	if tiles.is_empty():
		return
	var t: Vector2i = tiles[tiles.size() >> 2]
	var scene := ""
	match str(area.get("id", "")):
		"waste":
			scene = "world_landmark_waste"
		"wood":
			scene = "world_landmark_wood"
		"ash":
			scene = "world_landmark_ash"
		"frost":
			scene = "world_landmark_frost"
		"shore":
			scene = "world_landmark_shore"
		"sinkf":
			scene = "world_landmark_sinkf"
		"shaft":
			scene = "world_landmark_shaft"
	if scene != "":
		Assets.place(scene, world_root, Vector3(Cfg.wx(t.x), 0, Cfg.wx(t.y)))


func _service_prop(kind: String) -> Node3D:
	if kind == "spring":
		return _make_spring()
	var id := "world_stash" if kind == "stash" else ("world_board" if kind == "board" else "world_waystone")
	var g: Node3D = Assets.spawn(id)
	return g if g else Node3D.new()


func _town_gate_line(id: String, n: String) -> String:
	match id:
		"town":
			return "雨停了。石桥。裂口的风从镇底下灌上来。先找桥头的人，再往广场北面走。"
		"rime":
			return "隘口的风先到，钟声后到。从南路走进%s。守隘的人在里面。" % n
		"harbor":
			return "潮声像有人在数船。从北路走进%s。灯塔亮了再看出海。" % n
		"sink":
			return "镇在往下沉。账还没写完。从海岸走进%s，先跟人说话。" % n
		"well":
			return "七根还在。从残镇走进%s。别停下来听井底下的人说话。" % n
		_:
			return "从入口走进%s。先跟人说话，再出镇。" % n


func _build_gate_posts(x: float, z: float) -> void:
	if world_root == null:
		return
	var inward := Vector2(-x, -z)
	if inward.length() < 0.1:
		inward = Vector2(0, -1)
	inward = inward.normalized()
	var side := Vector2(-inward.y, inward.x) * 2.1
	for s in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.55, 3.2, 0.55)
		post.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Cfg.hex_color(0x6a6258)
		post.material_override = mat
		post.position = Vector3(x + side.x * s, 1.6, z + side.y * s)
		world_root.add_child(post)
	var lint := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(5.1, 0.45, 0.7)
	lint.mesh = lb
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Cfg.hex_color(0x5a5248)
	lint.material_override = lm
	lint.position = Vector3(x, 3.35, z)
	lint.rotation.y = atan2(inward.x, inward.y)
	world_root.add_child(lint)


func _make_spring() -> Node3D:
	var g := Node3D.new()
	var well := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.08
	cyl.bottom_radius = 1.2
	cyl.height = 0.95
	cyl.radial_segments = 12
	well.mesh = cyl
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Cfg.hex_color(0x6a6258)
	well.material_override = wm
	well.position.y = 0.48
	g.add_child(well)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.78
	disc.bottom_radius = 0.78
	disc.height = 0.04
	disc.radial_segments = 12
	water.mesh = disc
	var wtm := StandardMaterial3D.new()
	wtm.albedo_color = Color(0.23, 0.35, 0.42, 0.82)
	wtm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wtm
	water.position.y = 0.92
	g.add_child(water)
	for ox in [-0.7, 0.7]:
		var p := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.12, 1.6, 0.12)
		p.mesh = pb
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Cfg.hex_color(0x4a3424)
		p.material_override = pm
		p.position = Vector3(ox, 1.4, 0)
		g.add_child(p)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.7, 0.12, 0.12)
	beam.mesh = bb
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Cfg.hex_color(0x4a3424)
	beam.material_override = bm
	beam.position = Vector3(0, 2.22, 0)
	g.add_child(beam)
	var bucket := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.16
	bc.bottom_radius = 0.18
	bc.height = 0.22
	bucket.mesh = bc
	var bkm := StandardMaterial3D.new()
	bkm.albedo_color = Cfg.hex_color(0x5a3a22)
	bucket.material_override = bkm
	bucket.position = Vector3(0, 0.2, 1.15)
	g.add_child(bucket)
	return g


func _rand_stand() -> Vector2:
	for _i in 40:
		var x := Cfg.rf(-50, 50)
		var z := Cfg.rf(-50, 50)
		if can_stand(x, z, 0.8):
			return Vector2(x, z)
	return Vector2.ZERO


func aoe_player(x: float, z: float, rad: float, dmg: float, elem: String, stun: float = 0.0, slow: float = 0.0) -> int:
	var hits := 0
	for e in W.enemies:
		if e.get("dead") or e.get("ally") or e.get("escaped"):
			continue
		if Cfg.dist2(e.x, e.z, x, z) < rad * rad:
			if dmg > 0.001:
				Game.deal_to_enemy(e, dmg, false, Color(0.95, 0.75, 0.5), false, true, elem)
			if stun > 0:
				e.stun = maxf(float(e.stun), stun)
			if slow > 0:
				e.slow = maxf(float(e.slow), slow)
			hits += 1
	return hits


func cone_player(dir: float, rad: float, half: float, dmg: float, elem: String, stun: float = 0.0) -> int:
	var hits := 0
	var px: float = float(Game.P.x)
	var pz: float = float(Game.P.z)
	var fx := sin(dir)
	var fz := cos(dir)
	for e in W.enemies:
		if e.get("dead") or e.get("ally") or e.get("escaped"):
			continue
		var dx: float = float(e.x) - px
		var dz: float = float(e.z) - pz
		var d: float = Cfg.hypot(dx, dz)
		if d > rad or d < 0.01:
			continue
		if dx / d * fx + dz / d * fz < cos(half):
			continue
		Game.deal_to_enemy(e, dmg, false, Color(0.95, 0.75, 0.5), false, true, elem)
		if stun > 0:
			e.stun = maxf(float(e.stun), stun)
		hits += 1
	return hits


func line_aoe(aim: Vector3, length: float, width: float, dmg: float, elem: String, stun: float = 0.0) -> int:
	var dx: float = aim.x - float(Game.P.x)
	var dz: float = aim.z - float(Game.P.z)
	var d: float = Cfg.hypot(dx, dz)
	if d < 0.01:
		dx = sin(float(Game.P.dir))
		dz = cos(float(Game.P.dir))
		d = 1.0
	dx /= d
	dz /= d
	var hits := 0
	for e in W.enemies:
		if e.get("dead") or e.get("ally") or e.get("escaped"):
			continue
		var px: float = float(e.x) - float(Game.P.x)
		var pz: float = float(e.z) - float(Game.P.z)
		var along: float = px * dx + pz * dz
		if along < 0.0 or along > length:
			continue
		var lat: float = absf(px * dz - pz * dx)
		if lat > width:
			continue
		Game.deal_to_enemy(e, dmg, false, Color(0.95, 0.75, 0.5), false, true, elem)
		if stun > 0:
			e.stun = maxf(float(e.stun), stun)
		hits += 1
	return hits


func knock_around(x: float, z: float, rad: float, force: float) -> void:
	for e in W.enemies:
		if e.get("dead"):
			continue
		if Cfg.dist2(e.x, e.z, x, z) < rad * rad:
			var dx: float = e.x - x
			var dz: float = e.z - z
			var d: float = Cfg.hypot(dx, dz)
			if d < 0.01:
				continue
			move_entity(e, e.x + dx / d * force, e.z + dz / d * force)


func pull_around(x: float, z: float, rad: float, force: float) -> void:
	for e in W.enemies:
		if e.get("dead") or e.get("ally"):
			continue
		if Cfg.dist2(e.x, e.z, x, z) < rad * rad:
			var dx: float = x - float(e.x)
			var dz: float = z - float(e.z)
			var d: float = Cfg.hypot(dx, dz)
			if d < 0.01:
				continue
			move_entity(e, e.x + dx / d * force, e.z + dz / d * force)


func dash_player(aim: Vector3, dmg: float, end_only: bool = false) -> bool:
	var dir := Vector3(aim.x - float(Game.P.x), 0, aim.z - float(Game.P.z))
	if dir.length() < 0.1:
		dir = Vector3(sin(float(Game.P.dir)), 0, cos(float(Game.P.dir)))
	dir = dir.normalized()
	var dest := Vector3(float(Game.P.x), 0, float(Game.P.z)) + dir * 8.0
	var hit := false
	for i in 8:
		var t := (i + 1) / 8.0
		var x: float = lerpf(float(Game.P.x), dest.x, t)
		var z: float = lerpf(float(Game.P.z), dest.z, t)
		if can_stand(x, z, 0.45):
			Game.P.x = x
			Game.P.z = z
		if not end_only and aoe_player(Game.P.x, Game.P.z, 1.8, dmg, "phys") > 0:
			hit = true
	if end_only:
		hit = aoe_player(Game.P.x, Game.P.z, 3.6, dmg, "phys") > 0
	Game.P.path = []
	Game.on_dash_land(float(Game.P.x), float(Game.P.z))
	return hit


func blink_player(aim: Vector3, dmg: float) -> void:
	var ox: float = float(Game.P.x)
	var oz: float = float(Game.P.z)
	if Game.sk_rune("blink") == "afterimage":
		aoe_player(ox, oz, 2.4, dmg, "shadow")
	var x := aim.x
	var z := aim.z
	if can_stand(x, z, 0.5):
		Game.P.x = x
		Game.P.z = z
	aoe_player(Game.P.x, Game.P.z, 2.2, dmg, "shadow")
	Game.P.path = []
	if Game.sk_rune("blink") == "chain":
		if typeof(Game.P.up) != TYPE_DICTIONARY:
			Game.P.up = {}
		Game.P.up.blinkEcho = maxf(float(Game.P.up.get("blinkEcho", 0)), 2.0)


func roll_player(aim: Vector3, dur: float) -> void:
	var ox: float = float(Game.P.x)
	var oz: float = float(Game.P.z)
	Game.P.invuln = dur if Game.tal_rank("ag6") == 0 else 0.0
	var dir := Vector3(aim.x - float(Game.P.x), 0, aim.z - float(Game.P.z))
	if dir.length() < 0.1:
		dir = Vector3(sin(Game.P.dir), 0, cos(Game.P.dir))
	dir = dir.normalized() * 5.5
	var nx: float = float(Game.P.x) + dir.x
	var nz: float = float(Game.P.z) + dir.z
	if can_stand(nx, nz, 0.45):
		Game.P.x = nx
		Game.P.z = nz
	Game.P.path = []
	Game.on_dash_land(nx, nz)
	if Game.sk_rune("roll") == "smoke":
		add_zone(ox, oz, 2.4, 2.4, 0.0, "enemy", {"slow": 2.2, "tick": 0.25, "elem": "phys"})


func _proj_mesh(color_hex: int, arrow: bool) -> Node3D:
	var g: Node3D = Assets.spawn("fx_proj_arrow" if arrow else "fx_proj_orb")
	if g == null:
		g = Node3D.new()
	Assets.tint(g, color_hex, 1.0)
	if world_root:
		world_root.add_child(g)
	return g


func shoot_player(target: Dictionary, dmg: float, crit: bool, proj: Dictionary) -> void:
	var p := {
		"x": Game.P.x, "z": Game.P.z, "y": 1.3,
		"dx": target.x - Game.P.x, "dz": target.z - Game.P.z,
		"spd": float(proj.get("speed", 22)), "dmg": dmg, "crit": crit,
		"elem": "shadow" if Game.P.cls == "mage" else "phys", "from": "player", "life": 1.6,
		"pierce": Game.P.buffs.has("keen")
	}
	p.mesh = _proj_mesh(0xffe6a0 if Game.P.cls == "archer" else 0x9a5cff, Game.P.cls == "archer")
	_proj.append(p)


func shoot_aim(aim: Vector3, dmg: float, elem: String, poison: bool = false, dot: float = 0.0) -> void:
	var dx: float = aim.x - float(Game.P.x)
	var dz: float = aim.z - float(Game.P.z)
	shoot_dir(dx, dz, dmg, elem, {"poison": poison, "dot": dot})


func shoot_dir(dx: float, dz: float, dmg: float, elem: String, opt: Dictionary = {}) -> void:
	var p := {
		"x": Game.P.x, "z": Game.P.z, "y": 1.3, "dx": dx, "dz": dz,
		"spd": float(opt.get("spd", 22)), "dmg": dmg, "elem": elem, "from": "player",
		"life": float(opt.get("life", 1.8)), "poison": opt.get("poison", false) == true,
		"dot": float(opt.get("dot", 0)), "pierce": opt.get("pierce") == true,
		"linger": opt.get("linger") == true, "hitIds": [],
		"splash": float(opt.get("splash", 0)), "stun": float(opt.get("stun", 0)),
		"cloud": opt.get("cloud") == true, "vine": opt.get("vine") == true
	}
	p.mesh = _proj_mesh(0x9a5cff if elem == "shadow" else 0xff6a2a, false)
	_proj.append(p)


func fan_shots(n: int, dmg: float, spread: float = 0.18, pierce: bool = false) -> void:
	var base: float = atan2(Game.last_cursor.x - float(Game.P.x), Game.last_cursor.z - float(Game.P.z))
	for i in n:
		var a := base + (i - (n - 1) * 0.5) * spread
		var p := {
			"x": Game.P.x, "z": Game.P.z, "y": 1.2, "dx": sin(a), "dz": cos(a),
			"spd": 32.0, "dmg": dmg, "elem": "phys", "from": "player", "life": 1.2,
			"pierce": pierce, "hitIds": []
		}
		p.mesh = _proj_mesh(0xffe6a0, true)
		_proj.append(p)


func line_shot(aim: Vector3, dmg: float, single: bool, wide: bool = false, ricochet: bool = false) -> void:
	var dx: float = aim.x - float(Game.P.x)
	var dz: float = aim.z - float(Game.P.z)
	var d: float = Cfg.hypot(dx, dz)
	if d < 0.01:
		return
	dx /= d
	dz /= d
	var length := 10.0 if wide else 14.0
	var latw := 1.7 if wide else 0.9
	var first: Dictionary = {}
	for e in W.enemies:
		if e.get("dead"):
			continue
		var px: float = float(e.x) - float(Game.P.x)
		var pz: float = float(e.z) - float(Game.P.z)
		var along: float = px * dx + pz * dz
		if along < 0 or along > length:
			continue
		var lat: float = absf(px * dz - pz * dx)
		if lat < latw:
			Game.deal_to_enemy(e, dmg * (1.8 if single else 1.0), false, Color(0.95, 0.9, 0.7), false, true, "phys")
			if first.is_empty():
				first = e
			if single or ricochet:
				break
	if ricochet and not first.is_empty():
		var nxt := _nearest_from(first, 6.5, first.id)
		if not nxt.is_empty():
			Game.deal_to_enemy(nxt, dmg, false, Color(0.95, 0.9, 0.7), false, true, "phys")


func missiles(n: int, dmg: float, elem: String, opt: Dictionary = {}) -> void:
	var pierce: bool = opt.get("pierce") == true
	var splash: float = float(opt.get("splash", 0))
	var spd: float = float(opt.get("spd", 18))
	for _i in n:
		var t := _nearest_enemy(14)
		if t.is_empty():
			continue
		_proj.append({
			"x": Game.P.x, "z": Game.P.z, "y": 1.4, "homing": t,
			"dx": t.x - Game.P.x, "dz": t.z - Game.P.z, "spd": spd, "dmg": dmg,
			"elem": elem, "from": "player", "life": 2.4 if pierce else 2.0,
			"mesh": _proj_mesh(0x9a5cff, false), "pierce": pierce, "splash": splash, "hitIds": []
		})


func drain_nearest(dmg: float, heal_r: float, n: int = 1) -> Array:
	var got: Array = []
	var skip := {}
	for _k in n:
		var best: Dictionary = {}
		var bd := 10.0 * 10.0
		for e in W.enemies:
			if e.get("dead") or skip.has(e.id):
				continue
			var d: float = Cfg.dist2(float(e.x), float(e.z), float(Game.P.x), float(Game.P.z))
			if d < bd:
				bd = d
				best = e
		if best.is_empty():
			break
		got.append(best)
		skip[best.id] = 1
		Game.deal_to_enemy(best, dmg, false, Color(0.7, 0.2, 0.45), false, true, "shadow")
		if heal_r > 0:
			Game.heal_player(dmg * heal_r)
	return got


func _nearest_from(src: Dictionary, rad: float, skip_id) -> Dictionary:
	var best: Dictionary = {}
	var bd := rad * rad
	for e in W.enemies:
		if e.get("dead") or int(e.id) == int(skip_id):
			continue
		var d: float = Cfg.dist2(float(e.x), float(e.z), float(src.x), float(src.z))
		if d < bd:
			bd = d
			best = e
	return best


func nearest_enemy(rad: float) -> Dictionary:
	return _nearest_enemy(rad)


func _nearest_enemy(rad: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := rad * rad
	for e in W.enemies:
		if e.get("dead"):
			continue
		var d: float = Cfg.dist2(float(e.x), float(e.z), float(Game.P.x), float(Game.P.z))
		if d < bd:
			bd = d
			best = e
	return best


func pick_event_spot(away: float = 14.0, from = null) -> Dictionary:
	var px: float = float(from.x) if typeof(from) == TYPE_DICTIONARY else float(Game.P.x)
	var pz: float = float(from.z) if typeof(from) == TYPE_DICTIONARY else float(Game.P.z)
	for _i in 90:
		var x: float = -48.0 + Cfg._rng.randf() * 96.0
		var z: float = -48.0 + Cfg._rng.randf() * 96.0
		if not can_stand(x, z, 1.1):
			continue
		if Cfg.dist2(x, z, px, pz) < away * away:
			continue
		var near := false
		for m in W.marks:
			if Cfg.dist2(m.x, m.z, x, z) < 196:
				near = true
				break
		if near:
			continue
		for e in W.enemies:
			if e.get("dead"):
				continue
			if Cfg.dist2(e.x, e.z, x, z) < 64:
				near = true
				break
		if near:
			continue
		return {"x": x, "z": z}
	return {}


func ping_event(x: float, z: float, label: String, color: int, use: bool = false) -> Dictionary:
	add_mark({"kind": "event", "label": label, "x": x, "z": z, "color": color, "use": use})
	return W.marks[W.marks.size() - 1]


func hide_event_mark(m: Dictionary) -> void:
	if m.is_empty():
		return
	m.off = true
	m.use = false
	if m.get("node"):
		m.node.visible = false
	if m.get("label_node"):
		m.label_node.visible = false


func event_gate() -> Dictionary:
	for m in W.marks:
		if m.get("off"):
			continue
		if str(m.get("kind", "")) != "travel":
			continue
		var a: Dictionary = Data.AREA.get(str(m.get("to", "")), {})
		if a.get("kind") == "town":
			return m
	for m in W.marks:
		if str(m.get("kind", "")) == "travel" and not m.get("off"):
			return m
	return {}


func spawn_field_npc(opt: Dictionary) -> Dictionary:
	var look: Dictionary = opt.get("look", {"body": 0x6a4a2a, "skin": 0xb98a5a, "leg": 0x3a2a1a})
	var node := Assets.make_actor(str(opt.get("asset", "npc_kaden")), look, "human")
	if actors_root:
		actors_root.add_child(node)
	node.position = Vector3(opt.x, 0, opt.z)
	var lab := Label3D.new()
	lab.text = str(opt.n)
	lab.font = UiKit.ui_font()
	lab.font_size = 32
	lab.position.y = 2.6
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.91, 0.81, 0.58)
	node.add_child(lab)
	var n := {
		"id": opt.id, "name": opt.n, "x": opt.x, "z": opt.z, "node": node,
		"verb": opt.get("verb", "交谈"), "kind": "event", "path": []
	}
	W.npcs.append(n)
	return n


func route_npc(n: Dictionary, x: float, z: float) -> void:
	var tiles = find_path(Cfg.tx(n.x), Cfg.tz(n.z), Cfg.tx(x), Cfg.tz(z))
	if tiles == null:
		n.path = [{"x": x, "z": z}] if can_stand(x, z, 0.45) else []
		return
	n.path = path_to_world(tiles)
	if n.path.is_empty():
		n.path = [{"x": x, "z": z}]


func step_npc(n: Dictionary, dt: float, spd: float) -> String:
	var path: Array = n.get("path", [])
	if path.is_empty():
		return "idle"
	var p: Dictionary = path[0]
	var dx: float = float(p.x) - float(n.x)
	var dz: float = float(p.z) - float(n.z)
	var d: float = Cfg.hypot(dx, dz)
	if d < 0.4:
		path.remove_at(0)
		n.path = path
		if path.is_empty():
			return "arrive"
		return "walk"
	n.x = float(n.x) + dx / d * spd * dt
	n.z = float(n.z) + dz / d * spd * dt
	n.wphase = float(n.get("wphase", 0)) + dt * 10
	if n.get("node"):
		n.node.position = Vector3(n.x, 0, n.z)
		n.node.rotation.y = atan2(dx, dz)
	return "walk"


func maybe_field_event(force = false) -> Dictionary:
	if W.area.get("kind") != "field":
		return {}
	if W.get("event") and typeof(W.event) == TYPE_DICTIONARY and not W.event.is_empty():
		return W.event
	var forced := force == true or typeof(force) == TYPE_STRING
	if not forced and Cfg._rng.randf() >= 0.4:
		return {}
	var kinds := ["caravan", "chest", "riftwell", "apprentice"]
	var kind: String
	if typeof(force) == TYPE_STRING and kinds.has(str(force)):
		kind = str(force)
	else:
		kind = str(Cfg.pick(kinds))
	var spot := pick_event_spot(18)
	if spot.is_empty():
		return {}
	if kind == "caravan":
		start_caravan(spot)
	elif kind == "chest":
		start_chest_guard(spot)
	elif kind == "riftwell":
		start_rift_well(spot)
	else:
		start_apprentice(spot)
	if typeof(W.get("event")) == TYPE_DICTIONARY:
		return W.event
	return {}


func start_caravan(spot: Dictionary) -> void:
	var a: Dictionary = W.area
	var mark := ping_event(spot.x, spot.z, "商队遇袭", 0xd8c15c, false)
	var npc := spawn_field_npc({
		"id": "caravan", "n": "遇袭的商贩", "x": spot.x, "z": spot.z, "verb": "搭话",
		"look": {"body": 0x6a4a2a, "skin": 0xb98a5a, "leg": 0x3a2a1a}
	})
	var n: int = Cfg.ri(3, 4)
	for i in n:
		var ang: float = float(i) / float(n) * TAU
		var x: float = spot.x + cos(ang) * 3.2
		var z: float = spot.z + sin(ang) * 3.2
		if not can_stand(x, z, 0.6):
			continue
		var e := spawn_enemy(str(Cfg.pick(a.mobs)), x, z, maxi(1, int(a.lvl) + 1), i == 0)
		e.evt = "caravan"
	W.event = {"kind": "caravan", "state": "ambush", "x": spot.x, "z": spot.z, "mark": mark, "npc": npc, "t": 90.0}
	Game.hint("附近有商队遇袭")
	Game.say("车轴还在响。有人在喊。")


func on_caravan_kill() -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "caravan" or str(ev.get("state", "")) != "ambush":
		return
	for e in W.enemies:
		if not e.get("dead") and str(e.get("evt", "")) == "caravan":
			return
	begin_caravan_walk()


func begin_caravan_walk() -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "caravan":
		return
	if str(ev.get("state", "")) == "walk" or str(ev.get("state", "")) == "done":
		return
	var gate := event_gate()
	if gate.is_empty() or not ev.get("npc"):
		finish_caravan(true)
		return
	ev.state = "walk"
	ev.t = 90.0
	ev.gate = gate
	ev.waitHint = 0.0
	route_npc(ev.npc, gate.x, gate.z)
	Game.hint("护送商队到城门 · 别走远")
	Game.say("商贩：「走。别落太远。」")


func finish_caravan(ok: bool) -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "caravan":
		return
	if str(ev.get("state", "")) == "done" or str(ev.get("state", "")) == "fail":
		return
	ev.state = "done" if ok else "fail"
	ev.t = 0
	if ev.get("mark"):
		hide_event_mark(ev.mark)
	if ok:
		Game.P.shopDisc = int(Game.P.get("shopDisc", 0)) + 8
		Game.hint("商队脱险 · 回镇购物七折")
		Game.say("商贩记下了你。卡登他们会少收一截。")
		Sfx.quest()
	else:
		Game.hint("商队没能走出去")
		Game.say("车辙停了。人已经不在。")
	if ev.get("npc"):
		var n: Dictionary = ev.npc
		if n.get("node"):
			n.node.queue_free()
		W.npcs = W.npcs.filter(func(x): return x != n)
		ev.npc = null
	Game.save_soon()


func start_chest_guard(spot: Dictionary) -> void:
	var a: Dictionary = W.area
	var e := spawn_enemy(str(Cfg.pick(a.mobs)), spot.x, spot.z, maxi(1, int(a.lvl) + 4), true)
	e.evt = "chest"
	e.name = "宝箱守卫"
	e.hpMax = round(float(e.hpMax) * 1.85)
	e.hp = e.hpMax
	var cx: float = spot.x + 2.2
	var cz: float = spot.z + 1.4
	var mx: float = cx if can_stand(cx, cz, 0.7) else spot.x
	var mz: float = cz if can_stand(cx, cz, 0.7) else spot.z
	var mark := ping_event(mx, mz, "被守着的箱子", 0xe2a04a, false)
	W.event = {"kind": "chest", "state": "guard", "x": spot.x, "z": spot.z, "mark": mark, "guard": e}
	Game.hint("有人守着一口箱子")
	Game.say("箱子旁边站着一个不肯走的。")


func on_chest_guard_kill() -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "chest" or str(ev.get("state", "")) != "guard":
		return
	ev.state = "ready"
	if ev.get("mark"):
		ev.mark.use = true
	Game.hint("箱子没人守了")


func loot_event_chest(m: Dictionary) -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "chest" or str(ev.get("state", "")) == "looted":
		return
	if str(ev.get("state", "")) != "ready":
		Game.hint("还被守着")
		return
	ev.state = "looted"
	hide_event_mark(m)
	var lv: int = maxi(1, int(W.area.get("lvl", Game.P.lvl)) + 3)
	drop_item(m.x, m.z, Game.roll_item(lv, true))
	drop_gold(m.x + Cfg.rf(-0.6, 0.6), m.z + Cfg.rf(-0.6, 0.6), int(round((48 + lv * 20) * Cfg.rf(0.85, 1.25))))
	if Cfg._rng.randf() < 0.75:
		drop_item(m.x + Cfg.rf(-0.8, 0.8), m.z + Cfg.rf(-0.8, 0.8), Game.roll_rune())
	Game.hint("箱子开了")
	Sfx.loot()
	Game.say("箱子里的东西散了一地。")


func start_rift_well(spot: Dictionary) -> void:
	var mark := ping_event(spot.x, spot.z, "裂隙涌流", 0x8a4bff, true)
	W.event = {"kind": "riftwell", "state": "open", "x": spot.x, "z": spot.z, "mark": mark, "acc": 0.0}
	Game.hint("地上裂开了 · 站上去能封")
	Game.say("地上在喷东西。不封会一直喷。")


func close_rift_well() -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "riftwell" or str(ev.get("state", "")) != "open":
		return
	ev.state = "closed"
	if ev.get("mark"):
		hide_event_mark(ev.mark)
	drop_item(ev.x, ev.z, Game.roll_rune())
	drop_item(ev.x + Cfg.rf(-0.7, 0.7), ev.z + Cfg.rf(-0.7, 0.7), Game.roll_rune())
	Game.hint("裂口封上了")
	Sfx.quest()
	Game.say("裂口不喷了。地上多了两枚符文。")


func start_apprentice(spot: Dictionary) -> void:
	var dest := pick_event_spot(22, spot)
	if dest.is_empty():
		dest = pick_event_spot(14, spot)
	if dest.is_empty():
		return
	var mark := ping_event(spot.x, spot.z, "迷路的学徒", 0x7ec8ff, false)
	var npc := spawn_field_npc({
		"id": "apprentice", "n": "迷路的学徒", "x": spot.x, "z": spot.z, "verb": "跟上",
		"look": {"body": 0x3a4a6a, "skin": 0xd0a888, "leg": 0x2a3a45}
	})
	W.event = {"kind": "apprentice", "state": "idle", "x": spot.x, "z": spot.z, "mark": mark, "npc": npc, "dest": dest, "waitHint": 0.0}
	Game.hint("有个学徒站在原地")
	Game.say("有人在自言自语，说找不到回去的路。")


func begin_apprentice_walk() -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "apprentice" or str(ev.get("state", "")) != "idle" or not ev.get("npc"):
		return
	ev.state = "walk"
	route_npc(ev.npc, ev.dest.x, ev.dest.z)
	if ev.get("mark"):
		ev.mark.x = ev.dest.x
		ev.mark.z = ev.dest.z
		if ev.mark.get("node"):
			ev.mark.node.position = Vector3(ev.dest.x, 0.08, ev.dest.z)
		if ev.mark.get("label_node"):
			ev.mark.label_node.position = Vector3(ev.dest.x, 2.2, ev.dest.z)
			ev.mark.label_node.text = "学徒要去的地方"
		ev.mark.label = "学徒要去的地方"
	Game.hint("跟上学徒")
	Game.say("学徒：「跟上。那边有东西。」")


func finish_apprentice() -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "apprentice" or str(ev.get("state", "")) == "done":
		return
	ev.state = "done"
	var p: Dictionary = ev.get("dest", {"x": ev.x, "z": ev.z})
	var lv: int = maxi(1, int(W.area.get("lvl", Game.P.lvl)) + 2)
	drop_item(p.x, p.z, Game.roll_item(lv, true))
	drop_gold(p.x + Cfg.rf(-0.5, 0.5), p.z + Cfg.rf(-0.5, 0.5), int(round(30 + lv * 14)))
	if ev.get("mark"):
		hide_event_mark(ev.mark)
	Game.hint("挖出了东西")
	Sfx.loot()
	Game.say("学徒：「原来埋在这儿。」")


func use_event_mark(m: Dictionary) -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY:
		return
	if str(ev.get("kind", "")) == "chest":
		loot_event_chest(m)
	elif str(ev.get("kind", "")) == "riftwell" and str(ev.get("state", "")) == "open":
		if str(Game.P.get("casting", "")) != "":
			return
		Game.P.casting = "well"
		Game.P.castT = 0.0
		Game.hint("正在封口")


func event_npc_line(id: String) -> String:
	var ev = W.get("event")
	if id == "caravan":
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("kind", "")) == "caravan" and str(ev.get("state", "")) == "ambush":
			var left := false
			for e in W.enemies:
				if not e.get("dead") and str(e.get("evt", "")) == "caravan":
					left = true
					break
			if not left:
				begin_caravan_walk()
		if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "caravan":
			return "车已经空了。"
		var st := str(ev.get("state", ""))
		if st == "ambush":
			return "先把周围清了。我还能走。"
		if st == "walk":
			return "别停下。门还远。"
		if st == "done":
			return "记下了。回镇找卡登。"
		return "……算了。"
	if typeof(ev) == TYPE_DICTIONARY and str(ev.get("kind", "")) == "apprentice" and str(ev.get("state", "")) == "idle":
		begin_apprentice_walk()
	if typeof(ev) != TYPE_DICTIONARY or str(ev.get("kind", "")) != "apprentice":
		return "人已经走了。"
	var ast := str(ev.get("state", ""))
	if ast == "walk":
		return "跟上。那边有东西。"
	if ast == "done":
		return "原来埋在这儿。"
	return "我找不到回去的路。你跟不跟？"


func tick_event(dt: float) -> void:
	var ev = W.get("event")
	if typeof(ev) != TYPE_DICTIONARY or ev.is_empty():
		return
	if str(ev.get("kind", "")) == "caravan" and str(ev.get("state", "")) == "walk" and ev.get("npc"):
		ev.t = float(ev.t) - dt
		var n: Dictionary = ev.npc
		var far: bool = Cfg.dist2(n.x, n.z, Game.P.x, Game.P.z) > 16 * 16
		if far:
			ev.waitHint = float(ev.get("waitHint", 0)) + dt
			if float(ev.waitHint) > 3.2:
				ev.waitHint = 0
				Game.hint("商队在等你")
		else:
			ev.waitHint = 0
			var st := step_npc(n, dt, 3.4)
			if ev.get("mark"):
				ev.mark.x = n.x
				ev.mark.z = n.z
				if ev.mark.get("node"):
					ev.mark.node.position = Vector3(n.x, 0.08, n.z)
			var gate = ev.get("gate")
			if st == "arrive" or (typeof(gate) == TYPE_DICTIONARY and Cfg.dist2(n.x, n.z, gate.x, gate.z) < 9):
				finish_caravan(true)
		if str(ev.get("state", "")) == "walk" and float(ev.t) <= 0:
			finish_caravan(false)
	elif str(ev.get("kind", "")) == "apprentice" and str(ev.get("state", "")) == "walk" and ev.get("npc"):
		var n: Dictionary = ev.npc
		var far: bool = Cfg.dist2(n.x, n.z, Game.P.x, Game.P.z) > 15 * 15
		if far:
			ev.waitHint = float(ev.get("waitHint", 0)) + dt
			if float(ev.waitHint) > 3.5:
				ev.waitHint = 0
				Game.hint("学徒在等你")
		else:
			ev.waitHint = 0
			if step_npc(n, dt, 3.2) == "arrive":
				finish_apprentice()
	elif str(ev.get("kind", "")) == "riftwell" and str(ev.get("state", "")) == "open":
		ev.acc = float(ev.get("acc", 0)) + dt
		var near: bool = Cfg.dist2(float(ev.x), float(ev.z), float(Game.P.x), float(Game.P.z)) < 36 * 36
		var alive := 0
		for e in W.enemies:
			if not e.get("dead") and str(e.get("evt", "")) == "riftwell":
				alive += 1
		if near and alive < 6 and float(ev.acc) >= 2.2:
			ev.acc = 0
			var ang: float = Cfg._rng.randf() * TAU
			var r: float = 2.2 + Cfg._rng.randf() * 2.4
			var x: float = float(ev.x) + cos(ang) * r
			var z: float = float(ev.z) + sin(ang) * r
			if can_stand(x, z, 0.6):
				var e := spawn_enemy(str(Cfg.pick(W.area.mobs)), x, z, maxi(1, int(W.area.lvl)), false)
				e.evt = "riftwell"


func tick_world(dt: float) -> void:
	tick_event(dt)
	_tick_proj(dt)
	_tick_traps(dt)
	_tick_zones(dt)
	_tick_room_hint()
	_tick_torch_lights(dt)
	reveal_around_player()
	for e in W.enemies:
		if e.get("dead"):
			e.dieT = float(e.dieT) + dt
			_show_bar(e, false)
			if e.node:
				e.node.rotation.x = lerpf(e.node.rotation.x, -1.4, dt * 6)
				e.node.scale = e.node.scale.lerp(Vector3.ZERO, dt * 0.4)
			if e.dieT > 2.2 and e.node:
				e.node.queue_free()
				e.node = null
			continue
		e.atkCd = maxf(0, float(e.atkCd) - dt)
		e.stun = maxf(0, float(e.stun) - dt)
		e.slow = maxf(0, float(e.slow) - dt)
		e.frozen = maxf(0, float(e.frozen) - dt)
		e.hitFlash = maxf(0, float(e.hitFlash) - dt)
		e.skillCd = maxf(0, float(e.get("skillCd", 0)) - dt)
		e.woke = maxf(0, float(e.get("woke", 0)) - dt)
		e.spellImm = maxf(0, float(e.get("spellImm", 0)) - dt)
		if e.get("slamAt"):
			_tick_slam(e, dt)
		if e.get("ally"):
			_tick_ally(e, dt)
			continue
		if e.get("hoard"):
			_tick_hoard(e, dt)
			continue
		if e.get("sekhra") and int(e.get("phase", 1)) == 1 and float(e.hp) <= float(e.hpMax) * 0.5:
			e.phase = 2
			e.speed = float(e.speed) * 1.4
			e.shoutCd = 0
			Game.float_at(e.x, 5.0, e.z, "“%s”" % str(e.get("childName", "莉赛尔")), Color(1, 0.9, 0.63), 30)
			Game.say("塞克拉喊出「%s」。她不再找了，朝你冲过来。" % str(e.get("childName", "莉赛尔")))
			Sfx.boom()
		if has_mod(e, "count"):
			e.countT = float(e.get("countT", 8)) - dt
			if e.countT <= 0:
				e.countT = Cfg.rf(6, 10)
				Game.float_at(e.x, 3.2, e.z, "数到了", Color(0.89, 0.77, 0.5), 16)
				if Cfg.dist2(Game.P.x, Game.P.z, e.x, e.z) < 49:
					Game.hurt_player(Cfg.rf(e.dmg[0], e.dmg[1]) * 1.15, e)
					Game.knockback_player(e.x, e.z, 3.2)
		_decay_anim(e, dt)
		if e.stun > 0 or e.frozen > 0:
			_sync_node(e)
			continue
		if W.area.get("kind") == "town" or not Game.P.alive:
			_sync_node(e)
			continue
		if e.get("boss") and not e.get("seenIntro"):
			if Cfg.dist2(e.x, e.z, Game.P.x, Game.P.z) < 100:
				Game.start_boss_intro(e)
		if Game.cine_boss.size() > 0:
			_sync_node(e)
			continue
		var d: float = sqrt(Cfg.dist2(float(e.x), float(e.z), float(Game.P.x), float(Game.P.z)))
		var aggro := d <= 22.0 or float(e.get("woke", 0)) > 0
		if e.get("shout") and aggro and Game.P.alive:
			e.shoutCd = float(e.get("shoutCd", 0)) - dt
			if e.shoutCd <= 0:
				e.shoutCd = 4.5 if int(e.get("phase", 1)) == 2 else 6.5
				var nm: String = str(e.get("callName", e.get("childName", "——")))
				if e.get("sekhra") and int(e.get("phase", 1)) == 1:
					nm = str(e.get("callName", "孩子"))
				Game.float_at(e.x, 4.2, e.z, "“%s？”" % nm, Color(0.91, 0.86, 0.68), 20)
				Sfx.cast()
				var woke := 0
				var rad2: float = 196.0 if e.get("boss") else 100.0
				for o in W.enemies:
					if o == e or o.get("dead"):
						continue
					if Cfg.dist2(o.x, o.z, e.x, e.z) < rad2:
						o.woke = 3.0
						woke += 1
				if woke:
					Game.float_at(e.x, 5.0, e.z, "惊醒了 %d 具" % woke, Color(0.69, 0.6, 0.42), 14)
		if d > 28 and float(e.get("woke", 0)) <= 0:
			_sync_node(e)
			continue
		if e.get("boss") and str(e.get("skill", "")) != "" and float(e.get("skillCd", 0)) <= 0 and Game.P.alive and d < 22:
			_boss_skill(e)
		var choir := choir_src(e)
		var spd_m := 1.26 if not choir.is_empty() else 1.0
		if float(e.get("woke", 0)) > 0:
			spd_m *= 1.25
		if d > e.range:
			e.anim.walk = float(e.anim.get("walk", 0)) + dt * 9
			if has_mod(e, "rush") and d < float(e.range) + 2.2 and d > 1.2:
				var sp: float = float(e.speed) * dt * spd_m
				var dx: float = e.x - Game.P.x
				var dz: float = e.z - Game.P.z
				move_entity(e, e.x + dx / d * sp, e.z + dz / d * sp)
				e.dir = atan2(Game.P.x - e.x, Game.P.z - e.z)
			else:
				var sp: float = float(e.speed) * dt * (0.55 if e.slow > 0 else 1.0) * spd_m
				var dx: float = Game.P.x - e.x
				var dz: float = Game.P.z - e.z
				move_entity(e, e.x + dx / d * sp, e.z + dz / d * sp)
				e.dir = atan2(dx, dz)
		elif e.atkCd <= 0:
			e.anim.walk = lerpf(float(e.anim.get("walk", 0)), 0, dt * 6)
			e.atkCd = float(e.atkSpeed)
			e.anim.atk = 0.4
			var dmg := Cfg.rf(e.dmg[0], e.dmg[1]) * (1.38 if not choir.is_empty() else 1.0)
			Game.hurt_player(dmg, e)
		else:
			e.anim.walk = lerpf(float(e.anim.get("walk", 0)), 0, dt * 6)
		_sync_node(e)
	for it in W.items:
		if it.get("mesh"):
			it.t = float(it.get("t", 0)) + dt
			it.mesh.position = Vector3(it.x, 0.12 + sin(it.t * 3.2) * 0.08, it.z)
			it.mesh.rotation.y = it.t
			var lab: Node = it.mesh.get_node_or_null("lname")
			if lab:
				lab.visible = loot_name_on(it)
				lab.rotation.y = -it.t
			var beam: Node = it.mesh.get_node_or_null("beam")
			if beam:
				beam.rotation.y = -it.t
	for n in W.npcs:
		if n.get("node") == null:
			continue
		var path: Array = n.get("path", [])
		if path.is_empty():
			n.wphase = lerpf(float(n.get("wphase", 0)), 0, dt * 8)
		Assets.tick_anim(n.node, float(n.get("wphase", 0)), 0.0)
	if W.get("player_node"):
		var pn: Node3D = W.player_node
		pn.position = Vector3(Game.P.x, 0, Game.P.z)
		pn.rotation.y = Game.P.dir
		Assets.tick_anim(pn, float(Game.P.anim.walk), float(Game.P.anim.atk))


func _boss_skill(e: Dictionary) -> void:
	var sk: String = str(e.get("skill", ""))
	e.skillCd = 7.0 if sk == "slam" else 9.0
	if sk == "summon":
		for _i in 3:
			var ax: float = float(e.x) + Cfg.rf(-3.5, 3.5)
			var az: float = float(e.z) + Cfg.rf(-3.5, 3.5)
			if can_stand(ax, az, 0.6):
				spawn_enemy("spider" if Cfg._rng.randf() < 0.5 else "ghoul", ax, az, maxi(1, int(e.lvl) - 2), false)
		Game.float_at(e.x, 4.0, e.z, "召唤子嗣！", Color(1, 0.42, 0.35), 19)
	elif sk == "nova":
		Game.float_at(e.x, 4.0, e.z, "骨刺新星！", Color(1, 0.94, 0.63), 19)
		Sfx.cast()
		for i in 12:
			var a: float = float(i) / 12.0 * TAU
			var p := {
				"x": float(e.x) + cos(a), "z": float(e.z) + sin(a), "y": 1.3,
				"dx": cos(a), "dz": sin(a), "spd": 11.0,
				"dmg": Cfg.rf(e.dmg[0], e.dmg[1]) * 0.7, "from": "enemy", "life": 1.4,
				"src": e
			}
			p.mesh = _proj_mesh(0xf0e0a0, false)
			_proj.append(p)
	elif sk == "slam":
		e.slamAt = {"x": Game.P.x, "z": Game.P.z, "t": 1.1}
		Game.float_at(e.x, 4.0, e.z, "跃击！", Color(1, 0.54, 0.35), 19)


func _tick_slam(e: Dictionary, dt: float) -> void:
	var s2: Dictionary = e.slamAt
	s2.t = float(s2.t) - dt
	if float(s2.t) > 0:
		return
	e.slamAt = null
	Sfx.boom()
	if Cfg.dist2(Game.P.x, Game.P.z, float(s2.x), float(s2.z)) < 5.5 * 5.5:
		Game.hurt_player(Cfg.rf(e.dmg[0], e.dmg[1]) * 1.6, e)
		Game.knockback_player(float(s2.x), float(s2.z), 4.4)
		Game.P.stun = maxf(float(Game.P.stun), 0.4)
	if can_stand(float(s2.x), float(s2.z), 0.6):
		e.x = float(s2.x) + Cfg.rf(-1, 1)
		e.z = float(s2.z) + Cfg.rf(-1, 1)


func _tick_hoard(e: Dictionary, dt: float) -> void:
	var d: float = sqrt(Cfg.dist2(float(e.x), float(e.z), float(Game.P.x), float(Game.P.z)))
	e.hoardSeen = e.get("hoardSeen") == true or (Game.P.alive and d < 18)
	if e.get("hoardSeen") and Game.P.alive:
		e.hoardFlee = float(e.get("hoardFlee", 0)) + dt
		var ax: float = float(e.x) - float(Game.P.x)
		var az: float = float(e.z) - float(Game.P.z)
		var l: float = Cfg.hypot(ax, az)
		if l < 0.01:
			l = 1.0
		var spd: float = float(e.speed) * (0.4 if float(e.slow) > 0 else 1.0)
		var ox: float = float(e.x)
		var oz: float = float(e.z)
		move_entity(e, e.x + ax / l * spd * 1.5 * dt, e.z + az / l * spd * 1.5 * dt)
		if Cfg.hypot(float(e.x) - ox, float(e.z) - oz) < 0.03:
			var a: float = Cfg._rng.randf() * TAU
			move_entity(e, e.x + cos(a) * spd * 1.2 * dt, e.z + sin(a) * spd * 1.2 * dt)
		e.dir = atan2(float(e.x) - float(Game.P.x), float(e.z) - float(Game.P.z))
		var from: float = Cfg.hypot(float(e.x) - float(e.get("hoardX", 0)), float(e.z) - float(e.get("hoardZ", 0)))
		if float(e.hoardFlee) > 26.0 or from > 34.0:
			rift_hoard_escape(e)
	_sync_node(e)


func _tick_ally(e: Dictionary, dt: float) -> void:
	e.allyT = float(e.get("allyT", 0)) - dt
	if float(e.allyT) <= 0:
		ally_leave(e, "忘了")
		return
	var tgt := _nearest_hostile(e, 16.0)
	var tx: float = float(Game.P.x)
	var tz: float = float(Game.P.z)
	var atk := false
	if not tgt.is_empty():
		tx = float(tgt.x)
		tz = float(tgt.z)
		atk = Cfg.hypot(tx - float(e.x), tz - float(e.z)) <= float(e.range) + 0.35
	var d: float = Cfg.hypot(tx - float(e.x), tz - float(e.z))
	if d < 0.01:
		d = 1.0
	var spd: float = float(e.speed) * (0.4 if float(e.slow) > 0 else 1.0)
	if not atk and d > (1.4 if not tgt.is_empty() else 2.2):
		move_entity(e, e.x + (tx - float(e.x)) / d * spd * dt, e.z + (tz - float(e.z)) / d * spd * dt)
	e.dir = atan2(tx - float(e.x), tz - float(e.z))
	if atk and not tgt.is_empty() and float(e.atkCd) <= 0:
		e.atkCd = float(e.atkSpeed)
		var ad: float = Cfg.rf(e.dmg[0], e.dmg[1])
		tgt.hp -= ad
		Game.float_at(tgt.x, 2.3, tgt.z, str(int(ad)), Color(0.78, 0.63, 0.38), 15)
		if float(tgt.hp) <= 0:
			Game.kill_enemy(tgt)
	_sync_node(e)


func _nearest_hostile(from: Dictionary, maxd: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := maxd * maxd
	for o in W.enemies:
		if o == from or o.get("dead") or o.get("ally") or o.get("hoard"):
			continue
		var d: float = Cfg.dist2(o.x, o.z, from.x, from.z)
		if d < bd:
			bd = d
			best = o
	return best


func _tick_traps(dt: float) -> void:
	for r in W.get("traps", []):
		if typeof(r) != TYPE_DICTIONARY or str(r.get("trap", "")) == "":
			continue
		var inside := in_room_tile(r, Game.P.x, Game.P.z)
		if not inside or not Game.P.alive:
			r.trapAcc = 0
			continue
		r.trapIn = float(r.get("trapIn", 0)) + dt
		r.trapTick = float(r.get("trapTick", 0)) + dt
		if str(r.trap) == "spike" and float(r.trapTick) > 0.72:
			r.trapTick = 0
			Game.hurt_player(maxf(7.0, float(Game.P.hpMax) * 0.038), {}, true)
		if str(r.trap) == "rock" and float(r.trapTick) > 1.15:
			r.trapTick = 0
			Game.hurt_player(maxf(11.0, float(Game.P.hpMax) * 0.055), {}, true)
		if str(r.trap) == "fog" and float(r.trapTick) > 0.9:
			r.trapTick = 0
			Game.hurt_player(maxf(6.0, float(Game.P.hpMax) * 0.028), {}, true)
		if not r.get("trapDone") and float(r.trapIn) > 2.4:
			r.trapDone = true
			Game.hint("走过去了。地上有东西。")
			drop_item(Cfg.wx(r.cx), Cfg.wx(r.cy), Game.roll_item(floor_lvl(), true))


func _tick_room_hint() -> void:
	for r in W.rooms:
		if str(r.get("tag", "")) == "" or r.get("hinted"):
			continue
		if not in_room_tile(r, Game.P.x, Game.P.z):
			continue
		r.hinted = true
		var msg := {"vault": "这里堆着东西。也堆着人。", "shrine": "有人还在这里许愿。", "cage": "笼子里还有一口气。", "trap": "脚下不对。"}
		Game.hint(str(msg.get(str(r.tag), "")))


func add_zone(x: float, z: float, rad: float, life: float, dmg: float, hurt: String = "enemy", extra: Dictionary = {}) -> void:
	_zones.append({
		"x": x, "z": z, "r": rad, "t": life, "acc": 0.0, "dmg": dmg, "hurt": hurt,
		"rain": extra.get("rain", false) == true, "tick": float(extra.get("tick", 0.5)),
		"slow": float(extra.get("slow", 0)), "elem": str(extra.get("elem", "fire"))
	})


func _tick_zones(dt: float) -> void:
	var i := _zones.size() - 1
	while i >= 0:
		var z: Dictionary = _zones[i]
		z.t = float(z.t) - dt
		z.acc = float(z.acc) + dt
		if float(z.acc) >= float(z.get("tick", 0.5)):
			z.acc = 0
			if str(z.hurt) == "player":
				if Cfg.dist2(Game.P.x, Game.P.z, float(z.x), float(z.z)) < float(z.r) * float(z.r):
					Game.hurt_player(float(z.dmg), {}, true)
			else:
				aoe_player(float(z.x), float(z.z), float(z.r), float(z.dmg), str(z.get("elem", "fire")), 0.0, float(z.get("slow", 0)))
		if float(z.t) <= 0:
			_zones.remove_at(i)
		i -= 1


func _decay_anim(e: Dictionary, dt: float) -> void:
	if typeof(e.get("anim")) != TYPE_DICTIONARY:
		e.anim = {"walk": 0.0, "atk": 0.0}
	e.anim.atk = maxf(0.0, float(e.anim.get("atk", 0)) - dt)


func _sync_node(e: Dictionary) -> void:
	if e.node:
		e.node.position = Vector3(e.x, 0, e.z)
		e.node.rotation.y = float(e.get("dir", 0))
		var anim: Dictionary = e.get("anim", {})
		if typeof(anim) != TYPE_DICTIONARY:
			anim = {}
		Assets.tick_anim(e.node, float(anim.get("walk", 0)), float(anim.get("atk", 0)))
	_sync_bar(e)


func _tick_proj(dt: float) -> void:
	var i := _proj.size() - 1
	while i >= 0:
		var p: Dictionary = _proj[i]
		p.life = float(p.life) - dt
		if p.has("homing") and p.homing and not p.homing.get("dead", true):
			p.dx = p.homing.x - p.x
			p.dz = p.homing.z - p.z
		var L: float = Cfg.hypot(float(p.dx), float(p.dz))
		if L > 0.001:
			p.x += p.dx / L * float(p.spd) * dt
			p.z += p.dz / L * float(p.spd) * dt
		if p.get("mesh"):
			p.mesh.position = Vector3(p.x, float(p.get("y", 1.3)), p.z)
			p.mesh.rotation.y = atan2(float(p.dx), float(p.dz))
		var hit := false
		if str(p.from) == "player":
			for e in W.enemies:
				if e.get("dead") or e.get("ally"):
					continue
				var ids = p.get("hitIds", [])
				if typeof(ids) == TYPE_ARRAY and ids.has(e.id):
					continue
				if Cfg.dist2(e.x, e.z, p.x, p.z) < 0.9:
					Game.deal_to_enemy(e, float(p.dmg), p.get("crit", false) == true, Color(0.95, 0.85, 0.6), false, true, str(p.get("elem", "phys")))
					if p.get("poison") and p.get("dot", 0) > 0:
						e.dot = {"t": 6.0, "dmg": p.dot}
					if float(p.get("stun", 0)) > 0 or p.get("vine"):
						e.stun = maxf(float(e.stun), 0.8 if p.get("vine") else float(p.get("stun", 0)))
					if float(p.get("splash", 0)) > 0:
						aoe_player(float(p.x), float(p.z), float(p.splash), float(p.dmg) * 0.45, str(p.get("elem", "phys")))
					if p.get("pierce"):
						if typeof(ids) != TYPE_ARRAY:
							ids = []
						ids.append(e.id)
						p.hitIds = ids
					else:
						hit = true
						break
		elif str(p.from) == "enemy":
			if Cfg.dist2(Game.P.x, Game.P.z, p.x, p.z) < 0.95:
				var src: Dictionary = p.src if typeof(p.get("src")) == TYPE_DICTIONARY else {}
				Game.hurt_player(float(p.dmg), src)
				hit = true
		var wall: bool = not can_stand(p.x, p.z, 0.2)
		if hit or float(p.life) <= 0 or wall:
			if p.get("linger"):
				add_zone(p.x, p.z, 1.6, 3.0, float(p.dmg) * 0.22, "enemy")
			if p.get("cloud"):
				add_zone(p.x, p.z, 2.2, 3.2, float(p.dmg) * 0.18, "enemy", {"elem": "shadow", "tick": 0.35})
			if p.get("mesh"):
				p.mesh.queue_free()
			_proj.remove_at(i)
		i -= 1
