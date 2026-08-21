extends Node
## 每个模型一个 `res://models/<id>.tscn`。换模型只改那个场景，不必动代码。

const DIR := "res://models/"

var _pack: Dictionary = {}
var _parts: Dictionary = {}
var _pool: Dictionary = {}


func _exit_tree() -> void:
	for id in _pool.keys():
		for n in _pool[id]:
			if n:
				(n as Node).free()
	_pool.clear()


func path_of(id: String) -> String:
	if id == "":
		return ""
	return DIR + id + ".tscn"


func has(id: String) -> bool:
	return id != "" and ResourceLoader.exists(path_of(id))


func scene_of(id: String) -> PackedScene:
	if id == "":
		return null
	if _pack.has(id):
		return _pack[id]
	if not has(id):
		return null
	var ps: PackedScene = load(path_of(id))
	if ps:
		_pack[id] = ps
	return ps


func spawn(id: String) -> Node3D:
	var ps := scene_of(id)
	if ps == null:
		if id != "":
			push_warning("[assets] 无法加载 %s" % path_of(id))
		return null
	return ps.instantiate() as Node3D


func make_actor(id: String, look: Dictionary, fallback_form: String = "human") -> Node3D:
	var aid := id
	var g := _borrow(aid)
	if g == null:
		g = spawn(aid)
	if g == null:
		aid = "fallback_beast" if fallback_form == "beast" else "fallback_human"
		g = _borrow(aid)
		if g == null:
			g = spawn(aid)
		if g:
			g.scale = Vector3.ONE * float(look.get("scale", 1.0))
	if g == null:
		return Node3D.new()
	g.set_meta("aid", aid)
	tick_anim(g, 0.0, 0.0)
	return g


func recycle(n: Node) -> void:
	if n == null:
		return
	var par := n.get_parent()
	if par:
		par.remove_child(n)
	var aid := ""
	if n.has_meta("aid"):
		aid = str(n.get_meta("aid"))
	if aid == "":
		n.free()
		return
	var extra: Array = []
	for ch in n.get_children():
		if ch.name == "bar" or ch.name == "ename" or ch is Label3D:
			extra.append(ch)
	for ch in extra:
		n.remove_child(ch)
		ch.free()
	n.transform = Transform3D.IDENTITY
	n.visible = true
	if n.has_meta("anim_cur"):
		n.remove_meta("anim_cur")
	var arr: Array = _pool.get(aid, [])
	if arr.size() >= 40:
		n.free()
		return
	arr.append(n)
	_pool[aid] = arr


func _borrow(id: String) -> Node3D:
	if id == "" or not _pool.has(id):
		return null
	var arr: Array = _pool[id]
	if arr.is_empty():
		return null
	return arr.pop_back()


func tick_anim(n: Node, walk: float, atk: float) -> void:
	if n == null:
		return
	if not n.has_meta("ap_bound"):
		n.set_meta("ap_bound", true)
		var found: AnimationPlayer = _find_ap(n)
		if found:
			n.set_meta("ap", found)
	var ap: AnimationPlayer = null
	if n.has_meta("ap"):
		ap = n.get_meta("ap") as AnimationPlayer
	if ap:
		_prep_loops(ap)
		var lw := float(n.get_meta("lw", walk))
		n.set_meta("lw", walk)
		var moving := absf(walk - lw) > 0.05
		var want := "attack" if atk > 0.0 else ("run" if moving else "idle")
		var clip := _clip(ap, want)
		if clip == "":
			clip = _clip(ap, "idle")
			want = "idle"
		var cur := str(n.get_meta("anim_cur", ""))
		if clip != "" and want != cur:
			ap.play(clip, 0.16)
			n.set_meta("anim_cur", want)
		return
	_swing(n, walk, atk)


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for ch in n.get_children():
		var f := _find_ap(ch)
		if f:
			return f
	return null


func _clip(ap: AnimationPlayer, want: String) -> String:
	var aliases: PackedStringArray = [want]
	if want == "run":
		aliases.append("walk")
	if want == "attack":
		aliases.append("slash")
		aliases.append("punch")
	for n in ap.get_animation_list():
		var s := String(n)
		var base := s.get_file().to_lower()
		var low := s.to_lower()
		for a in aliases:
			var al := a.to_lower()
			if base == al or low == al or low.ends_with("/" + al):
				return s
	return ""


