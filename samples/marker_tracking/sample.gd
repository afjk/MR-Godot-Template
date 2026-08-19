extends Node3D

## マーカー追跡: QRコードやArUcoマーカーを見つけ、その場所に印を出すサンプル。
## AR FoundationのARTrackedImageManagerに近い役目です。
##
## 必要なもの: `xr/openxr/extensions/spatial_entity/enabled`と
##   `marker_tracking/enable`（設定済み）
## 対応端末: `XR_EXT_spatial_marker_tracking`を公開するruntime
##
## 印刷したマーカーを実空間に貼れば、そこが**アプリ側の既知の座標**になります。
## 事前スキャンもアンカーの共有も要らないので、複数人で同じ場所に物を出したい
## ときや、機械の特定の部位に情報を重ねたいときに向いています。
##
## 種類は4つあり、端末によって対応が違います。
##   QRコード / マイクロQRコード: `get_marker_data()`で中身の文字列が読める
##   ArUco / AprilTag: `marker_id`で番号だけが分かる
##
## 対応している種類だけを選んで`start_built_in_tracking()`に渡すのが要点です。
## 非対応の種類を混ぜると、まとめて失敗します。

## マーカーの種類のビット（OpenXRSpatialMarkerTrackingCapability.MarkerTypeFlags）。
const MARKER_QR_CODE := 1
const MARKER_MICRO_QR_CODE := 2
const MARKER_ARUCO := 4
const MARKER_APRIL_TAG := 8

## OpenXRMarkerTracker.marker_typeの値（OpenXRSpatialComponentMarkerList.MarkerType）。
const TYPE_NAMES := {
	1: "QRコード",
	2: "マイクロQR",
	3: "ArUco",
	4: "AprilTag",
}

var _stage: MRStage
## OpenXRSpatialMarkerTrackingCapability。非対応ならnull。
var _capability: Object
## tracker名 -> 表示しているXRAnchor3D。
var _markers: Dictionary = {}
var _started := false
var _supported_names: Array[String] = []

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	if not Engine.has_singleton(&"OpenXRSpatialMarkerTrackingCapability"):
		return

	_capability = Engine.get_singleton(&"OpenXRSpatialMarkerTrackingCapability")

	var types := _supported_types()
	if types == 0:
		_capability = null
		return

	# 対応している種類だけを渡す。非対応を混ぜると全体が失敗する。
	_started = bool(_capability.call(&"start_built_in_tracking", types))
	if not _started:
		return

	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_removed.connect(_on_tracker_removed)
	for tracker_name in XRServer.get_trackers(XRServer.TRACKER_ANCHOR):
		_add_marker(tracker_name)


func _exit_tree() -> void:
	if XRServer.tracker_added.is_connected(_on_tracker_added):
		XRServer.tracker_added.disconnect(_on_tracker_added)
		XRServer.tracker_removed.disconnect(_on_tracker_removed)

	if _started:
		_capability.call(&"stop_built_in_tracking", true)

	# リグにぶら下げたので、閉じるときに自分で片付ける。
	for marker: Node3D in _markers.values():
		if is_instance_valid(marker):
			marker.queue_free()

	_markers.clear()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	for tracker_name in _markers:
		_update_marker(tracker_name)

	_status.text = _build_status()


## この端末が読める種類だけをビットで集める。表示用に名前も控える。
func _supported_types() -> int:
	var types := 0
	_supported_names.clear()

	if bool(_capability.call(&"is_qrcode_supported")):
		types |= MARKER_QR_CODE
		_supported_names.append("QR")
	if bool(_capability.call(&"is_micro_qrcode_supported")):
		types |= MARKER_MICRO_QR_CODE
		_supported_names.append("マイクロQR")
	if bool(_capability.call(&"is_aruco_supported")):
		types |= MARKER_ARUCO
		_supported_names.append("ArUco")
	if bool(_capability.call(&"is_april_tag_supported")):
		types |= MARKER_APRIL_TAG
		_supported_names.append("AprilTag")

	return types


func _on_tracker_added(tracker_name: StringName, type: int) -> void:
	if type == XRServer.TRACKER_ANCHOR:
		_add_marker(tracker_name)


func _on_tracker_removed(tracker_name: StringName, _type: int) -> void:
	var marker: Node3D = _markers.get(tracker_name)
	if marker != null:
		marker.queue_free()
		_markers.erase(tracker_name)


## マーカー1つぶんの表示を作る。位置合わせはXRAnchor3Dがやる。
func _add_marker(tracker_name: StringName) -> void:
	var tracker := XRServer.get_tracker(tracker_name)
	# anchor種別にはアンカーや平面のトラッカーも混ざる。マーカーだけを拾う。
	if tracker == null or _markers.has(tracker_name) or not (tracker is OpenXRMarkerTracker):
		return

	var anchor := XRAnchor3D.new()
	anchor.tracker = tracker_name

	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = QuadMesh.new()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.95, 0.65, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	frame.material_override = material
	anchor.add_child(frame)

	var label := Label3D.new()
	label.name = "Label"
	label.font_size = 26
	label.pixel_size = 0.0008
	label.outline_size = 14
	label.render_priority = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	anchor.add_child(label)

	# XRAnchor3Dはトラッカーの姿勢を自分のローカル変換にするので、
	# XROrigin3Dの下に置かないと原点が動いたときにずれる。
	_stage.origin.add_child(anchor)
	_markers[tracker_name] = anchor
	_update_marker(tracker_name)


## 大きさと中身は追跡中に変わる。毎フレーム引き直す。
func _update_marker(tracker_name: StringName) -> void:
	var tracker := XRServer.get_tracker(tracker_name) as OpenXRMarkerTracker
	var anchor: Node3D = _markers.get(tracker_name)
	if tracker == null or anchor == null:
		return

	var frame := anchor.get_node(^"Frame") as MeshInstance3D
	(frame.mesh as QuadMesh).size = tracker.bounds_size

	var label := anchor.get_node(^"Label") as Label3D
	label.text = _describe(tracker)
	label.position = Vector3(0.0, tracker.bounds_size.y * 0.5 + 0.04, 0.0)


## マーカーの中身を1行にする。QRは文字列、ArUcoとAprilTagは番号。
func _describe(tracker: OpenXRMarkerTracker) -> String:
	var kind: String = TYPE_NAMES.get(tracker.marker_type, "不明")
	var data: Variant = tracker.get_marker_data()
	if data is String and not (data as String).is_empty():
		return "%s: %s" % [kind, data]
	if data is PackedByteArray:
		return "%s: %dバイト" % [kind, (data as PackedByteArray).size()]

	return "%s: #%d" % [kind, tracker.marker_id]


func _build_status() -> String:
	if _capability == null:
		return "マーカー追跡\nこの端末はマーカー追跡（XR_EXT_spatial_marker_tracking）を\n公開していません"

	if not _started:
		return "マーカー追跡\n追跡を開始できませんでした"

	var lines: Array[String] = ["マーカー追跡"]
	lines.append("対応: %s" % " ".join(_supported_names))
	if _markers.is_empty():
		lines.append("印刷したマーカーを写してください")
		return "\n".join(lines)

	lines.append("検出: %d" % _markers.size())
	return "\n".join(lines)
