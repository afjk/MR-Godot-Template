extends Node

## Autoload。シーンに`XROrigin3D`が無ければ`mr_stage.tscn`を挿す。
##
## これがあるおかげで、`samples/*/sample.tscn`をエディタで開いてF6を押すだけで、
## そのサンプル単体をMRで実行できます。ランチャー経由でも同じ経路を通ります。
##
## 土台はシーンが入った直後に作られるため、サンプルの`_ready()`より後になることが
## あります。サンプル側は`await SampleBootstrap.stage_async()`で受け取ってください。

## 土台の用意ができた。
signal stage_ready(stage: MRStage)

const STAGE_SCENE := "res://shared/mr_stage.tscn"

## 現在のシーンに挿さっているMRの土台。まだ無ければnull。
var stage: MRStage

var _known_scene: Node


func _ready() -> void:
	# Autoloadはmain sceneより先に走るため、シーンが入るのを1フレーム待つ。
	_ensure_stage.call_deferred()


func _process(_delta: float) -> void:
	# `change_scene_to_file()`で切り替わった場合も土台を挿し直す。
	if get_tree().current_scene != _known_scene:
		_ensure_stage()


## 土台を受け取る。まだ無ければ用意できるまで待つ。
func stage_async() -> MRStage:
	if stage == null:
		await stage_ready

	return stage


func _ensure_stage() -> void:
	var scene := get_tree().current_scene
	_known_scene = scene
	if scene == null:
		return

	var existing := get_tree().get_first_node_in_group(&"mr_stage") as MRStage
	if existing != null and scene.is_ancestor_of(existing):
		_set_stage(existing)
		return

	if _find_origin(scene) != null:
		# サンプルが独自のリグを持っている場合は手を出さない。
		return

	var instance: MRStage = load(STAGE_SCENE).instantiate()
	scene.add_child(instance)
	# サンプル側のノードより先に並べ、エディタ上の見え方と揃える。
	scene.move_child(instance, 0)
	_set_stage(instance)


func _set_stage(instance: MRStage) -> void:
	if stage == instance:
		return

	stage = instance
	stage_ready.emit(stage)


func _find_origin(node: Node) -> XROrigin3D:
	if node is XROrigin3D:
		return node

	for child in node.get_children():
		var found := _find_origin(child)
		if found != null:
			return found

	return null
