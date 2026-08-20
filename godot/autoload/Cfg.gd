extends Node
## 与网页版 CFG / 坐标函数一一对应。

const TILE := 2.0
const MAP := 68
const MAXLIGHT := 5
const BAG := 40
const STASH := 40
const CHARM := 24
const CAM_OFF := Vector3(0, 27, 21)
const FOV := 48.0
const SAVE_SLOTS := 3

var _rng := RandomNumberGenerator.new()
var _seed: int = 20260819


func _ready() -> void:
	seed_rng(20260819)


func seed_rng(s: int) -> void:
	_seed = s
	_rng.seed = s & 0xFFFFFFFF


func rf(a: float, b: float) -> float:
	return a + _rng.randf() * (b - a)


func ri(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]


func gi(x: int, y: int) -> int:
	return y * MAP + x


func wx(t: float) -> float:
	return (t - MAP * 0.5) * TILE


func tx(x: float) -> int:
	return int(round(x / TILE + MAP * 0.5))


func tz(z: float) -> int:
	return int(round(z / TILE + MAP * 0.5))


func dist2(ax: float, az: float, bx: float, bz: float) -> float:
	var dx := ax - bx
	var dz := az - bz
	return dx * dx + dz * dz


func hypot(a: float, b: float) -> float:
	return sqrt(a * a + b * b)


func hex_color(h: int) -> Color:
	return Color(
		((h >> 16) & 255) / 255.0,
		((h >> 8) & 255) / 255.0,
		(h & 255) / 255.0
	)


func tint_hex(a: int, b: int, t: float) -> int:
	var ar := (a >> 16) & 255
	var ag := (a >> 8) & 255
	var ab := a & 255
	var br := (b >> 16) & 255
	var bg := (b >> 8) & 255
	var bb := b & 255
	var r := int(ar + (br - ar) * t)
	var g := int(ag + (bg - ag) * t)
	var bl := int(ab + (bb - ab) * t)
	return (r << 16) | (g << 8) | bl


func today_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


func hash_str(s: String) -> int:
	var h: int = 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) * 16777619
		h = h & 0xFFFFFFFF
	return h


func roman(n: int) -> String:
	var rn := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
		"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
	if n < rn.size():
		return rn[n]
	return "XX+" + str(n - 20)
