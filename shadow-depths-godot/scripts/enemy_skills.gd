extends RefCounted
var g
func _init(owner_game): g = owner_game
func zone(p: Vector2,radius: float,c: Color,power: float = 1.0):
	var fx = g.combat.effect(p,"danger",radius,1.05,c)
	fx["power"] = power
func update(e: Dictionary,dt: float):
	e["skill_cd"] = e.get("skill_cd",2.5)-dt
	if e.pos.distance_to(g.player)>350 or e.skill_cd>0 or e.get("stun",0)>0: return
	if e.boss:
		var phase = e.hp/e.max<0.5
		if phase and not e.get("enraged",false):
			e.enraged = true; g.note(e.name+"："+g.Data.BOSS_SKILLS[g.chapter][2]); g.burst(e.pos,Color("d78555"))
		e.skill_cd = 2.6 if phase else 4.3
		e["cast"] = int(e.get("cast",0))+1
		if g.renderer_3d!=null: g.renderer_3d.animate_enemy(e,"skill",1.05)
		var c = Color(g.Data.CHAPTERS[g.chapter].color).lightened(0.2)
		match g.chapter:
			0:
				if e.cast%2==0:
					for i in (3 if phase else 2):
						var p = e.pos+Vector2.from_angle(i*TAU/3)*55
						if g.walkable(p) and g.enemies.size()<55: g.spawn_enemy(p,1)
					g.note("守墓人摇响晨钟，骷髅被迫重新上班！")
				else:
					for i in (8 if phase else 5): zone(g.player+Vector2.from_angle(i*TAU/8)*65,48,Color("c5aa7b"))
			1:
				for i in (5 if phase else 3): zone(g.player+Vector2.from_angle(i*2.4)*i*27,55,Color("81b56a"),1.1)
				for i in 5: g.combat.shoot(e.pos,e.pos.direction_to(g.player).rotated((i-2)*0.18),"venom",9+g.depth(),true)
			2:
				if e.cast%2==1:
					for i in 8: zone(g.player+Vector2.from_angle(i*TAU/8)*105,48,Color("85c6df"))
				else:
					for i in (9 if phase else 5): g.combat.shoot(e.pos,e.pos.direction_to(g.player).rotated((i-2)*0.18),"icebolt",10+g.depth(),true)
			3:
				var dir = e.pos.direction_to(g.player)
				for i in 6:
					zone(e.pos+dir*(45+i*35),42,Color("dd8854"),1.2)
					if phase: zone(e.pos+dir*(45+i*35)+dir.orthogonal()*75,38,Color("cf6843"),1.1)
			4:
				var target = g.player+Vector2.from_angle(e.cast*2.4)*130
				if g.walkable(target): g.burst(e.pos,c); e.pos = target; g.burst(e.pos,c)
				for i in (12 if phase else 8): g.combat.shoot(e.pos,Vector2.from_angle(i*TAU/(12 if phase else 8)),"hex",9+g.depth(),true)
				zone(g.player,85,Color("b291d5"),1.3)
	elif e.get("elite",false):
		e.skill_cd = 3.8
		if g.renderer_3d!=null: g.renderer_3d.animate_enemy(e,"skill",0.65)
		match e.affix:
			"烈焰": zone(g.player,55,Color("d89459"),0.75)
			"冰霜": g.combat.shoot(e.pos,e.pos.direction_to(g.player),"icebolt",7+g.depth(),true)
			"雷鸣":
				for i in 3: g.combat.shoot(e.pos,e.pos.direction_to(g.player).rotated((i-1)*0.25),"hex",6+g.depth(),true)
			"吸血": e.hp = minf(e.max,e.hp+e.max*0.05)
			"迅捷":
				for i in 5: e.pos = g.move_actor(e.pos,e.pos.direction_to(g.player)*9)
