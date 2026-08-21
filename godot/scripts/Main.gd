extends Node3D
## 主场景：相机、点击寻路、HUD、NPC 面板。

const SheetFrame := preload("res://scripts/SheetFrame.gd")

@onready var world: Node3D = $World
@onready var actors: Node3D = $Actors
@onready var cam: Camera3D = $CamRig/Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var hud: CanvasLayer = $HUD

var cam_zoom := 1.0
var _skills: Array = []
var _mice: Array = []
var _hold := false
var _hold_r := false
var _log: RichTextLabel
var _hint: Label
var _hp: ProgressBar
var _mp: ProgressBar
var _xp: ProgressBar
var _zone: Label
var _zone_sub: Label
var _pname: Label
var _gold: Label
var _pots: Label
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _dead: ColorRect
var _cine: ColorRect
var _cine_k: Label
var _cine_n: Label
var _cine_d: Label
var _pause: ColorRect
var _pause_meta: Label
var _floats: Node2D
var _track: Label
var _smith_tab := "shop"
var _socket_pick = null
var _sheet := ""
var _stat_tab := "core"
var _talk_id := ""
var _talk_pick := ""
var _quest_sel := ""
var _sk_assign := ""
var _nav: VBoxContainer
var _tip: PanelContainer
var _tip_lab: RichTextLabel
var _target: Label
var _buffs: HBoxContainer
var _cast: ProgressBar
var _hp_lab: Label
var _mp_lab: Label
var _xp_strip: ColorRect
var _xp_fill: ColorRect
var _pot_hp: Button
var _pot_mp: Button
var _hud_root: Control
var _mm: Control
var _mm_wrap: PanelContainer
var _mm_t := 0.0
var _doll_vp: SubViewport
var _doll_root: Node3D
var _doll_model: Node3D
var _doll_id := ""
var _doll_rot := 0.0
var _doll_drag := false
var _doll_auto := true
var _ach_sel := ""
var _ach_toast: PanelContainer
var _ach_toast_n: Label
var _ach_toast_d: Label
var _die_spin := 0.0
var _die_lab: Label
var _die_side := ""
var _combo: Label
var _evt: Label
var _beat: ColorRect
var _sheet_veil: ColorRect
var _nav_btns: Array = []
var _panel_title: Label
var _sk_sel := ""
var _bag_filter := "all"          # 背包分类：all/weapon/gear/rune/charm/scrap
var _last_lvl := 1
var _last_bag_n := 0
var _hp_disp := -1.0              # 平滑血条显示值（<0 表示未初始化）
var _mp_disp := -1.0
var _xp_disp := -1.0


func _ready() -> void:
	WorldState.bind(world, actors)
	_build_hud()
	Game.log_line.connect(_on_log)
	Game.hint_line.connect(_on_hint)
	Game.zone_changed.connect(_on_zone)
	Game.died.connect(_on_dead)
	Game.cine.connect(_on_cine)
	Game.npc_open.connect(open_npc)
	Game.world_ui.connect(_on_world_ui)
	Game.ui_refresh.connect(_refresh_hud)
	Game.floats.connect(_spawn_float)
	AchData.toast_show.connect(_on_ach_toast)
	AchData.toast_hide.connect(func(): _ach_toast.visible = false)
	InvCell.host = self
	_last_lvl = Game.P.lvl
	_last_bag_n = Game.P.bag.size()
	if Game.pending_enter != "":
		var dest := Game.pending_enter
		Game.pending_enter = ""
		WorldState.enter_area(dest)
		if Game.pending_intro:
			Game.pending_intro = false
			Game.maybe_intro_cine()
		Game.save_now()
	_refresh_hud()
	_apply_pal()
	if "--smoke" in OS.get_cmdline_user_args():
		print("SMOKE town=", WorldState.W.area.get("n"), " npcs=", WorldState.W.npcs.size(), " marks=", WorldState.W.marks.size(), " walk=", WorldState.W.grid.count(1))
		var t0 := Time.get_ticks_msec()
		WorldState.enter_area("waste")
		var su_n := 0
		for e in WorldState.W.enemies:
			if e.get("su"):
				su_n += 1
		print("SMOKE waste enemies=", WorldState.W.enemies.size(), " su=", su_n, " blockers=", WorldState.blocked_tiles().size(), " ms=", Time.get_ticks_msec() - t0)
		var set_it := Game.roll_set_item(8)
		var uni := Game.roll_unique("u_hammer", 8, 0)
		Game.ensure_bounties()
		print("SMOKE loot sets=", LootData.SETS.size(), " uniques=", LootData.UNIQUES.size(), " setitem=", set_it.get("name", ""), " unique=", uni.get("name", ""), " bounty=", Game.P.bountyList.size())
		t0 = Time.get_ticks_msec()
		WorldState.enter_dungeon("crypt", 1)
		print("SMOKE crypt enemies=", WorldState.W.enemies.size(), " rooms=", WorldState.W.rooms.size(), " ms=", Time.get_ticks_msec() - t0)
		t0 = Time.get_ticks_msec()
		WorldState.enter_dungeon("crypt", 2)
		var sekhra := 0
		for e in WorldState.W.enemies:
			if e.get("sekhra"):
				sekhra += 1
		print("SMOKE crypt2 sekhra=", sekhra, " ms=", Time.get_ticks_msec() - t0)
		WorldState.enter_rift(5)
		var rb := 0
		for e in WorldState.W.enemies:
			if e.get("boss"):
				rb += 1
		print("SMOKE rift5 enemies=", WorldState.W.enemies.size(), " rooms=", WorldState.W.rooms.size(), " mods=", WorldState.W.get("riftMods", []), " tags=", WorldState.W.get("roomTags", []).size(), " bosses=", rb)
		Game.P.lvl = 10
		Game.P.gold = 9999
		var tals: Array = Data.class_talents(Game.P.cls)
		if tals.size():
			Game.learn_talent(tals[0])
		print("SMOKE tal=", Game.tal_rank(str(tals[0].id) if tals.size() else ""), " pts=", Game.tal_pts(), " affixes=", Data.RIFT_AFFIXES.size(), " shrine=", Data.SHRINE_PICKS.size())
		var rk_n := 0
		var rk_miss := 0
		for sk in Data.SKILLS:
			if Data.SK_RUNES.has(str(sk.id)):
				rk_n += 1
			else:
				rk_miss += 1
		print("SMOKE runes=", rk_n, " miss=", rk_miss, " mouseR=", Game.mouse_skill(1), " white=", Game.show_white_loot())
		print("SMOKE chboss=", Data.ENEMY_ASSET.lord, ",", Data.ENEMY_ASSET.voice, ",", Data.ENEMY_ASSET.kor, " has=", Assets.has("boss_warrok"), Assets.has("boss_caster"), Assets.has("boss_undead"))
		get_tree().quit()


func _exit_tree() -> void:
	if _doll_vp and is_instance_valid(_doll_vp):
		_doll_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_doll_vp.queue_free()
		_doll_vp = null


func _apply_pal() -> void:
	var a: Dictionary = WorldState.W.area
	if a.is_empty():
		return
	var pal: Dictionary = Game.pal_for_diff(a.get("pal", Data.RIFT_PAL))
	var sky := Cfg.hex_color(int(pal.get("sky", 0x06050a)))
	var fogc := Cfg.hex_color(int(pal.get("fog", 0x06050a)))
	var e := env.environment
	e.background_mode = Environment.BG_COLOR
	e.background_color = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.16, 0.15, 0.25)
	e.ambient_light_energy = float(pal.get("amb", 0.6))
	e.fog_enabled = true
	e.fog_density = float(pal.get("dens", 0.02)) * 2.2
	e.fog_light_color = fogc
	sun.light_color = Cfg.hex_color(int(pal.get("sunc", 0x6a7ab0)))
	sun.light_energy = float(pal.get("sun", 0.5))


