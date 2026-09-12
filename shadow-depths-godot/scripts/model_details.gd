extends RefCounted
# Additional sculpted geometry is merged per articulated part, preserving animation.
var w
func _init(renderer): w = renderer
func mat(key: String,c: String,texture: String,metal: float = 0.0): return w.material("detail_"+key,Color(c),0.85,metal,texture)
func character(root: Node3D,kind: int):
	var mail = mat("mail","a8aba6","chainmail",0.5)
	var trim = mat("bronze","b7a079","copper",0.55)
	var straps = mat("straps","67503b","leather")
	var stitched = mat("stitched","949c89","embroidery")
	var steel = mat("engraved","a0acb0","metal",0.7)
	var cloth = mat("brocade"+str(kind),"8f6960" if kind==-1 else "687894","embroidery")
	if kind!=-2 and kind!=-3 and kind!=-4 and kind!=-5 and kind!=-6:
		for side in [-1,1]:
			var arm = root.get_node("SwordArm" if side==1 else "ShieldArm")
			w.cylinder(arm,Vector3(0,-0.16,0),0.102,0.22,mail)
			for k in 3: w.block(arm,Vector3(side*0.09,-0.28+k*0.05,-0.065),Vector3(0.06,0.035,0.16),steel)
			var leg = root.get_node("RightLeg" if side==1 else "LeftLeg")
			w.block(leg,Vector3(0,-0.59,-0.105),Vector3(0.11,0.14,0.035),trim)
			for k in 3: w.block(leg,Vector3(0,-0.64+k*0.04,-0.15),Vector3(0.13,0.018,0.02),straps)
		if kind in [-1,0,3,6]:
			for k in 7:
				var x = (k-3)*0.059
				w.block(root,Vector3(x,0.75,-0.16),Vector3(0.053,0.3+abs(k-3)*0.018,0.055),mail)
			w.ball(root,Vector3(0,1.17,-0.204),Vector3(0.23,0.27,0.06),trim)
			w.block(root,Vector3(0,1.17,-0.244),Vector3(0.035,0.20,0.016),steel)
			w.block(root,Vector3(0,1.20,-0.244),Vector3(0.15,0.027,0.016),steel)
			for k in 4: w.block(root,Vector3((k-1.5)*0.059,1.48,-0.203),Vector3(0.017,0.057,0.015),mat("vent","252b30","metal"))
	if kind==-1:
		var shield = root.get_node("ShieldArm")
		for k in 8:
			var a = k*TAU/8
			w.ball(shield,Vector3(-0.171,-0.28+sin(a)*0.27,-0.12+cos(a)*0.17),Vector3(0.027,0.035,0.035),trim)
		w.ball(shield,Vector3(-0.19,-0.28,-0.12),Vector3(0.09,0.14,0.14),steel)
		var weapon = root.get_node("SwordArm/Sword")
		w.ball(weapon,Vector3(0,-0.07,0),Vector3(0.10,0.10,0.10),trim)
		for y in [0.42,0.57,0.72]: w.block(weapon,Vector3(0.0,y,-0.027),Vector3(0.038,0.065,0.012),trim,Vector3(0,0,0.4))
		var plume = mat("plume","6b302c","fur")
		for k in 5: w.ball(root,Vector3(0,1.84+k*0.035,0.05+k*0.052),Vector3(0.075,0.13,0.16),plume)
	elif kind==-10 or kind==2:
		for k in 10:
			var a = k*TAU/10
			w.block(root,Vector3(cos(a)*0.26,0.75,sin(a)*0.26),Vector3(0.07,0.79,0.04),cloth,Vector3(0,-a,0.08))
		var cap = mat("hood","4c5879","cloth")
		w.ball(root,Vector3(0,1.72,0.07),Vector3(0.47,0.35,0.38),cap)
		for side in [-1,1]: w.block(root,Vector3(side*0.195,1.55,0.0),Vector3(0.11,0.32,0.3),cap,Vector3(0,0,side*0.14))
		w.block(root,Vector3(0.25,0.97,0.24),Vector3(0.24,0.34,0.14),mat("grimoire","786451","runes"),Vector3(0,0,-0.2))
		for k in 3: w.cylinder(root,Vector3(-0.20+k*0.1,0.90,-0.22),0.03,0.17,mat("vial","8aa8ac","glass"))
	elif kind==-11:
		var fur = mat("rangerfur","847557","fur")
		for k in 8:
			var a = k*TAU/8
			w.ball(root,Vector3(cos(a)*0.23,1.29,sin(a)*0.17),Vector3(0.14,0.12,0.16),fur)
		w.beam(root,Vector3(-0.21,1.29,-0.16),Vector3(0.23,0.86,-0.22),0.045,straps)
		w.block(root,Vector3(-0.28,0.82,0.03),Vector3(0.16,0.24,0.18),straps)
		for k in 3: w.ball(root,Vector3(-0.28,0.90-k*0.04,-0.07),Vector3(0.04,0.025,0.025),trim)
	elif kind in [-2,-3,-4,-5,-6]:
		var outfits = {-2:"826c4a",-3:"617f72",-4:"786055",-5:"70789a",-6:"95825e"}
		var fabric = mat("npcfabric"+str(kind),outfits[kind],"embroidery" if kind==-5 else "cloth")
		w.block(root,Vector3(0,1.0,-0.19),Vector3(0.36,0.45,0.035),fabric)
		for y in [0.96,1.08,1.20]: w.ball(root,Vector3(0,y,-0.22),Vector3(0.025,0.025,0.018),trim)
		for side in [-1,1]: w.block(root,Vector3(side*0.23,0.91,0.03),Vector3(0.1,0.17,0.13),straps)
		if kind==-2:
			for k in 4: w.block(root,Vector3(-0.15+k*0.10,1.16,0.52),Vector3(0.065,0.24,0.025),mat("letters","c5b897","parchment"),Vector3(0,0,(k-1.5)*0.08))
		elif kind==-3:
			for side in [-1,1]: w.ball(root,Vector3(side*0.205,1.56,-0.015),Vector3(0.055,0.12,0.055),trim)
			for k in 6: w.ball(root,Vector3(0.14,1.63-k*0.09,0.13+k*0.017),Vector3(0.10,0.13,0.11),mat("braid","5c4938","fur"))
		elif kind==-4:
			for side in [-1,1]: w.ball(root,Vector3(side*0.078,1.66,-0.188),Vector3(0.135,0.13,0.052),mat("goggles","8d875e","copper",0.6))
			w.beam(root,Vector3(-0.18,1.25,-0.2),Vector3(0.20,0.81,-0.24),0.028,trim)
		elif kind==-5:
			w.cylinder(root,Vector3(0,1.39,0),0.14,0.035,trim)
			w.ball(root,Vector3(0,1.28,-0.20),Vector3(0.10,0.12,0.035),mat("pendant","90a8bd","glass"))
		else:
			w.cylinder(root,Vector3(0,1.8,0),0.25,0.09,fabric)
			w.cylinder(root.get_node("SwordArm"),Vector3(0,-0.42,-0.05),0.08,0.19,mat("tankard","aa956f","copper",0.3))
	elif kind==1:
		for k in 5:
			for side in [-1,1]: w.beam(root,Vector3(0,1.20-k*0.062,0.03),Vector3(side*0.20,1.18-k*0.057,-0.07),0.035,mat("agedbone","b4aa8e","bone"))
		w.block(root,Vector3(0.0,0.85,0.14),Vector3(0.17,0.12,0.05),straps)
	# Overlapping shoulder lames and articulated gauntlets follow the arm joints.
	for side in [-1,1]:
		var arm = root.get_node("SwordArm" if side==1 else "ShieldArm")
		if kind in [-1,0,3,6]:
			for layer in 3:
				w.profile(arm,Vector3(side*0.035,-0.035-layer*0.062,0),[[0.0,0.15-layer*0.012,0.18],[0.035,0.16-layer*0.012,0.19],[0.065,0.115,0.14]],steel)
				for front in [-1,1]: w.ball(arm,Vector3(side*0.11,-0.02-layer*0.062,front*0.145),Vector3.ONE*0.026,trim)
		var glove = straps if kind!=1 else mat("handbone","b4aa8e","bone")
		w.ball(arm,Vector3(0,-0.48,-0.045),Vector3(0.13,0.15,0.13),glove)
		for finger in 4:
			w.ball(arm,Vector3((finger-1.5)*0.029,-0.52,-0.085),Vector3(0.027,0.09,0.045),glove)
		w.ball(arm,Vector3(-side*0.065,-0.47,-0.07),Vector3(0.04,0.08,0.055),glove)
	refine_character(root,kind,steel,trim,straps)
	if kind==3: boss(root)
