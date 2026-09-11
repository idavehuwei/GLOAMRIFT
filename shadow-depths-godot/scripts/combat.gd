extends RefCounted
var g
var next_id = 0
func _init(owner_game): g = owner_game
func aim():
	if g.mouse_in_world() and g.renderer_3d != null:
		var target = g.renderer_3d.ground(g.get_global_mouse_position())
		if target.distance_to(g.player)>2: g.facing = g.player.direction_to(target)
func effect(p: Vector2,kind: String,radius: float,life: float,color: Color) -> Dictionary:
	next_id += 1
	var data = {"id":next_id,"pos":p,"kind":kind,"radius":radius,"life":life,"maxlife":life,"color":color,"tick":0.0}
	g.effects.append(data)
	return data
func shoot(p: Vector2,dir: Vector2,kind: String,power: float,hostile: bool = false,pierce: int = 1):
	next_id += 1
	g.projectiles.append({"id":next_id,"pos":p,"dir":dir.normalized(),"kind":kind,"power":power,"hostile":hostile,"pierce":pierce,"hit":[],"life":2.0,"speed":420.0 if kind=="arrow" else 280.0})
func spend(cost: float) -> bool:
	if g.mana<cost: g.note("精力不足，稍等片刻即可恢复。"); return false
	g.mana -= cost
	return true
func attack(secondary: bool):
	if g.modal!="": return
	if g.in_town: g.note("这里是安全城镇。出城后才能施展战斗技能。"); return
	if secondary and g.nova_cd>0: return
	if not secondary and g.attack_cd>0: return
	if secondary and not spend(25): return
	aim()
	g.slash = 0.30
	g.cast = 0.18 if not secondary else 0.50
	if g.renderer_3d!=null: g.renderer_3d.animate_hero("skill" if secondary else "attack",0.55 if secondary else 0.36)
	if secondary and g.renderer_3d!=null:
		g.renderer_3d.cast_charge(g.player,Color(g.Data.CLASSES[g.hero_class].color),150 if g.hero_class==1 else 120,0.34)
	if secondary: g.nova_cd = 5.0
	else: g.attack_cd = [0.38,0.52,0.33][g.hero_class]
	g.tone([280,640,430][g.hero_class])
	if not secondary:
		match g.hero_class:
			0:
				area(g.player,76,g.damage(),"melee",true)
				effect(g.player,"slash",76,0.25,Color("eac08a"))
				if g.renderer_3d!=null: g.renderer_3d.swing_arc(g.player+g.facing*14,atan2(-g.facing.x,-g.facing.y),92,Color("ffc069"),2.30)
			1:
				shoot(g.player+g.facing*18,g.facing,"fireball",g.damage()*1.2)
				if g.renderer_3d!=null: g.renderer_3d.cast_charge(g.player+g.facing*22,Color("efa761"),46,0.16)
			2:
				shoot(g.player+g.facing*18,g.facing,"arrow",g.damage()*0.90,false,2)
				if g.renderer_3d!=null: g.renderer_3d.impact(g.player+g.facing*24,Color("d9c49a"),0.45)
	else:
		match g.hero_class:
			0: effect(g.player,"whirlwind",120,1.3,Color("e2b477")); g.invincible = 0.6
			1: area(g.player,150,g.damage()*1.7,"freeze"); effect(g.player,"ice",150,0.8,Color("83d3e9"))
			2:
				for i in 5: shoot(g.player+g.facing*20,g.facing.rotated((i-2)*0.16),"arrow",g.damage()*1.05,false,2)
				effect(g.player,"gust",80,0.4,Color("a0c48b"))
func ultimate():
	if g.modal!="" or g.in_town or g.ultimate_cd>0: return
	if not spend(45): return
	aim(); g.ultimate_cd = 11.0; g.slash = 0.4
	g.cast = 0.60
	if g.renderer_3d!=null:
		g.renderer_3d.animate_hero("skill",0.85)
		g.renderer_3d.cast_charge(g.player,Color(g.Data.CLASSES[g.hero_class].color),190,0.45)
	var target = g.player+g.facing*180
	if g.renderer_3d != null and g.mouse_in_world(): target = g.player+ (g.renderer_3d.ground(g.get_global_mouse_position())-g.player).limit_length(240)
	match g.hero_class:
		0: area(g.player+g.facing*60,150,g.damage()*3.5,"stun"); effect(g.player+g.facing*60,"slam",150,0.75,Color("deaa67")); g.shake = 0.3
		1: effect(target,"meteor",110,1.2,Color("ed8f56"))
		2: effect(target,"rain",125,3.0,Color("a5c994"))
	g.tone(180,0.18)
func dodge():
	if g.dash_cd>0 or g.modal!="": return
	g.dash_cd = [2.2,3.5,1.8][g.hero_class]
	g.invincible = 0.45
	if g.renderer_3d!=null: g.renderer_3d.animate_hero("dodge",0.45)
	var start = g.player
	for i in (19 if g.hero_class==1 else 14): g.player = g.move_actor(g.player,g.facing*8)
	var c = Color(g.Data.CLASSES[g.hero_class].color)
	effect(start,"blink" if g.hero_class==1 else "gust",45,0.4,c)
	g.burst(g.player,c)
	if g.hero_class==0 and not g.in_town: area(g.player,65,g.damage()*0.8,"stun")
