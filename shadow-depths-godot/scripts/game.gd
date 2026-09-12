extends Node2D

const Data = preload("res://scripts/content.gd")
const ORIGIN = Vector2(264,168)
const TILE = 30
var W = 30
var H = 20
const GOLD = Color("d4ae72")
const TEXT = Color("dcd8c9")
const MUTED = Color("7f898b")
const SAVE = "user://embers_save.json"
var panel_texture: Texture2D
var font: SystemFont
var rng = RandomNumberGenerator.new()
var chapter = 0
var stage = 0
var cycle = 0
var level = 1
var xp = 0
var gold = 0
var hp = 100.0
var potions = 5
var player = Vector2(135,285)
var facing = Vector2.RIGHT
var tiles: Array = []
var enemies: Array = []
var drops: Array = []
var chests: Array = []
var particles: Array = []
var floats: Array = []
var inventory: Array = []
var equipped: Array = [{"name":"旧铁剑", "power":4,"crit":3,"rarity":0}, {"name":"旅人外套", "power":2,"crit":0,"rarity":0}, {"name":"空", "power":0,"crit":0,"rarity":0}]
var seen = {}
var marks = 0
var kills = 0
var time = 0.0
var attack_cd = 0.0
var dash_cd = 0.0
var nova_cd = 0.0
var invincible = 0.0
var slash = 0.0
var cast = 0.0      # 施法蓄力计时，驱动法杖宝珠亮度
var hitstop = 0.0   # 命中卡帧，短暂放慢时间强化打击感
var shake = 0.0
var modal = "class"
var selected = 0
var logs: Array = ["你带着一把旧剑，走进没有黎明的边境。"]
var buttons: Array = []
var portal = Vector2(825,285)
var npc = Vector2(165,225)
var sound: AudioStreamPlayer
var muted = false
var in_town = true
var quest_accepted = false
var hero_class = 0
var mana = 100.0
var ultimate_cd = 0.0
var projectiles: Array = []
var effects: Array = []
var townsfolk: Array = []
var active_npc = 0
var activities
var gallery_index = 0
var combat
var enemy_skills
var pets
var enemy_uid = 0
var player_slow = 0.0
var renderer_3d
var map_seed = 0
var save_path = SAVE
var flow = {}
var flow_clock = 0.0

func _ready():
	rng.randomize()
	activities = preload("res://scripts/activities.gd").new(self)
	combat = preload("res://scripts/combat.gd").new(self)
	enemy_skills = preload("res://scripts/enemy_skills.gd").new(self)
	pets = preload("res://scripts/pets.gd").new(self)
	panel_texture = load("res://assets/textures/stone.png")
	font = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Heiti SC", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	sound = AudioStreamPlayer.new()
	add_child(sound)
	generate_map()
	hp = max_hp()
	if DisplayServer.get_name() != "headless":
		renderer_3d = preload("res://scripts/world_3d.gd").new()
		add_child(renderer_3d)
		renderer_3d.setup(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func depth() -> int: return cycle * 15 + chapter * 3 + stage + 1
func max_hp() -> float: return float(Data.CLASSES[hero_class].hp) + (level - 1) * 12 + int(equipped[1].power) * 3
func damage() -> int: return int((12 + level * 2 + int(equipped[0].power))*(1.25 if activities!=null and activities.buff_time>0 else 1.0))
func outdoor() -> bool: return in_town or Data.CHAPTERS[chapter].outside[stage]
func location_name() -> String: return Data.TOWNS[chapter] if in_town else Data.CHAPTERS[chapter].maps[stage]
func ready_exit() -> bool: return quest_accepted if in_town else marks >= 3 and enemies.is_empty()
func note(s: String):
	logs.push_front(s)
	if logs.size() > 4: logs.pop_back()
func tone(freq: float, duration: float = 0.08):
	if muted: return
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes = PackedByteArray()
	for i in range(int(22050 * duration)):
		var v = int(sin(TAU * freq * i / 22050.0) * 5500 * (1.0-i/(22050.0*duration)))
		bytes.append(v & 255)
		bytes.append((v >> 8) & 255)
	wav.data = bytes
	sound.stream = wav
	sound.play()

func generate_map():
	activities.reset_map()
	W = 30 if in_town else 54
	H = 20 if in_town else 36
	map_seed = rng.randi()
	var mr = RandomNumberGenerator.new()
	mr.seed = map_seed
	tiles.clear(); enemies.clear(); drops.clear(); chests.clear(); seen.clear(); particles.clear(); floats.clear()
	marks = 0; kills = 0
	projectiles.clear(); effects.clear(); townsfolk.clear()
	portal = Vector2(825,285)
	npc = Vector2(165,225)
	player = Vector2(135,285)
	if pets != null: pets.reset_position()
	for y in H:
		var row = []
		for x in W: row.append(0)
		tiles.append(row)
	for room in [Rect2i(2,5,7,11),Rect2i(11,2,8,7),Rect2i(11,11,8,7),Rect2i(22,4,6,12),Rect2i(6,8,19,4),Rect2i(14,6,3,10)]:
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x): tiles[y][x] = 1
	if outdoor():
		for y in range(1,H-1):
			for x in range(1,W-1):
				tiles[y][x] = 1
		for footprint in [Rect2i(6,1,4,4),Rect2i(18,1,4,4)]:
			for y in range(footprint.position.y,footprint.end.y):
				for x in range(footprint.position.x,footprint.end.x): tiles[y][x] = 0
	if not in_town:
		# Fifteen rooms and wide connecting corridors create a larger connected adventure.
		for rz in 3:
			for rx in 5:
				var start = Vector2i(2+rx*10,2+rz*10)
				for y in range(start.y,start.y+mr.randi_range(6,8)):
					for x in range(start.x,start.x+mr.randi_range(6,8)): tiles[y][x] = 1
				if rx<4:
					for y in range(start.y+3,start.y+6):
						for x in range(start.x+3,start.x+16): tiles[y][x] = 1
				if rz<2:
					for y in range(start.y+3,start.y+16):
						for x in range(start.x+3,start.x+6): tiles[y][x] = 1
		portal = Vector2((W-3)*30+15,18*30+15)
		for y in range(16,21):
			for x in range(44,W-1): tiles[y][x] = 1
	if outdoor() and not in_town:
		for footprint in [Rect2i(6,1,4,4),Rect2i(18,1,4,4),Rect2i(34,1,4,4),Rect2i(43,28,4,4)]:
			for y in range(footprint.position.y,footprint.end.y):
				for x in range(footprint.position.x,footprint.end.x): tiles[y][x] = 0
	# Extra alcoves vary each dungeon without breaking its guaranteed critical path.
	if not outdoor():
		for extra in range(3+stage):
			var rx = mr.randi_range(9,23)
			var ry = mr.randi_range(4,14)
			for yy in range(ry,mini(ry+4,H-1)):
				for xx in range(rx,mini(rx+4,W-1)): tiles[yy][xx] = 1
	if in_town:
		for y in range(1,H-1):
			for x in range(1,W-1): tiles[y][x] = 1
		for footprint in [Rect2i(6,1,4,4),Rect2i(18,1,4,4),Rect2i(5,14,5,4),Rect2i(18,14,5,4)]:
			for y in range(footprint.position.y,footprint.end.y):
				for x in range(footprint.position.x,footprint.end.x): tiles[y][x] = 0
		for cell in [Vector2i(14,8),Vector2i(15,8),Vector2i(14,9),Vector2i(15,9),Vector2i(10,6),Vector2i(20,10)]: tiles[cell.y][cell.x] = 0
		player = Vector2(435,315)
		portal = Vector2(795,285)
		var positions = [Vector2(465,225),Vector2(375,255),Vector2(570,315),Vector2(330,345),Vector2(465,405),Vector2(555,405)]
		for i in 6: townsfolk.append({"pos":positions[i],"name":Data.NPC_NAMES[i],"role":Data.NPC_ROLES[i],"type":-2-i})
		npc = positions[0]
		if pets != null: pets.reset_position()
		reveal(); update_flow()
		if renderer_3d != null: renderer_3d.rebuild()
		return
	update_flow()
	for p in [Vector2(435,135),Vector2(1035,735),Vector2(1395,465)]:
		drops.append({"pos":p,"kind":"mark"})
	for p in [Vector2(195,405),Vector2(525,195),Vector2(525,465),Vector2(1035,165),Vector2(1395,795),Vector2(735,735)]:
		chests.append({"pos":p,"open":false})
	var kinds = [0,1,2,4,5,6]
	for i in range(22+stage*6):
		var p = Vector2.ZERO
		for attempt in 600:
			p = Vector2(mr.randi_range(9,W-5)*30+15,mr.randi_range(3,H-5)*30+15)
			if walkable(p) and flow.has(Vector2i(p/TILE)) and p.distance_to(player)>210: break
		spawn_enemy(p,kinds[(i+chapter)%kinds.size()],i<4+stage)
	if stage==2: spawn_enemy(portal-Vector2(75,0),3,false,true)
	for y in range(7,11):
		for x in range(24,29): tiles[y][x] = 1
	for y in range(6,11):
		for x in range(3,7): tiles[y][x] = 1
	reveal()
	update_flow()
	if renderer_3d != null: renderer_3d.rebuild()