func refine_character(root: Node3D,kind: int,steel: Material,trim: Material,leather: Material):
	# Raised seams and shaped greaves remain attached to the existing joint rig.
	for side in [-1,1]:
		var leg = root.get_node("LeftLeg" if side<0 else "RightLeg")
		if kind in [-1,0,3,6]:
			w.profile(leg,Vector3(0,-0.66,-0.025),[[0.0,0.085,0.09],[0.08,0.115,0.13],[0.19,0.12,0.12],[0.26,0.09,0.09]],steel)
			w.beam(leg,Vector3(0,-0.63,-0.16),Vector3(0,-0.43,-0.16),0.018,trim)
		else:
			for k in 4:
				w.beam(leg,Vector3(-0.07,-0.62+k*0.035,-0.115),Vector3(0.07,-0.60+k*0.035,-0.115),0.012,trim)
		for k in 6:
			w.ball(root,Vector3(side*0.21,0.96+k*0.047,-0.145),Vector3(0.015,0.024,0.016),trim)
	if kind < -1:
		var skin = w.material("skin"+str(kind),Color("b89b7e"),1,0,"skin")
		var shadow = mat("face_shadow","473a32","skin")
		var eye = mat("eye_white","c3bba4","bone")
		w.ball(root,Vector3(0,1.565,-0.183),Vector3(0.062,0.11,0.073),skin)
		w.ball(root,Vector3(0,1.477,-0.15),Vector3(0.16,0.084,0.073),skin)
		w.beam(root,Vector3(-0.047,1.501,-0.195),Vector3(0.047,1.501,-0.195),0.012,shadow)
		for side in [-1,1]:
			w.ball(root,Vector3(side*0.198,1.59,0),Vector3(0.06,0.11,0.072),skin)
			w.ball(root,Vector3(side*0.081,1.623,-0.173),Vector3(0.077,0.036,0.035),eye)
			w.ball(root,Vector3(side*0.081,1.623,-0.193),Vector3(0.022,0.027,0.012),shadow)
			w.beam(root,Vector3(side*0.044,1.657,-0.179),Vector3(side*0.12,1.651,-0.164),0.022,shadow)
			w.ball(root,Vector3(side*0.107,1.558,-0.139),Vector3(0.102,0.073,0.071),skin)
	if kind in [-10,-11,-2,-3,-4,-5,-6,2]:
		for side in [-1,1]:
			w.beam(root,Vector3(side*0.06,1.32,-0.135),Vector3(side*0.15,1.20,-0.19),0.029,trim)
			w.block(root,Vector3(side*0.17,0.96,-0.201),Vector3(0.11,0.13,0.025),leather)
			w.block(root,Vector3(side*0.17,1.022,-0.22),Vector3(0.12,0.025,0.025),trim)

