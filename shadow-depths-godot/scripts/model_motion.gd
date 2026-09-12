extends RefCounted
# Local joint poses; gameplay owns timing and damage, rendering owns interpolation.
const ACTIONS = ["idle","walk","attack","skill","dodge","hit","death","work"]
const LABELS = ["待机","行走","攻击","施法 / 技能","闪避","受击","倒地","职业动作"]
var w
var swing_value = 0.0
const WINDUP = 0.30   # 蓄力段：0 → 0.30
const CONTACT = 0.50  # 击出瞬间
# 攻击曲线：先反向蓄力（-0.40），在 CONTACT 处爆发到 1，再收招回 0。
# 比原来的 sin(phase*PI) 对称摆动更有预备动作和收势。
func strike(phase: float) -> float:
	if phase < WINDUP:
		var k = phase / WINDUP
		return -0.40 * (1.0 - (1.0 - k) * (1.0 - k))
	if phase < CONTACT:
		var k = (phase - WINDUP) / (CONTACT - WINDUP)
		return lerpf(-0.40, 1.0, k * k * (3.0 - 2.0 * k))
	return 1.0 - smoothstep(0.0, 1.0, (phase - CONTACT) / (1.0 - CONTACT))
func _init(renderer): w = renderer
func pivot(parent: Node3D,name: String,p: Vector3) -> Node3D:
	var n = Node3D.new(); n.name = name; parent.add_child(n); n.position = p
	return n
func transfer(node: Node3D,parent: Node3D):
	var t = node.transform
	node.get_parent().remove_child(node); parent.add_child(node)
	node.transform = Transform3D(Basis.IDENTITY,-parent.position)*t
func rig(root: Node3D,kind: int):
	root.set_meta("kind",kind)
	if kind not in [4,5]:
		var head = pivot(root,"Head",Vector3(0,1.38,0))
		var chest = pivot(root,"Chest",Vector3(0,0.87,0))
		for n in root.get_children():
			if n is MeshInstance3D:
				if n.position.y>=1.38: transfer(n,head)
				elif n.position.y>0.88 and absf(n.position.x)<0.30: transfer(n,chest)
		for name in ["LeftLeg","RightLeg"]:
			var leg = root.get_node(name)
			var knee = pivot(leg,"Knee",Vector3(0,-0.37,0))
			for n in leg.get_children():
				if n is MeshInstance3D and n.position.y< -0.40: transfer(n,knee)
			# 踝关节让脚掌在落地与蹬地时单独转动，腿部线条不再是一根直棍。
			var ankle = pivot(knee,"Ankle",Vector3(0,-0.30,0))
			for n in knee.get_children():
				if n is MeshInstance3D and n.position.y< -0.18: transfer(n,ankle)
		for name in ["SwordArm","ShieldArm"]:
			var arm = root.get_node(name)
			var elbow = pivot(arm,"Elbow",Vector3(0,-0.23,0))
			for n in arm.get_children():
				if (n is MeshInstance3D and n.position.y< -0.25) or n.name in ["Bow","Staff","Crossbow"]: transfer(n,elbow)
			if arm.has_node("Sword"): arm.get_node("Sword").set_meta("rest",arm.get_node("Sword").transform)
	if kind in [4,5] and root.has_node("Jaw"): transfer(root.get_node("Jaw"),root.get_node("Head"))
	cache(root)
func cache(root: Node3D):
	var joints = {}
	collect(root,"",joints)
	root.set_meta("joints",joints)
func collect(n: Node3D,path: String,out: Dictionary):
	for c in n.get_children():
		if c is Node3D and not c is MeshInstance3D:
			var p = path+str(c.name)
			out[p] = {"node":c,"position":c.position,"rotation":c.rotation}
			collect(c,p+"/",out)
func play(root: Node3D,action: String,duration: float = 0.5):
	if root==null or not is_instance_valid(root): return
	if str(root.get_meta("action", "")) == "death": return
	root.set_meta("action",action); root.set_meta("elapsed",0.0); root.set_meta("duration",duration)