func spawn_enemy(p: Vector2,kind: int,elite: bool = false,boss: bool = false):
	enemy_uid += 1
	var health = (260.0+depth()*27) if boss else (30.0+depth()*7)*(3.0 if elite else 1.0)
	var affix = Data.ELITE_AFFIXES[rng.randi_range(0,Data.ELITE_AFFIXES.size()-1)] if elite else ""
	var title = Data.CHAPTERS[chapter].boss if boss else Data.MONSTER_NAMES[chapter][kind]
	enemies.append({"uid":enemy_uid,"name":title,"pos":p,"hp":health,"max":health,"type":kind,"cd":1.0,"skill_cd":rng.randf_range(1,3),"boss":boss,"elite":elite,"affix":affix,"hit":0.0})

func walkable(p: Vector2) -> bool:
	var t = Vector2i(p / TILE)
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H and tiles[t.y][t.x] == 1
func move_actor(p: Vector2, delta: Vector2) -> Vector2:
	var q = p + Vector2(delta.x,0)
	if walkable(q+Vector2(9,0)) and walkable(q-Vector2(9,0)) and walkable(q+Vector2(0,9)) and walkable(q-Vector2(0,9)): p.x = q.x
	q = p + Vector2(0,delta.y)
	if walkable(q+Vector2(9,0)) and walkable(q-Vector2(9,0)) and walkable(q+Vector2(0,9)) and walkable(q-Vector2(0,9)): p.y = q.y
	return p
func reveal():
	var t = Vector2i(player / TILE)
	for y in range(maxi(0,t.y-5),mini(H,t.y+6)):
		for x in range(maxi(0,t.x-5),mini(W,t.x+6)): seen[Vector2i(x,y)] = true

func _process(dt):
	if modal != "": queue_redraw(); return
	if hitstop>0: hitstop -= dt; dt *= 0.16
	time += dt
	activities.update(dt)
	mana = minf(100,mana+dt*10)
	cast = maxf(0,cast-dt)
	player_slow = maxf(0,player_slow-dt)
	ultimate_cd = maxf(0,ultimate_cd-dt)
	attack_cd = maxf(0,attack_cd-dt); dash_cd = maxf(0,dash_cd-dt); nova_cd = maxf(0,nova_cd-dt)
	slash = maxf(0,slash-dt); shake = maxf(0,shake-dt)
	for f in floats: f.life -= dt; f.pos.y -= dt*24
	floats = floats.filter(func(f): return f.life > 0)
	for p in particles: p.pos += p.vel*dt; p.life -= dt
	particles = particles.filter(func(p): return p.life > 0)
	if modal != "": queue_redraw(); return
	flow_clock -= dt
	if flow_clock <= 0: update_flow(); flow_clock = 0.4
	invincible = maxf(0,invincible-dt)
	var direction = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
	if renderer_3d != null: direction = renderer_3d.screen_direction(direction)
	if direction != Vector2.ZERO: facing = direction
	player = move_actor(player,direction*float(Data.CLASSES[hero_class].speed)*dt*(0.55 if player_slow>0 else 1.0))
	if not in_town and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mouse_in_world(): attack(false)
	combat.update(dt)
	if pets != null: pets.update(dt)
	reveal()
	for e in enemies.duplicate():
		enemy_skills.update(e,dt)
		e.cd -= dt; e.hit = maxf(0,e.hit-dt)
		e["slow"] = maxf(0,e.get("slow",0.0)-dt)
		e["stun"] = maxf(0,e.get("stun",0.0)-dt)
		if e.stun>0: continue
		var dist = e.pos.distance_to(player)
		if dist < (310 if e.boss else 235):
			if dist > (160 if e.type in [2,6] and not e.boss else 27): e.pos = move_actor(e.pos,enemy_direction(e.pos)*(44+chapter*5 if e.boss else 56+chapter*5)*dt*(0.4 if e.slow>0 else 1.0)*(1.45 if e.get("affix","")=="迅捷" else 1.0))
			if e.type in [2,6] and not e.boss and e.cd<=0 and dist<290:
				e.cd = 1.8
				if renderer_3d!=null: renderer_3d.animate_enemy(e,"attack",0.55)
				combat.shoot(e.pos,e.pos.direction_to(player),"arrow" if e.type==6 else "hex",6+depth(),true)
			if dist < (65 if e.boss else 32) and e.cd <= 0:
				e.cd = 1.3 if e.boss else 1.0
				if renderer_3d!=null: renderer_3d.animate_enemy(e,"attack",0.50)
				if invincible <= 0:
					var hit = maxf(3,9+depth()*2-(int(equipped[1].power)*0.3)) * (1.8 if e.boss else 1)
					# 宠物在附近会替主人挡刀；挡下时玩家不受伤。
					if pets == null or not pets.soak(e,hit):
						hp -= hit; invincible = 0.45; shake = 0.15
						if renderer_3d!=null: renderer_3d.animate_hero("death" if hp<=0 else "hit",0.85 if hp<=0 else 0.26)
						floating(player,"-"+str(int(hit)),Color("e77f75")); tone(100)
						if hp <= 0: hp = 0; modal = "dead"; break
					else: invincible = 0.28
	for i in range(drops.size()-1,-1,-1):
		var d = drops[i]
		if d.pos.distance_to(player) < 25:
			if d.kind == "mark": marks += 1; note("拾取余烬印记 %d / 3" % marks); tone(780)
			elif d.kind == "item":
				if inventory.size() >= 36: continue
				inventory.append(d.item); note("获得："+d.item.name); tone(540)
			else: gold += d.amount
			drops.remove_at(i)
	queue_redraw()

func floating(p: Vector2,s: String,c: Color): floats.append({"pos":p,"text":s,"color":c,"life":1.0})
func burst(p: Vector2,c: Color):
	if renderer_3d != null: renderer_3d.impact(p,c,1.15)
	for i in 14: particles.append({"pos":p,"vel":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(30,120),"color":c,"life":rng.randf_range(0.2,0.5)})
func attack(nova: bool): combat.attack(nova)
func defeat(i: int):
	var e = enemies[i]
	activities.killed(e)
	var elite = e.get("elite",false)
	kills += 1; xp += (15+depth()*3)*(5 if e.boss else (3 if elite else 1))
	if e.boss and pets != null: pets.boss_reward()
	gold += rng.randi_range(5,15)*depth()*(5 if elite or e.boss else 1)
	if rng.randf()<0.65 or elite or e.boss:
		for k in (3 if e.boss else (2 if elite else 1)):
			var item = Data.loot(rng,depth(),elite or e.boss,hero_class)
			if e.boss: item.rarity = 4 if k==0 else maxi(3,int(item.rarity)); item.power += 8
			elif elite: item.power += 3
			drops.append({"pos":e.pos+Vector2(k*7,0),"kind":"item","item":item})
	if e.boss: note(Data.CHAPTERS[chapter].joke+"  首领掉落：传说装备！"); potions += 2
	elif elite: note("击败「"+e.affix+" · "+e.name+"」，获得稀有战利品。")
	enemies.remove_at(i)
	while xp>=level*55:
		xp -= level*55; level += 1; hp = max_hp(); note("等级提升！生命恢复，属性增强。"); tone(880,0.2)
	if enemies.is_empty(): note("区域已清理。收齐印记后，前往东侧传送门。")
func interact():
	if not in_town and activities.interact(): return
	if in_town:
		for i in townsfolk.size():
			if player.distance_to(townsfolk[i].pos)<60:
				active_npc = i; modal = "npc"; return
		if player.distance_to(portal)<65:
			if quest_accepted: leave_town()
			else: note("出城前，先向鸦邮差领取本章委托。")
		return
	for chest in chests:
		if not chest.open and chest.pos.distance_to(player) < 65:
			chest.open = true
			activities.progress("chest")
			drops.append({"pos":chest.pos+Vector2(0,22),"kind":"item","item":Data.loot(rng,depth(),true,hero_class)})
			gold += 20 * depth(); tone(650); note("箱子里不是怪物。今天运气不错。"); return
	if player.distance_to(npc) < 65:
		if gold >= 25: gold -= 25; potions += 1; note("买到药水。邮差：包治不开心，不包治穷。")
		else: note("邮差：25 金一瓶药水。故事免费——"+Data.CHAPTERS[chapter].goal)
		return
	if player.distance_to(portal) < 65:
		if ready_exit(): next_map()
		else: note("传送门：请清理敌人，并收齐 3 枚印记。")
