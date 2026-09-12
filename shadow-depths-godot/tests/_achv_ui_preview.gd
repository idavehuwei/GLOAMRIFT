extends SceneTree
func _initialize(): call_deferred("run")
func shot(path: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false); g.muted = true
	g.save_path = "/tmp/embers-achv-ui.json"
	g.in_town = false; g.chapter = 1; g.stage = 0; g.generate_map()
	var a = g.achv
	a.bump("kills", 63)
	a.hit(455)
	for i in 12: a.chest()
	for i in 18: a.mark()
	a.looted({"name":"余烬之斩骨斧·破晓", "slot":0, "rarity":4, "power":188})
	a.looted({"name":"虚空之龙鳞袍·回声", "slot":1, "rarity":4, "power":164})
	a.looted({"name":"凌晨三点的旧怀表", "slot":2, "rarity":3, "power":92})
	a.looted({"name":"会讲冷笑话的纸箱战甲", "slot":1, "rarity":3, "power":77})
	for i in 4: a.pet_granted(i, 3 + i)
	for c in 5:
		for k in 7:
			if (c + k) % 3 == 0: a.bestiary["%d:%d" % [c, k]] = {"kills": 3 + c + k, "depth": 10 + c * 3}
	a.trophies["0"] = {"count": 2, "depth": 3, "name": g.Data.CHAPTERS[0].boss}
	a.trophies["1"] = {"count": 1, "depth": 6, "name": g.Data.CHAPTERS[1].boss}
	g.modal = "achievements"
	g.achv_tab = 0; g.achv_kind = -1; g.achv_page = 0
	g.queue_redraw()
	await shot("res://tests/_achv_list.png")
	g.achv_kind = 0
	g.queue_redraw()
	await shot("res://tests/_achv_combat.png")
	g.achv_tab = 1; g.coll_tab = 0
	g.queue_redraw()
	await shot("res://tests/_achv_bestiary.png")
	g.coll_tab = 1
	g.queue_redraw()
	await shot("res://tests/_achv_armory.png")
	g.coll_tab = 2
	g.queue_redraw()
	await shot("res://tests/_achv_trophies.png")
	g.coll_tab = 3
	g.queue_redraw()
	await shot("res://tests/_achv_pets.png")
	g.modal = ""
	a.toasts.append({"title": "清道夫", "desc": "累计击败 50 名敌人", "color": Color("c2705f"), "life": 4.0})
	g.queue_redraw()
	await shot("res://tests/_achv_hud.png")
	print("achievement UI previews written")
	g.queue_free(); await process_frame; quit()
