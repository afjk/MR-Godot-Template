extends Node3D

## 部屋メッシュ: 事前スキャン済みの部屋の形（壁・床・家具・部屋全体のメッシュ）を
## 取り出し、当たり判定と可視化を作るサンプル。
##
## 必要なもの: `xr/openxr/extensions/meta/scene_api=true`と`anchor_api=true`
##   （設定済み）、OpenXR Vendors plugin、端末側のSpace Setup（部屋のスキャン）
## 対応端末: Quest 3（`XR_FB_scene`と`XR_META_spatial_entity_mesh`）
##
## `plane_detection`が平面だけを返すのに対し、こちらは**部屋そのものの形**を
## 返します。壁や机は境界の箱として、部屋全体は三角形メッシュとして届きます。
##
## 実装の要は`OpenXRFbSceneManager`です。要素1つにつき1回、指定した`PackedScene`を
## 作って`XRAnchor3D`の下に置き、`setup_scene`を呼んでくれます。**アプリ側は
## クエリも姿勢の追従も書きません。**
##
## スキャン済みの部屋データが無ければ、pinchでSpace Setupを呼び出せます。
## データがある状態でpinchすると、表示のON/OFFが切り替わります。

const ANCHOR_SCENE := preload("res://samples/scene_mesh/scene_anchor.tscn")

var _stage: MRStage
## OpenXRFbSceneManager。pluginが無ければnull。
var _manager: Node
var _labels: Dictionary = {}
var _anchor_count := 0
var _global_mesh_count := 0
var _needs_capture := false
var _message := ""

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	_create_manager()


func _exit_tree() -> void:
	# リグにぶら下げたので、閉じるときに自分で片付ける。アンカーの解放は
	# OpenXRFbSceneManagerが木から外れるときに自分で行う。
	if is_instance_valid(_manager):
		_manager.queue_free()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_handle_pinch()
	_status.text = _build_status()


func _create_manager() -> void:
	if not ClassDB.class_exists(&"OpenXRFbSceneManager"):
		return

	_manager = ClassDB.instantiate(&"OpenXRFbSceneManager") as Node
	if _manager == null:
		return

	# 種類ごとにシーンを分けることもできる（`scenes/<label>`）。ここでは1つで受ける。
	_manager.set(&"default_scene", ANCHOR_SCENE)
	_manager.connect(&"openxr_fb_scene_anchor_created", _on_anchor_created)
	_manager.connect(&"openxr_fb_scene_data_missing", _on_scene_data_missing)
	_manager.connect(&"openxr_fb_scene_capture_completed", _on_capture_completed)

	# XROrigin3Dの直下でないと動かない。アンカーをそこへぶら下げるため。
	_stage.origin.add_child(_manager)


func _on_anchor_created(scene_node: Object, entity: Object) -> void:
	_anchor_count += 1
	_needs_capture = false

	if scene_node != null and bool(scene_node.get(&"is_global_mesh")):
		_global_mesh_count += 1
		return

	var labels := PackedStringArray(entity.call(&"get_semantic_labels"))
	var kind := labels[0] if not labels.is_empty() else "other"
	_labels[kind] = int(_labels.get(kind, 0)) + 1


func _on_scene_data_missing() -> void:
	_needs_capture = true
	_message = "部屋のスキャンがありません"


func _on_capture_completed(success: bool) -> void:
	_message = "" if success else "スキャンが完了しませんでした"
	if not success or _manager == null:
		return

	# スキャン直後は取り直しが要る。作り直せば新しい部屋データを読む。
	_reset_counts()
	_manager.call(&"remove_scene_anchors")
	_manager.call(&"create_scene_anchors")


func _handle_pinch() -> void:
	if _manager == null:
		return

	var pinched := false
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if _stage.is_pinch_just_started(hand):
			pinched = true
			break

	if not pinched:
		return

	if _needs_capture:
		if bool(_manager.call(&"is_scene_capture_supported")):
			_manager.call(&"request_scene_capture")
		return

	_manager.set(&"visible", not bool(_manager.get(&"visible")))


func _reset_counts() -> void:
	_anchor_count = 0
	_global_mesh_count = 0
	_labels.clear()


func _build_status() -> String:
	if _manager == null:
		return "部屋メッシュ\nこの端末はMeta Scene API（XR_FB_scene）を\n公開していません"

	if _needs_capture:
		return "部屋メッシュ\n%s\npinchでスキャンを始めます" % _message

	if _anchor_count == 0:
		return "部屋メッシュ\n部屋データを読み込んでいます"

	var lines: Array[String] = ["部屋メッシュ"]
	if not _message.is_empty():
		lines.append(_message)

	lines.append("要素: %d（部屋全体のメッシュ: %d）" % [_anchor_count - _global_mesh_count, _global_mesh_count])

	var parts: Array[String] = []
	for kind in _labels:
		parts.append("%s:%d" % [kind, _labels[kind]])

	if not parts.is_empty():
		lines.append(" ".join(parts))

	lines.append("表示: %s（pinchで切替）" % ("ON" if bool(_manager.get(&"visible")) else "OFF"))
	return "\n".join(lines)