func next_map():
	stage += 1
	if stage >= 3:
		stage = 0; chapter += 1; in_town = true; quest_accepted = false; activities.next_chapter()
		if chapter >= 5: chapter = 0; cycle += 1; modal = "victory"
		else: modal = "story"
	hp = max_hp(); potions += 1
	generate_map(); save_game(); note("抵达「"+location_name()+"」。")
func heal():
	if potions > 0 and hp < max_hp(): potions -= 1; hp = minf(max_hp(),hp+max_hp()*0.6); tone(700); floating(player,"+ 生命",Color("84c39d"))
func dash(): combat.dodge()
func leave_town():
	if not in_town or not quest_accepted: return
	in_town = false; modal = ""; generate_map(); save_game()
	note("离开城镇，进入「"+location_name()+"」。")
func return_town():
	if modal!="" or in_town: return
	in_town = true; hp = max_hp(); mana = 100; generate_map(); save_game()
	note("回到安全城镇。再次出城会从当前地图入口重新探索。")
func choose_class(index: int):
	var first = modal=="class"
	hero_class = clampi(index,0,2)
	if first: equipped[0].name = Data.CLASSES[hero_class].weapon
	hp = max_hp(); mana = 100; nova_cd = 0; ultimate_cd = 0; attack_cd = 0
	modal = "story" if first else ""
	if renderer_3d != null: renderer_3d.rebuild()
	note("你选择了「"+Data.CLASSES[hero_class].name+"」。")
	save_game()

func save_game():
	var f = FileAccess.open(save_path,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version":3,"activities":activities.snapshot(),"pets":pets.snapshot(),"in_town":in_town,"hero_class":hero_class,"quest_accepted":quest_accepted,"chapter":chapter,"stage":stage,"cycle":cycle,"level":level,"xp":xp,"gold":gold,"potions":potions,"inventory":inventory,"equipped":equipped}))
		note("进度已保存 · 继续时从本地图入口出发")
func load_game():
	if not FileAccess.file_exists(save_path): note("还没有存档。"); return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not d is Dictionary or int(d.get("version",0)) not in [1,2,3]: note("存档格式无法读取。"); return
	activities.restore(d.get("activities",{}))
	if pets != null: pets.restore(d.get("pets",{}))
	in_town = bool(d.get("in_town",true)); hero_class = clampi(int(d.get("hero_class",0)),0,2); quest_accepted = bool(d.get("quest_accepted",false)); mana = 100
	chapter = clampi(int(d.chapter),0,4); stage = clampi(int(d.stage),0,2); cycle = maxi(0,int(d.cycle))
	level = maxi(1,int(d.level)); xp = int(d.xp); gold = int(d.gold); potions = int(d.potions)
	inventory = d.inventory; equipped = d.equipped; hp = max_hp(); modal = ""
	generate_map(); note("旅人，欢迎回来。")
func equip_item():
	if inventory.is_empty(): return
	selected = clampi(selected,0,inventory.size()-1)
	var item = inventory[selected]
	var old = equipped[int(item.slot)]
	equipped[int(item.slot)] = item
	inventory.remove_at(selected)
	if old.name != "空":
		old["slot"] = item.slot
		inventory.append(old)
	hp = minf(hp,max_hp()); tone(480)
func sell_item():
	if inventory.is_empty(): return
	var item = inventory[clampi(selected,0,inventory.size()-1)]
	gold += 8 + int(item.power)*3
	inventory.remove_at(clampi(selected,0,inventory.size()-1)); tone(620)

func mouse_in_world() -> bool:
	var p = get_global_mouse_position()
	if modal != "" or p.y<110 or p.y>760: return false
	if p.x<306 and p.y<315: return false
	if p.x>1185 and p.y<305: return false
	return true

func _input(event):
	if modal in ["class","trainer"]:
		if event is InputEventKey and event.pressed:
			if event.physical_keycode in [KEY_1,KEY_2,KEY_3]: choose_class(event.physical_keycode-KEY_1)
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			for b in buttons:
				if b.rect.has_point(get_global_mouse_position()): action(b.id); return
		return
	if renderer_3d != null and event is InputEventMouseButton and event.pressed and modal == "":
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: renderer_3d.zoom(-0.8)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: renderer_3d.zoom(0.8)
	if modal == "dead":
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER: action("retry")
		elif event is InputEventMouseButton and event.pressed:
			for b in buttons:
				if b.id == "retry" and b.rect.has_point(get_global_mouse_position()): action("retry")
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for b in buttons:
			if b.rect.has_point(get_global_mouse_position()): action(b.id); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: modal = "pause" if modal == "" else ""
			KEY_TAB: modal = "" if modal=="automap" else "automap"
			KEY_B: modal = "" if modal=="contracts" else "contracts"
			KEY_N: modal = "" if modal=="gallery" else "gallery"
			KEY_C: modal = "" if modal=="character" else "character"
			KEY_L: modal = "" if modal=="skills" else "skills"
			KEY_V: modal = "" if modal=="quests" else "quests"
			KEY_I: modal = "" if modal == "inventory" else "inventory"
			KEY_M: modal = "" if modal == "map" else "map"
			KEY_P: modal = "" if modal == "pets" else "pets"
			KEY_ENTER:
				if modal == "story" or modal == "victory": modal = ""
			KEY_E:
				if modal == "": interact()
			KEY_Q:
				if modal == "": heal()
			KEY_SPACE:
				if modal == "": dash()
			KEY_J:
				if modal == "": attack(false)
			KEY_R:
				if modal == "": combat.ultimate()
			KEY_T:
				if modal == "": return_town()
			KEY_K:
				if modal == "": attack(true)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and modal == "": attack(true)
func action(id: String):
	if id.begins_with("contract:"): activities.contract_action(int(id.split(":")[1])); return
	if id.begins_with("upgrade:"): activities.upgrade(int(id.split(":")[1])); return
	if id.begins_with("model:"): gallery_index = int(id.split(":")[1]); return
	if id.begins_with("motion:") and renderer_3d!=null:
		renderer_3d.preview_action = id.split(":")[1]; renderer_3d.preview_clock = 0; return
	if id=="turntable" and renderer_3d!=null:
		renderer_3d.preview_turntable = not renderer_3d.preview_turntable; return
	if id.begins_with("class:"): choose_class(int(id.split(":")[1])); return
	if id.begins_with("item:"): selected = int(id.split(":")[1]); return
	if id.begins_with("pet:"): pets.set_active(int(id.split(":")[1])); return
	match id:
		"play":
			if modal == "story": save_game()
			modal = ""
		"gacha":
			if pets != null and pets.gacha(): save_game()
		"pets": modal = "pets"
		"pet_toggle": if pets != null: pets.toggle()
		"pet_release": if pets != null: pets.release()
		"contracts": modal = "contracts"
		"gallery": modal = "gallery"
		"salvage": activities.salvage()
		"inventory": modal = "inventory"
		"character": modal = "character"
		"skills": modal = "skills"
		"quests": modal = "quests"
		"map": modal = "map"
		"pause": modal = "pause"
		"save": save_game()
		"load": load_game()
		"equip": equip_item()
		"sell": sell_item()
		"heal": heal()
		"mute": muted = not muted
		"quality":
			if renderer_3d != null: renderer_3d.set_quality()
		"retry":
			hp = max_hp(); mana = 100; gold = int(gold*0.85); potions = maxi(3,potions); in_town = true; generate_map(); modal = ""
		"accept": quest_accepted = true; modal = ""; save_game(); note("已领取："+Data.CHAPTERS[chapter].goal)
		"rest": hp = max_hp(); mana = 100; modal = ""; note("热汤和床铺都是免费的。好评记得给老板。")
		"buy":
			if gold>=25: gold -= 25; potions += 1; note("购得一瓶药水。")
			else: note("金币不足，需要 25 金。")
		"forge":
			if inventory.size()>=36: note("背包已满，请先出售装备。")
			elif gold>=60*depth():
				gold -= 60*depth(); inventory.append(Data.loot(rng,depth(),true,hero_class)); note("铁匠：保修到你出门。")
			else: note("金币不足。")
		"trainer": modal = "trainer"
		"town": return_town()

func box(r: Rect2,c: Color,border: Color = Color.TRANSPARENT):
	draw_rect(r,c)
	if border.a > 0: draw_rect(r,border,false,1)
func label_at(p: Vector2,s: String,size: int = 16,c: Color = TEXT): draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)
func line(y: float,x: float = 28,width: float = 188): draw_line(Vector2(x,y),Vector2(x+width,y),Color("303537"))
func button(r: Rect2,s: String,id: String,primary: bool = false):
	var hover = r.has_point(get_global_mouse_position())
	box(r,Color("3a3328") if primary else (Color("2a3032") if hover else Color("191e20")),GOLD if primary or hover else Color("394042"))
	draw_line(r.position+Vector2(2,2),r.position+Vector2(r.size.x-2,2),Color("7e6b4c"),1)
	draw_line(r.position+Vector2(2,r.size.y-2),r.end-Vector2(2,2),Color("080a0b"),2)
	for x in [5,r.size.x-5]: draw_circle(r.position+Vector2(x,r.size.y/2),1.5,Color("8a785b"))
	var ts = font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
	label_at(r.position+Vector2((r.size.x-ts.x)/2, r.size.y/2+5),s,15,GOLD if primary else TEXT)
	buttons.append({"rect":r,"id":id})