func _build_hud() -> void:
	var root := Control.new()
	_hud_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.hud_theme()
	hud.add_child(root)
	_floats = Node2D.new()
	root.add_child(_floats)
	var tl := PanelContainer.new()
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_stylebox_override("panel", UiKit.plate())
	tl.position = Vector2(12, 10)
	tl.custom_minimum_size = Vector2(280, 112)
	root.add_child(tl)
	var tlv := VBoxContainer.new()
	tlv.add_theme_constant_override("separation", 3)
	tl.add_child(tlv)
	_pname = _lab(tlv, Vector2.ZERO, 18, UiKit.brass_hi())
	_zone = _lab(tlv, Vector2.ZERO, 13, UiKit.bone())
	_zone_sub = _lab(tlv, Vector2.ZERO, 11, UiKit.ash())
	_gold = _lab(tlv, Vector2.ZERO, 14, UiKit.gold())
	_track = _lab(root, Vector2.ZERO, 12, UiKit.bone())
	_track.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_track.offset_left = -236
	_track.offset_right = -14
	_track.offset_top = 204
	_track.offset_bottom = 300
	_track.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_track.mouse_filter = Control.MOUSE_FILTER_STOP
	_track.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_toggle_sheet("quests")
	)
	_hint = _lab(root, Vector2(0, 0), 14, Color(0.91, 0.81, 0.58))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_bottom = -130
	_hint.offset_top = -160
	_hint.offset_left = -240
	_hint.offset_right = 240
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log = RichTextLabel.new()
	_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log.offset_left = 16
	_log.offset_top = -220
	_log.offset_right = 420
	_log.offset_bottom = -90
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_log)
	var bars := HBoxContainer.new()
	bars.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bars.offset_left = -420
	bars.offset_right = 420
	bars.offset_top = -148
	bars.offset_bottom = -42
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 14)
	root.add_child(bars)
	_hp = _orb(bars, Color(0.85, 0.27, 0.19))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	bars.add_child(mid)
	_hp_lab = Label.new()
	_hp_lab.add_theme_font_size_override("font_size", 11)
	_hp_lab.add_theme_color_override("font_color", UiKit.bone())
	_hp_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_hp_lab)
	_mp_lab = Label.new()
	_mp_lab.add_theme_font_size_override("font_size", 11)
	_mp_lab.add_theme_color_override("font_color", UiKit.bone())
	_mp_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_mp_lab)
	_xp = _bar(mid, Color(0.69, 0.55, 0.31))
	_xp.custom_minimum_size = Vector2(0, 8)
	_mp = _orb(bars, Color(0.22, 0.47, 0.85))
	_pots = _lab(root, Vector2(0, 0), 12, Color(0.7, 0.66, 0.58))
	_pots.visible = false
	_target = _lab(root, Vector2(0, 0), 14, UiKit.brass())
	_target.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target.offset_left = -180
	_target.offset_right = 180
	_target.offset_top = 16
	_target.offset_bottom = 86
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_evt = _lab(root, Vector2(0, 0), 13, Color(0.89, 0.77, 0.5))
	_evt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_evt.offset_left = -220
	_evt.offset_right = 220
	_evt.offset_top = 52
	_evt.offset_bottom = 74
	_evt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo = _lab(root, Vector2(0, 0), 28, Color(0.96, 0.82, 0.42))
	_combo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_combo.offset_left = -80
	_combo.offset_right = 80
	_combo.offset_top = -300
	_combo.offset_bottom = -258
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo.visible = false
	_beat = ColorRect.new()
	_beat.color = Color(0.89, 0.77, 0.5, 0.0)
	_beat.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_beat.offset_bottom = 6
	_beat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_beat)
	_buffs = HBoxContainer.new()
	_buffs.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buffs.offset_left = -240
	_buffs.offset_right = 240
	_buffs.offset_top = -248
	_buffs.offset_bottom = -222
	_buffs.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_buffs)
	_cast = ProgressBar.new()
	_cast.visible = false
	_cast.show_percentage = false
	_cast.custom_minimum_size = Vector2(220, 10)
	_cast.set_anchors_preset(Control.PRESET_CENTER)
	_cast.offset_left = -110
	_cast.offset_right = 110
	_cast.offset_top = 80
	_cast.offset_bottom = 92
	root.add_child(_cast)
	_xp_strip = ColorRect.new()
	_xp_strip.color = Color(0.03, 0.024, 0.016)
	_xp_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_xp_strip.offset_top = -7
	root.add_child(_xp_strip)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.69, 0.55, 0.31)
	_xp_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_xp_fill.offset_right = 0
	_xp_strip.add_child(_xp_fill)
	var skrow := HBoxContainer.new()
	skrow.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skrow.offset_left = -420
	skrow.offset_right = 420
	skrow.offset_top = -218
	skrow.offset_bottom = -154
	skrow.alignment = BoxContainer.ALIGNMENT_CENTER
	skrow.add_theme_constant_override("separation", 6)
	root.add_child(skrow)
	for i in 2:
		var mb := Button.new()
		mb.custom_minimum_size = Vector2(56, 56)
		mb.add_theme_stylebox_override("normal", UiKit.slot())
		mb.add_theme_stylebox_override("hover", UiKit.slot_hover())
		mb.add_theme_stylebox_override("pressed", UiKit.slot_hover())
		mb.add_theme_stylebox_override("disabled", UiKit.cell_empty())
		var which := i
		mb.pressed.connect(func(): Game.try_mouse(which))
		skrow.add_child(mb)
		_mice.append(mb)
	for i in 6:
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		b.add_theme_stylebox_override("normal", UiKit.slot())
		b.add_theme_stylebox_override("hover", UiKit.slot_hover())
		b.add_theme_stylebox_override("pressed", UiKit.slot_hover())
		b.add_theme_stylebox_override("disabled", UiKit.cell_empty())
		b.pressed.connect(func(): Game.try_cast(i))
		skrow.add_child(b)
		_skills.append(b)
	_pot_hp = Button.new()
	_pot_hp.custom_minimum_size = Vector2(56, 56)
	_pot_hp.add_theme_stylebox_override("normal", UiKit.slot())
	_pot_hp.add_theme_stylebox_override("hover", UiKit.slot_hover())
	_pot_hp.pressed.connect(Game.drink_hp)
	skrow.add_child(_pot_hp)
	_pot_mp = Button.new()
	_pot_mp.custom_minimum_size = Vector2(56, 56)
	_pot_mp.add_theme_stylebox_override("normal", UiKit.slot())
	_pot_mp.add_theme_stylebox_override("hover", UiKit.slot_hover())
	_pot_mp.pressed.connect(Game.drink_mp)
	skrow.add_child(_pot_mp)
	_nav = VBoxContainer.new()
	_nav.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_nav.offset_left = 12
	_nav.offset_right = 96
	_nav.offset_top = -520
	_nav.offset_bottom = -160
	_nav.add_theme_constant_override("separation", 4)
	root.add_child(_nav)
	for pair in [["角色", "C", "char", "nav-char"], ["行囊", "I", "bag", "nav-bag"], ["技能", "S", "skills", "nav-skills"], ["天赋", "K", "talents", "nav-talents"], ["委托", "J", "quests", "nav-quests"], ["功绩", "Y", "achs", "nav-achs"]]:
		var nb := Button.new()
		nb.custom_minimum_size = Vector2(80, 52)
		nb.add_theme_font_size_override("font_size", 11)
		nb.add_theme_stylebox_override("normal", UiKit.nav())
		nb.add_theme_stylebox_override("hover", UiKit.nav_on())
		nb.add_theme_stylebox_override("pressed", UiKit.nav_on())
		UiKit.stamp_btn(nb, str(pair[3]), "%s\n%s" % [pair[0], pair[1]], 22)
		nb.set_meta("sheet", str(pair[2]))
		nb.pressed.connect(_toggle_sheet.bind(str(pair[2])))
		_nav.add_child(nb)
		_nav_btns.append(nb)
	_sheet_veil = ColorRect.new()
	_sheet_veil.color = Color(0.012, 0.008, 0.012, 0.72)
	_sheet_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_veil.visible = false
	_sheet_veil.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_sheet()
	)
	root.add_child(_sheet_veil)
	_panel = SheetFrame.new()
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", UiKit.plate())
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 108
	_panel.offset_right = -28
	_panel.offset_top = 28
	_panel.offset_bottom = -168
	root.add_child(_panel)
	var chrome := VBoxContainer.new()
	chrome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chrome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chrome.add_theme_constant_override("separation", 6)
	_panel.add_child(chrome)
	var hdrow := HBoxContainer.new()
	hdrow.alignment = BoxContainer.ALIGNMENT_CENTER
	hdrow.add_theme_constant_override("separation", 12)
	chrome.add_child(hdrow)
	var orn_l := ColorRect.new()
	orn_l.custom_minimum_size = Vector2(72, 1)
	orn_l.color = UiKit.brass()
	orn_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdrow.add_child(orn_l)
	_panel_title = Label.new()
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_title.add_theme_font_size_override("font_size", 16)
	_panel_title.add_theme_color_override("font_color", UiKit.brass_hi())
	hdrow.add_child(_panel_title)
	var orn_r := ColorRect.new()
	orn_r.custom_minimum_size = Vector2(72, 1)
	orn_r.color = UiKit.brass()
	orn_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdrow.add_child(orn_r)
	var xb := Button.new()
	xb.text = "✕"
	xb.custom_minimum_size = Vector2(36, 32)
	xb.add_theme_font_size_override("font_size", 14)
	xb.pressed.connect(_close_sheet)
	hdrow.add_child(xb)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chrome.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(pad)
	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 10)
	pad.add_child(_panel_body)
	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_stylebox_override("panel", UiKit.tip())
	_tip.z_index = 80
	root.add_child(_tip)
	_tip_lab = RichTextLabel.new()
	_tip_lab.bbcode_enabled = true
	_tip_lab.fit_content = true
	_tip_lab.scroll_active = false
	_tip_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lab.custom_minimum_size = Vector2(280, 0)
	_tip_lab.add_theme_font_size_override("normal_font_size", 12)
	_tip_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_lab)
	_dead = ColorRect.new()
	_dead.color = Color(0.02, 0.01, 0.02, 0.82)
	_dead.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dead.visible = false
	root.add_child(_dead)
	var dv := VBoxContainer.new()
	dv.set_anchors_preset(Control.PRESET_CENTER)
	dv.offset_left = -140
	dv.offset_right = 140
	dv.offset_top = -40
	dv.offset_bottom = 40
	_dead.add_child(dv)
	var dl := Label.new()
	dl.text = "你倒下了"
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_font_size_override("font_size", 28)
	dv.add_child(dl)
	var db := Button.new()
	db.text = "在井边醒来"
	db.pressed.connect(func():
		_dead.visible = false
		Game.revive()
		_apply_pal()
	)
	dv.add_child(db)
	_cine = ColorRect.new()
	_cine.color = Color(0.02, 0.01, 0.03, 0.55)
	_cine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cine.visible = false
	_cine.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			Game.end_story()
	)
	root.add_child(_cine)
	var cv := VBoxContainer.new()
	cv.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cv.offset_left = -280
	cv.offset_right = 280
	cv.offset_top = -220
	cv.offset_bottom = -80
	_cine.add_child(cv)
	_cine_k = Label.new()
	_cine_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cine_n = Label.new()
	_cine_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cine_n.add_theme_font_size_override("font_size", 36)
	_cine_n.add_theme_color_override("font_color", Color(0.91, 0.81, 0.58))
	_cine_d = Label.new()
	_cine_d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cine_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_cine_k)
	cv.add_child(_cine_n)
	cv.add_child(_cine_d)
	var skip := Label.new()
	skip.text = "点击继续"
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.add_theme_color_override("font_color", Color(0.4, 0.36, 0.32))
	cv.add_child(skip)
	_pause = ColorRect.new()
	_pause.color = Color(0.012, 0.008, 0.012, 0.78)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)
	var pplate := PanelContainer.new()
	pplate.add_theme_stylebox_override("panel", UiKit.plate())
	pplate.set_anchors_preset(Control.PRESET_CENTER)
	pplate.offset_left = -220
	pplate.offset_right = 220
	pplate.offset_top = -210
	pplate.offset_bottom = 230
	_pause.add_child(pplate)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	pplate.add_child(pv)
	UiKit.header(pv, "暂停")
	_pause_meta = Label.new()
	_pause_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_meta.add_theme_color_override("font_color", UiKit.ash())
	pv.add_child(_pause_meta)
	var resume := Button.new()
	resume.text = "继续"
	resume.pressed.connect(func(): _pause.visible = false)
	pv.add_child(resume)
	var saveb := Button.new()
	saveb.text = "写入卷宗"
	saveb.pressed.connect(func():
		Game.save_now()
		Game.hint("记下了")
	)
	pv.add_child(saveb)
	var expb := Button.new()
	expb.text = "导出卷宗"
	expb.pressed.connect(_export_save)
	pv.add_child(expb)
	var rst := Button.new()
	rst.text = "重新开始"
	rst.pressed.connect(_restart_run)
	pv.add_child(rst)
	var mute := Button.new()
	mute.text = "静音"
	mute.pressed.connect(func():
		var on := Sfx.toggle()
		Game.hint("音效开" if on else "音效关")
	)
	pv.add_child(mute)
	var whiteb := Button.new()
	whiteb.text = "显示普通掉落名"
	whiteb.pressed.connect(func():
		var on := Game.toggle_white_loot()
		Game.hint("普通掉落名开" if on else "普通掉落名关（Alt 仍可看）")
	)
	pv.add_child(whiteb)
	var titleb := Button.new()
	titleb.text = "保存并回标题"
	titleb.pressed.connect(func():
		Game.save_now()
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	)
	pv.add_child(titleb)
	_mm_wrap = PanelContainer.new()
	_mm_wrap.add_theme_stylebox_override("panel", UiKit.plate())
	_mm_wrap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mm_wrap.offset_left = -190
	_mm_wrap.offset_right = -14
	_mm_wrap.offset_top = 14
	_mm_wrap.offset_bottom = 190
	_mm_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_mm_wrap)
	_mm = preload("res://scripts/Minimap.gd").new()
	_mm_wrap.add_child(_mm)
	_ach_toast = PanelContainer.new()
	_ach_toast.visible = false
	_ach_toast.add_theme_stylebox_override("panel", UiKit.plate())
	_ach_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ach_toast.offset_left = -180
	_ach_toast.offset_right = 180
	_ach_toast.offset_top = 92
	_ach_toast.offset_bottom = 168
	_ach_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ach_toast.z_index = 90
	root.add_child(_ach_toast)
	var tv := VBoxContainer.new()
	_ach_toast.add_child(tv)
	var tk := Label.new()
	tk.text = "功绩解锁"
	tk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tk.add_theme_font_size_override("font_size", 10)
	tk.add_theme_color_override("font_color", UiKit.dim())
	tv.add_child(tk)
	_ach_toast_n = Label.new()
	_ach_toast_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ach_toast_n.add_theme_font_size_override("font_size", 20)
	_ach_toast_n.add_theme_color_override("font_color", UiKit.brass())
	tv.add_child(_ach_toast_n)
	_ach_toast_d = Label.new()
	_ach_toast_d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ach_toast_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ach_toast_d.add_theme_font_size_override("font_size", 12)
	_ach_toast_d.add_theme_color_override("font_color", Color(0.66, 0.61, 0.51))
	tv.add_child(_ach_toast_d)
	_setup_doll(root)


func _export_save() -> void:
	var t := Game.export_save_text()
	if t != "":
		DisplayServer.clipboard_set(t)
		Game.hint("已复制到剪贴板")


