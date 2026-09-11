extends Node3D
# 战斗特效池。扩散环、挥砍弧、地面残留、命中闪光、冰锥碎石、蓄能环和一个
# 五盏灯的动态点光池。所有几何与材质在代码里生成，与项目其余程序化美术一致，
# 不依赖任何外部资源。由 world_3d.sync 显式驱动 update(dt)，暂停时随场景冻结。

const MAX_ITEMS = 96
const MAX_LIGHTS = 5

var annulus: ArrayMesh
var disc: ArrayMesh
var arc: ArrayMesh
var sphere: SphereMesh
var spike: CylinderMesh
var column: CylinderMesh

var items: Array = []
var lights: Array = []
var light_life: Array = []
var light_max: Array = []
var light_peak: Array = []
var light_slot := 0
var clock := 0.0

func _init():
	annulus = ring_mesh(0.80, 1.0, 44)
	disc = ring_mesh(0.0, 1.0, 40)
	arc = arc_mesh(2.15, 0.40, 1.0, 22)
	sphere = SphereMesh.new()
	sphere.radius = 0.5; sphere.height = 1.0; sphere.radial_segments = 10; sphere.rings = 6
	spike = CylinderMesh.new()
	spike.top_radius = 0.0; spike.bottom_radius = 0.5; spike.height = 1.0; spike.radial_segments = 5
	column = CylinderMesh.new()
	column.top_radius = 0.55; column.bottom_radius = 0.55; column.height = 1.0
	column.radial_segments = 10; column.rings = 2

# ---------------------------------------------------------------- geometry ---
func ring_mesh(inner: float, outer: float, segments: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 = TAU * float(i) / float(segments)
		var a1 = TAU * float(i + 1) / float(segments)
		var p0 = Vector3(cos(a0), 0.0, sin(a0))
		var p1 = Vector3(cos(a1), 0.0, sin(a1))
		for v in [p0 * inner, p0 * outer, p1 * outer, p0 * inner, p1 * outer, p1 * inner]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2.ZERO); st.add_vertex(v)
	return st.commit()

func arc_mesh(sweep: float, inner: float, outer: float, segments: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 = -sweep * 0.5 + sweep * float(i) / float(segments)
		var a1 = -sweep * 0.5 + sweep * float(i + 1) / float(segments)
		# 前方为 -Z，与角色朝向的旋转约定一致。
		var p0 = Vector3(sin(a0), 0.0, -cos(a0))
		var p1 = Vector3(sin(a1), 0.0, -cos(a1))
		for v in [p0 * inner, p0 * outer, p1 * outer, p0 * inner, p1 * outer, p1 * inner]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2.ZERO); st.add_vertex(v)
	return st.commit()

# --------------------------------------------------------------- materials ---
func fx_mat(c: Color, additive: bool = true) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.render_priority = 8
	m.albedo_color = c
	return m

# ------------------------------------------------------------------ pooling ---
func register(node: Node3D, mat: Material, base: Color, kind: String, life: float, data: Dictionary) -> Node3D:
	while items.size() >= MAX_ITEMS:
		var old = items.pop_front()
		if is_instance_valid(old.node): old.node.queue_free()
	add_child(node)
	items.append({"node": node, "mat": mat, "base": base, "kind": kind, "life": life, "max": maxf(life, 0.001), "data": data})
	return node

func mesh_item(mesh: Mesh, mat: Material, base: Color, kind: String, life: float, data: Dictionary, p: Vector3) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = p
	return register(n, mat, base, kind, life, data)

# ----------------------------------------------------------------- effects ---
# 地面扩散环。thick 控制厚度方向的缩放，用来做薄冲击波或粗能量环。
func shockwave(p: Vector3, r0: float, r1: float, life: float, c: Color, thick: float = 1.0):
	var m = fx_mat(c)
	var n = mesh_item(annulus, m, c, "ring", life, {"r0": r0, "r1": r1, "thick": thick, "y": 1.0}, p + Vector3(0, 0.09, 0))
	n.scale = Vector3(r0, thick, r0)
	return n

# 贴地光斑，用于法术残留、焦痕、霜面。
func ground(p: Vector3, radius: float, life: float, c: Color, additive: bool = true, alpha: float = 0.75):
	var m = fx_mat(c, additive)
	var n = mesh_item(disc, m, c, "ground", life, {"r": radius, "a": alpha, "flat": 1.0}, p + Vector3(0, 0.07, 0))
	n.scale = Vector3(radius * 0.35, 1.0, radius * 0.35)
	return n

# 挥砍弧。angle 为世界朝向（与角色 rotation.y 同一约定）。
func swing(p: Vector3, angle: float, radius: float, life: float, c: Color, sweep: float = 2.15):
	var m = fx_mat(c)
	var n = mesh_item(arc, m, c, "swing", life, {"sweep": sweep, "r": radius}, p + Vector3(0, 0.78, 0))
	n.scale = Vector3(radius, 1.0, radius)
	n.rotation.y = angle - sweep * 0.5
	return n

# 命中核心：一个快速膨胀并消散的发光球。
func core(p: Vector3, radius: float, life: float, c: Color):
	var m = fx_mat(c)
	var n = mesh_item(sphere, m, c, "core", life, {"r": radius}, p + Vector3(0, 0.85, 0))
	n.scale = Vector3.ONE * 0.001
	return n