func bar(r: Rect2,value: float,maximum: float,c: Color):
	box(r,Color("24282a")); box(Rect2(r.position,Vector2(r.size.x*clampf(value/maximum,0,1),r.size.y)),c)
func update_flow():
	flow.clear()
	var start = Vector2i(player / TILE)
	flow[start] = 0
	var queue: Array = [start]
	var idx = 0
	while idx < queue.size():
		var cell = queue[idx]
		idx += 1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next = cell + step
			if not flow.has(next) and walkable(Vector2(next)*TILE+Vector2(15,15)):
				flow[next] = flow[cell]+1
				queue.append(next)
func enemy_direction(p: Vector2) -> Vector2:
	var cell = Vector2i(p / TILE)
	if cell == Vector2i(player / TILE): return p.direction_to(player)
	var best = cell
	for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var next = cell+step
		if flow.get(next,9999) < flow.get(best,9999): best = next
	var target = Vector2(best)*TILE+Vector2(15,15)
	var center = Vector2(cell)*TILE+Vector2(15,15)
	if best.x != cell.x and absf(p.y-center.y)>4: target = center
	if best.y != cell.y and absf(p.x-center.x)>4: target = center
	return p.direction_to(target)

func world_point(p: Vector2,y: float = 1.8) -> Vector2:
	return renderer_3d.project(p,y) if renderer_3d != null else ORIGIN+p
func ornament(p: Vector2,width: float):
	draw_line(p,p+Vector2(width,0),Color("736145"),1)
	for x in [0.0,width]:
		var q = p+Vector2(x,0)
		draw_colored_polygon(PackedVector2Array([q+Vector2(0,-4),q+Vector2(4,0),q+Vector2(0,4),q+Vector2(-4,0)]),GOLD)
func orb(p: Vector2,r: float,ratio: float,c: Color):
	draw_circle(p,r+9,Color("111519"))
	draw_arc(p,r+8,0,TAU,80,Color("6c5c44"),3)
	draw_arc(p,r+4,0,TAU,80,Color("b49b6c"),1)
	draw_circle(p,r,Color("17151a"))
	for yy in range(int(-r),int(r)):
		if yy < r-r*2*ratio: continue
		var half = sqrt(maxf(0,r*r-yy*yy))
		var shade = (float(yy)+r)/(r*2)
		draw_line(p+Vector2(-half,yy),p+Vector2(half,yy),c.lightened(0.13*(1-shade)).darkened(shade*0.5),1)
	draw_arc(p+Vector2(-r*0.17,-r*0.12),r*0.73,3.5,4.8,28,Color(0.8,0.7,0.6,0.19),3)
	draw_circle(p+Vector2(-r*0.36,-r*0.45),r*0.11,Color(0.9,0.8,0.7,0.14))
