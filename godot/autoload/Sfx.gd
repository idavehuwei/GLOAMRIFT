extends Node
## 程序化音效，对应网页版 SFX 振荡器。

var _on := true
var _player: AudioStreamPlayer
var _gen := AudioStreamGenerator.new()
var _playback: AudioStreamGeneratorPlayback
var _sample_hz := 22050.0


func _ready() -> void:
	_gen.mix_rate = _sample_hz
	_gen.buffer_length = 0.35
	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	_player.volume_db = -8.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func toggle() -> bool:
	_on = not _on
	return _on


func hit() -> void:
	_blip(160.0, 0.09, 0.08, 80.0)


func swing() -> void:
	_blip(90.0, 0.07, 0.04, 40.0)


func bow() -> void:
	_blip(300.0, 0.08, 0.05, 900.0)


func cast() -> void:
	_blip(420.0, 0.22, 0.07, 900.0)


func frost() -> void:
	_blip(880.0, 0.35, 0.06, 180.0)


func boom() -> void:
	_blip(90.0, 0.4, 0.1, 40.0)


func hurt() -> void:
	_blip(220.0, 0.2, 0.08, 90.0)


func die() -> void:
	_blip(120.0, 0.4, 0.09, 45.0)


func gold() -> void:
	_blip(1400.0, 0.07, 0.05)
	await get_tree().create_timer(0.055).timeout
	_blip(1900.0, 0.07, 0.04)


func loot() -> void:
	_blip(700.0, 0.1, 0.06, 1200.0)


func legend() -> void:
	_blip(180.0, 0.18, 0.09, 90.0)
	await get_tree().create_timer(0.08).timeout
	_blip(520.0, 0.22, 0.08, 980.0)
	await get_tree().create_timer(0.1).timeout
	_blip(880.0, 0.28, 0.07, 1400.0)


func level() -> void:
	for f in [523.0, 659.0, 784.0, 1046.0]:
		_blip(f, 0.22, 0.08)
		await get_tree().create_timer(0.09).timeout


func quest() -> void:
	for f in [659.0, 784.0, 988.0]:
		_blip(f, 0.28, 0.07)
		await get_tree().create_timer(0.13).timeout


func ach() -> void:
	for f in [523.0, 784.0, 1046.0]:
		_blip(f, 0.2, 0.08)
		await get_tree().create_timer(0.1).timeout


func potion() -> void:
	_blip(300.0, 0.18, 0.06, 760.0)


func portal() -> void:
	_blip(120.0, 0.5, 0.07, 600.0)


func ui() -> void:
	_blip(900.0, 0.05, 0.03)


func _blip(freq: float, dur: float, vol: float, end_f: float = -1.0) -> void:
	if not _on or _playback == null:
		return
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback()
	var n := int(dur * _sample_hz)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(max(n, 1))
		var f := freq if end_f < 0.0 else lerpf(freq, end_f, t)
		phase += TAU * f / _sample_hz
		var env := vol * sin(t * PI)
		if _playback.get_frames_available() > 0:
			_playback.push_frame(Vector2.ONE * sin(phase) * env)