func boss(root: Node3D):
	var c = w.game.chapter
	var dark = mat("obsidian","3c3b49","marble",0.2)
	var gold = mat("royalgold","b8a36f","copper",0.6)
	if c==0:
		var arm = root.get_node("SwordArm")
		root.get_node("SwordArm/Sword").hide()
		w.cylinder(arm,Vector3(0,0.1,0),0.045,2.1,mat("bellwood","64513b","wood"))
		w.cylinder(arm,Vector3(0,1.03,0),0.28,0.4,gold,Vector3.ZERO,true)
		w.ball(arm,Vector3(0,0.85,0),Vector3(0.13,0.13,0.13),dark)
		for k in 4: w.ball(root,Vector3((k-1.5)*0.11,0.8,-0.25),Vector3(0.1,0.12,0.09),mat("skulls","bbb49d","bone"))
	elif c==1:
		var scales = mat("frogscales","718e56","scales")
		w.ball(root,Vector3(0,1.02,-0.12),Vector3(0.72,0.72,0.56),scales)
		for side in [-1,1]:
			for k in 3: w.ball(root,Vector3(side*(0.28+k*0.06),0.09,-0.14-k*0.05),Vector3(0.15,0.10,0.25),scales)
		for k in 8: w.ball(root,Vector3(sin(k*2.3)*0.25,1.42+cos(k)*0.13,-0.37),Vector3(0.045,0.045,0.035),gold)
	elif c==2:
		var ice = mat("frostarmor","90afbb","marble",0.2)
		for side in [-1,1]:
			for k in 3: w.cylinder(root,Vector3(side*(0.31+k*0.06),1.42+k*0.10,0.03),0.085,0.6-k*0.08,ice,Vector3(0,0,-side*(0.2+k*0.25)),true)
		w.ball(root,Vector3(0,1.15,-0.20),Vector3(0.33,0.36,0.12),ice)
	elif c==3:
		var red = mat("demonskin","884936","scales")
		w.ball(root,Vector3(0,1.54,-0.12),Vector3(0.46,0.50,0.43),red)
		for side in [-1,1]:
			for k in 4: w.cylinder(root,Vector3(side*(0.2+k*0.065),1.8+k*0.09,0),0.075-k*0.015,0.24,gold,Vector3(0,0,-side*0.4),true)
			w.block(root,Vector3(side*0.31,1.3,0),Vector3(0.18,0.32,0.4),dark,Vector3(0,0,side*0.3))
	else:
		for k in 10:
			var a = k*TAU/10
			w.cylinder(root,Vector3(cos(a)*0.29,2.05,sin(a)*0.29),0.04,0.45,gold,Vector3(0,0,0),true)
		for side in [-1,1]:
			w.ball(root,Vector3(side*0.3,1.31,0),Vector3(0.34,0.20,0.44),dark)
			for k in 4: w.cylinder(root,Vector3(side*(0.38+k*0.04),1.38+k*0.08,0.1),0.045,0.32,gold,Vector3(0,0,-side*0.5),true)
