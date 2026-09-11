extends SceneTree
# 一次性检查脚本：把各类法术与攻击特效渲染成截图，便于人工核对。
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func step(g,frames: int,dt: float = 0.016):
	for i in frames:
		g.combat.update(dt)
		for e in g.enemies: e.cd = 99
		g.renderer_3d.sync(dt)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true; g.modal = ""
	g.save_path = "/tmp/embers-fx-preview.json"
	g.in_town = false; g.hero_class = 1; g.generate_map()
	g.player = Vector2(300, 300)
	g.renderer_3d.update_camera(0, true)
	for i in 5:
		var p = g.player + Vector2(80 + i * 24, (i - 2) * 22)
		if g.walkable(p): g.spawn_enemy(p, 0)
	step(g, 4)
	# 火焰弹飞行 + 命中爆炸
	g.attack_cd = 0; g.mana = 100; g.facing = Vector2.RIGHT
	g.combat.attack(false)
	step(g, 10)
	await shot("res://tests/_fx_fireball.png")
	step(g, 16)
	await shot("res://tests/_fx_explosion.png")
	# 寒冰新星
	g.nova_cd = 0; g.mana = 100
	g.combat.attack(true)
	step(g, 6)
	await shot("res://tests/_fx_ice.png")
	# 陨星
	g.hero_class = 1; g.ultimate_cd = 0; g.mana = 100
	g.combat.ultimate()
	step(g, 30)
	await shot("res://tests/_fx_meteor_air.png")
	step(g, 46)
	await shot("res://tests/_fx_meteor_hit.png")
	# 战士：挥砍弧 + 裂地
	g.hero_class = 0; g.generate_map(); g.player = Vector2(300, 300)
	g.renderer_3d.update_camera(0, true)
	for i in 5:
		var p = g.player + Vector2(80 + i * 24, (i - 2) * 22)
		if g.walkable(p): g.spawn_enemy(p, 0)
	step(g, 4)
	g.attack_cd = 0; g.combat.attack(false)
	step(g, 8)
	await shot("res://tests/_fx_slash.png")
	g.renderer_3d.swing_arc(g.player + Vector2(40, 0), atan2(-1, 0), 140, Color(1, 0.15, 0.1), 2.15)
	step(g, 3)
	await shot("res://tests/_fx_arc_only.png")
	g.ultimate_cd = 0; g.mana = 100; g.combat.ultimate()
	step(g, 12)
	await shot("res://tests/_fx_slam.png")
	g.nova_cd = 0; g.mana = 100; g.combat.attack(true)
	step(g, 14)
	await shot("res://tests/_fx_whirl.png")
	# 弓箭手：散射 + 箭雨
	g.hero_class = 2; g.generate_map(); g.player = Vector2(300, 300)
	g.renderer_3d.update_camera(0, true)
	for i in 5:
		var p = g.player + Vector2(90 + i * 24, (i - 2) * 22)
		if g.walkable(p): g.spawn_enemy(p, 0)
	step(g, 4)
	g.nova_cd = 0; g.mana = 100; g.combat.attack(true)
	step(g, 8)
	await shot("res://tests/_fx_arrows.png")
	g.ultimate_cd = 0; g.mana = 100; g.combat.ultimate()
	step(g, 30)
	await shot("res://tests/_fx_rain.png")
	print("FX previews written to res://tests/_fx_*.png")
	g.queue_free(); await process_frame; quit()
