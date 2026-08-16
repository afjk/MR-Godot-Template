extends Node3D

## 床面検知: 検出された平面から床を選び、無ければ仮定に落とすサンプル。
##
## 必要なもの: `xr/openxr/extensions/spatial_entity/*`（設定済み）。Quest 3で
##   Meta経路を使う場合は`meta/scene_api`と、端末側のSpace Setup（部屋のスキャン）
## 対応端末: 検出はruntime次第。取れない端末では仮定に落ちます
##
## 床の高さは取り方が端末で違うので、上から順に試します。
##   1. 平面検出（core）: `OpenXRPlaneTracker`から`floor`ラベルの平面を探す
##   2. Meta Scene: Quest 3の部屋スキャン結果から`FLOOR`ラベルのanchorを読む
##   3. Local Floor: reference spaceがLocal Floorなので、XROrigin3Dのy=0を床とみなす
##
## **3段目は検知ではなく仮定です。** どの段で得たかを`_source`として持ち、画面にも
## 出します。精度が要る処理は、出所を見て分岐できるようにするためです。
## 検出そのものを見たい場合は`plane_detection`サンプルを開いてください。

const META_FLOOR_LABEL := "FLOOR"
## 平面とscene entityを問い合わせる間隔。毎フレーム引く必要はない。
const POLL_INTERVAL := 0.5
const MARKER_SIZE := 0.12

var _stage: MRStage
## Meta経路の`OpenXRFbSceneManager`。pluginが無い端末ではnullのまま。
var _manager: Node
## 床として採用した平面に貼り付けるアンカー。coreの平面検出で使う。
var _floor_anchor: XRAnchor3D
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

	_floor_anchor = XRAnchor3D.new()
	_stage.origin.add_child(_floor_anchor)
	_setup_scene_manager()


func _exit_tree() -> void:
	# リグにぶら下げたものは自分で片付ける。
	for node: Node in [_manager, _floor_anchor]:
		if is_instance_valid(node):
			node.queue_free()


func _process(delta: float) -> void:
	if _stage == null:
		return

	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = POLL_INTERVAL
		if not _update_from_planes():
			_update_from_meta_scene()

	if _source == "plane" and _floor_anchor.tracker != &"":
		# 平面は動くことがある。採用した平面の高さを毎フレーム追う。
		_height = _floor_anchor.global_position.y

	_apply()
	_update_status()


## 1段目。coreの平面検出から床を選ぶ。見つかればtrue。
func _update_from_planes() -> bool:
	var best_name := &""
	var best_area := 0.0
	for tracker_name in XRServer.get_trackers(XRServer.TRACKER_ANCHOR):
		var tracker := XRServer.get_tracker(tracker_name) as OpenXRPlaneTracker
		if tracker == null:
			continue

		if tracker.plane_label.to_lower() == "floor":
			best_name = tracker_name
			break

		# ラベルを出さないruntimeもある。上向きの水平面のうち最も広いものを床とみなす。
		var alignment := OpenXRSpatialComponentPlaneAlignmentList.PLANE_ALIGNMENT_HORIZONTAL_UPWARD
		if tracker.plane_alignment != alignment:
			continue

		var area := tracker.bounds_size.x * tracker.bounds_size.y
		if area > best_area:
			best_area = area
			best_name = tracker_name

	if best_name == &"":
		return false

	_floor_anchor.tracker = best_name
	_source = "plane"
	_message = ""
	return true


## 2段目。Metaの部屋スキャン結果から床を読む。
func _update_from_meta_scene() -> void:
	if _manager == null or _source == "plane":
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
		if META_FLOOR_LABEL not in labels:
			continue

		var anchor := _manager.call(&"get_anchor_node", uuid) as Node3D
		if anchor == null:
			continue

		_height = anchor.global_position.y
		_source = "meta_scene"
		_message = ""
		return


func _setup_scene_manager() -> void:
	# pluginが無い環境でもこのサンプルが読めるよう、class名から生成する。
	if not ClassDB.class_exists(&"OpenXRFbSceneManager"):
		return

	_manager = ClassDB.instantiate(&"OpenXRFbSceneManager") as Node
	if _manager == null:
		return

	_manager.set(&"auto_create", true)
	_manager.set(&"visible", false)
	_stage.origin.add_child(_manager)
	_manager.connect(&"openxr_fb_scene_data_missing", _on_scene_data_missing)


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


func _apply() -> void:
	# 床面の板と、その上に載る立方体。高さが合っていれば浮きも沈みもしない。
	_plane.global_position = Vector3(
		_plane.global_position.x, _height + 0.002, _plane.global_position.z
	)
	_marker.global_position = Vector3(
		_marker.global_position.x, _height + MARKER_SIZE * 0.5, _marker.global_position.z
	)


func _update_status() -> void:
	var source_text := "Local Floorの仮定（検知ではありません）"
	if _source == "plane":
		source_text = "平面検出（core）"
	elif _source == "meta_scene":
		source_text = "Meta Sceneの部屋データ"

	var relative := _height - _stage.origin.global_position.y
	var lines: Array[String] = [
		"床面検知",
		"出所: %s" % source_text,
		"高さ: %+.3f m（原点から）" % relative,
	]
	if not _message.is_empty():
		lines.append(_message)

	_status.text = "\n".join(lines)