func creature(root: Node3D,kind: int):
	if kind==4:
		var fur = mat("beastfur"+str(w.game.chapter),"788184" if w.game.chapter==2 else "675541","fur")
		for k in 7:
			w.ball(root,Vector3(0,0.89+k*0.016,-0.32+k*0.115),Vector3(0.20,0.10,0.22),fur)
		var head = root.get_node("Head")
		for side in [-1,1]:
			for k in 5:
				w.cylinder(head,Vector3(side*(0.14+k*0.016),-0.04+k*0.038,0.075),0.044,0.20,fur,Vector3(0.4,0,-side*0.9),true)
			w.ball(head,Vector3(side*0.14,0.15,-0.17),Vector3(0.13,0.06,0.09),fur)
	else:
		var carapace = mat("carapace","797d78","chitin",0.15)
		for k in 5: w.ball(root,Vector3(0,0.74,0.05+k*0.105),Vector3(0.64-k*0.045,0.12,0.14),carapace)
		for side in [-1,1]:
			for k in 4: w.ball(root,Vector3(side*0.34,0.48,k*0.23-0.32),Vector3(0.10,0.10,0.10),carapace)
		var head = root.get_node("Head")
		for side in [-1,1]:
			for k in 4:
				var leg = root.get_node("Leg_%d_%d" % [side,k])
				w.ball(leg,Vector3.ZERO,Vector3(0.15,0.13,0.16),carapace)
				w.cylinder(leg,Vector3(side*0.14,0.10,0),0.03,0.18,carapace,Vector3(0,0,-side*0.6),true)
			w.ball(head,Vector3(side*0.16,-0.05,-0.16),Vector3(0.17,0.18,0.13),carapace)