func _restart_run() -> void:
	Game.start_new(Game.P.name, Game.P.cls)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _lab(parent: Control, pos: Vector2, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _bar(parent: Control, col: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(280, 10)
	p.show_percentage = false
	p.add_theme_stylebox_override("background", UiKit.bar_bg())
	p.add_theme_stylebox_override("fill", UiKit.bar_fill(col))
	parent.add_child(p)
	return p


func _orb(parent: Control, col: Color) -> ProgressBar:
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(108, 108)
	wrap.add_theme_stylebox_override("panel", UiKit.orb_ring())
	parent.add_child(wrap)
	var p := ProgressBar.new()
	p.show_percentage = false
	p.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	p.custom_minimum_size = Vector2(92, 92)
	p.add_theme_stylebox_override("background", UiKit.bar_bg())
	p.add_theme_stylebox_override("fill", UiKit.bar_fill(col))
	wrap.add_child(p)
	return p


func _toggle_sheet(kind: String) -> void:
	if _panel.visible and _sheet == kind:
		_close_sheet()
		return
	_sheet = kind
	match kind:
		"char":
			open_char()
		"bag":
			open_bag()
		"skills":
			open_skills()
		"talents":
			open_talents()
		"quests":
			open_quests()
		"achs":
			open_achs()
		_:
			pass


func _hd(t: String) -> void:
	if _panel_title:
		_panel_title.text = t
	else:
		UiKit.header(_panel_body, t)


func _show_tip(txt: String) -> void:
	_tip_lab.text = txt
	_tip.visible = txt != ""


func _hide_tip() -> void:
	_tip.visible = false


func _wire_tip(c: Control, txt: String) -> void:
	c.mouse_entered.connect(func(): _show_tip(txt))
	c.mouse_exited.connect(_hide_tip)


func _on_ach_toast(a: Dictionary) -> void:
	_ach_toast_n.text = str(a.get("n", ""))
	_ach_toast_d.text = str(a.get("d", ""))
	_ach_toast.visible = true
	EventBus.notify.emit(str(a.get("n", "成就")), str(a.get("d", "")), "ach")


func _tick_minimap(dt: float) -> void:
	_mm_t += dt
	if _mm_t < 0.1:
		return
	_mm_t = 0.0
	if _mm:
		_mm.queue_redraw()


func _setup_doll(root: Control) -> void:
	_doll_vp = SubViewport.new()
	_doll_vp.size = Vector2i(250, 320)
	_doll_vp.transparent_bg = true
	_doll_vp.own_world_3d = true
	_doll_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_doll_vp.msaa_3d = Viewport.MSAA_2X
	root.add_child(_doll_vp)
	_doll_root = Node3D.new()
	_doll_vp.add_child(_doll_root)
	var cam := Camera3D.new()
	cam.fov = 32
	cam.position = Vector3(0, 1.25, 4.4)
	cam.current = true
	_doll_root.add_child(cam)
	cam.look_at(Vector3(0, 1.05, 0))
	var amb := OmniLight3D.new()
	amb.light_color = Color(1, 1, 1)
	amb.light_energy = 0.45
	amb.omni_range = 12
	amb.position = Vector3(0, 2.2, 2)
	_doll_root.add_child(amb)
	var dl := DirectionalLight3D.new()
	dl.light_color = Color(1, 0.88, 0.69)
	dl.light_energy = 0.9
	dl.rotation_degrees = Vector3(-50, 35, 0)
	_doll_root.add_child(dl)
	var pl := OmniLight3D.new()
	pl.light_color = Color(0.416, 0.502, 1)
	pl.light_energy = 0.55
	pl.omni_range = 12
	pl.position = Vector3(-3, 2, 3)
	_doll_root.add_child(pl)
	_rebuild_doll()


func _rebuild_doll() -> void:
	if _doll_root == null:
		return
	var want: String = Data.CLASS_ASSET.get(Game.P.cls, "char_warrior")
	if _doll_model and is_instance_valid(_doll_model) and _doll_id == want:
		return
	if _doll_model and is_instance_valid(_doll_model):
		_doll_model.queue_free()
	_doll_id = want
	var look: Dictionary = Data.CLASSES[Game.P.cls].look.duplicate()
	_doll_model = Assets.make_actor(want, look, "human")
	_doll_root.add_child(_doll_model)
	_doll_model.position = Vector3.ZERO
	_doll_model.rotation.y = _doll_rot


func _tick_doll(dt: float) -> void:
	if _doll_vp == null:
		return
	var show: bool = _panel.visible and (_sheet == "char" or _sheet == "bag")
	_doll_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show else SubViewport.UPDATE_DISABLED
	if not show or _doll_model == null or not is_instance_valid(_doll_model):
		return
	if _doll_auto:
		_doll_rot += dt * 0.5
	_doll_model.rotation.y = _doll_rot
	Assets.tick_anim(_doll_model, 0.0, 0.0)


func _on_doll_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.double_click:
			_doll_auto = true
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_doll_drag = ev.pressed
			if ev.pressed:
				_doll_auto = false
	elif ev is InputEventMouseMotion and _doll_drag:
		_doll_rot += ev.relative.x * 0.012


func _tick_die(dt: float) -> void:
	if _die_spin <= 0.0:
		return
	_die_spin -= dt
	if _die_lab and is_instance_valid(_die_lab):
		_die_lab.text = str(Cfg.ri(1, 6))
	if _die_spin > 0.0:
		return
	var side := _die_side
	_die_side = ""
	Game.play_gamble(side)
	if _sheet == "npc":
		open_npc("vaun")


func _shop_grid(cols: int = 3) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_panel_body.add_child(g)
	return g


func _sitem(parent: Control, glyph: String, title: String, price: String, col: Color, tip: String, cb: Callable, off: bool = false) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 52)
	b.add_theme_stylebox_override("normal", UiKit.cell())
	b.disabled = off
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.stamp_btn(b, UiKit.icon_for_glyph(glyph), "%s\n%s" % [title, price], 28, true)
	b.add_theme_color_override("font_color", col)
	b.add_theme_font_size_override("font_size", 12)
	if tip != "":
		_wire_tip(b, tip)
	if not off:
		b.pressed.connect(cb)
	parent.add_child(b)


func open_achs() -> void:
	_sheet = "achs"
	_clear_panel()
	_show_panel()
	Game.ensure_ach()
	_hd("功绩  %d / %d" % [AchData.done_n(), AchData.LIST.size()])
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	_panel_body.add_child(cols)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(280, 0)
	cols.add_child(nav)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(detail)
	if _ach_sel == "" or AchData.by_id(_ach_sel).is_empty():
		_ach_sel = str(AchData.LIST[0].id)
		for a in AchData.LIST:
			if AchData.on(str(a.id)):
				_ach_sel = str(a.id)
				break
	for cat in AchData.cats():
		var list: Array = []
		for a in AchData.LIST:
			if str(a.cat) == cat:
				list.append(a)
		var done := 0
		for a in list:
			if AchData.on(str(a.id)):
				done += 1
		var cl := Label.new()
		cl.text = "%s  %d / %d" % [cat, done, list.size()]
		cl.add_theme_color_override("font_color", UiKit.brass())
		nav.add_child(cl)
		for a in list:
			var id: String = str(a.id)
			var on: bool = AchData.on(id)
			var hide: bool = a.get("hidden") == true and not on
			var row := Button.new()
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var need := int(a.get("need", 1))
			var p := mini(AchData.prog(a), need)
			var sub := "已解锁" if on else ("尚未揭开" if hide else "%d / %d" % [p, need])
			row.text = "%s\n%s" % ["？？？" if hide else a.n, sub]
			if id == _ach_sel:
				row.modulate = Color(1.2, 1.05, 0.7)
			if on:
				row.add_theme_color_override("font_color", Color(0.49, 0.78, 0.49))
			row.pressed.connect(func():
				_ach_sel = id
				open_achs()
			)
			nav.add_child(row)
	var a := AchData.by_id(_ach_sel)
	if a.is_empty():
		return
	var on: bool = AchData.on(str(a.id))
	var hide: bool = a.get("hidden") == true and not on
	var need := int(a.get("need", 1))
	var p := mini(AchData.prog(a), need)
	var ico := Label.new()
	ico.text = "◆" if on else "◇"
	ico.add_theme_font_size_override("font_size", 28)
	ico.add_theme_color_override("font_color", UiKit.brass())
	detail.add_child(ico)
	var hn := Label.new()
	hn.text = "？？？" if hide else str(a.n)
	hn.add_theme_font_size_override("font_size", 22)
	hn.add_theme_color_override("font_color", UiKit.brass())
	detail.add_child(hn)
	var qw := Label.new()
	qw.text = str(a.cat) + (" · 已解锁" if on else "")
	qw.add_theme_color_override("font_color", UiKit.dim())
	detail.add_child(qw)
	var qd := Label.new()
	qd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qd.text = "还没揭开。去做该做的事。" if hide else str(a.d)
	detail.add_child(qd)
	if not hide:
		var bar := ProgressBar.new()
		bar.max_value = need
		bar.value = p
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		detail.add_child(bar)
		var obj := Label.new()
		obj.text = "%s  %d / %d" % ["已达成" if on else "进度", p, need]
		detail.add_child(obj)
	if int(a.get("gold", 0)):
		var gr := Label.new()
		gr.text = "%s %d 金币" % ["已领取" if on else "解锁奖励", int(a.gold)]
		gr.add_theme_color_override("font_color", Color(0.96, 0.77, 0.32))
		detail.add_child(gr)


func _item_btn(label: String, it: Dictionary, left: Callable, right: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_color_override("font_color", UiKit.rarity_color(it))
	b.add_theme_stylebox_override("normal", UiKit.cell(LootData.item_hex(it) if not it.is_empty() else 0x3d3122))
	b.pressed.connect(left)
	if not it.is_empty():
		_wire_tip(b, Game.item_tip(it, true))
	if right.is_valid():
		b.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				right.call()
		)
	_panel_body.add_child(b)
	return b


func _refresh_combat_hud() -> void:
	if Game.P.target != null and not Game.P.target.get("dead", true):
		var t: Dictionary = Game.P.target
		_target.text = "%s  %d 级\n%d / %d" % [t.get("name", ""), int(t.get("lvl", 1)), int(t.hp), int(t.hpMax)]
		var mods := Game.target_mods(t)
		if mods != "":
			_target.text += "\n" + mods
		_target.visible = true
	else:
		_target.visible = false
	for c in _buffs.get_children():
		c.queue_free()
	for k in Game.P.buffs:
		var lab := Label.new()
		lab.text = "%s %.0f" % [UiKit.buff_name(str(k)), float(Game.P.buffs[k].t)]
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color(0.88, 0.78, 0.5))
		_buffs.add_child(lab)
	for st in Game.unique_stacks():
		var sl := Label.new()
		sl.text = str(st)
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", Color(0.78, 0.64, 1))
		_buffs.add_child(sl)
	if Game.P.casting != "":
		_cast.visible = true
		_cast.max_value = 2.2
		_cast.value = Game.P.castT
	else:
		_cast.visible = false
	var frac := 0.0 if Game.P.xpNext <= 0 else float(Game.P.xp) / float(Game.P.xpNext)
	_xp_fill.anchor_right = clampf(frac, 0, 1)
	if _evt:
		var line := Game.event_line()
		_evt.text = line
		_evt.visible = line != ""
	if _combo:
		var n := int(Game.feel.get("combo", 0))
		_combo.visible = n >= 2
		_combo.text = str(n)
	if _beat:
		var on: bool = typeof(Game.P.get("up")) == TYPE_DICTIONARY and Game.P.up.get("beatOn") == true
		_beat.color = Color(0.89, 0.77, 0.5, 0.55 if on else 0.0)


func _process(dt: float) -> void:
	Game.P.holdStand = Input.is_key_pressed(KEY_SHIFT)
	var scaled := Game.consume_feel(dt)
	if Game.P.alive and scaled > 0.0:
		Game.tick_player(scaled)
		WorldState.tick_world(scaled)
	var target := Vector3(float(Game.P.x), 0, float(Game.P.z))
	if Game.cine_boss.size() > 0:
		var e: Dictionary = Game.cine_boss.e
		target = Vector3(e.x, 0, e.z)
	var off: Vector3 = Cfg.CAM_OFF * cam_zoom
	var dest := target + off
	cam.global_position = cam.global_position.lerp(dest, clampf(dt * 6, 0, 1))
	if Game.cam_shake > 0:
		cam.global_position.x += Cfg.rf(-1, 1) * Game.cam_shake
		cam.global_position.z += Cfg.rf(-1, 1) * Game.cam_shake
	cam.look_at(target + Vector3(0, 1.2, 0))
	$Torch.global_position = Vector3(Game.P.x, 3.6, Game.P.z)
	$Torch.light_energy = (1.5 + sin(Time.get_ticks_msec() * 0.007) * 0.12) if WorldState.W.get("dark") else 0.35
	if _hold and Game.P.alive and Game.P.target == null and Game.P.pickupTarget == null and not Game.P.holdStand and not Game.player_locked():
		var gp := _ground_point()
		if gp != Vector3.INF and Cfg.dist2(gp.x, gp.z, Game.P.x, Game.P.z) > 1.4:
			WorldState.walk_to(gp.x, gp.z)
	if Game.P.alive and not Game.player_locked():
		if _hold_r:
			var gp2 := _ground_point()
			if gp2 != Vector3.INF:
				Game.last_cursor = gp2
			Game.try_mouse(1)
		elif _hold and Game.P.holdStand:
			var gp3 := _ground_point()
			if gp3 != Vector3.INF:
				Game.last_cursor = gp3
				Game.P.dir = atan2(gp3.x - Game.P.x, gp3.z - Game.P.z)
			if Game.mouse_skill(0) != "":
				Game.try_mouse(0)
			elif Game.P.target == null:
				var en := _enemy_under()
				if not en.is_empty():
					Game.P.target = en
	_refresh_bars(dt)
	_update_floats(dt)
	_refresh_combat_hud()
	_tick_minimap(dt)
	_tick_doll(dt)
	_tick_die(dt)
	if _mm_wrap:
		_mm_wrap.visible = not _panel.visible and not _pause.visible
	if _tip.visible:
		_tip.position = get_viewport().get_mouse_position() + Vector2(16, 16)
	if _pause.visible and _pause_meta:
		_pause_meta.text = "%s · %s · %d 级 · %s" % [Game.displayed_name(), Data.CLASSES[Game.P.cls].n, Game.P.lvl, Game.diff_now().n]