func _draw():
	if font == null: return
	buttons.clear()
	box(Rect2(0,0,1440,900),Color("12191d"))
	if renderer_3d != null:
		draw_texture_rect(renderer_3d.viewport.get_texture(),Rect2(0,0,1440,900),false)
	# World labels are projected by the same Camera3D used for ground picking.
	for e in enemies:
		if e.hp<e.max or e.boss or e.get("elite",false):
			var p = world_point(e.pos,2.9 if e.boss else 2.05)
			bar(Rect2(p-Vector2(28,0),Vector2(56,4)),e.hp,e.max,Color("ac5c50"))
			if e.boss: label_at(p-Vector2(62,10),Data.CHAPTERS[chapter].boss,15,GOLD)
			elif e.get("elite",false): label_at(p-Vector2(55,10),e.affix+" · "+e.name,13,Color("a8a6df"))
	if pets != null:
		var pet = pets.active_pet()
		if pet != null and not bool(pet.get("resting",false)):
			var pp = world_point(pets.pos,1.7)
			bar(Rect2(pp-Vector2(22,0),Vector2(44,3)),float(pet.hp),pets.max_hp(pet),Color("7ba36f"))
			if not bool(pet.alive): label_at(pp-Vector2(36,6),"复活 %.0f 秒" % float(pet.revive),13,Color("d78f7f"))
	for c in chests:
		if not c.open and player.distance_to(c.pos)<85:
			var p = world_point(c.pos,1.0)
			box(Rect2(p-Vector2(48,22),Vector2(96,29)),Color(0.04,0.055,0.06,0.85),Color("6a593f"))
			label_at(p-Vector2(36,3),"宝箱  [E]",14,GOLD)
	if not in_town and player.distance_to(npc)<140:
		var p = world_point(npc,2.0)
		label_at(p-Vector2(32,3),"鸦邮差",15,GOLD)
		if player.distance_to(npc)<65: label_at(p+Vector2(-60,20),"[E] 药水 · 25 金",13,TEXT)
	if in_town:
		for n in townsfolk:
			if player.distance_to(n.pos)<230:
				var p = world_point(n.pos,2.15)
				label_at(p-Vector2(42,0),n.name,13,GOLD)
				if player.distance_to(n.pos)<60: label_at(p+Vector2(-31,20),"[E] "+n.role,13,TEXT)
	if player.distance_to(portal)<190:
		var p = world_point(portal,3.5)
		label_at(p-Vector2(55,0),("出城冒险 · E" if in_town else "传送门 · E") if ready_exit() else ("先向邮差领取委托" if in_town else "封印尚未解除"),14,GOLD)
	for site in activities.sites:
		if player.distance_to(site.pos)<120:
			var p = world_point(site.pos,2.0)
			label_at(p-Vector2(65,0),site.name+(" · 已使用" if site.used else " [E]"),14,GOLD)
	if activities.buff_time>0: label_at(Vector2(45,315),"祝福 +25% 伤害 · %d 秒" % activities.buff_time,13,Color("aabd8a"))
	for d in drops:
		if player.distance_to(d.pos)<95:
			var p = world_point(d.pos,0.9)
			var c = GOLD if d.kind=="mark" else Color(Data.RARITY_COLORS[int(d.item.rarity)])
			label_at(p-Vector2(24,0),"余烬印记" if d.kind=="mark" else d.item.name,13,c)
	for f in floats: label_at(world_point(f.pos,2.1),f.text,22,f.color)
	for e in enemies:
		if e.boss and player.distance_to(e.pos)<420:
			box(Rect2(470,96,510,58),Color(0.03,0.035,0.04,0.88),Color("796244"))
			label_at(Vector2(487,117),e.name+(" · 狂暴" if e.get("enraged",false) else ""),16,GOLD)
			bar(Rect2(485,126,480,8),e.hp,e.max,Color("8f3933"))
			label_at(Vector2(485,149),"%d / %d    %s / %s" % [e.hp,e.max,Data.BOSS_SKILLS[chapter][0],Data.BOSS_SKILLS[chapter][1]],10,TEXT)
	# Thin top frame, small journal, and a transparent exploration map.
	for i in 100: box(Rect2(0,i,1440,1),Color(0.035,0.045,0.05,(1-i/100.0)*0.9))
	label_at(Vector2(34,46),"烬 下",30,GOLD)
	label_at(Vector2(36,68),"B E L O W   T H E   E M B E R S",9,Color("a29883"))
	label_at(Vector2(504,40),"第 %d 章  /  %s" % [chapter+1,Data.CHAPTERS[chapter].name],15,GOLD)
	label_at(Vector2(504,67),location_name()+"  ·  "+("安全城镇" if in_town else ("地面" if outdoor() else "地下城")),22,TEXT)
	button(Rect2(896,27,60,36),"角色","character")
	button(Rect2(963,27,60,36),"技能","skills")
	button(Rect2(1030,27,60,36),"任务","quests")
	button(Rect2(1100,27,137,36),"世界地图  M","map")
	button(Rect2(1248,27,160,36),"篝火 / 设置  Esc","pause")
	box(Rect2(28,113,268,182),Color(0.055,0.06,0.06,0.78))
	ornament(Vector2(42,116),237)
	label_at(Vector2(45,147),"当前委托",12,Color("a19b8b"))
	label_at(Vector2(45,181),Data.CHAPTERS[chapter].name,23,GOLD)
	label_at(Vector2(45,214),("◇  本章委托              "+("已领取" if quest_accepted else "待领取")) if in_town else "◇  寻回印记                 %d / 3" % marks,14,TEXT)
	label_at(Vector2(45,242),"◇  城镇服务         补给 / 锻造" if in_town else "◇  消灭区域敌人             %d" % enemies.size(),14,TEXT)
	label_at(Vector2(45,275),("出城前可向导师切换职业" if in_town else "清理完毕，前往东侧传送门") if ready_exit() else ("与鸦邮差交谈，领取章节任务" if in_town else "探索遗迹，揭开黑夜的秘密"),12,Color("a19b8b"))
	box(Rect2(28,303,268,132),Color(0.055,0.06,0.06,0.78))
	ornament(Vector2(42,306),237)
	if pets != null and pets.active_pet() != null:
		var hud_pet = pets.active_pet()
		label_at(Vector2(42,336),"伙伴 · "+str(hud_pet.name),15,pets.rarity_color(hud_pet))
		label_at(Vector2(42,358),"Lv.%d · %s · %s" % [int(hud_pet.level),Data.RARITY_NAMES[int(hud_pet.rarity)],("远程" if pets.ranged(hud_pet) else "近战")],12,MUTED)
		bar(Rect2(42,368,238,8),float(hud_pet.hp),pets.max_hp(hud_pet),Color("6f9c6a"))
		label_at(Vector2(42,394),"攻击 %d · 每 %.1f 秒" % [int(pets.power(hud_pet)),pets.rate(hud_pet)],13,TEXT)
		if not bool(hud_pet.alive): label_at(Vector2(42,416),"复活倒计时 %.0f 秒" % float(hud_pet.revive),13,Color("d78f7f"))
		else: label_at(Vector2(42,416),"休息中 · 缓慢恢复" if bool(hud_pet.get("resting",false)) else "出战中",12,MUTED)
	else:
		label_at(Vector2(42,342),"尚未获得伙伴",15,MUTED)
		label_at(Vector2(42,372),"城镇宠物商可以抽卡，",13,TEXT)
		label_at(Vector2(42,392),"每章首领也会掉落。",13,TEXT)
	button(Rect2(42,404,120,26),"伙伴  P","pets")
	box(Rect2(1210,104,198,161),Color(0.045,0.05,0.055,0.70))
	label_at(Vector2(1224,128),"%s · %02d" % [Data.CHAPTERS[chapter].region,depth()],12,GOLD)
	for y in H:
		for x in W:
			if seen.has(Vector2i(x,y)) and tiles[y][x] == 1:
				var p = Vector2(1307,158)+Vector2((float(x)/W-float(y)/H)*82,(float(x)/W+float(y)/H)*43)
				box(Rect2(p,Vector2(3,2)),Color("8d9180"))
	var pt = player/TILE
	draw_circle(Vector2(1307,158)+Vector2((pt.x/W-pt.y/H)*82,(pt.x/W+pt.y/H)*43),3,GOLD)
	# Gothic-inspired bottom belt: red life, blue skill reserve, six engraved slots.
	for i in 125: box(Rect2(0,775+i,1440,1),Color(0.025,0.035,0.04,i/125.0*0.96))
	box(Rect2(330,789,780,97),Color("181b1c"),Color("5d513e"))
	ornament(Vector2(342,790),756)
	orb(Vector2(266,815),56,hp/max_hp(),Color("972f29"))
	orb(Vector2(1174,815),56,mana/100.0,Color("305c86"))
	label_at(Vector2(225,816),"%d / %d" % [hp,max_hp()],15,TEXT)
	label_at(Vector2(240,844),"生命",12,Color("d7b6a0"))
	label_at(Vector2(1151,819),"精 力",17,TEXT)
	label_at(Vector2(1147,844),"%d / 100" % mana,12,Color("adbed0"))
	label_at(Vector2(345,775),"%s   /   LV. %02d" % [Data.CLASSES[hero_class].name,level],13,GOLD)
	label_at(Vector2(884,775),"%d 金币   ·   攻击 %d" % [gold,damage()],13,GOLD)
	var skills = Data.CLASSES[hero_class].skills
	var slots = [["左键 / J",skills[0]],["K · %.1fs" % nova_cd if nova_cd>0 else "右键 / K",skills[1]],["SPACE",skills[3]],["Q","药水 ×%d" % potions],["R · %.1fs" % ultimate_cd if ultimate_cd>0 else "R",skills[2]],["E / T","交互 / 回城"]]
	for i in slots.size():
		var p = Vector2(350+i*97,803)
		box(Rect2(p,Vector2(84,65)),Color("252827"),Color("6e6047"))
		label_at(p+Vector2(9,16),slots[i][0],10,Color("b4aa92"))
		label_at(p+Vector2(12,47),slots[i][1],16,GOLD)
		if i==3: buttons.append({"rect":Rect2(p,Vector2(84,65)),"id":"heal"})
		
	button(Rect2(943,809,146,51),"装备与行囊","inventory")
	bar(Rect2(349,878,741,3),xp,level*55,GOLD)
	label_at(Vector2(28,872),"WASD 移动 · Tab 地图 · T 回城",12,Color("a19b8b"))
	label_at(Vector2(1235,872),"%d / 3  ·  %s" % [stage+1,"深渊 +%d" % cycle if cycle>0 else "剧情远征"],12,Color("a19b8b"))
	if logs.size()>0:
		var s = str(logs[0])
		var width = font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		label_at(Vector2((1440-width)/2,734),s,14,Color("c4bba6"))
	if modal != "": draw_modal()