func building(p: Vector3):
	var stone = mat("cutstone","9a9688","stone")
	var trim = mat("weatheredbronze","8c8167","copper",0.4)
	var moss = mat("wallmoss","607153","moss")
	for side in [-1,1]:
		# Buttress feet and decorated corner masonry.
		w.block(w.scenery,p+Vector3(side*1.85,0.15,1.5),Vector3(0.60,0.3,0.64),stone)
		for k in 4: w.block(w.scenery,p+Vector3(side*1.82,0.38+k*0.15,1.52),Vector3(0.43,0.07,0.43),stone)
		w.block(w.scenery,p+Vector3(side*1.73,2.5,1.63),Vector3(0.10,0.18,0.06),trim)
		for k in 6: w.ball(w.scenery,p+Vector3(side*1.78,0.08+k*0.07,-1.2+sin(k)*0.3),Vector3(0.11,0.14,0.34),moss)
	var glass = mat("windowglass","c6bcb1","glass")
	for side in [-1,1]:
		w.block(w.scenery,p+Vector3(side*1.16,1.68,1.72),Vector3(0.32,0.53,0.035),glass)
		for k in 3: w.block(w.scenery,p+Vector3(side*1.16+(k-1)*0.13,1.68,1.75),Vector3(0.022,0.58,0.04),trim)
		w.block(w.scenery,p+Vector3(side*1.16,1.68,1.75),Vector3(0.36,0.025,0.04),trim)
	# Door threshold, masonry fragments and circular ornamental boss.
	w.cylinder(w.scenery,p+Vector3(0,2.51,1.78),0.13,0.045,trim,Vector3(PI/2,0,0))
	for k in 4: w.block(w.scenery,p+Vector3(1.9+k*0.1,0.08,1.6-k*0.14),Vector3(0.17,0.15,0.21),stone,Vector3(0,k*0.7,0))
func tree(p: Vector3,s: float,index: int):
	var bark = mat("rootbark","655745","bark")
	for k in 4:
		var a = k*2.1+index
		w.beam(w.scenery,p+Vector3(0,0.22,0),p+Vector3(cos(a)*0.68,0.025,sin(a)*0.68)*s,0.055*s,bark)
		w.ball(w.scenery,p+Vector3(cos(a)*0.28,0.08,sin(a)*0.28),Vector3(0.3,0.12,0.22),mat("rootmoss","657050","moss"))
	if index%3==0:
		var shelf = mat("bracketfungus","98836a","scales")
		for k in 3: w.ball(w.scenery,p+Vector3(0.14,0.5+k*0.17,0),Vector3(0.28,0.055,0.20),shelf)
func prop(root: Node3D):
	var iron = mat("chestiron","aaa07d","copper",0.6)
	for x in [-0.3,0.3]:
		for y in [0.11,0.40]: w.ball(root,Vector3(x,y,0.303),Vector3(0.04,0.04,0.02),iron)
	for side in [-1,1]:
		w.block(root,Vector3(side*0.42,0.25,0),Vector3(0.05,0.11,0.22),iron)
		w.block(root,Vector3(side*0.43,0.25,0),Vector3(0.025,0.06,0.14),mat("handlevoid","302f29","metal"))
func bake(root: Node3D):
	for child in root.get_children():
		if child is Node3D and not child is MeshInstance3D: bake(child)
	var groups = {}
	for child in root.get_children():
		if not child is MeshInstance3D or not child.visible or child.mesh==null or child.material_override==null: continue
		var key = child.material_override.get_instance_id()
		if not groups.has(key): groups[key] = {"mat":child.material_override,"items":[]}
		groups[key].items.append(child)
	for group in groups.values():
		if group.items.size()<2: continue
		var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child in group.items: st.append_from(child.mesh,0,child.transform)
		var combined = MeshInstance3D.new(); combined.mesh = st.commit(); combined.material_override = group.mat
		root.add_child(combined)
		for child in group.items: child.free()
