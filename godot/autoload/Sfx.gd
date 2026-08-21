extends Node
## 采样音效（Kenney CC0：rpg-audio / impact-sounds / ui-pack）。
## 接口沿用网页版 SFX 事件名，改为播放真实音频样本，多样本随机 + 轻微变调。
## 备注：Kenney 素材无魔法/号角音，施法与升级类以 impactBell_heavy 钟声按音高排布近似。

const DIR := "res://audio/"
const POOL := 10

var _on := true
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _banks := {}


func _ready() -> void:
	for _i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_banks = {
		"hit": _load(["impactSoft_medium_000", "impactSoft_medium_001", "impactSoft_medium_002", "impactSoft_medium_003", "impactSoft_medium_004"]),
		"hurt": _load(["impactPunch_medium_000", "impactPunch_medium_001", "impactPunch_medium_002", "impactPunch_medium_003", "impactPunch_medium_004"]),
		"die": _load(["impactSoft_heavy_000", "impactSoft_heavy_001", "impactSoft_heavy_002", "impactSoft_heavy_003", "impactSoft_heavy_004"]),
		"boom": _load(["impactMetal_heavy_000", "impactMetal_heavy_001", "impactMetal_heavy_002", "impactMetal_heavy_003", "impactMetal_heavy_004"]),
		"frost": _load(["impactGlass_light_000", "impactGlass_light_001", "impactGlass_light_002", "impactGlass_light_003", "impactGlass_light_004"]),
		"bell": _load(["impactBell_heavy_000", "impactBell_heavy_001", "impactBell_heavy_002", "impactBell_heavy_003", "impactBell_heavy_004"]),
		"swing": _load(["knifeSlice", "knifeSlice2", "chop"]),
		"bow": _load(["drawKnife1", "drawKnife2", "drawKnife3"]),
		"gold": _load(["handleCoins", "handleCoins2"]),
		"loot": _load(["handleSmallLeather", "handleSmallLeather2", "dropLeather"]),
		"potion": _load(["metalLatch"]),
		"ui": _load(["click-a"]),
	}


func toggle() -> bool:
	_on = not _on
	return _on


# —— 战斗 ——
func hit() -> void:
	_play("hit", -4.0, 0.95, 1.1)


func swing() -> void:
	_play("swing", -9.0, 0.9, 1.1)


func bow() -> void:
	_play("bow", -6.0, 0.95, 1.12)


func cast() -> void:
	_play("bell", -7.0, 0.92, 1.08)


func frost() -> void:
	_play("frost", -5.0, 0.9, 1.1)


func boom() -> void:
	_play("boom", -2.0, 0.82, 1.0)


func hurt() -> void:
	_play("hurt", -3.0, 0.9, 1.05)


func die() -> void:
	_play("die", -2.0, 0.78, 0.95)


# —— 拾取 ——
func gold() -> void:
	_play("gold", -5.0, 0.98, 1.06)


func loot() -> void:
	_play("loot", -6.0, 0.95, 1.08)


func potion() -> void:
	_play("potion", -5.0, 0.95, 1.1)


# —— 传送/界面 ——
func portal() -> void:
	_play_pitch("bell", -4.0, 0.6)


func ui() -> void:
	_play("ui", -8.0, 0.98, 1.04)


# —— 号角（钟声按音高上行近似）——
func legend() -> void:
	await _fanfare([0.8, 1.0, 1.25], 0.09, -3.0)


func level() -> void:
	await _fanfare([0.75, 0.95, 1.15, 1.5], 0.09, -4.0)


func quest() -> void:
	await _fanfare([1.0, 1.25, 1.5], 0.12, -4.0)


func ach() -> void:
	await _fanfare([0.9, 1.35, 1.8], 0.1, -4.0)


# —— 内部 ——
func _load(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var s := load(DIR + n + ".ogg")
		if s != null:
			out.append(s)
	return out


func _pick() -> AudioStreamPlayer:
	var p := _players[_next]
	_next = (_next + 1) % POOL
	return p


func _play(bank: String, vol_db: float, pitch_min: float, pitch_max: float) -> void:
	if not _on:
		return
	var arr: Array = _banks.get(bank, [])
	if arr.is_empty():
		return
	var p := _pick()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = vol_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()


func _play_pitch(bank: String, vol_db: float, pitch: float) -> void:
	if not _on:
		return
	var arr: Array = _banks.get(bank, [])
	if arr.is_empty():
		return
	var p := _pick()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func _fanfare(pitches: Array, gap: float, vol_db: float) -> void:
	for i in pitches.size():
		_play_pitch("bell", vol_db, pitches[i])
		if i < pitches.size() - 1:
			await get_tree().create_timer(gap).timeout
