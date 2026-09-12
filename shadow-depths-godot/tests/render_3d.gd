extends SceneTree
var checks = 0
var failures = 0
func check(ok: bool,message: String):
	if not ok: failures += 1; push_error(message)
	checks += 1
func _initialize(): call_deferred("run")
func capture(game,path: String):
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false); game.modal = ""; game.muted = true
	game.save_path = "/tmp/embers-render-save.json"
	var view = game.renderer_3d
	check(view!=null,"3D renderer exists")
	check(view.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Isometric camera is orthographic")
	for p in [Vector2(135,285),Vector2(435,135),Vector2(765,375)]:
		var screen = view.project(p,0.0)
		check(view.ground(screen).distance_to(p)<0.05,"Projected click maps back to world")
	var right = view.screen_direction(Vector2.RIGHT)
	check(view.project(game.player+right*30,0.0).x>view.project(game.player,0.0).x,"D moves screen-right")
	var up = view.screen_direction(Vector2.UP)
	check(view.project(game.player+up*30,0.0).y<view.project(game.player,0.0).y,"W moves screen-up")
	view.zoom(-100); check(view.camera.size==10.0,"Zoom lower bound")
	view.zoom(100); check(view.camera.size==22.0,"Zoom upper bound")
	view.camera.size = 15.0
	for i in 3:
		view.set_quality()
		check(view.post.size==Vector2(view.viewport.size),"Postprocess tracks resolution")
	await capture(game,"res://tests/town.png")
	game.modal = "class"
	await capture(game,"res://tests/classes.png")
	game.modal = ""
	game.in_town = false; game.generate_map()
	await capture(game,"res://tests/gameplay.png")
	for c in 5:
		game.chapter = c; game.in_town = true; game.generate_map()
		check(view.actors.is_empty(),"All chapter towns render without enemies")
		await capture(game,"res://tests/town_%d.png" % (c+1))
	game.in_town = false
	var paths = [Vector2i(0,2),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(4,2)]
	for pair in paths:
		game.chapter = pair.x; game.stage = pair.y; game.generate_map()
		check(view.actors.size()==game.enemies.size(),"Renderer rebuilds all actors")
		check(view.hero.position.distance_to(view.v(game.player))<0.1,"Hero respawns at matching 3D position")
		await capture(game,"res://tests/chapter_%d_%d.png" % [pair.x+1,pair.y+1])
	game.chapter = 0; game.stage = 0; game.generate_map()
	for job in 3:
		game.hero_class = job; game.hp = game.max_hp(); game.generate_map(); game.modal = ""
		game.player = Vector2(435,285); view.update_camera(0,true); view.sync(0.1)
		game.facing = Vector2.RIGHT; game.mana = 100; game.nova_cd = 0; game.ultimate_cd = 0
		game.attack(true); game.combat.ultimate(); game.attack_cd = 0; game.attack(false)
		game.combat.update(0.15)
		view.sync(0.15)
		await capture(game,"res://tests/class_%d.png" % job)
		check(view.skill_models.size()>0,"Class skill has visible 3D effect")
		if job>0: check(view.shot_models.size()>0,"Ranged class has visible projectiles")
	game.hero_class = 0; game.generate_map()
	# Simulate motion, combat animation, drops and removal in the rendered scene.
	game.player += Vector2(15,0); game.slash = 0.15; view.sync(0.016)
	check(view.hero.position.distance_to(view.v(game.player))<0.1,"3D actor follows movement")
	var before = view.actors.size(); game.defeat(0); view.sync(0.016)
	check(view.actors.size()==before-1,"Defeated enemy mesh removed")
	game.chests[0].open = true; view.sync(0.016)
	var lid = view.chest_models[0].get_node("Lid")
	check(lid.rotation.x<0 and lid.rotation.x> -1.0,"Chest begins a gradual opening")
	for frame in 60: view.sync(0.016)
	check(lid.rotation.x< -1.0,"Chest lid reaches the open position")
	game.inventory = [game.Data.loot(game.rng,7,true),game.Data.loot(game.rng,10,true)]
	game.modal = "inventory"
	await capture(game,"res://tests/inventory.png")
	for screen in ["character","skills","quests","automap","map","pause"]:
		game.modal = screen
		await capture(game,"res://tests/panel_"+screen+".png")
	game.modal = "story"
	await capture(game,"res://tests/story.png")
	game.modal = ""; game.slash = 0
	for c in 5:
		game.chapter = c; game.stage = 2; game.in_town = false; game.generate_map()
		var boss = game.enemies.filter(func(e): return e.boss)[0]
		game.player = boss.pos-Vector2(95,0); view.update_camera(0,true)
		boss.skill_cd = 0; game.enemy_skills.update(boss,0.1); view.sync(0.1)
		await capture(game,"res://tests/boss_%d.png" % (c+1))
	var start = Time.get_ticks_msec()
	for i in 90:
		game.queue_redraw()
		await process_frame
	print("PASS:" if failures==0 else "FAIL:"," ",checks," 3D checks; 90 frames in ",Time.get_ticks_msec()-start," ms; draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.queue_free()
	await process_frame
	quit(1 if failures>0 else 0)