func _unhandled_input(event: InputEvent) -> void:
	if Game.story.size() > 0:
		if event.is_action_pressed("pause_menu") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
			Game.end_story()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_zoom = clampf(cam_zoom - 0.09, 0.62, 1.75)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_zoom = clampf(cam_zoom + 0.09, 0.62, 1.75)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_hold = event.pressed
			if event.pressed:
				_click()
			else:
				_hold = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_hold_r = event.pressed
			if event.pressed:
				_right_click()
			else:
				_hold_r = false
	if event.is_action_pressed("skill_1"):
		Game.try_cast(0)
	elif event.is_action_pressed("skill_2"):
		Game.try_cast(1)
	elif event.is_action_pressed("skill_3"):
		Game.try_cast(2)
	elif event.is_action_pressed("skill_4"):
		Game.try_cast(3)
	elif event.is_action_pressed("skill_5"):
		Game.try_cast(4)
	elif event.is_action_pressed("skill_6"):
		Game.try_cast(5)
	elif event.is_action_pressed("potion_hp"):
		Game.drink_hp()
	elif event.is_action_pressed("potion_mp"):
		Game.drink_mp()
	elif event.is_action_pressed("open_char"):
		_toggle_sheet("char")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		_toggle_sheet("talents")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		_toggle_sheet("skills")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y:
		_toggle_sheet("achs")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		Game.fire_retally()
	elif event.is_action_pressed("open_bag"):
		_toggle_sheet("bag")
	elif event.is_action_pressed("open_quest"):
		_toggle_sheet("quests")
	elif event.is_action_pressed("town_portal"):
		if WorldState.W.area.get("kind") != "town":
			Game.P.casting = "town"
			Game.P.castT = 0
			Game.hint("回城…")
	elif event.is_action_pressed("pause_menu"):
		if _panel.visible:
			_panel.visible = false
			_sheet = ""
		else:
			_pause.visible = not _pause.visible


func _click() -> void:
	if not Game.P.alive:
		return
	if WorldState.W.get("player_node") == null:
		return
	var gp := _ground_point()
	Game.last_cursor = gp if gp != Vector3.INF else Vector3(Game.P.x, 0, Game.P.z)
	var npc := _npc_under()
	if not npc.is_empty():
		Game.P.target = null
		Game.P.pickupTarget = null
		Game.P.npcTarget = npc.id
		WorldState.walk_to(npc.x, npc.z + 1.6)
		return
	var loot := WorldState.loot_under(Game.last_cursor.x, Game.last_cursor.z)
	if not loot.is_empty():
		Game.P.target = null
		Game.P.npcTarget = ""
		Game.P.pickupTarget = loot
		WorldState.walk_to(float(loot.x), float(loot.z))
		return
	var en := _enemy_under()
	if not en.is_empty():
		Game.P.pickupTarget = null
		Game.P.target = en
		Game.P.path = []
		Game.P.npcTarget = ""
		if Game.P.holdStand:
			Game.P.path = []
		return
	if Game.P.onMark != null and Cfg.dist2(Game.P.onMark.x, Game.P.onMark.z, Game.P.x, Game.P.z) < 6.0:
		WorldState.use_mark(Game.P.onMark)
		return
	Game.P.target = null
	Game.P.pickupTarget = null
	if Game.P.holdStand:
		return
	if gp != Vector3.INF:
		WorldState.walk_to(gp.x, gp.z)


func _right_click() -> void:
	if not Game.P.alive:
		return
	if str(WorldState.W.area.get("kind", "")) == "town":
		return
	var gp := _ground_point()
	Game.last_cursor = gp if gp != Vector3.INF else Vector3(Game.P.x, 0, Game.P.z)
	var en := _enemy_under()
	if not en.is_empty():
		Game.last_cursor = Vector3(float(en.x), 0, float(en.z))
	Game.try_mouse(1)


func _ground_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if abs(dir.y) < 0.001:
		return Vector3.INF
	var t := -from.y / dir.y
	return from + dir * t


func _npc_under() -> Dictionary:
	var gp := _ground_point()
	if gp == Vector3.INF:
		return {}
	for n in WorldState.W.npcs:
		if Cfg.dist2(n.x, n.z, gp.x, gp.z) < 2.2 * 2.2:
			return n
	return {}


func _enemy_under() -> Dictionary:
	var gp := _ground_point()
	if gp == Vector3.INF:
		return {}
	for e in WorldState.W.enemies:
		if e.get("dead"):
			continue
		if Cfg.dist2(e.x, e.z, gp.x, gp.z) < 1.8 * 1.8:
			return e
	return {}


func _on_log(t: String) -> void:
	_log.append_text(t + "\n")


func _on_hint(t: String) -> void:
	_hint.text = t


func _on_zone(n: String, sub: String) -> void:
	_zone.text = n
	var d: String = str(Game.diff_now().n) if Game.diff_id() != "normal" else ""
	_zone_sub.text = sub + ((" · " + d) if d != "" else "")
	_apply_pal()


func _on_dead() -> void:
	_dead.visible = true


func _on_cine(kind: String, meta: Dictionary) -> void:
	if kind == "":
		_cine.visible = false
		return
	_cine.visible = true
	_cine_k.text = str(meta.get("k", ""))
	_cine_n.text = str(meta.get("n", ""))
	_cine_d.text = str(meta.get("d", ""))


func _refresh_bars(dt := 0.0) -> void:
	_hp.max_value = Game.P.hpMax
	_mp.max_value = Game.P.mpMax
	_xp.max_value = Game.P.xpNext
	# 平滑过渡：显示值向真实值收敛，避免硬跳变（HUD 最佳实践）
	var k := clampf(dt * 14.0, 0.0, 1.0)
	if _hp_disp < 0.0:
		_hp_disp = float(Game.P.hp); _mp_disp = float(Game.P.mp); _xp_disp = float(Game.P.xp)
	_hp_disp = lerp(_hp_disp, float(Game.P.hp), k)
	_mp_disp = lerp(_mp_disp, float(Game.P.mp), k)
	_xp_disp = lerp(_xp_disp, float(Game.P.xp), k)
	_hp.value = _hp_disp
	_mp.value = _mp_disp
	_xp.value = _xp_disp
	_hp_lab.text = "生命  %d / %d" % [int(Game.P.hp), int(Game.P.hpMax)]
	_mp_lab.text = "法力  %d / %d" % [int(Game.P.mp), int(Game.P.mpMax)]
	# 事件钩子：升级 / 拾取 通知（经 EventBus -> Notify 通知栈）
	if Game.P.lvl != _last_lvl:
		if Game.P.lvl > _last_lvl:
			EventBus.notify.emit("升级！", "达到 %d 级" % Game.P.lvl, "good")
		_last_lvl = Game.P.lvl
	if Game.P.bag.size() > _last_bag_n:
		var d: int = int(Game.P.bag.size()) - _last_bag_n
		var nm := "物品"
		if Game.P.bag.size() > 0:
			var last: Dictionary = Game.P.bag[Game.P.bag.size() - 1]
			nm = str(last.get("name", "物品"))
		EventBus.notify.emit("拾取 +%d" % d, nm, "loot")
		_last_bag_n = Game.P.bag.size()


func _refresh_hud() -> void:
	_pname.text = Game.displayed_name() + "  ·  %s  %d 级  装等 %d" % [Data.CLASSES[Game.P.cls].n, Game.P.lvl, Game.gear_power()]
	_gold.text = "金币 %d" % Game.P.gold
	UiKit.stamp_btn(_pot_hp, "potion-hp", "Q %d" % Game.P.potHp, 28)
	UiKit.stamp_btn(_pot_mp, "potion-mp", "E %d" % Game.P.potMp, 28)
	_pot_hp.disabled = Game.P.potCd > 0 or Game.P.potHp <= 0
	_pot_mp.disabled = Game.P.potCd > 0 or Game.P.potMp <= 0
	if Game.P.potCd > 0:
		_pot_hp.text = "%.0f" % Game.P.potCd
	var q := Game.active_quest()
	if q.is_empty():
		_track.text = ""
	else:
		_track.text = "%s\n%d / %d" % [q.n, Game.quest_prog(q), int(q.need)]
	for i in 6:
		var id: String = Game.P.barSkills[i]
		var b: Button = _skills[i]
		var prev := ""
		if b.has_meta("sid"):
			prev = str(b.get_meta("sid"))
		if prev != id:
			b.set_meta("sid", id)
			if id == "":
				UiKit.stamp_btn(b, "", "·\n%d" % (i + 1), 32)
			else:
				UiKit.stamp_btn(b, UiKit.icon_for_skill(id), str(i + 1), 36)
		if id == "":
			b.text = "·\n%d" % (i + 1)
			b.disabled = true
			b.tooltip_text = ""
		else:
			var sk := Data.sk_by_id(id)
			var cd := float(Game.P.cds.get(id, 0))
			b.disabled = cd > 0
			b.add_theme_font_size_override("font_size", 12)
			if cd > 0:
				b.text = "%.0f" % cd
			else:
				b.text = str(i + 1)
			b.tooltip_text = str(sk.get("n", ""))
	var mlab := ["左", "右"]
	for i in 2:
		if i >= _mice.size():
			break
		var mid: String = Game.mouse_skill(i)
		var mb: Button = _mice[i]
		var mprev := ""
		if mb.has_meta("sid"):
			mprev = str(mb.get_meta("sid"))
		if mprev != mid:
			mb.set_meta("sid", mid)
			if mid == "":
				UiKit.stamp_btn(mb, "", "%s\n普攻" % mlab[i], 28)
			else:
				UiKit.stamp_btn(mb, UiKit.icon_for_skill(mid), mlab[i], 32)
		if mid == "":
			mb.text = "%s\n普攻" % mlab[i]
			mb.disabled = i == 1
			mb.tooltip_text = "左键点地走、点怪打" if i == 0 else "右键技能未绑"
		else:
			var msk := Data.sk_by_id(mid)
			var mcd := float(Game.P.cds.get(mid, 0))
			mb.disabled = mcd > 0
			mb.add_theme_font_size_override("font_size", 11)
			if mcd > 0:
				mb.text = "%.0f" % mcd
			else:
				mb.text = mlab[i]
			mb.tooltip_text = str(msk.get("n", ""))
	if _panel.visible:
		match _sheet:
			"char":
				open_char()
			"bag":
				open_bag()
			"skills":
				open_skills()
			"talents":
				open_talents()
			"quests":
				open_quests()
			"achs":
				open_achs()


