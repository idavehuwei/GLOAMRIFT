# res://scripts/ObjectPool.gd
# 通用对象池(设计参考 godot-object-pool / cms-pm/zort)。
# 预分配一批实例并复用,避免战斗 / 特效中反复 instantiate / queue_free 造成的分配抖动与 GC 压力。
# 典型用途:投射物、伤害数字、粒子特效、临时怪物。
#
# 用法:
#   var pool := ObjectPool.new(bullet_scene, get_tree().current_scene, 64, "bullet")
#   var b := pool.obtain()
#   # ... 使用 b ...
#   pool.release(b)   # 对象"死亡"时归还

class_name ObjectPool
extends RefCounted

var _scene: PackedScene
var _parent: Node
var _prefix: String
var _pool: Array[Node] = []
var _active: Array[Node] = []

func _init(scene: PackedScene, parent: Node, size: int, prefix: String = "pooled") -> void:
	_scene = scene
	_parent = parent
	_prefix = prefix
	for i in size:
		var inst := _scene.instantiate()
		inst.name = "%s_%d" % [prefix, i]
		inst.visible = false
		if inst.has_method("set_process"):
			inst.set_process(false)
			inst.set_physics_process(false)
		_parent.add_child(inst)
		_pool.append(inst)

## 取出一个未使用实例;池耗尽时动态扩容一个(仍优于无池时反复创建)。
func obtain() -> Node:
	var inst: Node
	if not _pool.is_empty():
		inst = _pool.pop_back()
	else:
		inst = _scene.instantiate()
		inst.name = "%s_dyn_%d" % [_prefix, _active.size()]
		_parent.add_child(inst)
	inst.visible = true
	if inst.has_method("set_process"):
		inst.set_process(true)
		inst.set_physics_process(true)
	_active.append(inst)
	return inst

## 归还实例(通常由对象自身在"死亡 / 命中"时调用)。
func release(inst: Node) -> void:
	var idx := _active.find(inst)
	if idx == -1:
		return
	_active.remove_at(idx)
	inst.visible = false
	if inst.has_method("set_process"):
		inst.set_process(false)
		inst.set_physics_process(false)
	_pool.append(inst)

func active_count() -> int:
	return _active.size()

func pool_count() -> int:
	return _pool.size()
