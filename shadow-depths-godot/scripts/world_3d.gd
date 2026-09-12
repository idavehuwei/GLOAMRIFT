extends Node
# The simulation remains on an X/Z grid; this renderer supplies actual depth,
# orthographic projection, dynamic shadows and deliberately crisp rasterization.
var game
var detailer
var motion
var npc_models: Array = []
var fallen: Array = []
var preview_action = "idle"
var preview_turntable = true
var preview_clock = 0.0
var preview_viewport: SubViewport
var preview_subject: Node3D
var preview_kind = -999
var viewport: SubViewport
var world: Node3D
var scenery: Node3D
var dynamic: Node3D
var camera: Camera3D
var hero: Node3D
var post: ColorRect
var light: OmniLight3D
var materials = {}
var batches = {}
var actors = {}
var chest_models: Array = []
var loot_models: Array = []
var torches: Array = []
var previous_player = Vector2.ZERO
var camera_target = Vector3.ZERO
var tick = 0.0
var visual_id = 0
var random = RandomNumberGenerator.new()
var quality = 0
var portal_model: Node3D
var ring: MeshInstance3D
var fx
var vfx
var circle: ArrayMesh
var pet_model: Node3D
var pet_species = -999
var pet_ring: MeshInstance3D
const PET_FLYING = [2,4,8,9]
var shot_models = {}
var skill_models = {}
var tree_index = 0
var attack_effect: MeshInstance3D