func draw_modal():
	buttons.clear()
	box(Rect2(0,0,1440,900),Color(0.025,0.035,0.045,0.90))
	rpg_frame(Rect2(280,140,880,620))
	label_at(Vector2(320,181),"B E L O W   T H E   E M B E R S",11,GOLD)
	ornament(Vector2(320,194),790)
	if modal not in ["class","trainer","dead"]:
		for i in 6: button(Rect2(590+i*87,154,81,31),["角色","行囊","技能","任务","委托","图鉴"][i],["character","inventory","skills","quests","contracts","gallery"][i],modal==["character","inventory","skills","quests","contracts","gallery"][i])
	if modal in ["class","trainer"]:
		label_at(Vector2(320,232),"选择你的道路",32,TEXT)
		label_at(Vector2(320,269),"三种职业，三种战斗方式。可在每章城镇的导师处重新选择。",16,MUTED)
		for i in 3:
			var p = Vector2(320+i*267,303)
			var c = Data.CLASSES[i]
			box(Rect2(p,Vector2(248,317)),Color("22292b"),Color(c.color))
			label_at(p+Vector2(19,43),"0%d   %s" % [i+1,c.name],26,Color(c.color))
			label_at(p+Vector2(19,78),c.title,14,GOLD)
			for k in 4: label_at(p+Vector2(19,125+k*34),["左键  ","右键  ","R       ","空格  "][k]+c.skills[k],16,TEXT)
			label_at(p+Vector2(19,277),"生命 %d · 精力自动恢复" % c.hp,13,MUTED)
			button(Rect2(p+Vector2(0,339),Vector2(248,50)),"选择"+c.name+"  ["+str(i+1)+"]","class:"+str(i),hero_class==i)
		if FileAccess.file_exists(save_path): button(Rect2(921,701,192,35),"继续已有存档","load")
		return
	if modal=="npc":
		var n = townsfolk[active_npc]
		label_at(Vector2(320,249),n.name,32,GOLD)
		label_at(Vector2(320,289),Data.TOWNS[chapter]+" / "+n.role,16,MUTED)
		var dialogue = [Data.CHAPTERS[chapter].story,"药水 25 金一瓶。
入口微苦，回味是你还活着的幸福。","稀有装备现打现卖，三围随机。
本店不接受“隔壁骷髅穿起来更帅”作为退货理由。","剑、魔法和弓都可以救世界。
在城镇可以免费切换职业，保留等级和装备。","坐吧，热汤是免费的。
床铺没有跳蚤，它们都去隔壁旅店团建了。","笼子里的家伙都在装睡。
抽一次 %d 金，抽到什么全看命——她们管这叫「缘分经济」。
首领身上会掉更好的，但前提是你活着回来。" % pets.cost()]
		var rows = dialogue[active_npc].split("\n")
		for i in rows.size(): label_at(Vector2(320,356+i*36),rows[i],18,TEXT)
		label_at(Vector2(320,559),"金币 %d   ·   药水 %d   ·   职业 %s" % [gold,potions,Data.CLASSES[hero_class].name],16,GOLD)
		var captions = ["确认委托 / 准备出城","购买药水 · 25 金","锻造稀有装备 · %d 金" % (60*depth()),"选择职业","休息 · 恢复生命与精力","打开宠物笼 · %d 金 / 次" % pets.cost()]
		button(Rect2(320,610,420,54),captions[active_npc],["accept","buy","forge","trainer","rest","pets"][active_npc],true)
		button(Rect2(880,682,233,44),"离开","play")
		return
	if modal == "pets":
		draw_pet_panel()
		return
	if modal == "story" or modal == "victory":
		label_at(Vector2(320,247),"黎明已归来" if modal == "victory" else "第 %d 章  ·  %s" % [chapter+1,Data.CHAPTERS[chapter].name],36,TEXT)
		label_at(Vector2(320,287),"无限深渊已解锁 · 敌人与装备等级持续成长" if modal == "victory" else Data.CHAPTERS[chapter].region+"    /    三张地图，一段荒唐的救赎",16,GOLD)
		line(316,320,790)
		var story = "你敲响晨钟，把黎明退回了人间。\n永夜之王留下差评：这个勇者完全不讲售后流程。\n故事落幕，但深渊不会。下一轮地图和装备会更强。" if modal == "victory" else Data.CHAPTERS[chapter].story
		var rows = story.split("\n")
		for i in rows.size(): label_at(Vector2(320,362+i*36),rows[i],19,TEXT)
		label_at(Vector2(320,505),"本章任务  /  "+Data.CHAPTERS[chapter].goal,17,GOLD)
		label_at(Vector2(320,555),"先在城镇向邮差领取委托、补给整装，再从东侧城门出发。",15,MUTED)
		label_at(Vector2(320,586),"野外收集 3 枚印记并清敌。R 终极技能，T 随时返回本章城镇。",15,MUTED)
		button(Rect2(320,649,270,58),"继续深入  →" if modal == "victory" else "进入城镇  →  Enter","play",true)
		if FileAccess.file_exists(save_path): button(Rect2(614,649,190,58),"读取旅程","load")
	elif modal == "inventory":
		label_at(Vector2(320,242),"装备与行囊",29,GOLD)
		label_at(Vector2(876,239),"%d / 36 格    %d 金" % [inventory.size(),gold],15,TEXT)
		label_at(Vector2(320,286),Data.CLASSES[hero_class].name+"  ·  等级 %d" % level,17,TEXT)
		for i in 3:
			var p = Vector2(320,309+i*97)
			inset(Rect2(p,Vector2(231,81)))
			item_icon(p+Vector2(34,39),i,Color(Data.RARITY_COLORS[int(equipped[i].rarity)]),str(equipped[i].name))
			label_at(p+Vector2(67,25),Data.SLOTS[i],12,MUTED)
			label_at(p+Vector2(67,47),str(equipped[i].name).substr(0,10),13,GOLD)
			label_at(p+Vector2(67,68),"力量 +%d" % equipped[i].power,12,TEXT)
		for i in 36:
			var r = Rect2(579+(i%6)*52,309+int(i/6)*52,49,49)
			inset(r)
			if i<inventory.size():
				var it = inventory[i]
				if i==selected: draw_rect(r,Color("ae915e"),false,2)
				item_icon(r.get_center(),int(it.slot),Color(Data.RARITY_COLORS[int(it.rarity)]),it.name)
				buttons.append({"rect":r,"id":"item:"+str(i)})
		inset(Rect2(912,309,206,311))
		if not inventory.is_empty():
			selected = clampi(selected,0,inventory.size()-1)
			var it = inventory[selected]
			var c = Color(Data.RARITY_COLORS[int(it.rarity)])
			label_at(Vector2(926,339),Data.RARITY_NAMES[int(it.rarity)]+" · "+Data.SLOTS[int(it.slot)],14,c)
			label_at(Vector2(926,371),str(it.name).substr(0,11),16,c)
			if str(it.name).length()>11: label_at(Vector2(926,395),str(it.name).substr(11),15,c)
			ornament(Vector2(929,411),174)
			label_at(Vector2(928,444),"力量  +%d" % it.power,19,TEXT)
			label_at(Vector2(928,477),"暴击词缀  +%d%%" % it.crit,14,Color("92a9dc"))
			var diff = int(it.power)-int(equipped[int(it.slot)].power)
			label_at(Vector2(928,511),"对比当前  %+d 力量" % diff,13,Color("8bab78") if diff>=0 else Color("be8071"))
			label_at(Vector2(928,555),"武器 / 护符：暴击生效",12,MUTED)
			label_at(Vector2(928,580),"护甲：生命与减伤",12,MUTED)
			button(Rect2(579,644,147,44),"装备","equip",true)
			button(Rect2(740,644,147,44),"出售 +%d 金" % (8+int(it.power)*3),"sell")
		else: label_at(Vector2(928,349),"等待新的战利品",14,MUTED)
		button(Rect2(320,644,231,44),"角色属性  C","character")
		button(Rect2(579,703,308,32),"分解为锻造碎片 · 仅城镇","salvage")
		button(Rect2(912,644,206,44),"关闭  I / Esc","play")
	elif modal in ["character","skills","quests","automap","contracts","gallery"]:
		draw_codex_panel()
	elif modal == "map":
		label_at(Vector2(320,236),"五章 · 无昼之路",30,TEXT)
		for i in 5:
			var yy = 288+i*74
			draw_circle(Vector2(338,yy),8,GOLD if i<=chapter else Color("444b50"))
			if i<4: draw_line(Vector2(338,yy+12),Vector2(338,yy+62),Color("444b50"),2)
			label_at(Vector2(366,yy+5),"%02d  %s" % [i+1,Data.CHAPTERS[i].name],18,GOLD if i==chapter else TEXT)
			label_at(Vector2(626,yy+5),Data.TOWNS[i]+" → "+" → ".join(Data.CHAPTERS[i].maps),14,MUTED)
		label_at(Vector2(320,695),"当前：第 %d 章 / 第 %d 张地图。按剧情顺序解锁。" % [chapter+1,stage+1],14,MUTED)
		button(Rect2(933,670,180,48),"返回  M / Esc","play",true)
	elif modal == "dead":
		label_at(Vector2(320,286),"你倒下了。账单没有。",36,TEXT)
		label_at(Vector2(320,356),"鸦邮差会把你送回本章城镇，收取 15% 金币搬运费。",19,MUTED)
		label_at(Vector2(320,397),"装备与等级保留，药水至少补充到 3 瓶。",18,GOLD)
		button(Rect2(320,555,260,58),"再试一次","retry",true)
	else:
		label_at(Vector2(320,259),"在篝火旁歇一会儿",34,TEXT)
		label_at(Vector2(320,303),"游戏已暂停。存档保留装备和章节，读档会重置当前地图。",17,MUTED)
		button(Rect2(320,362,340,54),"继续冒险","play",true)
		button(Rect2(320,434,340,54),"保存旅程","save")
		button(Rect2(320,506,340,54),"读取旅程","load")
		button(Rect2(320,578,340,54),"音效：关闭" if muted else "音效：开启","mute")
		label_at(Vector2(716,399),"烬下 / 铸魂工坊 0.5",22,GOLD)
		label_at(Vector2(716,446),"5 座安全城镇 · 15 张冒险地图",16,TEXT)
		label_at(Vector2(716,480),"三种职业 · 随机装备 · 无限周目",16,TEXT)
		label_at(Vector2(716,514),"正交 3D · 实时阴影 · 像素渲染",15,MUTED)
		button(Rect2(716,566,350,54),"画面精度："+(["精细像素","经典像素","原生细节"][renderer_3d.quality] if renderer_3d != null else "无头测试"),"quality")

func rpg_frame(r: Rect2):
	box(Rect2(r.position-Vector2(10,10),r.size+Vector2(20,20)),Color(0.01,0.015,0.017,0.85))
	if panel_texture!=null: draw_texture_rect(panel_texture,r,true,Color("373737"))
	box(r,Color(0.035,0.04,0.045,0.88),Color("8e7851"))
	for offset in [3,7]: draw_rect(Rect2(r.position+Vector2.ONE*offset,r.size-Vector2.ONE*offset*2),Color("514938"),false,1)
	for corner in [r.position,r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)]:
		draw_circle(corner,10,Color("252522"))
		draw_arc(corner,9,0,TAU,16,Color("b29a68"),2)
		draw_colored_polygon(PackedVector2Array([corner+Vector2(0,-5),corner+Vector2(4,0),corner+Vector2(0,5),corner+Vector2(-4,0)]),Color("84714b"))
