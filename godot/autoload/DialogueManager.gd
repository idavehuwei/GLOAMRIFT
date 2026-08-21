extends Node
## 对话数据管理：解耦 UI 与对话数据源，并支持分支选项。
## 设计参考 DialogueQuest 的「写手 / 程序分离」思路——UI 只调用本管理器，
## 不直接依赖具体数据模块；未来可无缝切换为 .tres 资源库而不改 UI。
##
## 当前数据后端：TalkData（静态 Q&A 字典，autoload）。本管理器是其稳定门面，
## 并额外提供分支(branch)能力：topic dict 含 branch:[{label, next}] 时即多选项对话。

func open(id: String) -> void:
	EventBus.dialogue_opened.emit(id)


func greet(id: String) -> String:
	return TalkData.greet(id)


func topics(id: String) -> Array:
	return TalkData.topics(id)


func answer(id: String, tid: String) -> String:
	return TalkData.answer(id, tid)


## 某主题是否含分支选项（默认数据暂无，预留扩展）。
func has_branch(t: Variant) -> bool:
	if typeof(t) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = t
	return d.has("branch")


func branch_of(t: Variant) -> Array:
	if not has_branch(t):
		return []
	var d: Dictionary = t
	return d.get("branch", [])