func update(root: Node3D,dt: float,moving: bool = false,forced: String = "",time: float = -1.0):
	var kind = int(root.get_meta("kind",0))
	var elapsed = float(root.get_meta("elapsed",0.0))+dt
	root.set_meta("elapsed",elapsed)
	var action = str(root.get_meta("action","idle"))
	var duration = float(root.get_meta("duration",0.5))
	if elapsed>=duration and action!="death": action = "walk" if moving else "idle"
	if forced!="": action = forced
	var t = time if time>=0 else w.tick+float(root.get_instance_id()%97)*0.13
	var phase = fmod(t,1.0) if forced!="" else clampf(elapsed/maxf(0.01,duration),0,1)
	var pulse = sin(phase*PI)
	# 攻击不再是 sin 对称摆动，而是「蓄力 → 击出 → 收招」三段曲线。
	var drawing = false
	var swing = strike(phase)
	var rise = maxf(0.0,swing)
	var wind = maxf(0.0,-swing)
	swing_value = swing
	var locomotion = action=="walk" or (moving and action in ["attack","skill"])
	var stride = sin(t*10.0)*0.55 if locomotion else sin(t*1.8)*0.025
	var pose = {}
	var lift = absf(stride)*0.055
	pose["Head"] = Vector3(sin(t*1.8)*0.025,sin(t*0.65)*0.10,0)
	pose["Chest"] = Vector3(0,sin(t*1.1)*0.025,sin(t*1.8)*0.015)
	pose["LeftLeg"] = Vector3(stride,0,0); pose["RightLeg"] = Vector3(-stride,0,0)
	pose["LeftLeg/Knee"] = Vector3(maxf(0,-stride)*0.95,0,0)
	pose["RightLeg/Knee"] = Vector3(maxf(0,stride)*0.95,0,0)
	pose["LeftLeg/Knee/Ankle"] = Vector3(-stride*0.28,0,0)
	pose["RightLeg/Knee/Ankle"] = Vector3(stride*0.28,0,0)
	pose["SwordArm"] = Vector3(-stride*0.5,0,-0.08)
	pose["ShieldArm"] = Vector3(stride*0.5,0,0.08)
	pose["SwordArm/Elbow"] = Vector3(-0.10,0,0)
	pose["ShieldArm/Elbow"] = Vector3(-0.18,0,0)
	pose["Cape"] = Vector3(0.08+absf(stride)*0.3+sin(t*4)*0.045,sin(t*2)*0.045,0)
	var tilt = Vector3.ZERO
	if action in ["attack","skill"]:
		if kind in [-10,2]:
			# 施法：法杖前推，空手上扬，蓄力时双肩后收。
			pose["SwordArm"] = Vector3(-0.25-rise*0.55+wind*0.30,0,-rise*0.50)
			pose["SwordArm/Elbow"] = Vector3(-0.35*rise,0,0)
			pose["ShieldArm"] = Vector3(-(rise*1.45+wind*0.30),0,rise*0.55)
			pose["ShieldArm/Elbow"] = Vector3(-0.30*rise,0,0)
			pose["Head"] = Vector3(-rise*0.16,0,0)
			pose["Chest"] = Vector3(0,rise*0.10,0)
			lift += rise*0.05
		elif kind in [-11,6]:
			# 弓：拉满后撒放，弓弦与箭随 drawing 联动。
			var drawing_phase = phase < CONTACT
			var draw = clampf((swing+0.40)/1.40,0.0,1.0) if drawing_phase else 0.0
			pose["ShieldArm"] = Vector3(1.3*draw,0,0.15)
			pose["ShieldArm/Elbow"] = Vector3.ZERO
			pose["ShieldArm/Elbow/Bow"] = Vector3(-1.3*draw,0,0)
			pose["SwordArm"] = Vector3(1.8*draw,-0.3*draw,-0.35*draw)
			pose["SwordArm/Elbow/Crossbow"] = Vector3(-0.5*draw,0,0)
			pose["SwordArm/Elbow"] = Vector3(-1.3*draw,0,0)
			pose["Chest"] = Vector3(0,0.25*draw,0)
			pose["Head"] = Vector3(-0.10*draw,0,0)
			drawing = drawing_phase and draw>0.12
		else:
			# 近战：转体蓄力，击出时压身，收招回正。
			pose["SwordArm"] = Vector3(-1.8*rise+wind*0.55,sin(phase*TAU)*0.55*rise,-0.45*rise)
			pose["SwordArm/Elbow"] = Vector3(-0.65*rise,0,0)
			pose["ShieldArm"] = Vector3(-0.65*rise+wind*0.30,0,0.22*rise)
			pose["Chest"] = Vector3(0,-0.24*rise+sin(phase*TAU)*0.14,0)
			pose["Head"] = Vector3(-0.12*rise,0,0)
			lift += rise*0.03
			if action=="skill":
				pose["SwordArm"] = Vector3(-2.6*rise+wind*0.40,0,-0.3)
				pose["Head"] = Vector3(-0.18*rise,0,0)
				lift += rise*0.12
		if kind==3:
			var chapter = w.game.chapter
			pose["Head"] = Vector3(-0.35*rise,sin(t*7)*0.12,0)
			pose["ShieldArm"] = Vector3(-rise*(1.7 if chapter in [0,4] else 0.9),0,0.3)
			lift += rise*(0.25 if chapter==1 else 0.06)
			pose["Chest"] = Vector3(-rise*0.14,sin(phase*TAU)*0.2,0)
	if action=="dodge":
		# 位移：前倾、收腿、披风扬起，末端回正。
		tilt.x = -0.72*pulse; lift += pulse*0.15
		pose["LeftLeg"] = Vector3(-0.82*pulse,0,0); pose["RightLeg"] = Vector3(0.55*pulse,0,0)
		pose["LeftLeg/Knee"] = Vector3(0.62*pulse,0,0)
		pose["Cape"] = Vector3(0.78*pulse,0,0)
		pose["SwordArm"] = Vector3(-0.55*pulse,0,-0.32*pulse)
		pose["Head"] = Vector3(0.12*pulse,0,0)
	if action=="hit":
		# 受击：后仰 + 含胸 + 头偏，配合渲染层的挤压回弹。
		tilt.x = 0.44*pulse
		pose["Head"] = Vector3(-0.44*pulse,0,0)
		pose["Chest"] = Vector3(0.20*pulse,0,0)
		pose["SwordArm"] = Vector3(-0.32*pulse,0,-0.45*pulse)
		pose["ShieldArm"] = Vector3(-0.28*pulse,0,0.30*pulse)
	if action=="death":
		# 倒地：先跪后倒，最后轻微沉降。
		var fall = smoothstep(0.0,0.8,phase)
		var drop = smoothstep(0.35,1.0,phase)
		tilt.z = -1.45*fall; lift = 0.08*fall-0.05*drop
		pose["LeftLeg/Knee"] = Vector3(0.6*fall,0,0)
		pose["RightLeg/Knee"] = Vector3(0.35*fall,0,0)
		pose["Head"] = Vector3(0.25*fall,0,0)
		pose["Chest"] = Vector3(0.18*fall,0,0)
		pose["SwordArm"] = Vector3(-0.5*fall,0,-0.4*fall)
	if action=="work" or (kind in [-2,-3,-4,-5,-6] and action=="idle"):
		var beat = (sin(t*3.5)+1)*0.5
		match kind:
			-4: # Hammer lift, strike, recovery.
				pose["SwordArm"] = Vector3(-0.3-beat*1.35,0,-0.1)
				pose["Head"] = Vector3(0.18,0,0); pose["ShieldArm"] = Vector3(-0.7,0,0.15)
			-3: pose["SwordArm"] = Vector3(-0.7,0,sin(t*4)*0.22); pose["Head"] = Vector3(0.2,0,0)
			-5: pose["ShieldArm"] = Vector3(-0.6,0,0.12); pose["SwordArm"] = Vector3(-0.7,beat*0.2,0); pose["Head"] = Vector3(0.2,0,0)
			-6: pose["SwordArm"] = Vector3(-0.25-beat*1.25,0,-0.12); pose["SwordArm/Elbow"] = Vector3(-0.6*beat,0,0)
			_: pose["SwordArm"] = Vector3(-0.8-beat*0.4,0,-0.3); pose["ShieldArm"] = Vector3(-0.35,0,0.1)
	if kind in [4,5]:
		pose["Head"] = Vector3(sin(t*2)*0.05, sin(t)*0.08,0)
		pose["Tail"] = Vector3(0,sin(t*4)*0.3,0)
		pose["Head/Jaw"] = Vector3(-(0.1+pulse*0.45) if action in ["attack","skill","work"] else -0.04,0,0)
		if action in ["attack","skill"]: tilt.x = -pulse*0.25; lift += pulse*0.16
		for side in [-1,1]:
			for k in (2 if kind==4 else 4):
				var name = "Leg_%d_%d" % [side,k]
				var a = t*(11 if kind==4 else 9)+k*PI+(PI if side<0 else 0)
				var wave = sin(a) if action=="walk" else sin(a*0.25)*0.05
				pose[name] = Vector3(wave*0.48,0,0) if kind==4 else Vector3(0,wave*0.18,side*maxf(0,wave)*0.19)
				pose[name+"/Knee"] = Vector3(maxf(0,-wave)*0.65,0,0) if kind==4 else Vector3(0,0,-side*maxf(0,wave)*0.27)
	var joints: Dictionary = root.get_meta("joints",{})
	# Capture the visible pose on state changes, including interrupted attacks.
	if str(root.get_meta("blend_action","")) != action:
		var source = {}
		for path in joints: source[path] = joints[path].node.quaternion
		root.set_meta("blend_source",source)
		root.set_meta("blend_age",0.0)
		root.set_meta("blend_height",root.position.y)
		root.set_meta("blend_action",action)
	var age = float(root.get_meta("blend_age",0.0))+maxf(dt,0.0)
	root.set_meta("blend_age",age)
	var transition = 0.08 if action in ["hit","dodge"] else 0.16
	var weight = smoothstep(0.0,transition,age) if time<0 else 1.0
	var source: Dictionary = root.get_meta("blend_source",{})
	var blend = 1.0-exp(-maxf(dt,0.0)*22) if time<0 else 1.0
	for path in joints:
		var j = joints[path]; var target = j.rotation+pose.get(path,Vector3.ZERO)
		var target_q = Quaternion.from_euler(target)
		if kind not in [4,5] and path in ["Head","SwordArm","ShieldArm"]:
			target_q = Quaternion.from_euler(pose.get("Chest",Vector3.ZERO)) * target_q
		var mixed = source.get(path,j.node.quaternion).slerp(target_q,weight)
		j.node.quaternion = mixed
	if kind not in [4,5] and root.has_node("Chest"):
		var chest = root.get_node("Chest")
		var rest_chest: Vector3 = joints["Chest"].position
		var delta_basis = chest.basis * Basis.from_euler(joints["Chest"].rotation).inverse()
		for path in ["Head","SwordArm","ShieldArm"]:
			var joint = joints[path]
			joint.node.position = rest_chest + delta_basis * (joint.position-rest_chest)
	# Weapons remain on their stable public path but follow the elbow pivot.
	if root.has_node("SwordArm/Sword"):
		var sword = root.get_node("SwordArm/Sword")
		if sword.has_meta("rest"):
			var elbow = root.get_node("SwordArm/Elbow")
			sword.transform = Transform3D(Basis.IDENTITY,elbow.position)*Transform3D(Basis.from_euler(elbow.rotation),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-elbow.position)*sword.get_meta("rest")
	if kind==-11 and root.has_node("ShieldArm/Elbow/Bow"):
		var bow = root.get_node("ShieldArm/Elbow/Bow")
		var draw = clampf((swing_value+0.40)/1.40,0.0,1.0) if drawing else 0.0
		var center = Vector3(-0.08,-0.18,-0.14+draw*0.26)
		for i in 2:
			var tip = Vector3(-0.08,-0.82 if i==0 else 0.46,-0.14)
			var string_part = bow.get_node("StringUpper" if i==0 else "StringLower")
			var direction = (center-tip).normalized()
			string_part.position = (tip+center)*0.5
			string_part.basis = Basis.looking_at(direction,Vector3.FORWARD)*Basis.from_scale(Vector3(0.009,0.009,tip.distance_to(center)))
		var arrow = bow.get_node("NockedArrow"); arrow.position = center
		arrow.scale = Vector3.ONE*(1.0 if drawing else 0.0001)
	# 有翅膀的小宠物：翅膀在关节插值之后直接驱动，避免被回中插值拉平。
	if root.has_meta("wings"):
		var flap = sin(t*16.0+float(root.get_instance_id()%97)*0.11)
		for wing_name in ["WingL","WingR"]:
			var wg = root.get_node_or_null(wing_name)
			if wg != null: wg.rotation.z = (-1.0 if wing_name=="WingL" else 1.0)*(0.16+flap*0.62)
	root.rotation.x = lerpf(root.rotation.x,tilt.x,blend); root.rotation.z = lerpf(root.rotation.z,tilt.z,blend)
	root.position.y = lerpf(float(root.get_meta("blend_height",0.0)),lift,weight)
	root.set_meta("pose_action",action)
