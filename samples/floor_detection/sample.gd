extends Node3D

## 床面検知: 床の高さを3段構えで決めるサンプル。
##
## 必要なもの: Quest 3で平面を使うには`xr/openxr/extensions/meta/scene_api=true`と、
##   端末側でのSpace Setup（部屋のスキャン）
## 対応端末: 全機種（Quest 3は平面API、それ以外はLocal Floorの仮定になります）
##
## MRで最初に要るのが床の高さです。取り方は端末で違うので、上から順に試します。
##   1. 平面API: Metaのscene entityから`FLOOR`ラベルの高さを読む
##   2. 手で合わせる: 実際の床に手を置いてpinchすると、その高さを床とみなす
##   3. Local Floor: reference spaceがLocal Floorなので、XROrigin3Dのy=0が床
##
## 3段目は「検知」ではなく「仮定」です。どの段で得たかを`_source`として持ち、
## 画面にも出します。精度が要る処理は、出所を見て分岐できるようにするためです。

const FLOOR_LABEL := "FLOOR"
## 平面APIを問い合わせる間隔。毎フレーム引く必要はない。
const POLL_INTERVAL := 0.5
const MARKER_SIZE := 0.12

var _stage: MRStage
## OpenXRFbSceneManager。pluginが無い端末ではnullのまま。
var _manager: Node
var _source := "local_floor"
var _height := 0.0
var _poll_timer := 0.0
var _capture_requested := false
var _message := ""

@onready var _plane: MeshInstance3D = $FloorPlane
@onready var _marker: MeshInstance3D = $Marker
@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	# 3段目。Local Floorのy=0がそのまま床の高さになる。
	_height = _stage.origin.global_position.y
	_setup_scene_manager()


func _exit_tree() -> void:
	# リグにぶら下げたので、閉じるときに自分で片付ける。
	if is_instance_valid(_manager):
		_manager.queue_free()


func _process(delta: float) -> void:
	if _stage == null:
		return

	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = POLL_INTERVAL
		_update_from_scene()

	_calibrate_with_pinch()
	_apply()
	_update_status()


func _setup_scene_manager() -> void:
	# pluginが無い環境でもこのサンプルが読めるよう、class名から生成する。
	if not ClassDB.class_exists(&"OpenXRFbSceneManager"):
		_message = "Meta Scene APIがありません"
		return

	_manager = ClassDB.instantiate(&"OpenXRFbSceneManager") as Node
	if _manager == null:
		return

	_manager.set(&"auto_create", true)
	_manager.set(&"visible", false)
	_stage.origin.add_child(_manager)
	_manager.connect(&"openxr_fb_scene_data_missing", _on_scene_data_missing)


func _update_from_scene() -> void:
	if _manager == null:
		return

	if not bool(_manager.call(&"are_scene_anchors_created")):
		# セッション途中でぶら下げた場合は、こちらから作りにいく。
		_manager.call(&"create_scene_anchors")
		return

	for uuid in _manager.call(&"get_anchor_uuids"):
		var entity: Object = _manager.call(&"get_spatial_entity", uuid)
		if entity == null:
			continue

		var labels: PackedStringArray = entity.call(&"get_semantic_labels")
		if FLOOR_LABEL not in labels:
			continue

		var anchor := _manager.call(&"get_anchor_node", uuid) as Node3D
		if anchor == null:
			continue

		_height = anchor.global_position.y
		_source = "meta_scene"
		_message = ""
		return


func _on_scene_data_missing() -> void:
	# 部屋のスキャンが無い状態。空の結果とセットアップ未完了は区別できる。
	_message = "部屋のスキャンがありません"
	if _capture_requested or _manager == null:
		return

	if not bool(_manager.call(&"is_scene_capture_supported")):
		return

	# アプリからSpace Setupへ誘導できる。ユーザーは一度端末側の画面へ移る。
	_capture_requested = true
	_manager.call(&"request_scene_capture")
	_message = "部屋のスキャンを開始しました"


func _calibrate_with_pinch() -> void:
	if _source == "meta_scene":
		return

	# 実際の床に指先を置いてpinchすると、その高さを床とみなす。
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if not _stage.is_pinching(hand):
			continue

		var tracker := _stage.get_hand_tracker(hand)
		var joint := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
		if not (tracker.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID):
			continue

		var tip := _stage.origin.global_transform * tracker.get_hand_joint_transform(joint).origin
		_height = tip.y
		_source = "manual"
		return


func _apply() -> void:
	# 床面の板と、その上に載る立方体。高さが合っていれば浮きも沈みもしない。
	_plane.global_position = Vector3(
		_plane.global_position.x, _height + 0.002, _plane.global_position.z
	)
	_marker.global_position = Vector3(
		_marker.global_position.x, _height + MARKER_SIZE * 0.5, _marker.global_position.z
	)


func _update_status() -> void:
	var source_text := "Local Floor（仮定）"
	if _source == "meta_scene":
		source_text = "平面API（FLOORラベル）"
	elif _source == "manual":
		source_text = "手で合わせた高さ"

	var relative := _height - _stage.origin.global_position.y
	var lines: Array[String] = [
		"床面検知",
		"出所: %s" % source_text,
		"高さ: %+.3f m（原点から）" % relative,
	]
	if not _message.is_empty():
		lines.append(_message)
	if _source != "meta_scene":
		lines.append("床に指先を置いてpinchすると合わせられます")

	_status.text = "\n".join(lines)
