extends Node3D

## 空間アンカー: 実空間の位置に印を打ち、**アプリを再起動しても同じ場所に残す**
## サンプル。AR FoundationのARAnchorManagerに当たります。
##
## 必要なもの: `xr/openxr/extensions/spatial_entity/enabled`、
##   `enable_spatial_anchors`、`enable_persistent_anchors`、
##   `enable_builtin_anchor_detection`（すべて設定済み）
## 対応端末: `XR_EXT_spatial_anchor`と`XR_EXT_spatial_persistence`を公開するruntime
##
## 「原点からの相対座標で覚えておく」のとは違います。recenterしても、部屋を出て
## 戻っても、**runtimeが実空間を見て同じ場所へ復元します**。
##
## 操作:
##   右手のpinch: 見ている先にアンカーを作り、そのまま永続化する
##   左手のpinch: 最後に作ったアンカーを消す（永続化も取り消す）
##
## 永続化されたアンカーは、次回の起動時にruntimeから自動で戻ってきます
## （`enable_builtin_anchor_detection`）。アプリ側は`XRServer`のトラッカーが
## 増えるのを待つだけで、UUIDの管理も再問い合わせも書きません。

## アンカーを置く距離。ポインタの向きに沿ってこれだけ先へ置く。
const PLACE_DISTANCE := 0.8
const MARKER_SIZE := 0.06

var _stage: MRStage
## OpenXRSpatialAnchorCapability。非対応ならnull。
var _capability: Object
## tracker名 -> 表示しているXRAnchor3D。
var _markers: Dictionary = {}
## 自分で作ったトラッカー。消すときに使う。
var _created: Array[Object] = []
var _restored := 0
var _message := ""

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	if not _is_supported():
		return

	_capability = Engine.get_singleton(&"OpenXRSpatialAnchorCapability")
	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_removed.connect(_on_tracker_removed)

	# 前回の起動で永続化したアンカーは、もう戻ってきていることが多い。
	for tracker_name in XRServer.get_trackers(XRServer.TRACKER_ANCHOR):
		_add_marker(tracker_name, true)


func _exit_tree() -> void:
	if XRServer.tracker_added.is_connected(_on_tracker_added):
		XRServer.tracker_added.disconnect(_on_tracker_added)
		XRServer.tracker_removed.disconnect(_on_tracker_removed)

	# リグにぶら下げたので、閉じるときに自分で片付ける。
	# アンカー自体は端末に残るので、ここでは表示を消すだけ。
	for marker: Node3D in _markers.values():
		if is_instance_valid(marker):
			marker.queue_free()

	_markers.clear()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	if _capability != null:
		_handle_pinch()

	_status.text = _build_status()


func _handle_pinch() -> void:
	if _stage.is_pinch_just_started(MRStage.Hand.RIGHT):
		_place_anchor()
	elif _stage.is_pinch_just_started(MRStage.Hand.LEFT):
		_remove_last_anchor()


## 見ている先にアンカーを作る。位置はXROrigin3Dのローカル座標で渡す。
func _place_anchor() -> void:
	var pointer := _stage.get_pointer_transform()
	var world := pointer.origin - pointer.basis.z * PLACE_DISTANCE
	var local := _stage.origin.global_transform.affine_inverse() * world

	var tracker: Object = _capability.call(&"create_new_anchor", Transform3D(Basis(), local))
	if tracker == null:
		_message = "アンカーを作れませんでした"
		return

	_created.append(tracker)
	_message = ""

	if not bool(_capability.call(&"is_spatial_persistence_supported")):
		_message = "この端末は永続化に対応していません（今回限りのアンカーです）"
		return

	# 永続化は非同期。成否はOpenXRFutureResultのcompletedで受ける。
	var future: Object = _capability.call(&"persist_anchor", tracker, RID(), Callable())
	if future == null:
		_message = "永続化を開始できませんでした"
		return

	future.connect(&"completed", _on_persist_completed)


func _on_persist_completed(result: Object) -> void:
	_message = "" if bool(result.call(&"get_result_value")) else "永続化に失敗しました"


## 最後に作ったアンカーを消す。永続化したものは、先に取り消してから消す。
## 順番を守らないと`remove_anchor`が弾かれます（永続アンカーは消せない）。
func _remove_last_anchor() -> void:
	if _created.is_empty():
		_message = "消せるアンカーがありません"
		return

	var tracker: Object = _created[-1]
	if not bool(tracker.call(&"has_uuid")):
		_created.pop_back()
		_capability.call(&"remove_anchor", tracker)
		return

	# コールバックには対象のトラッカーがそのまま渡る。成功したときだけ呼ばれる。
	if _capability.call(&"unpersist_anchor", tracker, RID(), _on_unpersisted) == null:
		_message = "永続化の取り消しを開始できませんでした"


func _on_unpersisted(tracker: Object) -> void:
	_created.erase(tracker)
	_capability.call(&"remove_anchor", tracker)


func _on_tracker_added(tracker_name: StringName, type: int) -> void:
	if type == XRServer.TRACKER_ANCHOR:
		_add_marker(tracker_name, false)


func _on_tracker_removed(tracker_name: StringName, _type: int) -> void:
	var marker: Node3D = _markers.get(tracker_name)
	if marker != null:
		marker.queue_free()
		_markers.erase(tracker_name)


## アンカー1つぶんの表示を作る。位置合わせはXRAnchor3Dがやる。
func _add_marker(tracker_name: StringName, restored: bool) -> void:
	var tracker := XRServer.get_tracker(tracker_name)
	if tracker == null or _markers.has(tracker_name) or not (tracker is OpenXRAnchorTracker):
		return

	if restored:
		_restored += 1

	var anchor := XRAnchor3D.new()
	anchor.tracker = tracker_name

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * MARKER_SIZE

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.98, 0.75, 0.25) if restored else Color(0.35, 0.85, 0.95)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	marker.material_override = material
	anchor.add_child(marker)

	# XRAnchor3Dはトラッカーの姿勢を自分のローカル変換にするので、
	# XROrigin3Dの下に置かないと原点が動いたときにずれる。
	_stage.origin.add_child(anchor)
	_markers[tracker_name] = anchor


func _is_supported() -> bool:
	if not Engine.has_singleton(&"OpenXRSpatialAnchorCapability"):
		return false

	return Engine.get_singleton(&"OpenXRSpatialAnchorCapability").is_spatial_anchor_supported()


func _build_status() -> String:
	if _capability == null:
		return "空間アンカー\nこの端末は空間アンカー（XR_EXT_spatial_anchor）を\n公開していません"

	var lines: Array[String] = ["空間アンカー"]
	if not _message.is_empty():
		lines.append(_message)

	lines.append("アンカー: %d（前回から復元: %d）" % [_markers.size(), _restored])
	lines.append("右手pinchで置く／左手pinchで最後の1つを消す")
	if _restored == 0:
		lines.append("置いたあとアプリを入れ直すと、同じ場所に戻ります")

	return "\n".join(lines)