func _spawn_float(pos: Vector3, text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.set_meta("life", 0.9)
	l.set_meta("world", pos)
	_floats.add_child(l)


func _update_floats(dt: float) -> void:
	for c in _floats.get_children():
		var life: float = c.get_meta("life") - dt
		c.set_meta("life", life)
		var wp: Vector3 = c.get_meta("world")
		wp.y += dt * 1.2
		c.set_meta("world", wp)
		c.position = cam.unproject_position(wp)
		c.modulate.a = clampf(life / 0.4, 0, 1)
		if life <= 0:
			c.queue_free()


func _clear_panel() -> void:
	for c in _panel_body.get_children():
		c.queue_free()


func _show_panel() -> void:
	_panel.visible = true
	if _sheet_veil:
		_sheet_veil.visible = true
	_sync_nav()


func _sync_nav() -> void:
	for nb in _nav_btns:
		var on: bool = _panel.visible and str(nb.get_meta("sheet")) == _sheet
		nb.add_theme_stylebox_override("normal", UiKit.nav_on() if on else UiKit.nav())


func _btn(t: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	_panel_body.add_child(b)


func _plab(t: String, sz: int = 14) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", UiKit.ash() if sz <= 12 else UiKit.bone())
	_panel_body.add_child(l)


func _equip_slot(k: String) -> Button:
	var it = Game.P.equip.get(k)
	var b := InvCell.new()
	b.cell_kind = "equip"
	b.slot_key = k
	b.it_ref = it if (typeof(it) == TYPE_DICTIONARY) else {}
	b.custom_minimum_size = Vector2(64, 64)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 11)
	if it != null and typeof(it) == TYPE_DICTIONARY and not it.is_empty():
		UiKit.stamp_btn(b, UiKit.icon_for_item(it), str(it.name).substr(0, 4), 32)
		b.add_theme_color_override("font_color", UiKit.rarity_color(it))
		b.add_theme_stylebox_override("normal", UiKit.cell(LootData.item_hex(it)))
		b.add_theme_stylebox_override("hover", UiKit.cell_hover(LootData.item_hex(it)))
		_wire_tip(b, Game.item_tip(it))
		var slot := k
		b.pressed.connect(func():
			Game.unequip_slot(slot)
			_reload_gear()
		)
	else:
		UiKit.stamp_btn(b, UiKit.icon_for_slot(k), UiKit.slot_name(k), 28)
		b.add_theme_color_override("font_color", UiKit.ash())
		b.add_theme_stylebox_override("normal", UiKit.cell_empty())
		b.add_theme_stylebox_override("disabled", UiKit.cell_empty())
		b.disabled = true
	return b


func _slot_pad() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(64, 64)
	return c


func _pick_stat_tab(tab: String) -> void:
	_stat_tab = tab
	_reload_gear()


func _pick_skill_id(sid: String) -> void:
	_sk_sel = sid
	open_skills()


func _assign_skill_slot(slot: int) -> void:
	Game.assign_bar(_sk_assign, slot)
	_sk_assign = ""
	open_skills()


func _reload_gear() -> void:
	if _sheet == "bag":
		open_bag()
	else:
		open_char()


func _item_cell(it, idx: int, kind: String) -> Button:
	var cell := InvCell.new()
	cell.cell_kind = kind
	cell.cell_idx = idx
	cell.it_ref = it if (typeof(it) == TYPE_DICTIONARY) else {}
	cell.custom_minimum_size = Vector2(70, 70)
	cell.clip_text = true
	cell.add_theme_font_size_override("font_size", 20)
	if it != null and typeof(it) == TYPE_DICTIONARY and not it.is_empty():
		UiKit.stamp_btn(cell, UiKit.icon_for_item(it as Dictionary), "", 40)
		cell.add_theme_color_override("font_color", UiKit.rarity_color(it as Dictionary))
		cell.add_theme_stylebox_override("normal", UiKit.cell(LootData.item_hex(it as Dictionary)))
		cell.add_theme_stylebox_override("hover", UiKit.cell_hover(LootData.item_hex(it as Dictionary)))
		_wire_tip(cell, Game.item_tip(it as Dictionary, true))
		var i := idx
		if kind == "bag":
			cell.pressed.connect(func():
				Game.equip_from_bag(i)
				_reload_gear()
			)
			cell.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					Game.discard_bag(i)
					_reload_gear()
			)
		else:
			cell.pressed.connect(func():
				if Game.P.charms.size() > i and Game.P.charms[i].get("unknown"):
					Game.recall_from_charm(i)
				else:
					Game.charm_to_bag(i)
				_reload_gear()
			)
			cell.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					Game.discard_charm(i)
					_reload_gear()
			)
		# 堆叠数量角标（qty>1 时显示）
		var qty := int(it.get("qty", 1))
		if qty > 1:
			var badge := Label.new()
			badge.text = "x%d" % qty
			badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", UiKit.bone())
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(badge)
	else:
		cell.disabled = true
		cell.add_theme_stylebox_override("disabled", UiKit.cell_empty())
	return cell


func _bag_grid(parent: Control) -> void:
	# 分类筛选标签
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	parent.add_child(tabs)
	var cats := [["all", "全部"], ["weapon", "武器"], ["gear", "护甲"], ["rune", "符文"], ["charm", "护符"], ["scrap", "材料"]]
	for c in cats:
		var tb := Button.new()
		tb.text = c[1]
		tb.custom_minimum_size = Vector2(54, 24)
		tb.add_theme_font_size_override("font_size", 12)
		tb.add_theme_stylebox_override("normal", UiKit.tab_on() if _bag_filter == c[0] else UiKit.tab())
		tb.add_theme_color_override("font_color", UiKit.brass_hi() if _bag_filter == c[0] else UiKit.ash())
		var cat: String = c[0]
		tb.pressed.connect(func():
			if _bag_filter != cat:
				_bag_filter = cat
				_reload_gear()
		)
		tabs.add_child(tb)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(grid)
	for i in Cfg.BAG:
		if i < Game.P.bag.size():
			var it: Dictionary = Game.P.bag[i]
			if _bag_filter != "all" and _cat(it) != _bag_filter:
				continue
			grid.add_child(_item_cell(it, i, "bag"))
		else:
			grid.add_child(_item_cell(null, i, "bag"))


func _cat(it: Dictionary) -> String:
	var t := str(it.get("type", ""))
	if t == "weapon":
		return "weapon"
	if t == "rune":
		return "rune"
	if t == "charm":
		return "charm"
	if t == "scrap":
		return "scrap"
	return "gear"


## 拖拽落点协调：复用既有 Game.equip_from_bag / unequip_slot / charm_to_bag。
func _inv_drop(src: Dictionary, dst: Dictionary) -> void:
	if src.kind == dst.kind and src.get("idx", -1) == dst.get("idx", -1) and src.get("slot", "") == dst.get("slot", ""):
		return
	match src.kind:
		"bag":
			if dst.kind == "equip":
				Game.equip_from_bag(int(src.idx))
			elif dst.kind == "bag":
				_swap_bag(int(src.idx), int(dst.idx))
		"equip":
			if dst.kind == "bag":
				Game.unequip_slot(str(src.slot))
		"charm":
			if dst.kind == "bag":
				Game.charm_to_bag(int(src.idx))
	_reload_gear()


func _swap_bag(i: int, j: int) -> void:
	var b: Array = Game.P.bag
	if i < 0 or j < 0 or i >= b.size() or j >= b.size() or i == j:
		return
	var t: Dictionary = b[i]
	b[i] = b[j]
	b[j] = t


func _charm_grid(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	var charms: Array = Game.P.get("charms", [])
	for ci in charms.size():
		grid.add_child(_item_cell(charms[ci], ci, "charm"))
	var free_n := Cfg.CHARM - Game.charm_used()
	for _k in free_n:
		grid.add_child(_item_cell(null, 0, "charm"))


func _paper_doll() -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 7)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 7)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 7)
	root.add_child(left)
	root.add_child(mid)
	root.add_child(right)
	left.add_child(_slot_pad())
	left.add_child(_equip_slot("weapon"))
	left.add_child(_equip_slot("gloves"))
	left.add_child(_equip_slot("belt"))
	left.add_child(_equip_slot("ring1"))
	mid.add_child(_equip_slot("helm"))
	var doll_wrap := PanelContainer.new()
	doll_wrap.custom_minimum_size = Vector2(250, 280)
	doll_wrap.add_theme_stylebox_override("panel", UiKit.cell_empty())
	var doll := TextureRect.new()
	doll.custom_minimum_size = Vector2(250, 280)
	doll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	doll.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	doll.texture = _doll_vp.get_texture()
	doll.gui_input.connect(_on_doll_input)
	doll_wrap.add_child(doll)
	mid.add_child(doll_wrap)
	mid.add_child(_slot_pad())
	right.add_child(_equip_slot("amulet"))
	right.add_child(_equip_slot("offhand"))
	right.add_child(_equip_slot("armor"))
	right.add_child(_equip_slot("boots"))
	right.add_child(_equip_slot("ring2"))
	return root


func _stat_panel(parent: Control) -> void:
	var s := Game.p_stats()
	var name_l := Label.new()
	name_l.text = Game.displayed_name()
	name_l.add_theme_font_size_override("font_size", 22)
	name_l.add_theme_color_override("font_color", UiKit.brass_hi())
	parent.add_child(name_l)
	var cls_l := Label.new()
	cls_l.text = "%s  ·  %d 级" % [Data.CLASSES[Game.P.cls].n, Game.P.lvl]
	cls_l.add_theme_font_size_override("font_size", 12)
	cls_l.add_theme_color_override("font_color", UiKit.ash())
	parent.add_child(cls_l)
	var pw := PanelContainer.new()
	pw.add_theme_stylebox_override("panel", UiKit.gcard())
	parent.add_child(pw)
	var pwh := HBoxContainer.new()
	pw.add_child(pwh)
	var pwk := Label.new()
	pwk.text = "装等"
	pwk.add_theme_font_size_override("font_size", 11)
	pwk.add_theme_color_override("font_color", UiKit.ash())
	pwh.add_child(pwk)
	var pwv := Label.new()
	pwv.text = str(Game.gear_power())
	pwv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pwv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pwv.add_theme_font_size_override("font_size", 26)
	pwv.add_theme_color_override("font_color", UiKit.gold())
	pwh.add_child(pwv)
	var xp := ProgressBar.new()
	xp.show_percentage = false
	xp.custom_minimum_size = Vector2(0, 8)
	xp.max_value = Game.P.xpNext
	xp.value = Game.P.xp
	xp.add_theme_stylebox_override("background", UiKit.bar_bg())
	xp.add_theme_stylebox_override("fill", UiKit.bar_fill(UiKit.brass()))
	parent.add_child(xp)
	var xpl := Label.new()
	xpl.text = "经验  %d / %d" % [int(Game.P.xp), int(Game.P.xpNext)]
	xpl.add_theme_font_size_override("font_size", 11)
	xpl.add_theme_color_override("font_color", UiKit.ash())
	parent.add_child(xpl)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	parent.add_child(tabs)
	for pair in [["core", "属性"], ["off", "攻击"], ["def", "防御"], ["util", "辅助"]]:
		var tb := Button.new()
		tb.text = pair[1]
		tb.add_theme_stylebox_override("normal", UiKit.tab_on() if _stat_tab == pair[0] else UiKit.tab())
		tb.add_theme_stylebox_override("hover", UiKit.tab_on())
		tb.add_theme_color_override("font_color", UiKit.brass_hi() if _stat_tab == pair[0] else UiKit.ash())
		tb.pressed.connect(_pick_stat_tab.bind(str(pair[0])))
		tabs.add_child(tb)
	match _stat_tab:
		"off":
			UiKit.stat_row(parent, "伤害", "%d–%d" % [s.dmgMin, s.dmgMax])
			UiKit.stat_row(parent, "暴击", "%.0f%%" % s.crit)
			UiKit.stat_row(parent, "攻速加成", "%.0f" % s.asB)
			UiKit.stat_row(parent, "技能伤害", "%.0f" % s.skDmg)
		"def":
			UiKit.stat_row(parent, "护甲", str(s.armor))
			UiKit.stat_row(parent, "减伤", "%.0f%%" % s.dr)
			UiKit.stat_row(parent, "闪避", "%.0f" % s.dodge)
			UiKit.stat_row(parent, "物抗", "%.0f" % s.resPhys)
			UiKit.stat_row(parent, "火抗", "%.0f" % s.resFire)
			UiKit.stat_row(parent, "冰抗", "%.0f" % s.resIce)
			UiKit.stat_row(parent, "暗抗", "%.0f" % s.resShadow)
			UiKit.stat_row(parent, "抗性上限", "%.0f" % s.resCap)
		"util":
			UiKit.stat_row(parent, "移速", "%.0f" % s.speed)
			UiKit.stat_row(parent, "冷却缩减", "%.0f" % s.cdr)
			UiKit.stat_row(parent, "金运", "%.0f" % s.gf)
			UiKit.stat_row(parent, "魔运", "%.0f" % s.mf)
			UiKit.stat_row(parent, "汲取", "%.0f" % s.leech)
		_:
			UiKit.stat_row(parent, "力量", str(s.str))
			UiKit.stat_row(parent, "敏捷", str(s.dex))
			UiKit.stat_row(parent, "体魄", str(s.vit))
			UiKit.stat_row(parent, "精神", str(s.ene))
			UiKit.stat_row(parent, "未分配", str(Game.P.pts))
			UiKit.stat_row(parent, "生命", str(int(Game.P.hpMax)))
			UiKit.stat_row(parent, "法力", str(int(Game.P.mpMax)))
			if Game.P.pts > 0:
				var prow := HBoxContainer.new()
				parent.add_child(prow)
				for k in ["str", "dex", "vit", "ene"]:
					var pb := Button.new()
					pb.text = "+ " + k
					pb.pressed.connect(Game.spend_stat.bind(k))
					prow.add_child(pb)
	Game.rebuild_powers()
	var worn: Dictionary = Game.P.get("sets", {})
	if typeof(worn) == TYPE_DICTIONARY and worn.size():
		UiKit.group(parent, "套装")
		for sid in worn.keys():
			var def := LootData.set_by_id(str(sid))
			if def.is_empty():
				continue
			var n: int = int(worn[sid])
			var sl := Label.new()
			sl.text = "%s（%d / %d）" % [def.n, n, def.pieces.size()]
			sl.add_theme_font_size_override("font_size", 13)
			parent.add_child(sl)
			for bns in def.get("bonuses", []):
				var bl := Label.new()
				bl.text = "(%d) %s" % [int(bns.need), bns.t]
				bl.add_theme_font_size_override("font_size", 12)
				bl.add_theme_color_override("font_color", UiKit.ash())
				parent.add_child(bl)
	var relics: Array = Game.P.get("relics", [])
	var codex: Array = Game.P.get("codex", [])
	if relics.size() or codex.size():
		UiKit.group(parent, "残句与遗物")
		for r in relics:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			parent.add_child(row)
			row.add_child(UiKit.icon_rect(UiKit.icon_for_glyph(str(r.get("icon", "🕯"))), 22))
			var rl := Label.new()
			rl.text = "%s  %s" % [r.get("n", ""), r.get("d", "")]
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rl.add_theme_font_size_override("font_size", 12)
			row.add_child(rl)
		for c in codex:
			var cl := Label.new()
			cl.text = "▍ %s  %s" % [c.get("n", ""), c.get("text", "")]
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cl.add_theme_font_size_override("font_size", 12)
			parent.add_child(cl)


