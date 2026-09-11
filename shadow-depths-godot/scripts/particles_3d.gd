extends Node3D
# 环境粒子与战斗爆发粒子。全部使用 CPUParticles3D，一次性发射的粒子在生命
# 结束后自动回收；continuous 的粒子由场景重建时统一释放。

var dot: SphereMesh
var live: Array = []

func _ready():
	ensure_dot()

func ensure_dot():
	if dot != null: return
	dot = SphereMesh.new(); dot.radius = 0.045; dot.height = 0.09; dot.radial_segments = 5; dot.rings = 3

# kind: spark 火花 / burst 命中爆发 / ember 上升余烬 / frost 冰晶 / dust 尘团 /
#       smoke 烟雾 / snow 飞雪 / motes 浮尘光点
func spawn(p: Vector3,color: Color,kind: String = "spark",continuous: bool = false,amount: int = 24) -> CPUParticles3D:
	ensure_dot()
	var node = CPUParticles3D.new()
	add_child(node)
	node.position = p
	node.mesh = dot
	node.amount = amount
	node.one_shot = not continuous
	node.explosiveness = 0.0 if continuous else 0.85
	node.direction = Vector3.UP
	node.scale_amount_min = 0.5
	match kind:
		"smoke":
			node.lifetime = 3.5; node.spread = 18; node.gravity = Vector3(0, 0.12, 0)
			node.initial_velocity_min = 0.5; node.initial_velocity_max = 0.65
			node.scale_amount_max = 7.0; node.damping_min = 0.4; node.damping_max = 1.2
		"burst":
			node.lifetime = 0.55; node.spread = 180.0; node.gravity = Vector3(0, -6.5, 0)
			node.initial_velocity_min = 2.4; node.initial_velocity_max = 6.2
			node.scale_amount_max = 0.95; node.damping_min = 1.5; node.damping_max = 4.0
		"ember":
			node.lifetime = 1.25; node.spread = 26.0; node.gravity = Vector3(0, 0.75, 0)
			node.initial_velocity_min = 0.5; node.initial_velocity_max = 1.7
			node.scale_amount_max = 0.75; node.damping_min = 0.6; node.damping_max = 1.6
			node.explosiveness = 0.0
		"frost":
			node.lifetime = 0.95; node.spread = 180.0; node.gravity = Vector3(0, -3.4, 0)
			node.initial_velocity_min = 1.4; node.initial_velocity_max = 3.6
			node.scale_amount_max = 1.1; node.damping_min = 2.5; node.damping_max = 6.0
		"dust":
			node.lifetime = 0.8; node.spread = 62.0; node.gravity = Vector3(0, -0.35, 0)
			node.initial_velocity_min = 0.7; node.initial_velocity_max = 2.1
			node.scale_amount_max = 3.4; node.damping_min = 2.0; node.damping_max = 4.5
		"snow":
			node.lifetime = 8.0; node.spread = 12.0; node.gravity = Vector3(0, -0.2, 0)
			node.initial_velocity_min = 0.2; node.initial_velocity_max = 1.0
			node.scale_amount_max = 0.8; node.explosiveness = 0.0
		"motes":
			node.lifetime = 4.0; node.spread = 180.0; node.gravity = Vector3(0, 0.18, 0)
			node.initial_velocity_min = 0.05; node.initial_velocity_max = 0.35
			node.scale_amount_max = 0.7; node.explosiveness = 0.0
		_:
			node.lifetime = 1.1; node.spread = 65.0; node.gravity = Vector3(0, -2.5, 0)
			node.initial_velocity_min = 0.5; node.initial_velocity_max = 2.2
			node.scale_amount_max = 1.5; node.damping_min = 0.0; node.damping_max = 0.0
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	node.material_override = mat
	node.color_ramp = ramp(color, kind in ["burst", "frost", "ember"])
	node.emitting = true
	if not continuous: live.append({"node": node, "life": node.lifetime + 0.3})
	return node

# 命中类粒子先白热再回到本色，读起来更有打击感。
func ramp(color: Color, hot: bool) -> Gradient:
	var g = Gradient.new()
	if hot:
		g.offsets = PackedFloat32Array([0.0, 0.32, 1.0])
		g.colors = PackedColorArray([color.lightened(0.65), color, Color(color.r, color.g, color.b, 0.0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	return g

# 投射物拖尾：local_coords 关闭，粒子留在发射时的世界坐标上形成尾迹。
func trail(parent: Node3D, color: Color, amount: int = 22, life: float = 0.30) -> CPUParticles3D:
	ensure_dot()
	var node = CPUParticles3D.new()
	parent.add_child(node)
	node.mesh = dot
	node.amount = amount
	node.lifetime = life
	node.one_shot = false
	node.explosiveness = 0.0
	node.local_coords = false
	node.direction = Vector3.UP
	node.spread = 10.0
	node.gravity = Vector3.ZERO
	node.initial_velocity_min = 0.0
	node.initial_velocity_max = 0.14
	node.damping_min = 3.0
	node.damping_max = 6.0
	node.scale_amount_min = 0.45
	node.scale_amount_max = 1.05
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	node.material_override = mat
	node.color_ramp = ramp(color, true)
	node.emitting = true
	return node

# 把持续发射器挂到会移动的节点（技能环、旋风）上，跟随父节点一起走。
func attach(parent: Node3D, color: Color, kind: String = "ember", amount: int = 18) -> CPUParticles3D:
	var node = spawn(Vector3.ZERO, color, kind, true, amount)
	remove_child(node)
	parent.add_child(node)
	return node

func _process(dt):
	for i in range(live.size() - 1, -1, -1):
		live[i].life -= dt
		if live[i].life <= 0: live[i].node.queue_free(); live.remove_at(i)