func hit_enemy(index: int,power: float,status: String = ""):
	if index>=g.enemies.size(): return
	var e = g.enemies[index]
	var crit = g.rng.randi_range(0,99)<mini(75,8+int(g.equipped[0].crit)+int(g.equipped[2].crit))
	var hit = power*(1.65 if crit else 1)
	e.hp -= hit; e.hit = 0.17
	e["knock_dir"] = g.player.direction_to(e.pos) if e.pos.distance_to(g.player)>1 else g.facing
	if g.renderer_3d!=null:
		g.renderer_3d.animate_enemy(e,"hit",0.26)
		g.renderer_3d.impact(e.pos,Color("ffd9a8") if crit else Color("e0a487"),1.35 if crit else 0.85)
	if crit: g.hitstop = 0.075; g.shake = maxf(g.shake,0.20)
	if status=="freeze": e["slow"] = 2.6; e["stun"] = 0.8
	if status=="stun": e["stun"] = 1.2
	if status=="slow": e["slow"] = 1.5
	g.floating(e.pos,str(int(hit))+("!" if crit else ""),g.GOLD if crit else g.TEXT)
	g.burst(e.pos,Color("b9755a"))
	if e.hp<=0: g.defeat(index)
func area(p: Vector2,radius: float,power: float,status: String = "",directional: bool = false):
	for i in range(g.enemies.size()-1,-1,-1):
		var e = g.enemies[i]
		if p.distance_to(e.pos)>radius or not clear_line(p,e.pos): continue
		if directional and g.facing.dot(p.direction_to(e.pos))< -0.15: continue
		hit_enemy(i,power,status)
func clear_line(a: Vector2,b: Vector2) -> bool:
	var steps = maxi(1,int(a.distance_to(b)/9))
	for i in range(1,steps+1):
		if not g.walkable(a.lerp(b,float(i)/steps)): return false
	return true
func hurt_player(power: float):
	if g.invincible>0 or g.in_town: return
	g.hp = maxf(0,g.hp-power); g.invincible = 0.4; g.shake = 0.20; g.hitstop = 0.06
	g.floating(g.player,"-"+str(int(power)),Color("e77f75"))
	if g.renderer_3d!=null:
		g.renderer_3d.animate_hero("death" if g.hp<=0 else "hit",0.85 if g.hp<=0 else 0.26)
		g.renderer_3d.impact(g.player,Color("e77f75"),0.9)
	if g.hp<=0: g.modal = "dead"
func update(dt: float):
	for i in range(g.projectiles.size()-1,-1,-1):
		var p = g.projectiles[i]
		p.life -= dt
		var steps = maxi(1,int(p.speed*dt/8)+1)
		for step in steps:
			p.pos += p.dir*p.speed*dt/steps
			if not g.walkable(p.pos): p.life = 0; break
			if p.hostile:
				if p.pos.distance_to(g.player)<18:
					hurt_player(p.power)
					if p.kind=="icebolt": g.player_slow = 2.0
					p.life = 0; break
			else:
				for j in range(g.enemies.size()-1,-1,-1):
					var e = g.enemies[j]
					var id = e.get("uid",j)
					if p.hit.has(id) or p.pos.distance_to(e.pos)>20: continue
					p.hit.append(id)
					if p.kind=="fireball": area(p.pos,58,p.power); effect(p.pos,"fire",58,0.4,Color("efa66b"))
					else: hit_enemy(j,p.power)
					p.pierce -= 1
					if p.pierce<=0: p.life = 0; break
			if p.life<=0: break
		if p.life<=0: g.projectiles.remove_at(i)
	for i in range(g.effects.size()-1,-1,-1):
		var e = g.effects[i]
		e.life -= dt; e.tick -= dt
		if e.kind=="whirlwind":
			e.pos = g.player
			if e.tick<=0: area(e.pos,e.radius,g.damage()*0.48); e.tick = 0.23
		elif e.kind=="rain" and e.tick<=0:
			area(e.pos,e.radius,g.damage()*0.48,"slow"); e.tick = 0.33
		elif e.kind=="meteor" and e.life<=0:
			area(e.pos,e.radius,g.damage()*4.0,"stun"); g.shake = 0.32; g.hitstop = 0.09
			if g.renderer_3d!=null: g.renderer_3d.explode(e.pos,Color("f4a864"),1.5)
			else: g.burst(e.pos,Color("f4a864"))
		elif e.kind=="danger" and e.life<=0:
			if e.pos.distance_to(g.player)<e.radius: hurt_player((12+g.depth()*2)*e.get("power",1.0))
			if g.renderer_3d!=null: g.renderer_3d.explode(e.pos,Color("b75d75"),0.85)
			else: g.burst(e.pos,Color("b75d75"))
		if e.life<=0: g.effects.remove_at(i)