func open_npc(id: String) -> void:
	_sheet = "npc"
	_talk_id = id
	_clear_panel()
	_show_panel()
	var def: Dictionary = {}
	for d in Data.NPCDEF:
		if str(d.id) == id:
			def = d
			break
	if not def.is_empty() and str(def.get("kind", "")) == "":
		_hd(str(def.get("n", id)))
		_plab(str(def.get("t", "")), 12)
		_plab(TalkData.greet(id))
		var topics: Array = TalkData.topics(id)
		if topics.size():
			_plab("打听", 13)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_panel_body.add_child(row)
			for t in topics:
				var tid: String = str(t.id)
				var tb := Button.new()
				tb.text = str(t.q)
				if _talk_pick == tid:
					tb.modulate = Color(1.2, 1.05, 0.7)
				tb.pressed.connect(func():
					_talk_pick = tid
					open_npc(id)
				)
				row.add_child(tb)
			if _talk_pick != "":
				var ans: String = TalkData.answer(id, _talk_pick)
				if ans != "":
					_plab(ans)
	match id:
		"selin":
			if def.is_empty():
				_hd("执政官 塞琳")
			for q in Data.QUESTS:
				var st: String = Game.P.quests.get(q.id, {}).get("state", "locked")
				if st == "open":
					var line := "%s  %d/%d" % [q.n, Game.quest_prog(q), int(q.need)]
					if Game.quest_done(q):
						_btn("交付 · " + q.n, func():
							Game.turn_in(q.id)
							open_npc("selin")
						)
					else:
						_plab(line + "\n" + q.d)
			_btn("关掉", func(): _close_sheet())
		"kaden":
			_open_kaden()
		"mara":
			_open_mara()
		"vaun":
			if def.is_empty():
				_hd("赌徒 沃恩")
			_plab("猜大小 · 金币 %d" % Game.P.gold, 13)
			var diebox := VBoxContainer.new()
			diebox.alignment = BoxContainer.ALIGNMENT_CENTER
			_panel_body.add_child(diebox)
			_die_lab = Label.new()
			_die_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_die_lab.add_theme_font_size_override("font_size", 42)
			var lg: Dictionary = Game.last_gamble
			if _die_spin > 0.0:
				_die_lab.text = "?"
				_die_lab.add_theme_color_override("font_color", UiKit.brass())
			elif lg.is_empty():
				_die_lab.text = "?"
				_die_lab.add_theme_color_override("font_color", UiKit.brass())
			else:
				_die_lab.text = str(lg.get("die", "?"))
				if lg.get("win"):
					_die_lab.add_theme_color_override("font_color", Color(0.49, 0.78, 0.49))
				else:
					_die_lab.add_theme_color_override("font_color", Color(0.75, 0.35, 0.29))
			diebox.add_child(_die_lab)
			var res := Label.new()
			res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if lg.is_empty():
				res.text = "1–3 小 · 4–6 大。先选注码，再押大小。"
			else:
				res.text = str(lg.get("text", ""))
			diebox.add_child(res)
			var stakes := HBoxContainer.new()
			_panel_body.add_child(stakes)
			for pair in [[1, "小注"], [2, "中注"], [4, "豪注"]]:
				var mul: int = pair[0]
				var sb := Button.new()
				sb.text = "%s %d 金" % [pair[1], Game.gamble_cost(mul)]
				if Game.gamble_stake == mul:
					sb.modulate = Color(1.2, 1.05, 0.7)
				sb.pressed.connect(func():
					Game.gamble_stake = mul
					open_npc("vaun")
				)
				stakes.add_child(sb)
			var bets := HBoxContainer.new()
			_panel_body.add_child(bets)
			var sm := Button.new()
			sm.text = "押小"
			sm.pressed.connect(func(): _start_gamble("small"))
			bets.add_child(sm)
			var bg := Button.new()
			bg.text = "押大"
			bg.pressed.connect(func(): _start_gamble("big"))
			bets.add_child(bg)
			_plab("今夜赌货（金币 %d）" % Game.P.gold, 13)
			if Game.shop_stock.is_empty():
				_plab("今夜的货被掏空了。掷骰子还能再开。", 12)
			else:
				var grid := _shop_grid(2)
				var si := 0
				for it in Game.shop_stock:
					var idx := si
					si += 1
					var cost := Game.shop_price(Game.buy_price(it))
					_sitem(grid, str(it.glyph), str(it.name), "%d 金" % cost, UiKit.rarity_color(it), Game.item_tip(it, true), func():
						Game.buy_stock(idx)
						open_npc("vaun")
					)
			_btn("关掉", func(): _close_sheet())
		"bridge":
			_btn("念名", func():
				Game.recites_name()
				Game.save_now()
				_close_sheet()
			)
			_btn("存档", func():
				Game.save_now()
				Game.hint("记下了")
				_close_sheet()
			)
			_btn("关掉", func(): _close_sheet())
		"spring":
			_hd("复活井")
			_plab("井水还是温的。出镇打仗，死了会在这儿醒。")
			_plab("每一座据点都有一口。喝一口，血和蓝都回来。", 12)
			_btn("喝一口", func():
				Game.drink_spring()
				_close_sheet()
			)
			_btn("关掉", func(): _close_sheet())
		"waystone":
			open_waystone()
		"stash":
			_open_stash()
		"board":
			_open_board()
		"caravan":
			_hd("遇袭的商贩")
			_plab(WorldState.event_npc_line("caravan"))
			_btn("关掉", func(): _close_sheet())
		"apprentice":
			_hd("迷路的学徒")
			_plab(WorldState.event_npc_line("apprentice"))
			_btn("关掉", func(): _close_sheet())
		_:
			if def.is_empty():
				_hd(id)
				_plab("风从那边来。你知道该往哪走。")
			_btn("关掉", func(): _close_sheet())


func _open_kaden() -> void:
	_plab("铁匠 卡登", 20)
	_plab("制式 · 重铸 · 箱子。黑铁放下。词缀打歪了拿来重铸。稀有的能开孔。")
	_plab("金币 %d · 行囊 %d/%d" % [Game.P.gold, Game.P.bag.size(), Cfg.BAG], 12)
	var tabs := HBoxContainer.new()
	_panel_body.add_child(tabs)
	for pair in [["shop", "制式"], ["crate", "箱子"], ["reforge", "重铸"], ["socket", "镶嵌"], ["craft", "合成"], ["phrase", "一句话"], ["redeem", "兑换"]]:
		var id: String = pair[0]
		var b := Button.new()
		b.text = pair[1]
		if _smith_tab == id:
			b.modulate = Color(1.2, 1.05, 0.7)
		b.pressed.connect(func():
			_smith_tab = id
			_socket_pick = null
			open_npc("kaden")
		)
		tabs.add_child(b)
	match _smith_tab:
		"shop":
			_plab("制式（随你等级）")
			var stock := _shop_grid(3)
			for type in ["weapon", "armor", "helm", "offhand", "gloves", "boots"]:
				var sample := Game.make_basic_item(type, Game.P.cls, maxi(1, int(Game.P.lvl)))
				Game.item_seq -= 1
				var cost := Game.shop_price(Game.buy_price(sample))
				var typ: String = type
				_sitem(stock, str(sample.glyph), str(sample.name), "%d 金" % cost, UiKit.rarity_color(sample), Game.item_tip(sample, true), func():
					Game.buy_basic(typ)
					open_npc("kaden")
				)
			_plab("卖出行囊")
			if Game.P.bag.is_empty():
				_plab("行囊是空的。")
			else:
				var sell := _shop_grid(3)
				var i := 0
				for it in Game.P.bag:
					var idx := i
					i += 1
					var unk: bool = it.get("unknown") == true
					var nm := "想不起来的东西" if unk else str(it.name)
					var gl := "❔" if unk else str(it.glyph)
					_sitem(sell, gl, nm, "+%d 金" % Game.sell_price(it), UiKit.rarity_color(it), Game.item_tip(it), func():
						Game.sell_bag(idx)
						open_npc("kaden")
					)
		"crate":
			_plab("来路不明的箱子。买下后要想起来才知道是什么。")
			var crates := _shop_grid(3)
			for type in Data.CRATE_TYPES:
				var cost := Game.crate_cost(type)
				var typ: String = type
				_sitem(crates, "❔", Data.slot_name_of(type), "%d 金" % cost, Color(0.6, 0.56, 0.48), "不知道是什么。也不问从哪来。\n%d 金 · 买下后要想起来才知道是什么" % cost, func():
					Game.buy_crate(typ)
					open_npc("kaden")
				)
		"reforge":
			var list: Array = []
			for g in Game.smith_gear():
				if int(Data.RARITY[int(g.it.rarity)].af) > 0 and not Game.is_locked_gear(g.it):
					list.append(g)
			if list.is_empty():
				_plab("没有带词缀的装备。魔法品质以上才能重铸。")
			for g in list:
				var it: Dictionary = g.it
				var bits: PackedStringArray = []
				for a in it.get("affixes", []):
					bits.append("+%d %s%s" % [a.v, a.n, " · 记得的" if a.get("feel") else ""])
				_plab("%s  ·  %s\n%s" % [it.name, g.where, " · ".join(bits)])
				var loc: String = g.loc
				_btn("重铸全部 · %d 金" % Game.reforge_cost(it), func():
					if Game.do_reforge(loc):
						open_npc("kaden")
				)
				var ai := 0
				for a in it.get("affixes", []):
					var aidx := ai
					_btn("改「%s」 · %d 金" % [a.n, Game.nudge_cost(it)], func():
						if Game.do_nudge(loc, aidx):
							open_npc("kaden")
					)
					ai += 1
		"socket":
			if _socket_pick:
				var host := Game.gear_at(str(_socket_pick.loc))
				if host.is_empty():
					_socket_pick = null
				else:
					_plab("把碎屑镶进「%s」的第 %d 孔。" % [host.name, int(_socket_pick.idx) + 1])
					_btn("取消", func():
						_socket_pick = null
						open_npc("kaden")
					)
					var any := false
					var bi := 0
					for it in Game.P.bag:
						if it.get("type") == "rune":
							any = true
							var bag_i := bi
							_btn("%s  +%d %s" % [it.name, it.v, Data.affix_by_k(str(it.k)).get("n", it.k)], func():
								if Game.do_socket_in(str(_socket_pick.loc), int(_socket_pick.idx), bag_i):
									_socket_pick = null
									open_npc("kaden")
							)
						bi += 1
					if not any:
						_plab("行囊里没有碎屑。去打怪，三枚同级可合成。")
			if _socket_pick:
				pass
			else:
				var list: Array = []
				for g in Game.smith_gear():
					if not Game.is_locked_gear(g.it) and (int(g.it.rarity) >= 2 or g.it.get("sockets", []).size()):
						list.append(g)
				if list.is_empty():
					_plab("稀有以上装备才能开孔。碎屑从怪物掉落，三合一升级。")
				for g in list:
					var it: Dictionary = g.it
					var mx := Game.max_sockets(it)
					var have: int = it.get("sockets", []).size()
					var holes: PackedStringArray = []
					for s in it.get("sockets", []):
						holes.append(str(Data.rune_by_id(str(s.id)).get("g", "◆")) if s else "○")
					_plab("%s  ·  %s  孔 %d/%d  %s" % [it.name, g.where, have, mx if mx else have, " ".join(holes)])
					if it.get("phrase"):
						var ph := Data.phrase_by_id(str(it.phrase))
						_plab("「%s」已念出，拆不开" % ph.get("n", it.phrase), 12)
					var loc: String = g.loc
					if have < mx:
						_btn("打孔 %d 金" % Game.punch_cost(it), func():
							if Game.do_punch(loc):
								open_npc("kaden")
						)
					var si := 0
					for s in it.get("sockets", []):
						if not s:
							var sidx := si
							_btn("镶入第 %d 孔" % (sidx + 1), func():
								_socket_pick = {"loc": loc, "idx": sidx}
								open_npc("kaden")
							)
						si += 1
					if not it.get("phrase"):
						var filled := false
						for s in it.get("sockets", []):
							if s:
								filled = true
								break
						if filled:
							_btn("取出碎屑", func():
								if Game.do_socket_out(loc):
									open_npc("kaden")
							)
		"craft":
			var groups := {}
			for it in Game.P.bag:
				if it.get("type") != "rune":
					continue
				var key := "%s_%d" % [it.runeId, int(it.get("grade", 1))]
				if not groups.has(key):
					groups[key] = {"id": it.runeId, "g": int(it.get("grade", 1)), "n": 0, "sample": it}
				groups[key].n += 1
			if groups.is_empty():
				_plab("行囊里没有碎屑。精英和普通怪都会掉。")
			for key in groups.keys():
				var r: Dictionary = groups[key]
				var need := 3 - int(r.n)
				var line := "%s ×%d" % [r.sample.name, r.n]
				if int(r.g) >= 3:
					_plab(line + "  ·  已经是完整的了")
				elif int(r.n) >= 3:
					_btn(line + "  ·  合成 %d 金" % (30 * int(r.g)), func():
						Game.combine_rune(str(r.id), int(r.g))
						open_npc("kaden")
					)
				else:
					_plab(line + "  ·  还差 %d 枚" % need)
		"phrase":
			Game.rebuild_powers()
			for p in Data.PHRASES:
				var known := Game.known_phrase(p.id)
				var on := Game.phrase_on(p.id)
				var names: PackedStringArray = []
				for i in p.runes.size():
					if not known and i > 0:
						names.append("？")
					else:
						names.append(str(Data.rune_by_id(p.runes[i]).get("n", "?")))
				_plab(("「%s」" % p.n) if known else "想不起来的念法")
				_plab("%s · %d 孔 · %s%s" % [Game.phrase_need(p), int(p.need), " + ".join(names), " · 正在生效" if on else ""], 12)
				_plab(p.pw if known else "残句会写出其中几个字。精英和首领掉。", 12)
		"redeem":
			_plab("四十枚信物换一件专属。章节 Boss 会掉。")
			if typeof(Game.P.tokens) != TYPE_DICTIONARY:
				Game.P.tokens = {}
			for b in LootData.TOKEN_ORDER:
				var n: int = int(Game.P.tokens.get(b, 0))
				var pool: Array = LootData.unique_pool(b, false)
				_plab("%s · %d / 40" % [LootData.TOKEN_N.get(b, b), n], 14)
				if n >= 40 and pool.size():
					for u in pool:
						_btn("兑换 %s" % u.n, func():
							Game.redeem_unique(str(u.id))
							open_npc("kaden")
						)
				else:
					_plab("还差 %d 枚" % maxi(0, 40 - n), 12)
	_btn("关掉", func(): _close_sheet())