func inset(r: Rect2):
	box(r,Color("111518"),Color("57503e"))
	draw_line(r.position+Vector2(1,1),r.position+Vector2(r.size.x-1,1),Color("06090a"),3)
	draw_line(r.position+Vector2(1,r.size.y-1),r.end,Color("6a5e44"),1)
func item_icon(p: Vector2,slot: int,c: Color,title: String = ""):
	var shadow = Color("090c0d")
	if slot==0:
		if "弓" in title or "弩" in title:
			draw_arc(p+Vector2(-7,0),18,-1.1,1.1,14,shadow,5)
			draw_arc(p+Vector2(-7,0),18,-1.1,1.1,14,c,3)
			draw_line(p+Vector2(1,-16),p+Vector2(1,16),Color("baad91"),1)
			draw_line(p+Vector2(-12,0),p+Vector2(19,0),GOLD,2)
		elif "杖" in title or "枝" in title:
			draw_line(p+Vector2(-11,18),p+Vector2(9,-16),shadow,6)
			draw_line(p+Vector2(-11,18),p+Vector2(9,-16),Color("967959"),3)
			draw_colored_polygon(PackedVector2Array([p+Vector2(9,-22),p+Vector2(15,-16),p+Vector2(9,-9),p+Vector2(4,-16)]),c)
		else:
			draw_line(p+Vector2(-12,16),p+Vector2(15,-19),shadow,7)
			draw_line(p+Vector2(-8,11),p+Vector2(15,-19),c,4)
			draw_line(p+Vector2(-13,3),p+Vector2(1,15),GOLD,3)
			draw_line(p+Vector2(-8,11),p+Vector2(-14,19),Color("795b3e"),4)
	elif slot==1:
		var points = PackedVector2Array([p+Vector2(-15,-15),p+Vector2(-7,-20),p+Vector2(0,-12),p+Vector2(7,-20),p+Vector2(15,-15),p+Vector2(12,7),p+Vector2(8,18),p+Vector2(-8,18),p+Vector2(-12,7)])
		draw_colored_polygon(points,c.darkened(0.45))
		draw_polyline(points+PackedVector2Array([points[0]]),c,2)
		draw_line(p+Vector2(0,-10),p+Vector2(0,15),c,2)
		for yy in [-4,2,8]: draw_line(p+Vector2(-9,yy),p+Vector2(9,yy),c.darkened(0.1),1)
	else:
		draw_arc(p+Vector2(0,-7),12,0.1,3.0,18,Color("a89363"),2)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,0),p+Vector2(10,10),p+Vector2(0,23),p+Vector2(-10,10)]),c.darkened(0.4))
		draw_line(p+Vector2(0,2),p+Vector2(7,10),c,2)
		draw_line(p+Vector2(7,10),p+Vector2(0,21),c,2)
func draw_codex_panel():
	var c = Data.CLASSES[hero_class]
	label_at(Vector2(320,242),{"character":"角色属性","skills":"技能秘典","quests":"任务卷宗","automap":"区域探索图","contracts":"悬赏与锻造","gallery":"角色与怪物图鉴"}[modal],29,GOLD)
	button(Rect2(914,681,204,43),"返回冒险  Esc","play")
	if modal in ["contracts","gallery"]:
		draw_expansion_panel()
	elif modal=="automap":
		var scale_size = minf(750.0/W,390.0/H)
		var origin = Vector2(340+(750-W*scale_size)/2,269)
		inset(Rect2(origin-Vector2(8,8),Vector2(W,H)*scale_size+Vector2(16,16)))
		for y in H:
			for x in W:
				if tiles[y][x]==1: box(Rect2(origin+Vector2(x,y)*scale_size,Vector2.ONE*(scale_size-1)),Color("737264") if seen.has(Vector2i(x,y)) else Color("242827"))
		for e in enemies:
			if seen.has(Vector2i(e.pos/TILE)): draw_circle(origin+e.pos/TILE*scale_size,3,Color("b59cdd") if e.get("elite",false) else Color("c66b59"))
		for d in drops:
			if seen.has(Vector2i(d.pos/TILE)): draw_circle(origin+d.pos/TILE*scale_size,2,GOLD)
		draw_circle(origin+portal/TILE*scale_size,4,Color("86c3c4"))
		draw_circle(origin+player/TILE*scale_size,4,GOLD)
		label_at(Vector2(320,693),"金：旅人 / 物品   青：出口   红：敌人   紫：精英",13,TEXT)
		label_at(Vector2(320,722),"Tab 打开 / 关闭；明亮区域已探索，暗色区域未探索。",13,MUTED)
	elif modal=="character":
		inset(Rect2(320,278,290,360))
		label_at(Vector2(344,319),c.name+" · 无名旅人",23,GOLD)
		label_at(Vector2(344,354),c.title,14,MUTED)
		if renderer_3d!=null: draw_texture_rect(renderer_3d.preview([-1,-10,-11][hero_class]),Rect2(330,347,269,285),false)
		var rows = [["等级",str(level)],["生命","%d / %d" % [hp,max_hp()]],["精力","%d / 100" % mana],["基础伤害",str(damage())],["暴击概率","%d%%" % mini(75,8+int(equipped[0].crit)+int(equipped[2].crit))],["移动速度",str(c.speed)],["下级经验","%d / %d" % [xp,level*55]],["金币",str(gold)]]
		for i in rows.size():
			var y = 312+i*40
			if i%2==0: box(Rect2(646,y-23,472,37),Color("1e211f"))
			label_at(Vector2(666,y),rows[i][0],16,MUTED)
			label_at(Vector2(920,y),rows[i][1],17,TEXT)
		button(Rect2(320,681,290,43),"装备与行囊  I","inventory")
		button(Rect2(637,681,240,43),"小宠物  P","pets")
	elif modal=="skills":
		label_at(Vector2(320,278),c.name+" · 技能随角色等级及武器伤害成长",16,MUTED)
		var descriptions = [["前方扇形攻击，命中可暴击。","持续旋转 1.3 秒，打击周围敌人。","震击前方大范围，造成重伤并眩晕。"],["发射火弹，命中后造成范围爆炸。","冻结附近敌人并施加持续减速。","延迟轰击目标地点，造成高额伤害。"],["箭矢可穿透两名敌人。","同时射出五支穿透箭。","在目标区域持续降下减速箭雨。"]][hero_class]
		for i in 3:
			var p = Vector2(320+i*267,306)
			inset(Rect2(p,Vector2(248,300)))
			item_icon(p+Vector2(124,50),0,Color(c.color),["剑","杖","弓"][hero_class])
			label_at(p+Vector2(20,105),c.skills[i],24,GOLD)
			label_at(p+Vector2(20,144),["左键 / J","右键 / K","R"][i],14,TEXT)
			label_at(p+Vector2(20,180),"精力消耗  %d" % [0,25,45][i],14,MUTED)
			label_at(p+Vector2(20,210),["快速普攻","冷却 5 秒","冷却 11 秒"][i],14,MUTED)
			label_at(p+Vector2(20,248),descriptions[i].substr(0,13),14,TEXT)
			label_at(p+Vector2(20,273),descriptions[i].substr(13),14,TEXT)
		label_at(Vector2(320,652),"空格 · "+c.skills[3]+"    精力每秒恢复 10 点；城镇导师可免费切换职业。",16,GOLD)
	else:
		for i in 5:
			var y = 294+i*67
			inset(Rect2(320,y,290,55))
			label_at(Vector2(336,y+24),"第 %d 章 · %s" % [i+1,Data.CHAPTERS[i].name],16,GOLD if chapter==i else TEXT)
			label_at(Vector2(336,y+45),"进行中" if i==chapter else ("已完成" if i<chapter else "尚未抵达"),12,MUTED)
		inset(Rect2(637,294,481,325))
		label_at(Vector2(659,336),Data.CHAPTERS[chapter].goal,22,GOLD)
		label_at(Vector2(659,380),"城镇："+Data.TOWNS[chapter],17,TEXT)
		label_at(Vector2(659,418),"当前："+location_name(),17,TEXT)
		label_at(Vector2(659,456),"委托状态："+("已领取" if quest_accepted else "请与城镇邮差交谈"),16,MUTED)
		label_at(Vector2(659,494),"印记 %d / 3    敌人剩余 %d" % [marks,enemies.size()],16,TEXT)
		label_at(Vector2(659,541),"章节首领："+Data.CHAPTERS[chapter].boss,17,Color("bf9070"))
		label_at(Vector2(659,579),"最终首领必掉传说装备。精英必掉稀有装备。",14,GOLD)

