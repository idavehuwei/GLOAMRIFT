extends Node
## 每个模型一个 `res://models/<id>.tscn`。换模型只改那个场景，不必动代码。

const DIR := "res://models/"


func path_of(id: String) -> String:
	if id == "":
		return ""
	return DIR + id + ".tscn"


func has(id: String) -> bool:
	return id != "" and ResourceLoader.exists(path_of(id))


func spawn(id: String) -> Node3D:
	if not has(id):
		return null
	var ps: PackedScene = load(path_of(id))
	if ps == null:
		push_warning("[assets] 无法加载 %s" % path_of(id))
		return null
	return ps.instantiate() as Node3D


func make_actor(id: String, look: Dictionary, fallback_form: String = "human") -> Node3D:
	var g := spawn(id)
	if g == null:
		var fb := "fallback_beast" if fallback_form == "beast" else "fallback_human"
		g = spawn(fb)
		if g:
			g.scale = Vector3.ONE * float(look.get("scale", 1.0))
	if g == null:
		return Node3D.new()
	tick_anim(g, 0.0, 0.0)
	return g


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
	for n in ap.get_animation_list():
		var s := String(n)
		if s == want or s.ends_with("/" + want) or s.get_file() == want:
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
		var s := String(n)
		var loop := s.ends_with("idle") or s.ends_with("run") or s == "idle" or s == "run"
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
	g.position = pos
	g.rotation.y = yaw
	if scl != null:
		if scl is Vector3:
			g.scale = scl
		else:
			g.scale = Vector3.ONE * float(scl)
	if parent:
		parent.add_child(g)
	return g


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
