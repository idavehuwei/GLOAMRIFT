# res://autoload/ThreadPool.gd
# 基于 Godot 4 WorkerThreadPool 的后台任务封装。
# 设计参考:Godot 官方 WorkerThreadPool 文档样例、godot-performance-optimization skill。
#
# 适用场景:与场景树 / 渲染 / 物理 / 资源加载无关的"纯数据"重计算,
#   例如 A* 寻路、世界生成、大批量数据解析。
# 线程安全红线:worker 线程内严禁操作节点、访问场景树、调用非线程安全的 Godot API。
#   计算结果一律通过 call_deferred 回主线程,避免跨线程访问场景树。

extends Node

## 提交单个后台任务。action 在 worker 线程执行(返回值作为结果),
## 完成后在主线程以 call_deferred 调用 on_done.call(result)。
## 返回 task id,可配合 is_done / wait 使用。
func submit(action: Callable, on_done: Callable = Callable()) -> int:
	return WorkerThreadPool.add_task(
		func() -> void:
			var result = action.call()
			if on_done.is_valid():
				call_deferred("_deliver", on_done, result)
	)

func _deliver(cb: Callable, result: Variant) -> void:
	cb.call(result)

## 提交分组任务:action(index) 由 worker 线程按 index=0..elements-1 多次执行,
## 适合"遍历大量独立元素"(如敌人 AI、网格计算)。结果汇总由调用方自行处理。
## 返回 group id,可配合 is_group_done / wait_group 使用。
func submit_group(action: Callable, elements: int, high_priority: bool = false) -> int:
	return WorkerThreadPool.add_group_task(action, elements, -1, high_priority)

func is_done(task_id: int) -> bool:
	return WorkerThreadPool.is_task_completed(task_id)

func wait(task_id: int) -> void:
	WorkerThreadPool.wait_for_task_completion(task_id)

func is_group_done(group_id: int) -> bool:
	return WorkerThreadPool.is_group_task_completed(group_id)

func wait_group(group_id: int) -> void:
	WorkerThreadPool.wait_for_group_task_completion(group_id)