func _prep_loops(ap: AnimationPlayer) -> void:
	if ap.has_meta("looped"):
		return
	ap.set_meta("looped", true)
	for n in ap.get_animation_list():
		var anim: Animation = ap.get_animation(n)
		if anim == null:
			continue
		var s := String(n).to_lower()
		var loop := s.ends_with("idle") or s.ends_with("run") or s.ends_with("walk")
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _swing(n: Node, walk: float, atk: float) -> void:
	var swing := 1.4 if atk > 0.0 else sin(walk) * 0.6
	var arm_r := n.find_child("ArmR", true, false)
	var arm_l := n.find_child("ArmL", true, false)
	var leg_r := n.find_child("LegR", true, false)
	var leg_l := n.find_child("LegL", true, false)
	if arm_r:
		arm_r.rotation.x = swing
	if arm_l:
		arm_l.rotation.x = -swing * 0.7
	if leg_r:
		leg_r.rotation.x = -sin(walk) * 0.5
	if leg_l:
		leg_l.rotation.x = sin(walk) * 0.5


func make_prop(id: String, scl: float = 1.0) -> Node3D:
	var g := spawn(id)
	if g == null:
		g = spawn("fallback_box")
	if g and scl != 1.0:
		g.scale *= scl
	return g


func place(id: String, parent: Node, pos: Vector3, yaw: float = 0.0, scl = null) -> Node3D:
	var g := spawn(id)
	if g == null:
		return null
	g.transform = xf3(pos, yaw, scl)
	if parent:
		parent.add_child(g)
	return g


func xf3(pos: Vector3, yaw: float = 0.0, scl = null) -> Transform3D:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	if scl != null:
		if scl is Vector3:
			b = b.scaled(scl)
		else:
			var f := float(scl)
			b = b.scaled(Vector3(f, f, f))
	return Transform3D(b, pos)


func batch(id: String, parent: Node, xfs: Array) -> Node3D:
	if parent == null or xfs.is_empty():
		return null
	var parts: Array = _mesh_parts(id)
	if parts.is_empty():
		for xf in xfs:
			var g := spawn(id)
			if g == null:
				continue
			g.transform = xf
			parent.add_child(g)
		return null
	var holder := Node3D.new()
	holder.name = "%s_batch" % id
	parent.add_child(holder)
	var n: int = xfs.size()
	for p in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = p.mesh
		mm.instance_count = n
		var loc: Transform3D = p.xf
		for i in n:
			mm.set_instance_transform(i, xfs[i] * loc)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if p.mat:
			mmi.material_override = p.mat
		holder.add_child(mmi)
	return holder


func _mesh_parts(id: String) -> Array:
	if _parts.has(id):
		return _parts[id]
	var g := spawn(id)
	var acc: Array = []
	if g:
		_collect_meshes(g, acc, Transform3D.IDENTITY)
		g.free()
	_parts[id] = acc
	return acc


func _collect_meshes(n: Node, acc: Array, xf: Transform3D) -> void:
	for ch in n.get_children():
		var next := xf
		if ch is Node3D:
			next = xf * (ch as Node3D).transform
		if ch is MeshInstance3D:
			var mi: MeshInstance3D = ch
			acc.append({"mesh": mi.mesh, "mat": mi.material_override, "xf": next})
		_collect_meshes(ch, acc, next)


func tint(n: Node, hex: int, emit: float = -1.0) -> void:
	if n == null:
		return
	_tint(n, Cfg.hex_color(hex), emit)


func _tint(n: Node, c: Color, emit: float) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.material_override:
			var m: Material = mi.material_override.duplicate()
			if m is StandardMaterial3D:
				var sm: StandardMaterial3D = m
				sm.albedo_color = Color(c.r, c.g, c.b, sm.albedo_color.a)
				if emit >= 0.0:
					sm.emission_enabled = true
					sm.emission = c
					sm.emission_energy_multiplier = emit
			mi.material_override = m
	elif n is OmniLight3D:
		(n as OmniLight3D).light_color = c
	for ch in n.get_children():
		_tint(ch, c, emit)