func draw_pet_panel():
	var p = pets.active_pet()
	label_at(Vector2(320,242),"小宠物",29,GOLD)
	label_at(Vector2(876,239),"%d 金   ·   伙伴 %d / 10" % [gold,pets.roster.size()],15,TEXT)
	inset(Rect2(320,278,300,300))
	if p == null:
		label_at(Vector2(344,330),"还没有伙伴",22,GOLD)
		label_at(Vector2(344,368),"在城镇找宠物商抽卡，",14,TEXT)
		label_at(Vector2(344,392),"或者击败每章首领。",14,TEXT)
		label_at(Vector2(344,436),"伙伴会自动索敌、替你挡刀，",13,MUTED)
		label_at(Vector2(344,458),"阵亡后 30 秒自动复活。",13,MUTED)
	else:
		var c = pets.rarity_color(p)
		var info = pets.spec(p)
		draw_circle(Vector2(470,318),26,Color("15191b"))
		draw_arc(Vector2(470,318),26,0,TAU,44,c,2)
		draw_circle(Vector2(470,318),18,c.darkened(0.28))
		var ns = font.get_string_size(str(p.name),HORIZONTAL_ALIGNMENT_LEFT,-1,24)
		label_at(Vector2(470-ns.x/2,378),str(p.name),24,c)
		label_at(Vector2(470-58,400),"Lv.%d · %s" % [int(p.level),Data.RARITY_NAMES[int(p.rarity)]],13,MUTED)
		bar(Rect2(350,414,240,9),float(p.hp),pets.max_hp(p),Color("6f9c6a"))
		label_at(Vector2(350,440),"生命 %d / %d" % [int(p.hp),int(pets.max_hp(p))],13,TEXT)
		label_at(Vector2(350,466),"攻击 %d   ·   每 %.2f 秒出手" % [int(pets.power(p)),pets.rate(p)],13,TEXT)
		label_at(Vector2(350,490),"形态：%s   经验 %d / %d" % [("远程" if pets.ranged(p) else "近战"),int(p.xp),int(p.level)*22],13,TEXT)
		var desc = str(info.desc)
		label_at(Vector2(350,520),desc.substr(0,mini(16,desc.length())),12,MUTED)
		if desc.length()>16: label_at(Vector2(350,538),desc.substr(16),12,MUTED)
		var status = "复活倒计时 %.0f 秒" % float(p.revive) if not bool(p.alive) else ("休息中 · 缓慢恢复" if bool(p.get("resting",false)) else "出战中")
		var sc = Color("d78f7f") if not bool(p.alive) else (MUTED if bool(p.get("resting",false)) else Color("8bab78"))
		label_at(Vector2(350,566),status,14,sc)
	for i in 10:
		var r = Rect2(637+(i%2)*245,278+int(i/2)*62,236,56)
		inset(r)
		if i == pets.active: draw_rect(r,Color("ae915e"),false,2)
		if i < pets.roster.size():
			var q = pets.roster[i]
			label_at(r.position+Vector2(14,26),str(q.name),16,pets.rarity_color(q))
			var st = "出战" if i==pets.active and not bool(q.get("resting",false)) else ("休息" if bool(q.get("resting",false)) else ("复活 %.0fs" % float(q.revive) if not bool(q.alive) else "待命"))
			label_at(r.position+Vector2(14,46),"Lv.%d · %s · %s" % [int(q.level),Data.RARITY_NAMES[int(q.rarity)],st],12,MUTED)
			buttons.append({"rect":r,"id":"pet:"+str(i)})
		else: label_at(r.position+Vector2(14,32),"空笼位",13,Color("4d5457"))
	inset(Rect2(637,592,481,52))
	if pets.result_name != "":
		label_at(Vector2(653,614),"最近获得："+pets.result_name+("（新伙伴）" if pets.result_new else "（进阶 +2 级）"),14,Color(Data.RARITY_COLORS[clampi(pets.result_rarity,0,4)]))
		label_at(Vector2(653,634),"重复物种自动转为进阶；每章首领掉落稀有起步的伙伴。",12,MUTED)
	else:
		label_at(Vector2(653,614),"抽卡 %d 金 / 次 · 重复物种转为进阶" % pets.cost(),14,GOLD)
		label_at(Vector2(653,634),"伙伴自动索敌、替你挡刀，阵亡 30 秒后自动复活。",12,MUTED)
	button(Rect2(320,681,300,43),"抽卡 · %d 金" % pets.cost(),"gacha",true)
	button(Rect2(637,681,232,43),"出战 / 休息","pet_toggle")
	button(Rect2(883,681,235,43),"返回冒险  P / Esc","play")

func draw_expansion_panel():
	if modal=="contracts":
		label_at(Vector2(320,278),"锻造碎片 %d    ·    金币 %d" % [activities.shards,gold],16,TEXT)
		for i in activities.contracts.size():
			var c = activities.contracts[i]
			var p = Vector2(320,302+i*112)
			inset(Rect2(p,Vector2(415,99)))
			label_at(p+Vector2(15,27),c.name,20,GOLD)
			label_at(p+Vector2(15,57),"进度 %d / %d  ·  稀有装备 + 金币 + 5 碎片" % [c.count,c.goal],12,TEXT)
			var caption = "已领取奖励" if c.claimed else ("领取委托" if not c.accepted else ("领取奖励" if c.count>=c.goal else "进行中"))
			button(Rect2(p+Vector2(255,64),Vector2(145,28)),caption,"contract:"+str(i),c.count>=c.goal and not c.claimed)
		label_at(Vector2(775,284),"装备强化 · 最高 +5",18,GOLD)
		for i in 3:
			var p = Vector2(770,302+i*112)
			var it = equipped[i]
			var rank = int(it.get("upgrade",0))
			inset(Rect2(p,Vector2(348,99)))
			item_icon(p+Vector2(30,35),i,GOLD,it.name)
			label_at(p+Vector2(60,29),Data.SLOTS[i]+"  +%d" % rank,18,TEXT)
			label_at(p+Vector2(60,53),"力量 %d → %d" % [it.power,it.power+2+depth()],13,MUTED)
			button(Rect2(p+Vector2(16,66),Vector2(315,26)),"强化 · %d 碎片 / %d 金" % [3+rank*2,25*depth()*(rank+1)],"upgrade:"+str(i))
		label_at(Vector2(320,663),"城镇领取/提交委托和强化；行囊可分解备用装备。每章刷新委托。",14,MUTED)
	else:
		var entries = [[-1,"战士"],[-10,"法师"],[-11,"弓箭手"],[-2,"鸦邮差"],[-3,"药剂师"],[-4,"铁匠"],[-5,"职业导师"],[-6,"旅店老板"],[0,"亡卒"],[1,"骷髅"],[2,"术士"],[4,"猎犬"],[5,"蜘蛛"],[6,"弩手"],[3,"本章最终首领"]]
		gallery_index = clampi(gallery_index,0,entries.size()-1)
		for i in entries.size():
			button(Rect2(320+(i%2)*204,287+int(i/2)*43,194,36),entries[i][1],"model:"+str(i),gallery_index==i)
		inset(Rect2(753,281,365,372))
		if renderer_3d!=null: draw_texture_rect(renderer_3d.preview(int(entries[gallery_index][0])),Rect2(766,289,337,354),false)
		label_at(Vector2(776,635),entries[gallery_index][1],19,GOLD)
		if renderer_3d!=null:
			for i in 8:
				button(Rect2(320+i*97,657,91,29),renderer_3d.motion.LABELS[i],"motion:"+renderer_3d.motion.ACTIONS[i],renderer_3d.preview_action==renderer_3d.motion.ACTIONS[i])
			button(Rect2(320,697,165,29),"转台：开" if renderer_3d.preview_turntable else "转台：关","turntable")
			label_at(Vector2(505,718),"动作循环预览 · 战斗中随攻击、技能、受击事件播放",13,MUTED)