# 一圈锥体（冰刺 / 碎石）。
func shards(p: Vector3, count: int, radius: float, height: float, life: float, c: Color, tilt: float = 0.22):
	var m = fx_mat(c)
	var root = Node3D.new()
	root.position = p
	for i in count:
		var a = TAU * float(i) / float(count)
		var s = MeshInstance3D.new()
		s.mesh = spike
		s.material_override = m
		s.position = Vector3(cos(a) * radius, height * 0.5, sin(a) * radius)
		s.scale = Vector3(height * 0.30, height, height * 0.30)
		s.rotation = Vector3(sin(a) * tilt, 0.0, -cos(a) * tilt)
		root.add_child(s)
	root.scale.y = 0.02
	return register(root, m, c, "shards", life, {"r": radius, "h": height})

# 竖直光柱，用于陨星、蓄能、传送。
func pillar(p: Vector3, radius: float, height: float, life: float, c: Color):
	var m = fx_mat(c)
	var n = mesh_item(column, m, c, "pillar", life, {"r": radius, "h": height}, p)
	n.scale = Vector3(radius, 0.02, radius)
	return n

# 蓄能：环由外向内收缩，配合逐渐变亮的地面光斑。
func charge(p: Vector3, r0: float, r1: float, life: float, c: Color):
	var m = fx_mat(c)
	var n = mesh_item(annulus, m, c, "charge", life, {"r0": r0, "r1": r1}, p + Vector3(0, 0.09, 0))
	n.scale = Vector3(r0, 1.0, r0)
	return n

# ------------------------------------------------------------------ lights ---
func ensure_lights():
	if not lights.is_empty(): return
	for i in MAX_LIGHTS:
		var l = OmniLight3D.new()
		l.omni_range = 6.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		lights.append(l); light_life.append(0.0); light_max.append(1.0); light_peak.append(0.0)

func flash(p: Vector3, c: Color, energy: float, range_: float, life: float):
	ensure_lights()
	var i = light_slot
	light_slot = (light_slot + 1) % lights.size()
	var l = lights[i]
	l.position = p
	l.light_color = c
	l.light_energy = energy
	l.omni_range = range_
	light_life[i] = life; light_max[i] = maxf(life, 0.001); light_peak[i] = energy

# ------------------------------------------------------------------ update ---
func update(dt: float):
	clock += dt
	for i in lights.size():
		if light_life[i] <= 0.0: continue
		light_life[i] -= dt
		if light_life[i] <= 0.0:
			lights[i].light_energy = 0.0
		else:
			var k = light_life[i] / light_max[i]
			lights[i].light_energy = light_peak[i] * k * k
	for i in range(items.size() - 1, -1, -1):
		var it = items[i]
		it.life -= dt
		var t = clampf(1.0 - it.life / it.max, 0.0, 1.0)
		var a = clampf(it.life / it.max, 0.0, 1.0)
		var n: Node3D = it.node
		var d: Dictionary = it.data
		if not is_instance_valid(n):
			items.remove_at(i); continue
		match it.kind:
			"ring":
				var ease = 1.0 - pow(1.0 - t, 3.0)
				var r = lerpf(d.r0, d.r1, ease)
				n.scale = Vector3(r, d.thick, r)
				apply_fade(it, a * a)
			"ground":
				var pop = 1.0 - pow(1.0 - minf(1.0, t * 3.0), 2.0)
				var r = lerpf(d.r * 0.35, d.r, pop)
				n.scale = Vector3(r, 1.0, r)
				apply_fade(it, sin(a * PI * 0.9) * d.a)
			"swing":
				n.rotation.y += dt * d.sweep / maxf(it.max, 0.001)
				var s = d.r * (0.86 + 0.22 * t)
				n.scale = Vector3(s, 1.0, s)
				apply_fade(it, sin(clampf(t, 0.0, 1.0) * PI) * 0.85)
			"core":
				var ease = 1.0 - pow(1.0 - t, 2.2)
				var s = lerpf(d.r * 0.25, d.r * 1.65, ease)
				n.scale = Vector3.ONE * s
				apply_fade(it, pow(a, 0.65))
			"shards":
				var grow = 1.0 - pow(1.0 - minf(1.0, t * 3.2), 3.0)
				n.scale.y = lerpf(0.02, 1.0, grow) * (1.0 - 0.18 * maxf(0.0, t - 0.75) / 0.25)
				n.rotation.y += dt * 0.7
				apply_fade(it, sin(a * PI * 0.85))
			"pillar":
				var grow = 1.0 - pow(1.0 - minf(1.0, t * 2.4), 3.0)
				n.scale.y = lerpf(0.02, d.h, grow)
				n.scale.x = d.r * (1.0 - 0.35 * t)
				n.scale.z = d.r * (1.0 - 0.35 * t)
				apply_fade(it, sin(a * PI * 0.8))
			"charge":
				var ease = t * t
				var r = lerpf(d.r0, d.r1, ease)
				n.scale = Vector3(r, 1.0 + 0.4 * t, r)
				n.rotation.y += dt * 3.0
				apply_fade(it, sin(t * PI * 0.85))
		if it.life <= 0.0:
			n.queue_free(); items.remove_at(i)

func apply_fade(it: Dictionary, k: float):
	var m: StandardMaterial3D = it.mat
	var c: Color = it.base
	k = clampf(k, 0.0, 1.0)
	if m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
		# 同时压低 RGB 与 alpha，无论加法混合是否乘 alpha 都能正确淡出。
		m.albedo_color = Color(c.r * k, c.g * k, c.b * k, k)
	else:
		m.albedo_color = Color(c.r, c.g, c.b, k * float(it.data.get("a", 1.0)))

func clear():
	for it in items:
		if is_instance_valid(it.node): it.node.queue_free()
	items.clear()
	for i in lights.size():
		lights[i].light_energy = 0.0
		light_life[i] = 0.0