func setup(owner_game):
	game = owner_game
	detailer = preload("res://scripts/model_details.gd").new(self)
	motion = preload("res://scripts/model_motion.gd").new(self)
	viewport = SubViewport.new()
	viewport.name = "IsometricWorld"
	viewport.size = Vector2i(960,600)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 2048
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.near = 0.1
	camera.far = 100.0
	world.add_child(camera)
	camera.current = true
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141b21")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("889cae")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("283039")
	env.fog_density = 0.009
	env.fog_sky_affect = 0.0
	env_node.environment = env
	world.add_child(env_node)
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-28,0)
	moon.light_color = Color("b2c3cf")
	moon.light_energy = 1.25
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 48
	moon.shadow_bias = 0.04
	world.add_child(moon)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30,145,0)
	fill.light_color = Color("626e7f")
	fill.light_energy = 0.45
	world.add_child(fill)
	light = OmniLight3D.new()
	light.light_color = Color("f9bb72")
	light.light_energy = 1.8
	light.omni_range = 5.0
	world.add_child(light)
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
void fragment(){
 vec3 c = texture(screen_texture, SCREEN_UV).rgb;
 float d = mod(FRAGCOORD.x,2.0) == mod(FRAGCOORD.y,2.0) ? 0.003 : -0.003;
 c = floor(clamp(c+d,0.0,1.0)*80.0)/80.0;
 float vignette = 1.0-smoothstep(0.22,0.78,distance(SCREEN_UV,vec2(0.5)))*0.38;
 COLOR = vec4(c*vignette,1.0);
}"""
	post = ColorRect.new()
	post.size = Vector2(viewport.size)
	var sm = ShaderMaterial.new()
	sm.shader = shader
	post.material = sm
	var layer = CanvasLayer.new()
	viewport.add_child(layer)
	layer.add_child(post)
	vfx = preload("res://scripts/vfx_3d.gd").new()
	vfx.name = "CombatVFX"
	world.add_child(vfx)
	rebuild()

func material(key: String, color: Color, roughness: float = 0.9, metallic: float = 0.0, texture_kind: String = "") -> StandardMaterial3D:
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if texture_kind != "":
		var img = Image.create(64,64,false,Image.FORMAT_RGB8)
		var r = RandomNumberGenerator.new()
		r.seed = absi(hash(key))
		for y in 64:
			for x in 64:
				var n = r.randf_range(0.70,1.18)
				if texture_kind == "stone":
					if y%16 < 2 or (x+(16 if (y/16)%2 else 0))%32 < 2: n *= 0.55
					if y%16 == 2: n *= 1.22
				elif texture_kind == "wood":
					if x%12<2: n *= 0.5
					n += sin(x*3.0+y*0.09)*0.13
				elif texture_kind == "soil":
					n += sin(x*0.4)*cos(y*0.6)*0.14
				img.set_pixel(x,y,Color(n,n,n))
		var texture_path = "res://assets/textures/"+texture_kind+".png"
		m.albedo_texture = load(texture_path) if ResourceLoader.exists(texture_path) else ImageTexture.create_from_image(img)
		var normal_path = "res://assets/textures/"+texture_kind+"_normal.png"
		if ResourceLoader.exists(normal_path):
			m.normal_enabled = true
			m.normal_texture = load(normal_path)
			m.normal_scale = 0.18 if texture_kind=="skin" else (0.24 if texture_kind in ["metal","rust","chitin","fur"] else 0.48)
		var rough_path = "res://assets/textures/"+texture_kind+"_roughness.png"
		if ResourceLoader.exists(rough_path):
			m.roughness_texture = load(rough_path)
			m.roughness = 1.0
		if texture_kind in ["soil","stone"]:
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE*(1.2 if texture_kind=="stone" else 0.9)
	materials[key] = m
	return m
func glow(key: String,c: Color,energy: float = 2.0) -> StandardMaterial3D:
	var m = material(key,c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy*0.25
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
func emit_mesh(parent: Node3D,mesh: Mesh,mat: Material,p: Vector3,size: Vector3 = Vector3.ONE,rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var basis = Basis.from_euler(rot) * Basis.from_scale(size)
	if parent == scenery:
		var key = str(mesh.get_instance_id())+":"+str(mat.get_instance_id())
		if not batches.has(key): batches[key] = {"mesh":mesh,"mat":mat,"transforms":[]}
		batches[key].transforms.append(Transform3D(basis,p))
		return null
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.transform = Transform3D(basis,p)
	parent.add_child(node)
	return node
var cube: BoxMesh
var sphere: SphereMesh
var tube: CylinderMesh
var cone: CylinderMesh
# 细分档位：角色与生物用高精度，场景批量网格由 detail 参数另算。
const BALL_SEGMENTS = 24
const BALL_RINGS = 12
const TUBE_SEGMENTS = 16
const CONE_SEGMENTS = 12
func block(parent: Node3D,p: Vector3,size: Vector3,m: Material,rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if cube == null: cube = BoxMesh.new()
	return emit_mesh(parent,cube,m,p,size,rot)
func ball(parent: Node3D,p: Vector3,size: Vector3,m: Material) -> MeshInstance3D:
	if sphere == null:
		sphere = SphereMesh.new(); sphere.radius = 0.5; sphere.height = 1.0
		sphere.radial_segments = BALL_SEGMENTS; sphere.rings = BALL_RINGS
	return emit_mesh(parent,sphere,m,p,size)
func cylinder(parent: Node3D,p: Vector3,radius: float,height: float,m: Material,rot: Vector3 = Vector3.ZERO,taper: bool = false) -> MeshInstance3D:
	if tube == null:
		tube = CylinderMesh.new(); tube.top_radius = 0.5; tube.bottom_radius = 0.5; tube.height = 1.0
		tube.radial_segments = TUBE_SEGMENTS; tube.rings = 2
		cone = CylinderMesh.new(); cone.top_radius = 0.10; cone.bottom_radius = 0.5; cone.height = 1.0
		cone.radial_segments = CONE_SEGMENTS
	return emit_mesh(parent,cone if taper else tube,m,p,Vector3(radius*2,height,radius*2),rot)
func beam(parent: Node3D,a: Vector3,b: Vector3,width: float,m: Material):
	var mid = (a+b)*0.5
	var basis = Basis.looking_at((b-a).normalized(),Vector3.FORWARD if absf((b-a).normalized().dot(Vector3.UP))>0.99 else Vector3.UP)
	emit_mesh(parent,cube if cube != null else BoxMesh.new(),m,mid,Vector3(width,width,a.distance_to(b)),basis.get_euler())
func flush_batches():
	for data in batches.values():
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data.mesh
		mm.instance_count = data.transforms.size()
		for i in data.transforms.size(): mm.set_instance_transform(i,data.transforms[i])
		var node = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = data.mat
		scenery.add_child(node)
	batches.clear()
func v(p: Vector2,y: float = 0.0) -> Vector3: return Vector3(p.x/30.0,y,p.y/30.0)
func project(p: Vector2,y: float = 1.8) -> Vector2: return camera.unproject_position(v(p,y))*Vector2(1440.0/viewport.size.x,900.0/viewport.size.y)
func ground(screen: Vector2) -> Vector2:
	var uv = screen*Vector2(viewport.size)/Vector2(1440,900)
	var origin = camera.project_ray_origin(uv)
	var dir = camera.project_ray_normal(uv)
	var hit = origin+dir*(-origin.y/dir.y)
	return Vector2(hit.x,hit.z)*30.0
func screen_direction(direction: Vector2) -> Vector2:
	var right = camera.global_basis.x
	var up = camera.global_basis.y
	return Vector2(right.x*direction.x-up.x*direction.y,right.z*direction.x-up.z*direction.y).normalized()

func rebuild():
	preview_kind = -999
	if scenery != null: scenery.free()
	if dynamic != null: dynamic.free()
	npc_models.clear(); fallen.clear(); actors.clear(); chest_models.clear(); loot_models.clear(); torches.clear(); batches.clear(); shot_models.clear(); skill_models.clear(); tree_index = 0
	pet_model = null
	pet_species = -999
	pet_ring = null
	if vfx != null: vfx.clear()
	scenery = Node3D.new(); scenery.name = "BatchedEnvironment"; world.add_child(scenery)
	dynamic = Node3D.new(); dynamic.name = "ActorsAndProps"; world.add_child(dynamic)
	fx = preload("res://scripts/particles_3d.gd").new()
	dynamic.add_child(fx)
	random.seed = game.map_seed
	var tint = Color(game.Data.CHAPTERS[game.chapter].color)
	var soil = material("soil"+str(game.chapter),(Color("879394") if game.chapter == 2 else Color("46463a").lerp(tint,0.30)),1,0,"soil")
	var stone = material("stone"+str(game.chapter),Color("70736c").lerp(tint,0.18),0.94,0,"stone")
	var darkstone = material("darkstone",Color("414a4b"),1,0,"stone")
	var dirt = material("dirt",Color("383a33"),1,0,"soil")
	var moss = material("moss",Color("47543e"),1,0,"soil")
	var iron = material("iron",Color("353a3c"),0.6,0.65)
	block(scenery,Vector3(game.W/2.0,-0.45,game.H/2.0),Vector3(game.W+40,0.7,game.H+40),soil if game.outdoor() else dirt)
	# Ground is irregular cobblestone set into soil, not a visible square tile grid.
	for z in range(-4,game.H+5):
		for x in range(-4,game.W+5):
			var inside = x>=0 and z>=0 and x<game.W and z<game.H
			var walk = inside and game.tiles[z][x] == 1
			var road = (absf(z-9.5)<2.0 or absf(x-14.5)<1.6 or (not game.in_town and (absf(z-25.5)<1.5 or absf(x-44.5)<1.5))) and inside
			if walk and (road or not game.outdoor()):
				for k in 4:
					var p = Vector3(x+(k%2)*0.48+0.25,random.randf_range(-0.06,-0.025),z+int(k/2)*0.48+0.25)
					block(scenery,p,Vector3(random.randf_range(0.36,0.46),0.12,random.randf_range(0.35,0.46)),stone,Vector3(0,random.randf_range(-0.09,0.09),0))
			elif game.outdoor():
				for k in random.randi_range(1,4):
					var p = Vector3(x+random.randf(),-0.06,z+random.randf())
					ball(scenery,p,Vector3(random.randf_range(0.18,0.45),0.10,random.randf_range(0.2,0.5)),moss if k%2 else dirt)
			if inside and not walk:
				if game.outdoor():
					if x>0 and x<game.W-1 and z>0 and z<game.H-1: continue
					if random.randf()<0.23 and x>0 and x<game.W-1 and z>0 and z<game.H-1: tree(Vector3(x+0.5,0,z+0.5),random.randf_range(0.7,1.2))
					elif random.randf()<0.4: ball(scenery,Vector3(x+0.5,0.17,z+0.5),Vector3(0.8,0.5,0.7),darkstone)
				else:
					var edge = false
					for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var q = Vector2i(x,z)+step
						if q.x>=0 and q.y>=0 and q.x<game.W and q.y<game.H and game.tiles[q.y][q.x]==1: edge = true
					if edge:
						var height = 1.1 if z>10 else 2.5
						block(scenery,Vector3(x+0.5,height/2,z+0.5),Vector3(1,height,1),stone)
						block(scenery,Vector3(x+0.5,height+0.06,z+0.5),Vector3(1.1,0.17,1.1),darkstone)
			if walk and not road and random.randf()<0.16: details(Vector3(x+0.5,0,z+0.5))
	if game.outdoor():
		# Two permanent architectural landmarks sit on blocked footprints.
		landmark(Vector3(8,0,3),stone,darkstone,iron)
		landmark(Vector3(20,0,3),stone,darkstone,iron)
		if not game.in_town:
			landmark(Vector3(36,0,3),stone,darkstone,iron)
			landmark(Vector3(45,0,30),stone,darkstone,iron)
			for p in [Vector3(32,0,15),Vector3(42,0,25),Vector3(24,0,26)]: campfire(p); cart(p+Vector3(1.5,0,1)); barrel(p+Vector3(-1,0,0))
		for x in [0,game.W-1]:
			for z in range(-1,game.H+2,3): tree(Vector3(x+random.randf_range(-2,0),0,z),random.randf_range(0.9,1.4))
		for x in range(1,game.W-1,2):
			fence(Vector3(x,0,0.7),iron,stone)
		for p in [Vector3(3,0,3),Vector3(4.2,0,4.5),Vector3(11,0,4.8),Vector3(12,0,3),Vector3(23,0,6),Vector3(24.4,0,5.5)]: grave(p,stone)
		if not game.in_town: cart(Vector3(8.3,0,12.6))
		campfire(Vector3(5.9,0,7.6))
	else:
		for p in [Vector3(2.4,0,5.5),Vector3(8.5,0,5.5),Vector3(11.4,0,2.5),Vector3(18.5,0,2.5),Vector3(22.4,0,4.5),Vector3(27.5,0,4.5)]: column(p,stone,darkstone)
		for p in [Vector3(4,0,6),Vector3(16,0,3),Vector3(24,0,5)]: grave(p,stone)
	for p in [Vector3(3.1,0,8),Vector3(8.7,0,8),Vector3(13.0,0,4.0),Vector3(19.5,0,10),Vector3(24,0,14)]: brazier(p)
	if game.in_town: town_details(stone,darkstone,iron)
	portal_model = Node3D.new(); dynamic.add_child(portal_model); portal_model.position = v(game.portal)
	portal_arch(portal_model,stone)
	hero = character([-1,-10,-11][game.hero_class])
	hero.name = "Wanderer"
	attach_hero_fx(hero)
	dynamic.add_child(hero)
	if game.in_town:
		for n in game.townsfolk:
			var model = character(n.type); dynamic.add_child(model); model.position = v(n.pos); model.rotation.y = -0.5; npc_models.append(model)
	else:
		var merchant = character(-2); dynamic.add_child(merchant); merchant.position = v(game.npc); merchant.rotation.y = -0.6; npc_models.append(merchant)
	for c in game.chests: chest_models.append(chest(v(c.pos)))
	for e in game.enemies: add_enemy_model(e)
	var torus = TorusMesh.new(); torus.inner_radius = 0.42; torus.outer_radius = 0.46; torus.rings = 32; torus.ring_segments = 6
	ring = MeshInstance3D.new(); ring.mesh = torus; ring.material_override = glow("selection",Color("c8ba85"),0.6); dynamic.add_child(ring)
	var effect_mesh = TorusMesh.new(); effect_mesh.inner_radius = 0.96; effect_mesh.outer_radius = 1.0; effect_mesh.rings = 40; effect_mesh.ring_segments = 4
	attack_effect = MeshInstance3D.new(); attack_effect.mesh = effect_mesh; attack_effect.material_override = glow("strike",Color("f2c48a"),2.0); dynamic.add_child(attack_effect)
	var revive_torus = TorusMesh.new(); revive_torus.inner_radius = 0.44; revive_torus.outer_radius = 0.52; revive_torus.rings = 26; revive_torus.ring_segments = 4
	pet_ring = MeshInstance3D.new(); pet_ring.mesh = revive_torus; pet_ring.material_override = aura_mat("petrevive",Color("9fd1a8"),0.6)
	pet_ring.visible = false; dynamic.add_child(pet_ring)
	if game.chapter==2:
		var snow = fx.spawn(v(game.player,6),Color(0.85,0.92,0.95,0.8),"snow",true,100)
		snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; snow.emission_box_extents = Vector3(14,1,14)
		snow.direction = Vector3(0.25,-1,0.12); snow.gravity = Vector3(0,-0.2,0); snow.lifetime = 8; snow.initial_velocity_max = 1
	elif game.chapter==1:
		var motes = fx.spawn(v(game.player,1),Color("8dc99c"),"motes",true,45)
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; motes.emission_box_extents = Vector3(12,0.7,12); motes.lifetime = 4
	activity_models()
	flush_batches()
	previous_player = game.player
	camera_target = v(game.player)+Vector3(1.5,0,-0.5)
	update_camera(1.0,true)
	sync(0.0)

func tree(p: Vector3,s: float):
	tree_index += 1
	detailer.tree(p,s,tree_index)
	var variant = tree_index%5
	if variant in [1,2,3]:
		var bark = material("treebark"+str(variant),Color("726c59") if variant==2 else Color("453f32"),1,0,"bark")
		cylinder(scenery,p+Vector3(0,1.25*s,0),0.16*s,2.5*s,bark)
		if variant==1:
			for k in 4:
				var mat = material("firleaves",Color("3c574b"),1,0,"soil")
				cylinder(scenery,p+Vector3(0,(1.4+k*0.48)*s,0),(1.1-k*0.2)*s,1.4*s,mat,Vector3.ZERO,true)
				if game.chapter==2: cylinder(scenery,p+Vector3(0,(1.65+k*0.48)*s,0),(0.85-k*0.16)*s,1.05*s,material("snowleaf",Color("a7b3b1"),1,0,"soil"),Vector3.ZERO,true)
		else:
			var leaves = material("canopy"+str(variant),Color("796c3d") if variant==3 else Color("526a4d"),1,0,"soil")
			for k in 7:
				var a = k*2.4
				var end = p+Vector3(cos(a)*0.8,2.0+sin(k)*0.3,sin(a)*0.8)*s
				beam(scenery,p+Vector3(0,1.2*s,0),end,0.08*s,bark)
				ball(scenery,end,Vector3(1.1,0.85,1.0)*s,leaves)
				if variant==3:
					for j in 3: beam(scenery,end+Vector3(j*0.16,0,0),end+Vector3(j*0.16,-0.9,0),0.026,leaves)
		if variant==2:
			for k in 9: block(scenery,p+Vector3(0,0.35+k*0.23,0.15*s),Vector3(0.22*s,0.045,0.025),material("birchmarks",Color("363b38")))
		return
	var bark = material("bark",Color("39342e"),1,0,"wood")
	cylinder(scenery,p+Vector3(0,1.25*s,0),0.14*s,2.5*s,bark,Vector3(0,0,0.06),true)
	for k in 5:
		var a = k*2.4+p.x
		var start = p+Vector3(0,(1.0+k*0.25)*s,0)
		var end = start+Vector3(cos(a)*0.85,0.65,sin(a)*0.85)*s
		beam(scenery,start,end,0.09*s,bark)
		beam(scenery,end,end+Vector3(cos(a+0.5)*0.38,0.6,sin(a+0.5)*0.38)*s,0.05*s,bark)
		if game.chapter in [1,2]:
			var col = Color("687b78") if game.chapter == 2 else Color("35594c")
			if game.chapter == 2:
				cylinder(scenery,end+Vector3(0,0.18,0),0.65*s,0.8*s,material("fir",Color("53655e"),1,0,"soil"),Vector3.ZERO,true)
				cylinder(scenery,end+Vector3(0,0.42,0),0.45*s,0.5*s,material("snowleaf",Color("a7b3b1"),1,0,"soil"),Vector3.ZERO,true)
			else: ball(scenery,end,Vector3(1.2,0.5,1.0)*s,material("leaves"+str(game.chapter),col,1,0,"soil"))
	for k in 4:
		var a = k*PI/2
		beam(scenery,p+Vector3(0,0.3,0),p+Vector3(cos(a)*0.6,0.01,sin(a)*0.6)*s,0.11*s,bark)
func column(p: Vector3,stone: Material,dark: Material):
	block(scenery,p+Vector3(0,0.12,0),Vector3(0.85,0.24,0.85),dark)
	block(scenery,p+Vector3(0,1.3,0),Vector3(0.52,2.4,0.52),stone)
	for y in [0.4,2.3,2.6]: block(scenery,p+Vector3(0,y,0),Vector3(0.75,0.18,0.75),dark)
	cylinder(scenery,p+Vector3(0,2.96,0),0.3,0.65,stone,Vector3.ZERO,true)
func arch(parent: Node3D,p: Vector3,width: float,height: float,mat: Material):
	for side in [-1,1]: block(parent,p+Vector3(side*width*0.5,height*0.32,0),Vector3(0.32,height*0.64,0.5),mat)
	for k in range(11):
		var a = PI*k/10.0
		block(parent,p+Vector3(cos(a)*width*0.5,height*0.63+sin(a)*height*0.34,0),Vector3(width*0.19,0.34,0.52),mat,Vector3(0,0,a-PI/2))
func landmark(p: Vector3,stone: Material,dark: Material,iron: Material):
	detailer.building(p)
	if game.chapter in [0,2]:
		crypt(p,stone,dark,iron)
	elif game.chapter == 1:
		var wood = material("wetwood",Color("536152"),1,0,"wood")
		block(scenery,p+Vector3(0,1.25,0),Vector3(3.5,2.1,3.3),wood)
		for x in [-1.8,1.8]:
			for z in [-1.7,1.7]: cylinder(scenery,p+Vector3(x,1.35,z),0.12,2.7,wood)
		var reed = material("reeds",Color("536d50"),1,0,"wood")
		for side in [-1,1]: block(scenery,p+Vector3(side*0.95,2.8,0),Vector3(2.65,0.24,4.1),reed,Vector3(0,0,-side*0.43))
		block(scenery,p+Vector3(0,1.1,1.67),Vector3(1.0,1.8,0.06),dark)
		for x in [-1.15,1.15]:
			block(scenery,p+Vector3(x,1.5,1.68),Vector3(0.5,0.6,0.06),glow("hutwindow",Color("609980"),0.6))
			for k in 3: block(scenery,p+Vector3(x-0.18+k*0.18,1.5,1.72),Vector3(0.055,0.6,0.06),wood)
		for k in 5:
			var q = p+Vector3(2.0,0,k*0.6-1)
			cylinder(scenery,q+Vector3(0,0.5,0),0.07,1,wood)
			ball(scenery,q+Vector3(0,1,0),Vector3(0.8,0.3,0.7),glow("large_mushroom",Color("4c8e79"),0.4))
	elif game.chapter == 3:
		var brick = material("furnacebrick",Color("695349"),1,0,"stone")
		block(scenery,p+Vector3(0,1.4,0),Vector3(3.5,2.8,3.3),brick)
		block(scenery,p+Vector3(0,2.9,0),Vector3(3.9,0.24,3.8),iron)
		for x in [-1.55,1.55]:
			block(scenery,p+Vector3(x,1.45,1.72),Vector3(0.14,2.9,0.15),iron)
			for y in [0.4,1.4,2.4]: ball(scenery,p+Vector3(x,y,1.82),Vector3(0.2,0.2,0.1),iron)
		block(scenery,p+Vector3(0,1.0,1.68),Vector3(1.5,1.8,0.08),glow("furnace",Color("b04a24"),1.2))
		arch(scenery,p+Vector3(0,0.05,1.76),1.7,2.3,brick)
		for k in 7: block(scenery,p+Vector3(k*0.21-0.63,1.0,1.83),Vector3(0.075,1.85,0.09),iron)
		for x in [-0.8,0.8]:
			cylinder(scenery,p+Vector3(x,3.8,-0.7),0.42,2.6,brick)
			for y in [3,4,5]: cylinder(scenery,p+Vector3(x,y,-0.7),0.47,0.16,iron)
	else:
		for x in [-1.7,1.7]:
			for z in [-1.5,1.5]: column(p+Vector3(x,0,z),stone,dark)
		arch(scenery,p+Vector3(0,0,1.4),3.2,4.0,stone)
		var crystal = glow("royalcrystal",Color("8e6caa"),0.7)
		for k in 5:
			cylinder(scenery,p+Vector3((k-2)*0.42,1.2+abs(k-2)*0.13,0),0.28,2.8-abs(k-2)*0.3,crystal,Vector3(0,0,(k-2)*0.15),true)
		block(scenery,p+Vector3(0,0.15,0),Vector3(4,0.3,3.5),dark)

func crypt(p: Vector3,stone: Material,dark: Material,iron: Material):
	building_details(p,stone,iron)
	block(scenery,p+Vector3(0,0.13,0),Vector3(4.2,0.26,4.2),dark)
	block(scenery,p+Vector3(0,1.5,-0.1),Vector3(3.5,2.8,3.3),stone)
	# Roof built as paired sloping slate slabs with a ridge, individual ribs and finials.
	var slate = material("slate"+str(game.chapter),Color("9aabae") if game.chapter==2 else Color("323d48"),0.9,0,"roof")
	for side in [-1,1]:
		block(scenery,p+Vector3(side*0.93,3.3,-0.1),Vector3(2.6,0.22,4.0),slate,Vector3(0,0,-side*0.56))
		for z in range(-3,4): block(scenery,p+Vector3(side*0.93,3.44,z*0.52),Vector3(2.6,0.075,0.065),dark,Vector3(0,0,-side*0.56))
	block(scenery,p+Vector3(0,4.0,-0.1),Vector3(0.17,0.18,4.1),dark)
	for x in [-1.7,1.7]:
		column(p+Vector3(x,0,1.55),stone,dark)
		block(scenery,p+Vector3(x,1.2,-1.55),Vector3(0.5,2.5,0.5),dark)
	var wood = material("cryptdoor",Color("322b24"),1,0,"wood")
	block(scenery,p+Vector3(0,1.0,1.61),Vector3(1.35,2.0,0.08),wood)
	arch(scenery,p+Vector3(0,0.1,1.72),1.5,2.5,dark)
	for x in [-0.4,0.0,0.4]: block(scenery,p+Vector3(x,1.0,1.7),Vector3(0.055,1.8,0.045),iron)
	for y in [0.4,1.4]: block(scenery,p+Vector3(0,y,1.76),Vector3(1.25,0.08,0.08),iron)
	block(scenery,p+Vector3(0,4.65,-0.5),Vector3(0.12,1.15,0.12),iron)
	block(scenery,p+Vector3(0,4.84,-0.5),Vector3(0.64,0.1,0.12),iron)
	for step in 3: block(scenery,p+Vector3(0,0.06+step*0.055,2.1-step*0.22),Vector3(2.0,0.12+step*0.11,0.36),stone)
func grave(p: Vector3,stone: Material):
	var dark = material("gravedark",Color("3c4240"),1,0,"stone")
	block(scenery,p+Vector3(0,0.04,0.5),Vector3(0.75,0.13,1.5),dark)
	block(scenery,p+Vector3(0,0.42,-0.1),Vector3(0.65,0.84,0.2),stone,Vector3(0,0,0.035))
	ball(scenery,p+Vector3(0,0.82,-0.1),Vector3(0.64,0.43,0.2),stone)
	block(scenery,p+Vector3(0,0.57,0.011),Vector3(0.06,0.35,0.025),dark)
	block(scenery,p+Vector3(0,0.62,0.012),Vector3(0.24,0.05,0.025),dark)
func fence(p: Vector3,iron: Material,stone: Material):
	block(scenery,p+Vector3(0,0.3,0),Vector3(2,0.6,0.35),stone)
	for x in range(-3,4):
		block(scenery,p+Vector3(x*0.28,1.0,0),Vector3(0.045,1.0,0.045),iron)
		cylinder(scenery,p+Vector3(x*0.28,1.57,0),0.085,0.18,iron,Vector3.ZERO,true)
	for y in [0.85,1.25]: block(scenery,p+Vector3(0,y,0),Vector3(2,0.06,0.07),iron)
func details(p: Vector3):
	if game.chapter == 1:
		var stem = material("stem",Color("a2a68a"))
		for k in 3:
			var pos = p+Vector3(k*0.16,0,random.randf()*0.4)
			cylinder(scenery,pos+Vector3(0,0.18,0),0.04,0.36,stem)
			ball(scenery,pos+Vector3(0,0.36,0),Vector3(0.4,0.18,0.36),glow("mushroom",Color("4b9a86"),0.5))
	elif game.chapter == 2:
		ball(scenery,p,Vector3(1.0,0.2,0.8),material("snow",Color("b0bbc0"),1,0,"soil"))
	elif game.chapter == 3:
		block(scenery,p+Vector3(0,0.03,0),Vector3(0.8,0.12,0.8),glow("coals",Color("ab4725"),0.8))
		for k in 5: block(scenery,p+Vector3(k*0.15-0.3,0.11,0),Vector3(0.055,0.05,0.8),material("grate",Color("272b30"),0.5,0.6))
	elif game.chapter == 4:
		for k in 3: cylinder(scenery,p+Vector3(k*0.15,0.28,0),0.1,0.6,glow("crystals",Color("8268a6"),0.5),Vector3(0,k,k*0.2),true)
	else:
		var grass = material("deadgrass",Color("77704e"),1)
		for k in 5: block(scenery,p+Vector3(random.randf()*0.45,0.14,random.randf()*0.4),Vector3(0.026,random.randf_range(0.15,0.38),0.03),grass,Vector3(0,0,random.randf_range(-0.35,0.35)))
func brazier(p: Vector3):
	var iron = material("iron",Color("353a3c"),0.6,0.65)
	cylinder(scenery,p+Vector3(0,0.08,0),0.27,0.16,iron)
	cylinder(scenery,p+Vector3(0,0.65,0),0.065,1.2,iron)
	cylinder(scenery,p+Vector3(0,1.22,0),0.28,0.18,iron)
	for k in 4:
		var a = k*TAU/4
		beam(scenery,p+Vector3(cos(a)*0.22,1.2,sin(a)*0.22),p+Vector3(cos(a)*0.29,1.53,sin(a)*0.29),0.045,iron)
	var flame = ball(dynamic,p+Vector3(0,1.45,0),Vector3(0.24,0.5,0.24),glow("fire",Color("ffc074"),2.3))
	var core = ball(dynamic,p+Vector3(0,1.4,0),Vector3(0.15,0.28,0.15),glow("firecore",Color("ffe7a1"),3.0))
	var lamp = OmniLight3D.new(); lamp.position = p+Vector3(0,1.6,0); lamp.light_color = Color("ffac61"); lamp.light_energy = 3.5; lamp.omni_range = 4.6
	dynamic.add_child(lamp)
	fx.spawn(p+Vector3(0,1.5,0),Color("edac68"),"embers",true,16)
	fx.spawn(p+Vector3(0,1.7,0),Color(0.3,0.3,0.29,0.35),"smoke",true,10)
	torches.append({"flame":flame,"core":core,"light":lamp})
func campfire(p: Vector3):
	var wood = material("bark",Color("39342e"),1,0,"wood")
	for k in 5:
		var a = k*TAU/5
		block(scenery,p+Vector3(cos(a)*0.17,0.15,sin(a)*0.17),Vector3(0.16,0.16,0.8),wood,Vector3(0,a,0.1))
	for k in 9:
		var a = k*TAU/9
		ball(scenery,p+Vector3(cos(a)*0.55,0.09,sin(a)*0.55),Vector3(0.25,0.25,0.23),material("firestones",Color("676d68")))
	ball(dynamic,p+Vector3(0,0.45,0),Vector3(0.35,0.7,0.35),glow("fire",Color("ffc074"),2.3))
	var lamp = OmniLight3D.new(); lamp.position = p+Vector3(0,0.9,0); lamp.light_color = Color("fbb57c"); lamp.light_energy = 4; lamp.omni_range = 5
	dynamic.add_child(lamp)
func cart(p: Vector3):
	var wood = material("cartwood",Color("6d5036"),1,0,"wood")
	var iron = material("iron",Color("353a3c"),0.6,0.65)
	for k in 6: block(scenery,p+Vector3(k*0.19-0.5,0.55,0),Vector3(0.16,0.12,1.45),wood)
	for x in [-0.6,0.6]:
		for k in 3: block(scenery,p+Vector3(x,0.65+k*0.19,0),Vector3(0.09,0.13,1.5),wood)
		cylinder(scenery,p+Vector3(x*1.2,0.38,0),0.38,0.12,iron,Vector3(0,0,PI/2))
		cylinder(scenery,p+Vector3(x*1.22,0.38,0),0.28,0.13,wood,Vector3(0,0,PI/2))
		block(scenery,p+Vector3(x*0.7,0.4,1.3),Vector3(0.09,0.1,1.3),wood,Vector3(0.15,0,0))
	for k in 3: ball(scenery,p+Vector3(k*0.25-0.3,0.8,k*0.2-0.3),Vector3(0.45,0.4,0.5),material("sacks",Color("948568"),1,0,"soil"))
func portal_arch(parent: Node3D,stone: Material):
	arch(parent,Vector3.ZERO,1.8,3.0,stone)
	var torus = TorusMesh.new(); torus.inner_radius = 0.73; torus.outer_radius = 0.78; torus.rings = 48; torus.ring_segments = 6
	var n = emit_mesh(parent,torus,glow("portal",Color("678c9f"),1.2),Vector3(0,1.3,0),Vector3(1,1,1.4),Vector3(PI/2,0,0))
	n.name = "GateRing"
func chest(p: Vector3) -> Node3D:
	var root = Node3D.new(); dynamic.add_child(root); root.position = p
	var wood = material("chestwood",Color("70513a"),1,0,"wood")
	var trim = material("chesttrim",Color("a68a56"),0.5,0.6)
	block(root,Vector3(0,0.25,0),Vector3(0.8,0.48,0.55),wood)
	var lid = Node3D.new(); root.add_child(lid); lid.position = Vector3(0,0.49,-0.28); lid.name = "Lid"
	block(lid,Vector3(0,0.04,0.28),Vector3(0.85,0.15,0.6),wood)
	for x in [-0.29,0.29]:
		block(root,Vector3(x,0.26,0.28),Vector3(0.055,0.46,0.03),trim)
		block(lid,Vector3(x,0.13,0.28),Vector3(0.06,0.03,0.6),trim)
	block(root,Vector3(0,0.39,0.3),Vector3(0.14,0.17,0.04),trim)
	detailer.prop(root)
	return root

func authored_character(kind: int) -> Node3D:
	var file = "warrior" if kind == -1 else ("mage" if kind == -10 else "archer")
	var packed = load("res://assets/models/realistic/authored/"+file+".glb")
	if packed == null: return null
	var root: Node3D = packed.instantiate(); root.name = "Authored_"+file
	root.set_meta("authored",true); root.set_meta("kind",kind); root.set_meta("action","idle")
	var skeleton = root.get_node_or_null("Rig/Skeleton3D")
	if skeleton != null:
		# Variant 0 is the default appearance; variant 1 is a swappable equipment set.
		for n in skeleton.get_children():
			if n.name.ends_with("_1"): n.visible = false
		var attachment = BoneAttachment3D.new(); attachment.name = "EquipmentSocket"; attachment.bone_name = "hand_r" if kind in [-1,-10] else "hand_l"; skeleton.add_child(attachment)
		var weapon_file = "sword" if kind == -1 else ("staff" if kind == -10 else "bow")
		var weapon = load("res://assets/models/realistic/authored/"+weapon_file+".glb")
		if weapon != null:
			var weapon_node = weapon.instantiate(); weapon_node.name = "EquippedWeapon"; weapon_node.scale = Vector3.ONE*0.72; attachment.add_child(weapon_node)
		if kind == -1:
			var off = BoneAttachment3D.new(); off.name = "OffhandEquipmentSocket"; off.bone_name = "lower_arm_l"; skeleton.add_child(off)
			var shield = load("res://assets/models/realistic/authored/shield.glb")
			if shield != null: off.add_child(shield.instantiate())
		if kind == -11:
			var back = BoneAttachment3D.new(); back.name = "BackEquipmentSocket"; back.bone_name = "chest"; skeleton.add_child(back)
			var quiver = load("res://assets/models/realistic/authored/quiver.glb")
			if quiver != null: back.add_child(quiver.instantiate())
	var anim = root.get_node_or_null("AnimationPlayer")
	if anim != null: anim.play("idle")
	return root

func _attach_authored_asset(skeleton: Node, bone_name: String, socket_name: String, asset_name: String, scale_value: float = 0.72) -> void:
	var socket = skeleton.get_node_or_null(socket_name)
	if socket == null:
		socket = BoneAttachment3D.new()
		socket.name = socket_name
		socket.bone_name = bone_name
		skeleton.add_child(socket)
	for child in socket.get_children(): child.free()
	var packed = load("res://assets/models/realistic/authored/"+asset_name+".glb")
	if packed != null:
		var item = packed.instantiate()
		item.name = "Equipped_"+asset_name
		item.scale = Vector3.ONE * scale_value
		socket.add_child(item)

func refresh_authored_hero_equipment() -> void:
	if hero == null or not hero.has_meta("authored") or game == null: return
	var skeleton = hero.get_node_or_null("Rig/Skeleton3D")
	if skeleton == null: return
	var kind = int(hero.get_meta("kind", -1))
	var weapon_name = "sword" if kind == -1 else ("staff" if kind == -10 else "bow")
	if game.equipped.size() > 0 and game.equipped[0] is Dictionary:
		var requested = str(game.equipped[0].get("visual_id", ""))
		if requested in ["sword", "axe", "staff", "staff_crystal", "bow", "bow_dark"]: weapon_name = requested
	_attach_authored_asset(skeleton, "hand_r" if kind in [-1,-10] else "hand_l", "EquipmentSocket", weapon_name)
	if kind == -1:
		_attach_authored_asset(skeleton, "lower_arm_l", "OffhandEquipmentSocket", "shield", 0.72)
	if kind == -11:
		_attach_authored_asset(skeleton, "chest", "BackEquipmentSocket", "quiver", 0.72)

func character(kind: int) -> Node3D:
	if kind in [-1,-10,-11]:
		var authored = authored_character(kind)
		if authored != null: return authored
	if kind in [4,5]: return creature(kind)
	var root = Node3D.new()
	var armor_color = Color("929da1") if kind==-1 else (Color("5b7295") if kind==-10 else (Color("597358") if kind==-11 else (Color("6f756a") if kind==0 else Color("675565"))))
	armor_color = {-2:Color("8d7754"),-3:Color("587f7c"),-4:Color("8c7160"),-5:Color("747e9b"),-6:Color("967b57")}.get(kind,armor_color)
	var armor = material("armor"+str(kind),armor_color,0.56,0.55 if kind>=-1 else 0.05,"rust" if kind in [0,6] else ("metal" if kind>=-1 else "leather"))
	var edge = material("armor_edge",Color("b8b5a0"),0.4,0.65)
	var leather = material("leather",Color("41352e"),0.9,0,"leather")
	var cloth = material("cloth"+str(kind),Color("783e37") if kind == -1 else (Color("625346") if kind == -2 else Color("41364e")),1,0,"cloth")
	var bone = material("bone",Color("b6b09a"),0.95,0,"bone")
	var skin = material("skin"+str(kind),Color("b89b7e") if kind<0 else Color("77856b"),1,0,"skin")
	var dark = material("visor",Color("141b1d"),0.6)
	var metal = material("blade",Color("c2c9c3"),0.3,0.8)
	var eyes = glow("eyes"+str(kind),Color("d7a767") if kind<0 else Color("d5754e"),0.8)
	for side in [-1,1]:
		var leg = Node3D.new(); leg.name = "LeftLeg" if side == -1 else "RightLeg"; root.add_child(leg); leg.position = Vector3(side*0.13,0.77,0)
		cylinder(leg,Vector3(0,-0.18,0),0.10,0.35,bone if kind==1 else leather)
		ball(leg,Vector3(0,-0.38,-0.035),Vector3(0.22,0.21,0.22),bone if kind==1 else armor)
		cylinder(leg,Vector3(0,-0.53,0),0.075 if kind==1 else 0.11,0.3,bone if kind==1 else armor)
		block(leg,Vector3(0,-0.7,-0.07),Vector3(0.22,0.14,0.36),leather)
	# Torso, ribbed mail skirt and breastplate; non-cubic silhouette.
	if kind == 1:
		cylinder(root,Vector3(0,1.0,0),0.06,0.5,bone)
		for y in [0.9,1.03,1.16]:
			ball(root,Vector3(0,y,-0.01),Vector3(0.42,0.07,0.25),bone)
	else:
		profile(root,Vector3(0,0.79,0),[[0.0,0.20,0.14],[0.13,0.23,0.16],[0.30,0.29,0.18],[0.44,0.28,0.17],[0.55,0.16,0.13]],armor if kind!=-2 else cloth)
		block(root,Vector3(0,1.13,-0.17),Vector3(0.15,0.27,0.06),edge)
		for x in [-0.18,0,0.18]: block(root,Vector3(x,0.77,-0.11),Vector3(0.16,0.28,0.14),armor,Vector3(-0.15,0,-x))
	cylinder(root,Vector3(0,0.86,0),0.26,0.09,leather)
	block(root,Vector3(0,0.85,-0.25),Vector3(0.12,0.10,0.06),edge)
	cylinder(root,Vector3(0,1.37,0),0.1,0.15,bone if kind==1 else dark)
	ball(root,Vector3(0,1.58,0),Vector3(0.40,0.48,0.37),bone if kind==1 else (skin if kind< -1 or kind==0 else armor))
	if kind == 1:
		for x in [-0.09,0.09]: ball(root,Vector3(x,1.61,-0.169),Vector3(0.10,0.12,0.055),dark)
		block(root,Vector3(0,1.42,-0.1),Vector3(0.26,0.12,0.20),bone)
		for x in [-0.08,0,0.08]: block(root,Vector3(x,1.4,-0.204),Vector3(0.025,0.07,0.015),dark)
	elif kind == -1 or kind >= 0:
		block(root,Vector3(0,1.57,-0.182),Vector3(0.34,0.07,0.06),dark)
		for x in [-0.095,0.095]: block(root,Vector3(x,1.575,-0.218),Vector3(0.075,0.025,0.015),eyes)
		block(root,Vector3(0,1.55,-0.232),Vector3(0.035,0.24,0.028),edge)
		block(root,Vector3(0,1.76,-0.025),Vector3(0.05,0.09,0.35),edge)
	# Shoulder pivots drive a visible swing and a walk cycle.
	for side in [-1,1]:
		var arm = Node3D.new(); arm.name = "SwordArm" if side==1 else "ShieldArm"; root.add_child(arm); arm.position = Vector3(side*0.32,1.25,0)
		ball(arm,Vector3.ZERO,Vector3(0.29,0.26,0.33),bone if kind==1 else armor)
		cylinder(arm,Vector3(0,-0.23,0),0.055 if kind==1 else 0.09,0.36,bone if kind==1 else leather,Vector3(0,0,-side*0.12))
		ball(arm,Vector3(side*0.02,-0.4,-0.04),Vector3(0.16,0.22,0.17),bone if kind==1 else armor)
		if side==1:
			var sword = Node3D.new(); sword.name = "Sword"; arm.add_child(sword); sword.position = Vector3(0.02,-0.43,-0.06); sword.rotation.x = -0.28
			cylinder(sword,Vector3(0,0.09,0),0.035,0.25,leather)
			block(sword,Vector3(0,0.23,0),Vector3(0.32,0.055,0.07),edge)
			block(sword,Vector3(0,0.66,0),Vector3(0.09,0.83,0.038),metal)
			cylinder(sword,Vector3(0,1.12,0),0.049,0.14,metal,Vector3.ZERO,true)
			block(sword,Vector3(0.01,0.64,-0.026),Vector3(0.018,0.7,0.01),edge)
		elif kind != 1:
			ball(arm,Vector3(-0.08,-0.28,-0.12),Vector3(0.12,0.68,0.49),edge)
			ball(arm,Vector3(-0.145,-0.28,-0.12),Vector3(0.045,0.55,0.39),cloth)
			block(arm,Vector3(-0.17,-0.28,-0.12),Vector3(0.02,0.38,0.04),edge)
	if kind != 1:
		var cape = Node3D.new(); cape.name = "Cape"; root.add_child(cape); cape.position = Vector3(0,1.26,0.16)
		var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for a in [Vector3(-0.23,0,0),Vector3(-0.35,-0.87,0.22),Vector3(0.34,-0.83,0.23),Vector3(-0.23,0,0),Vector3(0.34,-0.83,0.23),Vector3(0.23,0,0)]: st.add_vertex(a)
		st.generate_normals()
		var cape_mat = cloth.duplicate(); cape_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		emit_mesh(cape,st.commit(),cape_mat,Vector3.ZERO)
	if kind == 3:
		for x in [-0.23,0.23]: cylinder(root,Vector3(x,1.94,0),0.1,0.5,edge,Vector3(0,0,-x*1.5),true)
	if kind==6:
		root.get_node("SwordArm/Sword").hide()
		var hand = motion.pivot(root.get_node("SwordArm"),"Crossbow",Vector3.ZERO)
		block(hand,Vector3(0,-0.43,-0.25),Vector3(0.08,0.09,0.7),material("crossbow",Color("83674b"),0.8,0,"wood"))
		block(hand,Vector3(0,-0.43,-0.46),Vector3(0.6,0.05,0.07),edge)
		beam(hand,Vector3(-0.29,-0.43,-0.46),Vector3(0,-0.43,-0.20),0.009,edge)
		beam(hand,Vector3(0.29,-0.43,-0.46),Vector3(0,-0.43,-0.20),0.009,edge)
	character_details(root,kind,armor,cloth,leather,bone,skin,edge)
	detailer.character(root,kind)
	motion.rig(root,kind)
	detailer.bake(root)
	return root

func update_camera(dt: float,snap: bool = false):
	var target = v(game.player)+Vector3(0.9,0,-0.6)
	camera_target = target if snap else camera_target.lerp(target,1.0-exp(-dt*8.0))
	camera.position = camera_target + Vector3(12,15,12)
	camera.look_at(camera_target,Vector3.UP)
	if game.shake>0:
		var s = clampf(game.shake/0.30,0.0,1.5)
		var f = tick*74.0
		camera.h_offset = (sin(f)*0.075+sin(f*2.7)*0.028)*s
		camera.v_offset = (cos(f*1.31)*0.062+cos(f*3.1)*0.020)*s
		camera.rotation.z = sin(f*0.9)*0.013*s
	else:
		camera.h_offset = 0; camera.v_offset = 0; camera.rotation.z = 0
func sync(dt: float):
	if game == null or hero == null: return
	tick += dt
	update_camera(dt)
	var moving = previous_player.distance_to(game.player)>0.01
	hero.position = v(game.player)
	hero.rotation.y = lerp_angle(hero.rotation.y,atan2(-game.facing.x,-game.facing.y),minf(1,dt*18))
	update_model_animation(hero,dt,moving)
	update_hero_glow(dt)
	if vfx != null: vfx.update(dt)
	for model in npc_models: motion.update(model,dt)
	previous_player = game.player
	light.position = hero.position+Vector3(0,2.4,0)
	ring.position = hero.position+Vector3(0,0.055,0)
	attack_effect.visible = false
	attack_effect.position = hero.position+Vector3(0,0.08,0)
	attack_effect.scale = Vector3.ONE*(5.0*(1-game.slash/0.2) if game.nova_cd>4.7 else 1.3)
	sync_combat_fx()
	sync_pet(dt)
	var live = {}
	for e in game.enemies:
		if not e.has("visual_id") or not actors.has(e.visual_id): add_enemy_model(e)
		var id = e.visual_id
		if not actors.has(id): continue
		live[id] = true
		var a = actors[id]
		var old = a.position
		a.position = v(e.pos)
		var d = game.player-e.pos
		a.rotation.y = atan2(-d.x,-d.y)
		motion.update(a,dt,Vector2(old.x,old.z).distance_to(Vector2(a.position.x,a.position.z))>0.003)
		# 受击挤压回弹 + 轻微后退，让命中读得出来。
		var hurt = e.get("hit",0.0)
		var base_scale = 1.8 if e.boss else (1.23 if e.get("elite",false) else 1.0)
		if hurt>0.0:
			var k = clampf(hurt/0.17,0.0,1.0)
			a.scale = Vector3(base_scale*(1.0+0.17*k),base_scale*(1.0-0.14*k),base_scale*(1.0+0.17*k))
			var back = e.get("knock_dir",Vector2.ZERO)*hurt*0.45
			a.position += Vector3(back.x/30.0,0.0,back.y/30.0)
		else:
			a.scale = Vector3.ONE*base_scale
	for id in actors.keys():
		if not live.has(id):
			var corpse = actors[id]; motion.play(corpse,"death",0.85)
			fallen.append({"model":corpse,"life":1.4}); actors.erase(id)
	for body in fallen:
		body.life -= dt; motion.update(body.model,dt)
		if body.life<0.45: body.model.scale *= maxf(0,1-dt*5)
		if body.life<=0: body.model.queue_free()
	fallen = fallen.filter(func(body): return body.life>0)
	for i in chest_models.size(): chest_models[i].get_node("Lid").rotation.x = lerpf(chest_models[i].get_node("Lid").rotation.x,-1.1 if game.chests[i].open else 0.0,1-exp(-dt*8))
	# Lightweight nodes for loot. Rebuilt only when count changes; positions update every frame.
	while loot_models.size()>game.drops.size(): loot_models.pop_back().queue_free()
	while loot_models.size()<game.drops.size():
		var n = Node3D.new(); dynamic.add_child(n)
		var mesh = cylinder(n,Vector3.ZERO,0.10,0.34,glow("quest",Color("d8bb7a")),Vector3.ZERO,true)
		n.set_meta("mesh",mesh); loot_models.append(n)
	for i in game.drops.size():
		var d = game.drops[i]
		loot_models[i].position = v(d.pos,0.35+sin(tick*2+i)*0.10)
		loot_models[i].rotation.y = tick
		var col = Color("d8bb7a") if d.kind=="mark" else Color(game.Data.RARITY_COLORS[int(d.item.rarity)])
		loot_models[i].get_meta("mesh").material_override = glow("loot"+col.to_html(),col,1.4)
	for i in torches.size():
		torches[i].flame.scale.y = 0.5+sin(tick*13+i)*0.1
		torches[i].light.light_energy = 3.4+sin(tick*8+i)*0.25
	var gate = portal_model.get_node("GateRing")
	gate.rotation.z = tick*0.2
	gate.material_override = glow("portal_ready",Color("76cbc3"),2.5) if game.ready_exit() else glow("portal",Color("678c9f"),1.2)
func zoom(amount: float): camera.size = clampf(camera.size+amount,10.0,22.0)
func set_quality():
	quality = (quality+1)%3
	viewport.size = [Vector2i(960,600),Vector2i(720,450),Vector2i(1440,900)][quality]
	post.size = Vector2(viewport.size)
func _process(dt):
	if preview_subject!=null and game.modal in ["gallery","character"]:
		preview_clock += minf(dt,0.05)
		if preview_turntable: preview_subject.rotation.y += minf(dt,0.05)*0.35
		update_model_animation(preview_subject,dt,false,preview_action,preview_clock)
	sync(dt if game != null and game.modal in ["","dead"] else 0.0)

func update_model_animation(model: Node3D,dt: float,moving: bool=false,forced: String="",time: float=-1.0):
	if model != null and model.has_meta("authored"):
		var player: AnimationPlayer = model.get_node_or_null("AnimationPlayer")
		if player == null: return
		var action = forced if forced != "" else ("walk" if moving else str(model.get_meta("action","idle")))
		if not player.has_animation(action): action = "idle"
		if player.current_animation != action: player.play(action,0.14)
		model.set_meta("action",action)
		return
	motion.update(model,dt,moving,forced,time)

func barrel(p: Vector3):
	var wood = material("barrelwood",Color("806346"),1,0,"wood")
	var iron = material("barreliron",Color("424744"),0.6,0.5)
	cylinder(scenery,p+Vector3(0,0.38,0),0.32,0.75,wood)
	for y in [0.12,0.6]: cylinder(scenery,p+Vector3(0,y,0),0.34,0.06,iron)
	for k in 8:
		var a = k*TAU/8
		block(scenery,p+Vector3(cos(a)*0.32,0.38,sin(a)*0.32),Vector3(0.025,0.65,0.025),iron)
func building_details(p: Vector3,stone: Material,iron: Material):
	var trim = material("timbertrim",Color("564332"),1,0,"wood")
	var window = glow("warmwindow",Color("cf994f"),0.5)
	for z in [-0.9,0.7]:
		block(scenery,p+Vector3(-1.77,1.65,z),Vector3(0.055,0.8,0.55),trim)
		block(scenery,p+Vector3(-1.81,1.65,z),Vector3(0.025,0.62,0.4),window)
		for y in [1.43,1.72,1.96]: block(scenery,p+Vector3(-1.84,y,z),Vector3(0.04,0.045,0.51),iron)
		block(scenery,p+Vector3(-1.85,1.65,z),Vector3(0.04,0.78,0.04),iron)
		block(scenery,p+Vector3(-1.83,1.19,z),Vector3(0.23,0.12,0.7),stone)
	for side in [-1,1]:
		block(scenery,p+Vector3(side*1.8,0.5,0),Vector3(0.16,0.12,3.4),stone)
		for y in [0.8,1.3,1.8,2.3]: block(scenery,p+Vector3(side*1.81,y,1.5),Vector3(0.24,0.2,0.35),stone)
	# Hanging sign, door studs, a rainwater barrel, ivy and fallen roof stones.
	beam(scenery,p+Vector3(-1.3,2.2,1.7),p+Vector3(-1.3,2.2,2.45),0.09,iron)
	for x in [-1.5,-1.15]: block(scenery,p+Vector3(x,1.97,2.42),Vector3(0.025,0.45,0.025),iron)
	block(scenery,p+Vector3(-1.32,1.76,2.43),Vector3(0.6,0.4,0.085),trim)
	block(scenery,p+Vector3(-1.32,1.77,2.48),Vector3(0.25,0.055,0.025),material("signgold",Color("c6a366")))
	for x in [-0.5,0.5]:
		for y in [0.45,1.35]: ball(scenery,p+Vector3(x,y,1.82),Vector3(0.06,0.06,0.04),iron)
	barrel(p+Vector3(2.15,0,0.8))
	var ivy = material("ivy",Color("465c3f"),1,0,"cloth")
	for k in 13:
		var q = p+Vector3(1.82,0.6+k*0.15,-0.8+sin(k)*0.12)
		ball(scenery,q,Vector3(0.045,0.20,0.18),ivy)
func town_details(stone: Material,dark: Material,iron: Material):
	# Distinct town landmarks and actual services stand around a clear central square.
	landmark(Vector3(7.5,0,16),stone,dark,iron)
	landmark(Vector3(20.5,0,16),stone,dark,iron)
	var well = Vector3(15,0,9)
	cylinder(scenery,well+Vector3(0,0.16,0),0.9,0.32,dark)
	var water = material("wellwater",Color("3b7279"),0.18,0.35)
	cylinder(scenery,well+Vector3(0,0.39,0),0.65,0.05,water)
	for k in 12:
		var a = k*TAU/12
		block(scenery,well+Vector3(cos(a)*0.73,0.4,sin(a)*0.73),Vector3(0.4,0.4,0.25),stone,Vector3(0,-a+PI/2,0))
	var wood = material("marketwood",Color("72573d"),1,0,"wood")
	for x in [-0.8,0.8]: block(scenery,well+Vector3(x,1.0,0),Vector3(0.12,1.8,0.12),wood)
	block(scenery,well+Vector3(0,1.9,0),Vector3(1.9,0.14,0.14),wood)
	cylinder(scenery,well+Vector3(0,1.2,0),0.022,1.3,material("rope",Color("a28d66")))
	for p in [Vector3(10.5,0,6.7),Vector3(20.5,0,10.5)]: market_stall(p)
	var forge_pos = Vector3(19.8,0,10.3)
	block(scenery,forge_pos+Vector3(0,0.3,0),Vector3(0.55,0.6,0.55),wood)
	block(scenery,forge_pos+Vector3(0,0.68,0),Vector3(0.85,0.2,0.4),iron)
	cylinder(scenery,forge_pos+Vector3(0.47,0.7,0),0.18,0.42,iron,Vector3(0,0,PI/2),true)
	fx.spawn(forge_pos+Vector3(0,0.8,0),Color("efaf62"),"spark",true,9)
	for p in [Vector3(9,0,12),Vector3(18,0,12)]:
		block(scenery,p+Vector3(0,0.42,0),Vector3(1.5,0.12,0.42),wood)
		for x in [-0.55,0.55]: block(scenery,p+Vector3(x,0.2,0),Vector3(0.12,0.4,0.35),wood)
	for x in [4,25]:
		for z in [6,13]:
			column(Vector3(x,0,z),stone,dark)
			var banner = material("townbanner"+str(game.chapter),Color(game.Data.CHAPTERS[game.chapter].color),1,0,"cloth")
			block(scenery,Vector3(x,1.7,z+0.4),Vector3(0.65,1.15,0.04),banner)
			block(scenery,Vector3(x,1.7,z+0.425),Vector3(0.08,0.6,0.02),material("bannertrim",Color("c7ad77")))
	var smoke = fx.spawn(Vector3(20.5,4.3,16),Color(0.4,0.4,0.38,0.4),"smoke",true,25)
	smoke.direction = Vector3(0.3,1,0.1)
func market_stall(p: Vector3):
	var wood = material("marketwood",Color("72573d"),1,0,"wood")
	for x in [-0.9,0.9]:
		for z in [-0.5,0.5]: block(scenery,p+Vector3(x,1.1,z),Vector3(0.08,2.2,0.08),wood)
	for k in 8:
		var cloth = material("awning"+str(k%2),Color("7b403a") if k%2 else Color("c0af87"),1,0,"cloth")
		block(scenery,p+Vector3(k*0.26-0.92,2.2,0),Vector3(0.26,0.06,1.65),cloth,Vector3(0.15,0,0))
		block(scenery,p+Vector3(k*0.26-0.92,2.02,0.81),Vector3(0.26,0.25,0.04),cloth)
	block(scenery,p+Vector3(0,0.83,0),Vector3(2.0,0.1,0.85),wood)
	for k in 8:
		var c = Color("8cbeac") if k%2 else Color("b86957")
		cylinder(scenery,p+Vector3(k*0.2-0.72,1.0,0),0.075,0.25,material("bottles"+str(k%2),c,0.3))
		cylinder(scenery,p+Vector3(k*0.2-0.72,1.17,0),0.03,0.1,wood)
	barrel(p+Vector3(1.25,0,0))

func character_details(root: Node3D,kind: int,armor: Material,cloth: Material,leather: Material,bone: Material,skin: Material,edge: Material):
	var human = kind < -1
	var role_color = Color("879471") if kind==-11 else (Color("677baf") if kind==-10 else Color("8a674f"))
	var robes = material("robes"+str(kind),role_color,1,0,"cloth")
	var hair = material("hair"+str(kind),Color("b3aaa0") if kind==-5 else Color("514233"),1,0,"bark")
	if human:
		# Distinct faces: brow, inset eyes, nose, ears, hair locks and jaw.
		for side in [-1,1]:
			ball(root,Vector3(side*0.20,1.57,0),Vector3(0.09,0.15,0.11),skin)
			block(root,Vector3(side*0.083,1.63,-0.174),Vector3(0.083,0.032,0.036),hair)
			block(root,Vector3(side*0.085,1.585,-0.188),Vector3(0.035,0.035,0.025),material("humaneyes",Color("24343b")))
		ball(root,Vector3(0,1.54,-0.195),Vector3(0.07,0.10,0.09),skin)
		block(root,Vector3(0,1.45,-0.15),Vector3(0.1,0.022,0.025),hair)
		for k in 7: ball(root,Vector3((k-3)*0.049,1.78-abs(k-3)*0.013,0.01),Vector3(0.10,0.12,0.31),hair)
		var shield = root.get_node("ShieldArm")
		for i in range(3,shield.get_child_count()): shield.get_child(i).hide()
		root.get_node("SwordArm/Sword").hide()
	if kind==-10 or kind==2:
		cylinder(root,Vector3(0,0.73,0),0.4,1.05,robes if kind==-10 else cloth,Vector3.ZERO,true)
		for side in [-1,1]: block(root,Vector3(side*0.18,0.8,-0.25),Vector3(0.04,0.8,0.04),edge,Vector3(0,0,side*0.1))
		var staff_parent = motion.pivot(root.get_node("SwordArm"),"Staff",Vector3.ZERO)
		root.get_node("SwordArm/Sword").hide()
		cylinder(staff_parent,Vector3(0,-0.05,-0.13),0.035,1.8,leather)
		for k in 3: cylinder(staff_parent,Vector3(0,0.45+k*0.11,-0.13),0.065,0.035,edge)
		ball(staff_parent,Vector3(0,0.89,-0.13),Vector3(0.18,0.28,0.18),glow("staffcrystal",Color("8ebbe8"),1.2))
		for side in [-1,1]: beam(staff_parent,Vector3(0,0.62,-0.13),Vector3(side*0.14,0.89,-0.13),0.03,edge)
		if kind==2: cylinder(root,Vector3(0,1.91,0),0.25,0.65,cloth,Vector3.ZERO,true)
	if kind==-11:
		var bow_arm = motion.pivot(root.get_node("ShieldArm"),"Bow",Vector3.ZERO)
		var bowwood = material("bowwood",Color("997849"),0.8,0,"wood")
		var points = []
		for k in 10:
			var a = -PI/2+k*PI/9
			points.append(Vector3(-0.08,-0.18+sin(a)*0.64,-0.14-cos(a)*0.30))
		for k in 9: beam(bow_arm,points[k],points[k+1],0.047,bowwood)
		for name in ["StringUpper","StringLower"]:
			var string_part = motion.pivot(bow_arm,name,Vector3.ZERO)
			block(string_part,Vector3.ZERO,Vector3.ONE,edge)
		var arrow = motion.pivot(bow_arm,"NockedArrow",Vector3(-0.08,-0.18,-0.14))
		block(arrow,Vector3(0,0,-0.35),Vector3(0.016,0.016,0.7),bowwood)
		cylinder(arrow,Vector3(0,0,-0.75),0.032,0.12,bone,Vector3(-PI/2,0,0),true)
		cylinder(root,Vector3(0.20,1.04,0.25),0.11,0.65,leather,Vector3(0,0,-0.35))
		for k in 5:
			var p = Vector3(0.14+k*0.035,1.5,0.25)
			cylinder(root,p,0.012,0.43,bowwood,Vector3(0,0,-0.25))
			block(root,p+Vector3(-0.04,0.15,0),Vector3(0.06,0.12,0.016),bone,Vector3(0,0,-0.25))
	if kind in [-2,-3,-4,-5,-6]:
		# Unarmed town residents have recognizable silhouettes and trade tools.
		if kind==-4 or kind==-6:
			block(root,Vector3(0,0.89,-0.22),Vector3(0.41,0.73,0.055),material("apron",Color("725441"),1,0,"leather"))
			for k in 4: ball(root,Vector3((k-1.5)*0.065,1.37,-0.16),Vector3(0.10,0.18,0.15),hair)
		if kind==-2:
			block(root,Vector3(0,1.08,0.36),Vector3(0.48,0.6,0.28),leather)
			for x in [-0.16,0.16]: block(root,Vector3(x,1.12,0.515),Vector3(0.04,0.51,0.025),edge)
			cylinder(root,Vector3(0,1.82,0),0.30,0.06,leather)
		if kind==-3:
			for k in 4:
				cylinder(root,Vector3(-0.22+k*0.14,0.84,-0.25),0.045,0.16,glow("npcremedy"+str(k),Color("82bda0") if k%2 else Color("b87c6c"),0.3))
			cylinder(root,Vector3(0,0.66,0),0.34,0.86,robes,Vector3.ZERO,true)
		if kind==-4:
			var hand = root.get_node("SwordArm")
			cylinder(hand,Vector3(0,-0.25,0),0.03,0.5,leather)
			block(hand,Vector3(0,-0.02,0),Vector3(0.34,0.17,0.17),armor)
		if kind==-5:
			var hand = root.get_node("ShieldArm")
			block(hand,Vector3(-0.04,-0.39,-0.13),Vector3(0.32,0.09,0.4),material("book",Color("887653"),1,0,"leather"))
			cylinder(root,Vector3(0,0.72,0),0.35,0.93,robes,Vector3.ZERO,true)
	else:
		# Fine edge trim, buckles, rivets, boot straps and segmented mail.
		for side in [-1,1]:
			for k in 4:
				ball(root,Vector3(side*(0.13+k*0.027),1.08+k*0.06,-0.17),Vector3(0.025,0.025,0.025),edge)
			for y in [0.3,0.45]: block(root,Vector3(side*0.13,y,-0.09),Vector3(0.17,0.04,0.04),edge)
		for k in 5: block(root,Vector3((k-2)*0.07,0.74,-0.16),Vector3(0.035,0.25,0.025),edge)
	if kind==0:
		for side in [-1,1]: ball(root,Vector3(side*0.23,1.56,0),Vector3(0.15,0.19,0.15),skin)
		block(root,Vector3(0,1.4,-0.14),Vector3(0.21,0.12,0.11),bone)
	if kind==1:
		for k in 6: ball(root,Vector3(0,0.85+k*0.067,0.11),Vector3(0.12,0.055,0.09),bone)
		for side in [-1,1]: ball(root,Vector3(side*0.087,1.6,-0.19),Vector3(0.032,0.038,0.03),glow("skeleton_eyes",Color("db9852"),1.0))
	if kind==3:
		if game.chapter==1:
			var frog = material("frogskin",Color("719366"),0.8,0,"scales")
			ball(root,Vector3(0,1.58,-0.07),Vector3(0.7,0.42,0.58),frog)
			for side in [-1,1]: ball(root,Vector3(side*0.23,1.77,-0.14),Vector3(0.18,0.16,0.16),glow("frogeyes",Color("d5b164"),0.2))
		elif game.chapter==2:
			for side in [-1,1]: cylinder(root,Vector3(side*0.35,1.51,0),0.11,0.6,glow("icearmor",Color("8cc7d2"),0.5),Vector3(0,0,-side*0.5),true)
		elif game.chapter>=3:
			for side in [-1,1]:
				beam(root,Vector3(side*0.2,1.16,0.12),Vector3(side*0.75,1.6,0.4),0.08,leather)
				beam(root,Vector3(side*0.75,1.6,0.4),Vector3(side*0.93,0.86,0.4),0.065,leather)
			cylinder(root,Vector3(0,1.0,0),0.33,0.8,material("royalrobes",Color("633856"),1,0,"runes"),Vector3.ZERO,true)

func spark(p: Vector2,c: Color):
	if fx != null: fx.spawn(v(p,0.75),c,"spark",false,18)
# 贴地圆盘，复用特效层程序化生成的扇形网格。
func disc_mesh() -> ArrayMesh:
	if circle == null and vfx != null: circle = vfx.disc
	return circle
# 加色发光材质，缓存复用；需要单独控制透明度时用 duplicate()。
func aura_mat(key: String,c: Color,alpha: float = 0.5) -> StandardMaterial3D:
	var id = "aura_"+key
	if materials.has(id): return materials[id]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.render_priority = 6
	m.albedo_color = Color(c.r,c.g,c.b,alpha)
	materials[id] = m
	return m
# 命中反馈：白热核心 + 冲击环 + 爆发粒子 + 点光。
func impact(p: Vector2,c: Color,big: float = 1.0):
	if vfx == null or fx == null: return
	var q = v(p,0.0)
	vfx.core(q,0.62*big,0.20,c.lightened(0.45))
	vfx.shockwave(q,0.18*big,1.15*big,0.32,c,0.75)
	vfx.flash(q+Vector3(0,1.0,0),c,2.6*big,5.5*big,0.16)
	fx.spawn(v(p,0.8),c,"burst",false,int(10.0+10.0*big))
# 大范围爆发：双环 + 碎石 + 尘团 + 强光。
func explode(p: Vector2,c: Color,big: float = 1.0):
	if vfx == null or fx == null: return
	var q = v(p,0.0)
	vfx.core(q,1.5*big,0.30,c.lightened(0.40))
	vfx.shockwave(q,0.2,3.4*big,0.55,c,1.1)
	vfx.shockwave(q,0.2,2.1*big,0.35,c.lightened(0.30),0.6)
	vfx.ground(q,2.6*big,1.4,c,true,0.5)
	vfx.shards(q,7,1.7*big,0.85,0.5,c.lightened(0.15))
	vfx.flash(q+Vector3(0,1.2,0),c,6.0*big,10.0*big,0.35)
	fx.spawn(v(p,0.5),c,"burst",false,26)
	fx.spawn(v(p,0.3),c,"dust",false,14)
# 施法蓄能：由外向内收缩的环 + 地光 + 上升光点。
func cast_charge(p: Vector2,c: Color,radius: float,life: float):
	if vfx == null or fx == null: return
	var r = radius/30.0
	vfx.charge(v(p),r*1.35,r*0.25,life,c)
	vfx.ground(v(p),r*0.85,life,c,true,0.35)
	fx.spawn(v(p,0.5),c,"motes",false,12)
# 近战挥砍弧。
func swing_arc(p: Vector2,angle: float,radius: float,c: Color,sweep: float = 2.15):
	if vfx == null: return
	vfx.swing(v(p),angle,radius/30.0,0.26,c,sweep)
func build_shot(n: Node3D,p: Dictionary):
	var c = Color("8ac9df") if p.kind=="icebolt" else (Color("8bbd67") if p.kind=="venom" else (Color("b481ce") if p.hostile else Color("efa761")))
	if p.kind=="arrow":
		block(n,Vector3.ZERO,Vector3(0.025,0.025,0.7),material("arrowshaft",Color("bb9b6e")))
		cylinder(n,Vector3(0,0,-0.39),0.06,0.16,material("arrowtip",Color("c5c8b8"),0.4,0.5),Vector3(PI/2,0,0),true)
		block(n,Vector3(0,0,0.24),Vector3(0.14,0.015,0.14),material("feather",Color("c9c5a5")))
		ball(n,Vector3(0,0,-0.32),Vector3(0.14,0.14,0.22),aura_mat("arrowglow",Color("e0c79c"),0.35))
		fx.trail(n,Color("d9c49a"),14,0.20)
	else:
		ball(n,Vector3.ZERO,Vector3(0.22,0.22,0.35),glow("bolt"+p.kind,c,1.2))
		ball(n,Vector3.ZERO,Vector3(0.44,0.44,0.62),aura_mat("bolthalo"+p.kind,c,0.30))
		fx.trail(n,c,24,0.32)
		if p.kind=="fireball":
			var l = OmniLight3D.new()
			l.light_color = Color("ff9a52"); l.light_energy = 2.4; l.omni_range = 5.0; l.shadow_enabled = false
			n.add_child(l)
func spawn_skill_fx(e: Dictionary):
	var n = Node3D.new(); dynamic.add_child(n)
	n.position = v(e.pos,0.08)
	var torus = TorusMesh.new(); torus.inner_radius = 0.97; torus.outer_radius = 1.0; torus.rings = 48; torus.ring_segments = 4
	var ring_node = emit_mesh(n,torus,glow("skill"+e.color.to_html(),e.color,1.3),Vector3.ZERO); ring_node.name = "Circle"
	var radius = e.radius/30.0
	match e.kind:
		"slash": fx.spawn(v(e.pos,0.7),e.color,"burst",false,14)
		"gust","blink": fx.spawn(v(e.pos,0.6),e.color,"dust",false,10)
		"fire":
			vfx.core(v(e.pos),1.30,0.26,e.color.lightened(0.40))
			vfx.shockwave(v(e.pos),0.20,radius*1.25,0.36,e.color,0.9)
			vfx.ground(v(e.pos),radius*0.90,1.10,Color("5a3122"),false,0.55)
			vfx.flash(v(e.pos,1.0),e.color,5.0,9.0,0.30)
			fx.spawn(v(e.pos,0.4),e.color,"burst",false,24)
			fx.spawn(v(e.pos,0.3),e.color,"ember",false,14)
		"ice":
			for k in 12:
				var a = k*TAU/12
				cylinder(n,Vector3(cos(a)*0.8,0.1,sin(a)*0.8),0.07,0.5,glow("ice_fx",e.color,0.8),Vector3(0,0,0),true)
			vfx.shards(v(e.pos),14,radius*0.80,1.15,0.85,e.color)
			vfx.shockwave(v(e.pos),0.30,radius*1.20,0.55,e.color,0.8)
			vfx.ground(v(e.pos),radius*0.95,1.20,e.color,true,0.5)
			vfx.flash(v(e.pos,1.0),e.color,3.4,8.0,0.35)
			fx.spawn(v(e.pos,0.4),e.color,"frost",false,28)
		"slam":
			vfx.shockwave(v(e.pos),0.25,radius*1.50,0.60,Color("e6c489"),1.2)
			vfx.shockwave(v(e.pos),0.20,radius*1.00,0.40,Color("f4e0bb"),0.7)
			vfx.shards(v(e.pos),9,radius*0.70,1.00,0.55,Color("8d7c62"))
			vfx.ground(v(e.pos),radius*1.10,1.30,Color("6d5a41"),false,0.6)
			vfx.flash(v(e.pos,1.0),e.color,5.0,9.0,0.30)
			fx.spawn(v(e.pos,0.3),Color("c8b391"),"dust",false,22)
		"meteor":
			var m = ball(n,Vector3(0,7,0),Vector3(0.7,1.0,0.7),glow("meteor",Color("ef9861"),2)); m.name = "Meteor"
			var halo = ball(n,Vector3(0,7,0),Vector3(1.5,2.2,1.5),aura_mat("meteorhalo",Color("f2a366"),0.30)); halo.name = "MeteorGlow"
			vfx.pillar(v(e.pos),radius*0.55,0.50,1.15,Color("c77f45"))
			vfx.charge(v(e.pos),radius*1.10,radius*0.20,1.15,Color("e08a4a"))
			fx.spawn(v(e.pos,0.4),Color("dd8a4c"),"ember",true,18)
			fx.spawn(v(e.pos,0.2),Color("9a6a48"),"smoke",true,8)
		"rain":
			for k in 18:
				var a = k*2.4
				block(n,Vector3(cos(a)*0.8,1+(k%5)*0.4,sin(a)*0.8),Vector3(0.014,0.45,0.014),glow("rain_fx",e.color,0.6))
			fx.attach(n,e.color,"spark",14)
		"whirlwind":
			for k in 3:
				var blade = emit_mesh(n,vfx.arc,aura_mat("whirl",e.color,0.42),Vector3(0,0.35+k*0.35,0),Vector3(0.9,1.0,0.9),Vector3(0,k*TAU/3,0))
				blade.name = "Blade%d" % k
			var spin = fx.attach(n,e.color,"spark",18)
			spin.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			spin.emission_ring_radius = 0.8; spin.emission_ring_height = 0.5; spin.emission_ring_axis = Vector3(0,1,0)
			spin.gravity = Vector3(0,1.2,0); spin.initial_velocity_max = 1.2
		"danger":
			var fill = emit_mesh(n,disc_mesh(),aura_mat("dangerfill",e.color,0.22),Vector3(0,0.03,0),Vector3.ONE,Vector3(-PI/2,0,0))
			fill.name = "Fill"; fill.scale = Vector3(0.001,1.0,0.001)
			var rm = aura_mat("dangerring",e.color,0.55).duplicate() as StandardMaterial3D
			ring_node.material_override = rm
			n.set_meta("ring_mat",rm)
			fx.spawn(v(e.pos,0.25),e.color,"motes",false,10)
		_: fx.spawn(v(e.pos,0.3),e.color,"spark",false,36)
	skill_models[e.id] = n
func update_skill_fx(e: Dictionary):
	var n = skill_models[e.id]
	n.position = v(e.pos,0.08)
	var progress = 1.0-e.life/e.maxlife
	var radius = e.radius/30.0
	n.scale = Vector3(radius,1,radius)
	if e.kind in ["ice","slam","fire","blink","gust","slash"]: n.scale *= maxf(0.1,progress)
	n.rotation.y = tick*4 if e.kind=="whirlwind" else 0
	match e.kind:
		"meteor":
			var m = n.get_node_or_null("Meteor")
			if m != null: m.position.y = 7.0*(1-progress); m.scale = Vector3(0.7/radius,1.0,0.7/radius)
			var g = n.get_node_or_null("MeteorGlow")
			if g != null: g.position.y = 7.0*(1-progress); g.scale = Vector3(1.5/radius,2.2,1.5/radius)
		"rain":
			for child in n.get_children():
				if child.name!="Circle" and child is MeshInstance3D: child.position.y = fposmod(child.position.y-0.22,3)
		"danger":
			var f = n.get_node_or_null("Fill")
			if f != null: f.scale = Vector3(maxf(0.001,progress),1.0,maxf(0.001,progress))
			var rm = n.get_meta("ring_mat",null)
			if rm != null:
				var blink = 0.35+0.45*absf(sin(tick*(7.0+14.0*progress)))
				rm.albedo_color = Color(e.color.r,e.color.g,e.color.b,blink)
		"whirlwind":
			for child in n.get_children():
				if child.name.begins_with("Blade"): child.rotation.y = tick*9.0
func sync_combat_fx():
	var live_shots = {}
	for p in game.projectiles:
		live_shots[p.id] = true
		if not shot_models.has(p.id):
			var n = Node3D.new(); dynamic.add_child(n)
			build_shot(n,p)
			shot_models[p.id] = n
		var node = shot_models[p.id]
		node.position = v(p.pos,1.05); node.rotation.y = atan2(-p.dir.x,-p.dir.y)
	for id in shot_models.keys():
		if not live_shots.has(id): shot_models[id].queue_free(); shot_models.erase(id)
	var live_effects = {}
	for e in game.effects:
		live_effects[e.id] = true
		if not skill_models.has(e.id): spawn_skill_fx(e)
		update_skill_fx(e)
	for id in skill_models.keys():
		if not live_effects.has(id): skill_models[id].queue_free(); skill_models.erase(id)

# 主角专属发光件：法杖顶端宝珠随蓄力变亮，剑刃在挥砍瞬间亮起。
# 必须在 detailer.bake 之后添加，避免被按材质合并掉。
func attach_hero_fx(root: Node3D):
	var staff = root.get_node_or_null("SwordArm/Elbow/Staff")
	if staff != null:
		var orb = ball(staff,Vector3(0,0.95,-0.13),Vector3(0.30,0.30,0.30),glow("castorb",Color("a9d4f2"),2.6))
		orb.name = "CastOrb"
		# ball() 的 scale 承载尺寸，必须按比例缩放而不是整体覆盖。
		orb.set_meta("base",orb.scale)
		orb.scale = orb.scale*0.001
		root.set_meta("cast_orb",orb)
	var sword = root.get_node_or_null("SwordArm/Sword")
	if sword != null:
		var edge = block(sword,Vector3(0,0.66,0),Vector3(0.13,0.86,0.06),aura_mat("bladeglow",Color("ffe0b0"),0.55))
		edge.name = "BladeGlow"
		edge.set_meta("base",edge.scale)
		edge.scale = edge.scale*0.001
		root.set_meta("blade_glow",edge)
func update_hero_glow(dt: float):
	if hero == null: return
	var orb = hero.get_meta("cast_orb",null) if hero.has_meta("cast_orb") else null
	if orb != null and is_instance_valid(orb):
		var c = clampf(game.cast/0.45,0.0,1.0)
		orb.scale = orb.scale.lerp(orb.get_meta("base")*(0.001+1.30*c*c),1.0-exp(-dt*16.0))
	var glow_edge = hero.get_meta("blade_glow",null) if hero.has_meta("blade_glow") else null
	if glow_edge != null and is_instance_valid(glow_edge):
		var k = clampf(game.slash/0.30,0.0,1.0)
		glow_edge.scale = glow_edge.scale.lerp(glow_edge.get_meta("base")*(0.001+1.35*k),1.0-exp(-dt*22.0))
func add_enemy_model(e: Dictionary):
	visual_id += 1; e.visual_id = visual_id
	var model = character(3 if e.boss else int(e.type))
	dynamic.add_child(model)
	model.position = v(e.pos)
	if e.boss:
		model.scale = Vector3.ONE*1.8
		var crown = material("bosscrown",Color("bba06d"),0.5,0.7,"metal")
		for k in 7:
			var a = k*TAU/7
			cylinder(model,Vector3(cos(a)*0.21,1.89,sin(a)*0.21),0.04,0.28,crown,Vector3.ZERO,true)
		var banner = material("bosscape"+str(game.chapter),[Color("675a49"),Color("596f43"),Color("697f99"),Color("8c3e31"),Color("633777")][game.chapter],1,0,"runes")
		if model.has_node("Cape"):
			for mesh in model.get_node("Cape").get_children(): mesh.material_override = banner
	elif e.get("elite",false):
		model.scale = Vector3.ONE*1.23
		var torus = TorusMesh.new(); torus.inner_radius = 0.49; torus.outer_radius = 0.53; torus.rings = 24; torus.ring_segments = 4
		emit_mesh(model,torus,glow("eliteaura",Color("a99bd5"),0.5),Vector3(0,0.05,0))
		for x in [-0.35,0.35]: cylinder(model,Vector3(x,1.35,0),0.06,0.32,glow("eliteshard",Color("9b8ebf"),0.4),Vector3(0,0,x),true)
	actors[visual_id] = model
func creature(kind: int) -> Node3D:
	var root = Node3D.new()
	var shell = material("creature_v6_"+str(kind)+str(game.chapter),Color("766856") if kind==4 else Color("666b60").lerp(Color(game.Data.CHAPTERS[game.chapter].color),0.15),0.92,0,"fur" if kind==4 else "chitin")
	var bone = material("bone",Color("b6b09a"),0.95,0,"bone")
	var eyes = glow("beasteyes",Color("d99a59"),0.5)
	for name in ["LeftLeg","RightLeg","SwordArm"]: motion.pivot(root,name,Vector3.ZERO)
	var head = motion.pivot(root,"Head",Vector3(0,0.86,-0.49) if kind==4 else Vector3(0,0.45,-0.43))
	if kind==4:
		ball(root,Vector3(0,0.70,0.05),Vector3(0.49,0.53,1.0),shell)
		ball(root,Vector3(0,0.75,-0.25),Vector3(0.57,0.66,0.49),shell)
		ball(root,Vector3(0,0.69,0.43),Vector3(0.44,0.49,0.43),shell)
		ball(head,Vector3(0,0.06,-0.02),Vector3(0.37,0.36,0.46),shell)
		ball(head,Vector3(0,-0.03,-0.29),Vector3(0.23,0.18,0.39),shell)
		ball(head,Vector3(0,-0.015,-0.47),Vector3(0.18,0.10,0.11),material("nose",Color("262a29"),0.8))
		var jaw = motion.pivot(root,"Jaw",Vector3(0,0.72,-0.61))
		ball(jaw,Vector3(0,0,-0.17),Vector3(0.20,0.075,0.40),shell)
		for side in [-1,1]:
			cylinder(head,Vector3(side*0.13,0.29,0.03),0.105,0.29,shell,Vector3(-0.2,0,side*0.15),true)
			ball(head,Vector3(side*0.145,0.11,-0.18),Vector3(0.060,0.038,0.04),eyes)
			for z in [-0.14,-0.27]: cylinder(jaw,Vector3(side*0.085,0.07,z),0.018,0.09,bone,Vector3.ZERO,true)
			for k in 2:
				var leg = motion.pivot(root,"Leg_%d_%d" % [side,k],Vector3(side*0.20,0.69,-0.28 if k==0 else 0.43))
				var joint = Vector3(side*0.025,-0.30,0.06 if k==0 else -0.17)
				ball(leg,Vector3(0,-0.08,0),Vector3(0.18,0.35,0.22),shell)
				beam(leg,Vector3.ZERO,joint,0.095,shell)
				var knee = motion.pivot(leg,"Knee",joint)
				var foot = Vector3(0,-0.32,-0.06 if k==0 else 0.12)
				beam(knee,Vector3.ZERO,foot,0.065,shell)
				ball(knee,foot+Vector3(0,0,-0.045),Vector3(0.15,0.12,0.24),shell)
				for toe in 3: ball(knee,foot+Vector3((toe-1)*0.045,-0.025,-0.14),Vector3(0.022,0.025,0.055),bone)
		var tail = motion.pivot(root,"Tail",Vector3(0,0.73,0.63))
		beam(tail,Vector3.ZERO,Vector3(0,-0.17,0.47),0.13,shell)
		beam(tail,Vector3(0,-0.17,0.47),Vector3(0,-0.30,0.65),0.075,shell)
	else:
		ball(root,Vector3(0,0.52,0.23),Vector3(0.83,0.66,1.05),shell)
		ball(head,Vector3.ZERO,Vector3(0.48,0.36,0.50),shell)
		for side in [-1,1]:
			for k in 4:
				var a = Vector3(side*0.3,0.48,k*0.23-0.32)
				var b = Vector3(side*(0.76+sin(k)*0.15),0.72,k*0.4-0.55)
				var c = Vector3(side*1.02,0.06,k*0.46-0.55)
				var leg = motion.pivot(root,"Leg_%d_%d" % [side,k],a)
				beam(leg,Vector3.ZERO,b-a,0.055,shell); ball(leg,b-a,Vector3.ONE*0.075,shell)
				var knee = motion.pivot(leg,"Knee",b-a)
				beam(knee,Vector3.ZERO,c-b,0.037,shell)
			for k in 3: ball(head,Vector3(side*(0.06+k*0.07),0.09,-0.21),Vector3(0.055,0.055,0.035),eyes)
		var jaw = motion.pivot(root,"Jaw",Vector3(0,0.32,-0.62))
		for side in [-1,1]: cylinder(jaw,Vector3(side*0.14,-0.025,-0.06),0.045,0.22,bone,Vector3(0.5,0,side*0.3),true)
	detailer.creature(root,kind)
	motion.rig(root,kind)
	detailer.bake(root)
	return root

func sync_pet(dt: float):
	var pets = game.pets
	if pets == null or pet_ring == null: return
	if pet_ring.get_parent() == null: dynamic.add_child(pet_ring)
	var p = pets.active_pet()
	if p == null or bool(p.get("resting", false)):
		if pet_model != null: pet_model.visible = false
		pet_ring.visible = false
		return
	var species = int(p.species)
	if pet_model == null or pet_species != species:
		if pet_model != null: pet_model.free()
		var info = pets.spec(p)
		pet_model = companion(int(info.form), Color(str(info.color)))
		dynamic.add_child(pet_model)
		pet_species = species
	pet_model.visible = true
	pet_model.position = v(pets.pos)
	motion.update(pet_model, dt, pets.moving)
	if int(pets.spec(p).form) in PET_FLYING: pet_model.position.y += 0.30 + sin(tick*3.2)*0.07
	pet_model.rotation.y = lerp_angle(pet_model.rotation.y, atan2(-pets.facing.x, -pets.facing.y), minf(1.0, dt*12.0))
	pet_model.scale = Vector3.ONE*0.62
	# 阵亡：倒地 + 头顶复活进度环，30 秒读条结束后自动站起。
	var dead = not bool(p.alive)
	pet_ring.visible = dead
	if dead:
		var k = 1.0 - clampf(float(p.revive)/30.0, 0.0, 1.0)
		pet_ring.position = v(pets.pos, 1.15)
		pet_ring.scale = Vector3.ONE*(0.55 + k*0.55 + sin(tick*5.0)*0.04)
		pet_ring.rotation.y = tick*1.6
func animate_pet(action: String,duration: float = 0.5):
	if pet_model != null and is_instance_valid(pet_model): motion.play(pet_model, action, duration)
func companion(form: int,tint: Color) -> Node3D:
	var root = Node3D.new()
	var key = str(form)+tint.to_html(false)
	var body = material("petbody"+key,tint,0.85,0.05,"fur")
	var dark = material("petdark"+key,tint.darkened(0.42),0.9,0.0,"fur")
	var light = material("petlight"+key,tint.lightened(0.26),0.75,0.0,"fur")
	var trim = material("pettrim"+key,Color("cbb98d"),0.5,0.6,"copper")
	var eyes = glow("peteye"+key,Color("e6bdf5") if form==8 else Color("f6e3ba"),0.9)
	var head: Node3D = null
	var tail: Node3D = null
	if form in [0,1,3,7,9]:
		for side in [-1,1]:
			for k in 2:
				var leg = motion.pivot(root,"Leg_%d_%d" % [side,k],Vector3(side*0.16,0.30,-0.19+k*0.36))
				beam(leg,Vector3.ZERO,Vector3(0,-0.19,0),0.062,body)
				ball(leg,Vector3(0,-0.22,-0.03),Vector3(0.13,0.10,0.17),dark)
	match form:
		0:
			ball(root,Vector3(0,0.34,0.02),Vector3(0.38,0.33,0.56),body)
			head = motion.pivot(root,"Head",Vector3(0,0.38,-0.32))
			ball(head,Vector3.ZERO,Vector3(0.31,0.29,0.33),body)
			ball(head,Vector3(0,-0.04,-0.21),Vector3(0.17,0.13,0.20),light)
			ball(head,Vector3(0,-0.10,-0.29),Vector3(0.06,0.05,0.05),dark)
			for side in [-1,1]:
				ball(head,Vector3(side*0.16,0.17,-0.01),Vector3(0.21,0.21,0.05),dark)
				ball(head,Vector3(side*0.16,0.17,0.02),Vector3(0.13,0.13,0.04),light)
				ball(head,Vector3(side*0.10,0.02,-0.18),Vector3(0.055,0.055,0.04),eyes)
			tail = motion.pivot(root,"Tail",Vector3(0,0.36,0.30))
			beam(tail,Vector3.ZERO,Vector3(0,0.03,0.40),0.030,dark)
		1:
			ball(root,Vector3(0,0.40,0.03),Vector3(0.46,0.40,0.68),body)
			head = motion.pivot(root,"Head",Vector3(0,0.52,-0.40))
			ball(head,Vector3.ZERO,Vector3(0.36,0.34,0.38),body)
			ball(head,Vector3(0,-0.05,-0.24),Vector3(0.20,0.15,0.24),light)
			ball(head,Vector3(0,-0.11,-0.34),Vector3(0.08,0.06,0.06),dark)
			for side in [-1,1]:
				cylinder(head,Vector3(side*0.15,0.24,0.02),0.08,0.20,dark,Vector3(0,0,side*0.22),true)
				ball(head,Vector3(side*0.11,0.04,-0.19),Vector3(0.06,0.06,0.04),eyes)
			motion.pivot(root,"Jaw",Vector3(0,0.44,-0.55))
			var jaw = root.get_node("Jaw")
			ball(jaw,Vector3(0,0,-0.11),Vector3(0.17,0.07,0.26),dark)
			tail = motion.pivot(root,"Tail",Vector3(0,0.50,0.36))
			beam(tail,Vector3.ZERO,Vector3(0,0.20,0.18),0.06,body)
			beam(tail,Vector3(0,0.20,0.18),Vector3(0,0.30,0.06),0.045,light)
		2:
			ball(root,Vector3(0,0.52,0),Vector3(0.28,0.30,0.52),body)
			ball(root,Vector3(0,0.46,0.22),Vector3(0.24,0.24,0.24),light)
			head = motion.pivot(root,"Head",Vector3(0,0.62,-0.28))
			ball(head,Vector3.ZERO,Vector3(0.24,0.24,0.24),body)
			for side in [-1,1]:
				ball(head,Vector3(side*0.09,0.02,-0.13),Vector3(0.09,0.09,0.05),eyes)
				beam(head,Vector3(side*0.06,0.18,-0.02),Vector3(side*0.17,0.42,-0.18),0.014,dark)
				var wing = motion.pivot(root,"WingL" if side<0 else "WingR",Vector3(side*0.10,0.58,0.02))
				block(wing,Vector3(side*0.34,0.02,0.04),Vector3(0.68,0.03,0.44),light)
				block(wing,Vector3(side*0.26,-0.02,0.24),Vector3(0.48,0.03,0.30),body)
			root.set_meta("wings",true)
		3:
			ball(root,Vector3(0,0.30,0),Vector3(0.66,0.34,0.78),dark)
			ball(root,Vector3(0,0.44,-0.02),Vector3(0.78,0.42,0.86),body)
			for k in 6:
				var a = k*TAU/6.0
				block(root,Vector3(cos(a)*0.21,0.61,sin(a)*0.27),Vector3(0.17,0.05,0.21),light)
			block(root,Vector3(0,0.63,0),Vector3(0.30,0.06,0.34),light)
			head = motion.pivot(root,"Head",Vector3(0,0.38,-0.46))
			ball(head,Vector3.ZERO,Vector3(0.26,0.24,0.30),body)
			ball(head,Vector3(0,-0.03,-0.20),Vector3(0.15,0.12,0.16),light)
			for side in [-1,1]: ball(head,Vector3(side*0.08,0.03,-0.12),Vector3(0.05,0.05,0.035),eyes)
			tail = motion.pivot(root,"Tail",Vector3(0,0.30,0.44))
			ball(tail,Vector3(0,-0.02,0.08),Vector3(0.10,0.08,0.20),body)
		4:
			ball(root,Vector3(0,0.52,-0.02),Vector3(0.34,0.38,0.60),body)
			ball(root,Vector3(0,0.60,0.22),Vector3(0.30,0.30,0.30),light)
			head = motion.pivot(root,"Head",Vector3(0,0.76,-0.26))
			ball(head,Vector3.ZERO,Vector3(0.26,0.26,0.28),body)
			cylinder(head,Vector3(0,-0.02,-0.25),0.05,0.24,trim,Vector3(PI/2,0,0),true)
			for side in [-1,1]:
				ball(head,Vector3(side*0.10,0.04,-0.11),Vector3(0.07,0.07,0.04),eyes)
				var wing = motion.pivot(root,"WingL" if side<0 else "WingR",Vector3(side*0.14,0.58,0.02))
				block(wing,Vector3(side*0.30,-0.02,0.02),Vector3(0.60,0.05,0.40),dark)
				block(wing,Vector3(side*0.34,-0.06,0.22),Vector3(0.44,0.04,0.26),body)
				var leg = motion.pivot(root,"Leg_%d_0" % side,Vector3(side*0.10,0.38,0.02))
				beam(leg,Vector3.ZERO,Vector3(0,-0.18,0),0.035,trim)
				ball(leg,Vector3(0,-0.20,-0.04),Vector3(0.11,0.05,0.16),trim)
			root.set_meta("wings",true)
		5:
			ball(root,Vector3(0,0.22,0.02),Vector3(0.88,0.30,0.88),dark)
			ball(root,Vector3(0,0.34,0),Vector3(0.74,0.58,0.74),body)
			ball(root,Vector3(0,0.50,0),Vector3(0.44,0.34,0.44),light)
			ball(root,Vector3(0,0.34,-0.06),Vector3(0.30,0.24,0.30),glow("petcore"+key,tint.lightened(0.5),1.1))
			head = motion.pivot(root,"Head",Vector3(0,0.44,-0.30))
			for side in [-1,1]: ball(head,Vector3(side*0.11,0.02,-0.06),Vector3(0.09,0.11,0.05),eyes)
			for k in 4:
				var a = k*TAU/4.0+0.4
				ball(root,Vector3(cos(a)*0.30,0.09,sin(a)*0.30),Vector3(0.17,0.15,0.17),body)
			tail = motion.pivot(root,"Tail",Vector3(0,0.56,0.22))
			ball(tail,Vector3(0,0.10,0),Vector3(0.14,0.24,0.14),light)
		6:
			block(root,Vector3(0,0.30,0),Vector3(0.56,0.44,0.40),body)
			block(root,Vector3(0,0.66,0),Vector3(0.46,0.30,0.34),body)
			block(root,Vector3(0,0.44,-0.21),Vector3(0.30,0.06,0.04),trim)
			block(root,Vector3(0,0.30,-0.21),Vector3(0.36,0.06,0.04),trim)
			head = motion.pivot(root,"Head",Vector3(0,0.94,0))
			block(head,Vector3.ZERO,Vector3(0.36,0.32,0.34),body)
			block(head,Vector3(0,0.02,-0.18),Vector3(0.26,0.06,0.03),trim)
			for side in [-1,1]:
				ball(head,Vector3(side*0.09,0.04,-0.16),Vector3(0.07,0.05,0.03),glow("petrune"+key,Color("9fd8e8"),1.2))
				block(root,Vector3(side*0.34,0.62,0),Vector3(0.16,0.34,0.30),body)
				block(root,Vector3(side*0.34,0.62,-0.16),Vector3(0.10,0.06,0.03),trim)
				var leg = motion.pivot(root,"Leg_%d_0" % side,Vector3(side*0.16,0.16,0))
				block(leg,Vector3(0,-0.08,0),Vector3(0.17,0.24,0.20),dark)
		7:
			ball(root,Vector3(0,0.38,0.02),Vector3(0.40,0.36,0.66),body)
			head = motion.pivot(root,"Head",Vector3(0,0.50,-0.40))
			ball(head,Vector3.ZERO,Vector3(0.32,0.30,0.34),body)
			ball(head,Vector3(0,-0.06,-0.24),Vector3(0.16,0.13,0.22),light)
			ball(head,Vector3(0,-0.10,-0.33),Vector3(0.06,0.05,0.05),dark)
			for side in [-1,1]:
				cylinder(head,Vector3(side*0.14,0.24,0.02),0.07,0.26,body,Vector3(0,0,side*0.16),true)
				ball(head,Vector3(side*0.14,0.24,0.04),Vector3(0.04,0.16,0.03),light)
				ball(head,Vector3(side*0.10,0.04,-0.19),Vector3(0.065,0.06,0.04),eyes)
			tail = motion.pivot(root,"Tail",Vector3(0,0.46,0.34))
			beam(tail,Vector3.ZERO,Vector3(0,0.10,0.30),0.13,body)
			beam(tail,Vector3(0,0.10,0.30),Vector3(0,0.16,0.52),0.09,light)
			ball(tail,Vector3(0,0.18,0.56),Vector3(0.16,0.16,0.16),light)
			ball(root,Vector3(0,0.74,0.02),Vector3(0.16,0.20,0.16),glow("petflame"+key,Color("8fc8f0"),1.5))
		8:
			ball(root,Vector3(0,0.62,0),Vector3(0.52,0.52,0.52),body)
			ball(root,Vector3(0,0.62,-0.24),Vector3(0.34,0.34,0.12),light)
			ball(root,Vector3(0,0.62,-0.31),Vector3(0.18,0.18,0.08),glow("petiris"+key,Color("c99ae8"),1.3))
			ball(root,Vector3(0,0.62,-0.35),Vector3(0.09,0.13,0.05),dark)
			head = motion.pivot(root,"Head",Vector3(0,0.62,0))
			for k in 5:
				var a = k*TAU/5.0
				beam(head,Vector3(cos(a)*0.16,-0.17,sin(a)*0.16),Vector3(cos(a)*0.24,-0.46,sin(a)*0.24),0.035,dark)
			var halo = TorusMesh.new(); halo.inner_radius = 0.35; halo.outer_radius = 0.39; halo.rings = 22; halo.ring_segments = 4
			emit_mesh(root,halo,glow("pethalo"+key,Color("b79ae0"),0.9),Vector3(0,0.62,0))
		9:
			ball(root,Vector3(0,0.42,0.04),Vector3(0.44,0.40,0.68),body)
			cylinder(root,Vector3(0,0.60,-0.30),0.13,0.36,body,Vector3(0.5,0,0))
			head = motion.pivot(root,"Head",Vector3(0,0.74,-0.48))
			ball(head,Vector3.ZERO,Vector3(0.30,0.28,0.36),body)
			ball(head,Vector3(0,-0.04,-0.26),Vector3(0.18,0.14,0.22),light)
			for side in [-1,1]:
				cylinder(head,Vector3(side*0.12,0.20,0.06),0.045,0.24,trim,Vector3(-0.3,0,side*0.5),true)
				ball(head,Vector3(side*0.10,0.04,-0.18),Vector3(0.065,0.06,0.04),eyes)
				var wing = motion.pivot(root,"WingL" if side<0 else "WingR",Vector3(side*0.18,0.58,0.04))
				block(wing,Vector3(side*0.36,0.06,0.02),Vector3(0.72,0.04,0.46),light)
				block(wing,Vector3(side*0.34,0.02,0.24),Vector3(0.52,0.04,0.30),body)
			for k in 4: block(root,Vector3(0,0.66-k*0.02,0.10+k*0.14),Vector3(0.10,0.14,0.06),trim)
			tail = motion.pivot(root,"Tail",Vector3(0,0.40,0.38))
			beam(tail,Vector3.ZERO,Vector3(0,0.02,0.34),0.09,body)
			beam(tail,Vector3(0,0.02,0.34),Vector3(0,0.06,0.60),0.05,light)
			root.set_meta("wings",true)
	motion.rig(root,4)
	detailer.bake(root)
	return root
func profile(parent: Node3D,p: Vector3,rings: Array,mat: Material):
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count = 24
	rings = rings.duplicate()
	rings.push_front([rings[0][0],0.0,0.0]); rings.append([rings[-1][0],0.0,0.0])
	for y in rings.size()-1:
		for k in count:
			for pair in [[y,k],[y+1,k+1],[y+1,k],[y,k],[y,k+1],[y+1,k+1]]:
				var r = rings[pair[0]]; var angle = float(pair[1])*TAU/count
				st.set_uv(Vector2(float(pair[1])/count,float(pair[0])/(rings.size()-1)))
				st.add_vertex(Vector3(cos(angle)*r[1],r[0],sin(angle)*r[2]))
	st.generate_normals(); st.generate_tangents(); st.index()
	return emit_mesh(parent,st.commit(),mat,p)

func animate_hero(action: String,duration: float = 0.5):
	if hero != null and hero.has_meta("authored"):
		hero.set_meta("action",action)
		update_model_animation(hero,0.0,false,action)
	else: motion.play(hero,action,duration)
func animate_enemy(e: Dictionary,action: String,duration: float = 0.5):
	if e.has("visual_id") and actors.has(e.visual_id): motion.play(actors[e.visual_id],action,duration)

func preview(kind: int) -> Texture2D:
	if preview_viewport==null:
		preview_viewport = SubViewport.new(); preview_viewport.size = Vector2i(320,400); preview_viewport.own_world_3d = true
		preview_viewport.transparent_bg = true; preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		add_child(preview_viewport)
		var root = Node3D.new(); preview_viewport.add_child(root)
		var cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.55
		root.add_child(cam); cam.position = Vector3(3,2.0,-5); cam.look_at(Vector3(0,0.98,0))
		var lamp = DirectionalLight3D.new(); lamp.rotation_degrees = Vector3(-35,-25,0); lamp.light_energy = 1.4; root.add_child(lamp)
		var lamp2 = DirectionalLight3D.new(); lamp2.rotation_degrees = Vector3(-25,125,0); lamp2.light_energy = 0.8; lamp2.light_color = Color("91a4c4"); root.add_child(lamp2)
		var env_node = WorldEnvironment.new(); var env = Environment.new(); env.background_mode = Environment.BG_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("a4b5b9"); env.ambient_light_energy = 0.5
		env_node.environment = env; root.add_child(env_node)
	if preview_kind!=kind:
		if preview_subject!=null: preview_subject.free()
		preview_subject = character(kind); preview_viewport.get_child(0).add_child(preview_subject)
		preview_subject.rotation.y = 0.3
		preview_clock = 0
		preview_kind = kind
	return preview_viewport.get_texture()

func activity_models():
	for site in game.activities.sites:
		var p = v(site.pos)
		var stone = material("altarstone",Color("8a8b85"),0.9,0,"marble")
		var bronze = material("altarbronze",Color("a89972"),0.6,0.5,"copper")
		var cloth = material("altarrunes",Color("9babbe") if site.kind=="blessing" else Color("ba9386"),0.8,0,"runes")
		cylinder(scenery,p+Vector3(0,0.1,0),0.78,0.2,stone)
		cylinder(scenery,p+Vector3(0,0.32,0),0.58,0.3,stone)
		block(scenery,p+Vector3(0,0.56,0),Vector3(0.72,0.23,0.72),cloth)
		for k in 4:
			var a = k*TAU/4
			cylinder(scenery,p+Vector3(cos(a)*0.55,0.6,sin(a)*0.55),0.05,0.8,bronze)
		var color = Color("9bc4b3") if site.kind=="blessing" else Color("c98666")
		ball(dynamic,p+Vector3(0,1.15,0),Vector3(0.25,0.45,0.25),glow("altar"+site.kind,color,0.6))
		fx.spawn(p+Vector3(0,0.8,0),color,"motes",true,14)