func _open_mara() -> void:
	_plab("药剂商 玛拉", 20)
	_plab("想不起来的东西拿来。我替你记。")
	var unk := Game.count_unknown()
	_plab("回想（想不起来的东西 %d 件 · 纸条 %d 张）" % [unk, int(Game.P.get("recallNotes", 0))])
	var rec := _shop_grid(2)
	_sitem(rec, "🕯", "替我想起来", "免费", UiKit.brass(), ("回想全部 %d 件" % unk) if unk else "行囊里没有想不起来的东西", func():
		var n := Game.identify_all()
		if not n:
			Game.hint("没有想不起来的东西")
			return
		Sfx.loot()
		Game.say("玛拉替你想起了 %d 件东西。" % n)
		open_npc("mara")
	, unk == 0)
	_sitem(rec, "📜", "回想的纸条 ×1", "%d 金" % Game.shop_price(60), Color(0.96, 0.77, 0.32), "急的话拿去地下自己用", func():
		Game.buy_potion("note")
		open_npc("mara")
	)
	_plab("补给（金币 %d）" % Game.P.gold)
	var pp := Game.shop_price(Game.pot_price())
	var pots := _shop_grid(2)
	_sitem(pots, "🧪", "治疗药水 ×1", "%d 金" % pp, Color(0.75, 0.25, 0.19), "当前 %d 瓶" % Game.P.potHp, func():
		Game.buy_potion("hp")
		open_npc("mara")
	)
	_sitem(pots, "🔵", "法力药水 ×1", "%d 金" % pp, Color(0.35, 0.55, 0.9), "当前 %d 瓶" % Game.P.potMp, func():
		Game.buy_potion("mp")
		open_npc("mara")
	)
	_sitem(pots, "🧰", "治疗药水 ×5", "%d 金" % Game.shop_price(Game.pot_price() * 5), Color(0.75, 0.25, 0.19), "", func():
		Game.buy_potion("hp5")
		open_npc("mara")
	)
	_sitem(pots, "🧰", "法力药水 ×5", "%d 金" % Game.shop_price(Game.pot_price() * 5), Color(0.35, 0.55, 0.9), "", func():
		Game.buy_potion("mp5")
		open_npc("mara")
	)
	_btn("关掉", func(): _close_sheet())


func _open_stash() -> void:
	_plab("银行", 20)
	_plab("石桥镇的金库不分人。你存进去的，别的旅人也能取。密码就是：没有密码。")
	var stash: Array = Game.stash_items()
	_plab("银行 %d / %d · 左键取出" % [stash.size(), Cfg.STASH])
	var si := 0
	for it in stash:
		var idx := si
		_btn("取回  %s" % it.get("name", "?"), func():
			Game.stash_take(idx)
			open_npc("stash")
		)
		si += 1
	if stash.is_empty():
		_plab("金库是空的。")
	_plab("行囊 %d / %d · 左键存入" % [Game.P.bag.size(), Cfg.BAG])
	var bi := 0
	for it in Game.P.bag:
		var idx := bi
		var label := "想不起来的东西" if it.get("unknown") else str(it.name)
		_btn("存入  %s" % label, func():
			Game.stash_put(idx)
			open_npc("stash")
		)
		bi += 1
	if Game.P.bag.is_empty():
		_plab("行囊是空的。")
	_btn("关掉", func(): _close_sheet())


func _open_board() -> void:
	Game.ensure_bounties()
	_plab("悬赏板", 20)
	_plab("%s · 完成 %d / 5 · 三成开箱" % [Game.P.bountyDay, Game.claimed_count()])
	_plab("每天五张纸条。钉死三张，箱子就会响一声。")
	var claimed = Game.P.get("bountyClaimed", {})
	if typeof(claimed) != TYPE_DICTIONARY:
		claimed = {}
	for b in Game.P.bountyList:
		var p: int = Game.bounty_prog(b)
		var need: int = Game.bounty_need(b)
		var done: bool = Game.bounty_done(b)
		var got: bool = claimed.get(str(b.id)) == true
		var show := "第 %s / 第 %s" % [Cfg.roman(int(WorldState.W.get("riftDeepest", 1))), Cfg.roman(int(b.need))] if str(b.type) == "rift" else "%d / %d" % [p, need]
		_plab(str(b.n) + ("  已领" if got else ""))
		_plab(str(b.d), 12)
		if not got:
			_plab("进度 %s%s" % [show, " · 可领取" if done else ""], 12)
		_plab("奖励：%d 金币 · %d 经验" % [int(b.gold), int(b.xp)], 12)
		if done and not got:
			_btn("领取 · " + str(b.n), func():
				Game.claim_bounty(str(b.id))
				open_npc("board")
			)
	if Game.claimed_count() >= 3 and not Game.P.get("bountyChest"):
		_plab("今日三成")
		_btn("打开日俸木箱", func():
			Game.claim_bounty_chest()
			open_npc("board")
		)
	elif Game.P.get("bountyChest"):
		_plab("今日木箱已领")
	_btn("关掉", func(): _close_sheet())


func _start_gamble(side: String) -> void:
	if _die_spin > 0.0:
		return
	if Game.P.gold < Game.gamble_cost():
		Game.hint("金币不足")
		return
	_die_side = side
	_die_spin = 0.55
	if _die_lab and is_instance_valid(_die_lab):
		_die_lab.add_theme_color_override("font_color", UiKit.brass())


func open_waystone() -> void:
	_clear_panel()
	_show_panel()
	_plab("传送石碑", 20)
	_plab("你走过的路，石头都记得。五章打完，它可以带你走另一遍。")
	var row := HBoxContainer.new()
	_panel_body.add_child(row)
	for id in Data.DIFF_ORDER:
		var D: Dictionary = Data.DIFF[id]
		var b := Button.new()
		b.text = D.n
		b.disabled = not Game.diff_unlocked(id)
		b.pressed.connect(func():
			Game.way_diff_pick = id
			open_waystone()
		)
		if Game.way_diff_pick == id:
			b.modulate = Color(1.2, 1.05, 0.7)
		row.add_child(b)
	for id in Data.AREA.keys():
		var a: Dictionary = Data.AREA[id]
		var here: bool = id == str(WorldState.W.area.get("id", "")) and Game.way_diff_pick == Game.diff_id()
		var known: bool = WorldState.W.discovered.get(id, false)
		var allow := Game.can_enter_diff(Game.way_diff_pick, id)
		if here:
			_plab("· %s（你在这里）" % a.n)
		elif known and allow:
			_btn("前往 " + a.n, func():
				_panel.visible = false
				Sfx.portal()
				var mode := "well" if str(a.get("kind", "")) == "town" else "gate"
				Game.go_place("area", id, Game.way_diff_pick, mode)
				_apply_pal()
			)
		elif known:
			_plab("· %s（%s还没走到这一章）" % [a.n, Data.DIFF[Game.way_diff_pick].n])
		else:
			_plab("· %s（尚未探明）" % a.n)
	_btn("关掉", func(): _close_sheet())


func _close_sheet() -> void:
	_panel.visible = false
	if _sheet_veil:
		_sheet_veil.visible = false
	_sheet = ""
	_sync_nav()
	_hide_tip()


func open_char() -> void:
	_sheet = "char"
	_open_gear()


func open_bag() -> void:
	_sheet = "bag"
	_open_gear()


func _open_gear() -> void:
	_clear_panel()
	_show_panel()
	_rebuild_doll()
	_hd("%s  ·  %s  %d 级" % [Game.displayed_name(), Data.CLASSES[Game.P.cls].n, Game.P.lvl])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_child(row)
	var doll_col := VBoxContainer.new()
	doll_col.add_child(_paper_doll())
	row.add_child(doll_col)
	var stats := VBoxContainer.new()
	stats.custom_minimum_size = Vector2(300, 0)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stats)
	_stat_panel(stats)
	var rule := ColorRect.new()
	rule.color = Color(0.69, 0.55, 0.31, 0.22)
	rule.custom_minimum_size = Vector2(1, 420)
	row.add_child(rule)
	var inv := VBoxContainer.new()
	inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv.add_theme_constant_override("separation", 8)
	row.add_child(inv)
	var hint := Label.new()
	hint.text = "左键装备或鉴定  ·  右键丢弃"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UiKit.ash())
	inv.add_child(hint)
	UiKit.group(inv, "遗物袋  %d / %d  ·  纸条 %d" % [Game.charm_used(), Cfg.CHARM, int(Game.P.get("recallNotes", 0))])
	_charm_grid(inv)
	UiKit.group(inv, "行囊")
	_bag_grid(inv)
	var foot := HBoxContainer.new()
	inv.add_child(foot)
	var gold := Label.new()
	gold.text = "金币  %d" % Game.P.gold
	gold.add_theme_font_size_override("font_size", 16)
	gold.add_theme_color_override("font_color", UiKit.gold())
	foot.add_child(gold)
	var cnt := Label.new()
	cnt.text = "%d / %d" % [Game.P.bag.size(), Cfg.BAG]
	cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_color_override("font_color", UiKit.ash())
	foot.add_child(cnt)


func open_skills() -> void:
	_sheet = "skills"
	_clear_panel()
	_show_panel()
	_hd("技能  ·  点 %d" % Game.P.skPts)
	var skills: Array = Data.class_skills(Game.P.cls)
	if _sk_sel == "":
		_sk_sel = str(skills[0].id) if skills.size() else ""
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_child(split)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	split.add_child(list)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(320, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail)
	var picked: Dictionary = {}
	for sk in skills:
		var sid: String = str(sk.id)
		var rk := int(Game.P.ranks.get(sid, 0))
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 64)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.stamp_btn(row, UiKit.icon_for_skill(sid), "%s\n等级 %d  ·  需求 %d" % [sk.n, rk, int(sk.req)], 40, true)
		row.add_theme_stylebox_override("normal", UiKit.cell(0xb08d4f) if sid == _sk_sel else UiKit.gcard())
		row.add_theme_stylebox_override("hover", UiKit.cell_hover())
		if rk <= 0:
			row.add_theme_color_override("font_color", UiKit.ash())
		row.pressed.connect(_pick_skill_id.bind(sid))
		list.add_child(row)
		if sid == _sk_sel:
			picked = sk
	if picked.is_empty():
		return
	detail.add_child(UiKit.icon_rect(UiKit.icon_for_skill(str(picked.id)), 64))
	var nm := Label.new()
	nm.text = str(picked.n)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", UiKit.brass_hi())
	detail.add_child(nm)
	var meta := Label.new()
	meta.text = "法力 %d  ·  冷却 %.1fs  ·  %s" % [int(picked.mp), float(picked.cd), str(picked.get("kind", ""))]
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", UiKit.ash())
	detail.add_child(meta)
	var rk2 := int(Game.P.ranks.get(str(picked.id), 0))
	var rk_l := Label.new()
	rk_l.text = "已学 %d 级  ·  需求等级 %d" % [rk2, int(picked.req)]
	rk_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rk_l.add_theme_color_override("font_color", Color(0.49, 0.66, 0.85))
	detail.add_child(rk_l)
	var pid: String = str(picked.id)
	var learn := Button.new()
	learn.text = "学习"
	learn.pressed.connect(func():
		Game.learn_skill(pid)
		open_skills()
	)
	detail.add_child(learn)
	if rk2 > 0:
		var put := Button.new()
		put.text = "点底部栏位…" if _sk_assign == pid else "放入技能栏"
		put.pressed.connect(func():
			_sk_assign = pid
			open_skills()
		)
		detail.add_child(put)
	if Data.SK_RUNES.has(pid) and rk2 > 0:
		UiKit.group(detail, "符文")
		for rn in Data.SK_RUNES[pid]:
			var on: bool = Game.sk_rune(pid) == str(rn.id)
			var rb := Button.new()
			rb.text = "%s%s\n%s" % [rn.n, "  ·  已装" if on else "", rn.d]
			rb.add_theme_stylebox_override("normal", UiKit.cell() if on else UiKit.gcard())
			var rid: String = str(rn.id)
			rb.pressed.connect(func():
				Game.set_sk_rune(pid, rid)
				open_skills()
			)
			detail.add_child(rb)
		if Game.sk_rune(pid) != "":
			var off := Button.new()
			off.text = "卸下符文"
			off.pressed.connect(func():
				Game.set_sk_rune(pid, "")
				open_skills()
			)
			detail.add_child(off)
	if _sk_assign != "":
		var brow := HBoxContainer.new()
		detail.add_child(brow)
		for i in 6:
			var b := Button.new()
			b.text = str(i + 1)
			b.custom_minimum_size = Vector2(44, 44)
			b.add_theme_stylebox_override("normal", UiKit.slot())
			b.pressed.connect(_assign_skill_slot.bind(i))
			brow.add_child(b)
		var mrow := HBoxContainer.new()
		detail.add_child(mrow)
		var lb := Button.new()
		lb.text = "左键"
		lb.custom_minimum_size = Vector2(72, 44)
		lb.pressed.connect(func():
			Game.assign_mouse(_sk_assign, 0)
			_sk_assign = ""
			open_skills()
		)
		mrow.add_child(lb)
		var rb := Button.new()
		rb.text = "右键"
		rb.custom_minimum_size = Vector2(72, 44)
		rb.pressed.connect(func():
			Game.assign_mouse(_sk_assign, 1)
			_sk_assign = ""
			open_skills()
		)
		mrow.add_child(rb)


func open_talents() -> void:
	_sheet = "talents"
	_clear_panel()
	_show_panel()
	_hd("天赋  ·  点 %d  ·  已点 %d / %d" % [Game.tal_pts(), Game.tal_spent(), Game.tal_earned()])
	if Game.P.lvl < 10:
		_plab("10 级点亮第一格，20 级点亮第二格。")
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	_panel_body.add_child(cols)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)
	var i := 0
	for t in Game.class_talents():
		var box: VBoxContainer = left if i % 2 == 0 else right
		var on: bool = Game.tal_rank(str(t.id)) > 0
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		box.add_child(head)
		head.add_child(UiKit.icon_rect(UiKit.icon_for_glyph(str(t.g)), 28))
		var l := Label.new()
		l.text = str(t.n)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.54, 0.87, 0.5) if on else UiKit.brass())
		head.add_child(l)
		var d := Label.new()
		d.text = str(t.d)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 12)
		box.add_child(d)
		if on:
			var ok := Label.new()
			ok.text = "已点亮"
			ok.add_theme_font_size_override("font_size", 12)
			box.add_child(ok)
		elif Game.tal_can(t):
			var b := Button.new()
			b.text = "点亮"
			var tal: Dictionary = t
			b.pressed.connect(func():
				Game.learn_talent(tal)
				open_talents()
			)
			box.add_child(b)
		i += 1
	if Game.tal_spent() > 0:
		_btn("洗点 %d 金" % Game.tal_reset_cost(), func():
			Game.reset_talents()
			open_talents()
		)
	_btn("关掉", func(): _close_sheet())


func open_quests() -> void:
	_sheet = "quests"
	_clear_panel()
	_show_panel()
	_hd("委托")
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	_panel_body.add_child(split)
	var list := VBoxContainer.new()
	var detail := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(list)
	split.add_child(detail)
	var picked: Dictionary = {}
	for q in Data.QUESTS:
		var st: String = Game.P.quests.get(q.id, {}).get("state", "locked")
		if st == "locked":
			continue
		if _quest_sel == "" and st == "open":
			_quest_sel = str(q.id)
		var mark := "完成" if st == "done" else "%d/%d" % [Game.quest_prog(q), int(q.need)]
		var b := Button.new()
		b.text = "%s  ·  %s" % [q.n, mark]
		if str(q.id) == _quest_sel:
			b.modulate = Color(1.2, 1.05, 0.7)
			picked = q
		b.pressed.connect(func():
			_quest_sel = str(q.id)
			open_quests()
		)
		list.add_child(b)
	if picked.is_empty():
		var empty := Label.new()
		empty.text = "板上暂时没有你的名字。"
		detail.add_child(empty)
	else:
		var n := Label.new()
		n.text = str(picked.n)
		n.add_theme_font_size_override("font_size", 18)
		n.add_theme_color_override("font_color", UiKit.brass())
		detail.add_child(n)
		var d := Label.new()
		d.text = str(picked.d)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(d)
		var p := Label.new()
		p.text = "进度 %d / %d  ·  奖励 %d 金 / %d 经验" % [Game.quest_prog(picked), int(picked.need), int(picked.gold), int(picked.xp)]
		detail.add_child(p)
		if Game.P.quests.get(picked.id, {}).get("state") == "open":
			var pin := Button.new()
			pin.text = "取消追踪" if Game.P.trackId == picked.id else "追踪此任务"
			pin.pressed.connect(func():
				Game.set_track("" if Game.P.trackId == picked.id else str(picked.id))
				open_quests()
			)
			detail.add_child(pin)
	_btn("关掉", func(): _close_sheet())


func _on_world_ui(kind: String, payload: Dictionary) -> void:
	if kind == "rift":
		open_rift_panel()
	elif kind == "rift_go":
		open_rift_go_panel(int(payload.get("depth", 1)), payload.get("fromNext") == true)
	elif kind == "shrine":
		open_shrine_panel(payload)
	elif kind == "dungeon":
		open_dungeon_panel(str(payload.get("id", "")))


func open_dungeon_panel(id: String) -> void:
	_sheet = "dungeon"
	_clear_panel()
	_show_panel()
	var d := Data.dun_by_id(id)
	if d.is_empty():
		_close_sheet()
		return
	var boss: Dictionary = Data.ETYPES.get(str(d.boss), {})
	_hd(str(d.n))
	_plab("建议等级 %d · %d 层 · %s" % [int(d.lvl), int(d.floors), "已通关" if Game.dun_cleared_on(id) else "未通关"])
	_plab(str(d.desc))
	var row := HBoxContainer.new()
	_panel_body.add_child(row)
	for diff in Data.DIFF_ORDER:
		var D: Dictionary = Data.DIFF[diff]
		var b := Button.new()
		b.text = D.n
		b.disabled = not Game.can_enter_diff(diff, id)
		if Game.diff_id() == diff:
			b.modulate = Color(1.2, 1.05, 0.7)
		b.pressed.connect(func():
			Game.set_diff(diff)
			open_dungeon_panel(id)
		)
		row.add_child(b)
	_plab("首领：%s" % str(boss.get("n", d.boss)))
	_plab("通关后可获得首通奖励；重复通关仍会掉落对应等级的装备。每个难度单独算首通。", 12)
	if Game.P.lvl < int(d.lvl) - 2:
		_plab("你的等级低于建议等级，进去会很难看。", 12)
	_btn("进入副本", func():
		_close_sheet()
		Sfx.portal()
		Game.go_place("dungeon", id, Game.diff_id())
		_apply_pal()
	)
	_btn("再等等", func(): _close_sheet())


func open_rift_panel() -> void:
	_clear_panel()
	_show_panel()
	var deep := int(WorldState.W.get("riftDeepest", 0))
	_hd("裂隙")
	_plab("已探明：第 %d 层 · 无限层数，越深越强" % deep)
	_plab("下去容易，回来才难。第五层起，每一层都会带上一两句话。")
	_btn("从第 1 层开始", func(): open_rift_go_panel(1, false))
	if deep > 1:
		_btn("前往第 %d 层" % deep, func(): open_rift_go_panel(deep, false))
	_btn("再等等", func(): _close_sheet())


func open_rift_go_panel(depth: int, from_next: bool) -> void:
	_clear_panel()
	_show_panel()
	var o := Game.ensure_rift_offer(depth)
	var ids = o.get("ids", [])
	_hd("裂隙 第 %s 层" % Cfg.roman(depth))
	_plab("%s · %s" % [Game.diff_now().n, "门后带着词缀 · 下去前看清楚" if (typeof(ids) == TYPE_ARRAY and ids.size()) else "无限地下层 · 越深越强"])
	if typeof(ids) == TYPE_ARRAY:
		for rid in ids:
			var a := Data.rift_affix_by_id(str(rid))
			if a.is_empty():
				continue
			_plab("%s %s  掉落 +%d%%" % [a.get("g", ""), a.n, int(a.get("loot", 0))])
			_plab(str(a.d), 12)
		if ids.size():
			_plab("本层掉落 +%d%%" % Game.rift_loot_of(ids))
	_btn("下去", func():
		_panel.visible = false
		if from_next and not WorldState.W.get("usedPot"):
			Game.P.bountyPotless = int(Game.P.get("bountyPotless", 0)) + 1
		WorldState.enter_rift(depth)
		_apply_pal()
	)
	if typeof(ids) == TYPE_ARRAY and ids.size():
		var cost := Game.rift_reroll_cost(depth, int(o.get("rerolls", 0)))
		_btn("换一层 · %d 金" % cost, func():
			Game.reroll_rift_offer()
			open_rift_go_panel(depth, from_next)
		)
	_btn("再等等", func(): _close_sheet())


func open_shrine_panel(m: Dictionary) -> void:
	_clear_panel()
	_show_panel()
	_hd("祭坛")
	if str(WorldState.W.get("shrine", "")) != "":
		_plab("这一层已经许过了")
		_plab("许过的愿这一层都算数。出去才散。")
		_btn("知道了", func(): _close_sheet())
		return
	_plab("三选一 · 离开本层才散")
	_plab("有人还在这里许愿。你也可以。只能许一次。")
	for s in Data.SHRINE_PICKS:
		var sid: String = str(s.id)
		_btn("%s %s  ·  %s" % [s.g, s.n, s.d], func():
			WorldState.pick_shrine(sid, m)
			_panel.visible = false
		)
	_btn("再等等", func(): _close_sheet())
