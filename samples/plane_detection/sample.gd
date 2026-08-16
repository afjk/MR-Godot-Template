extends Node3D

## 平面検出: runtimeが検出した平面（床・壁・天井・机）を可視化するサンプル。
## AR FoundationのARPlaneManagerに当たります。
##
## 必要なもの: `xr/openxr/extensions/spatial_entity/enabled`と
##   `enable_plane_tracking`、`enable_builtin_plane_detection`（設定済み）。
##   端末側は事前の部屋スキャン、または光学センサーによる検出が要ります
## 対応端末: `XR_EXT_spatial_plane_tracking`を公開するruntimeのみ
##
## 平面は`XRServer`にanchor種別のトラッカーとして現れます。アプリ側は
## トラッカーの増減を購読し、`XRAnchor3D`で位置を合わせるだけです。
## メッシュと当たり判定は`OpenXRPlaneTracker`が作ってくれます。
##
## 注意: このAPIが返すのは、多くの端末では**事前にスキャンした部屋のデータ**です。
## Quest 3ではSpace Setupの結果になり、机を動かしても平面は動きません。
## その場で検出したい場合は`realtime_planes`サンプルを参照してください。

const LABEL_COLORS := {
	"floor": Color(0.25, 0.85, 0.45, 0.30),
	"wall": Color(0.30, 0.55, 0.95, 0.26),
	"ceiling": Color(0.70, 0.45, 0.95, 0.24),
	"table": Color(0.98, 0.65, 0.20, 0.32),
}
const DEFAULT_COLOR := Color(0.75, 0.80, 0.88, 0.24)

var _stage: MRStage
## tracker名 -> 平面を表示しているXRAnchor3D。
var _planes: Dictionary = {}

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_removed.connect(_on_tracker_removed)

	# 既に見つかっている平面も拾う。サンプルを開いた時点で検出済みのことが多い。
	for tracker_name in XRServer.get_trackers(XRServer.TRACKER_ANCHOR):
		_add_plane(tracker_name)


func _exit_tree() -> void:
	XRServer.tracker_added.disconnect(_on_tracker_added)
	XRServer.tracker_removed.disconnect(_on_tracker_removed)

	# リグにぶら下げたので、閉じるときに自分で片付ける。
	for anchor: Node3D in _planes.values():
		if is_instance_valid(anchor):
			anchor.queue_free()

	_planes.clear()


func _process(_delta: float) -> void:
	_status.text = _build_status()


func _on_tracker_added(tracker_name: StringName, type: int) -> void:
	if type == XRServer.TRACKER_ANCHOR:
		_add_plane(tracker_name)


func _on_tracker_removed(tracker_name: StringName, _type: int) -> void:
	var anchor: Node3D = _planes.get(tracker_name)
	if anchor != null:
		anchor.queue_free()
		_planes.erase(tracker_name)


func _add_plane(tracker_name: StringName) -> void:
	var tracker := XRServer.get_tracker(tracker_name) as OpenXRPlaneTracker
	if tracker == null or _planes.has(tracker_name):
		return

	# XRAnchor3Dがトラッカーの姿勢へ自動で追従する。位置合わせは書かなくてよい。
	var anchor := XRAnchor3D.new()
	anchor.tracker = tracker_name

	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	anchor.add_child(surface)

	var label := Label3D.new()
	label.name = "Label"
	label.font_size = 28
	label.pixel_size = 0.0008
	label.outline_size = 16
	label.render_priority = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	anchor.add_child(label)

	# XRAnchor3Dはトラッカーの姿勢を自分のローカル変換にする。原点の下に置かないと
	# XROrigin3Dが動いたときにずれる。
	_stage.origin.add_child(anchor)
	_planes[tracker_name] = anchor

	# 平面の形は後から更新される。作り直しの合図を購読しておく。
	tracker.mesh_changed.connect(_update_plane.bind(tracker_name))
	_update_plane(tracker_name)


func _update_plane(tracker_name: StringName) -> void:
	var tracker := XRServer.get_tracker(tracker_name) as OpenXRPlaneTracker
	var anchor: Node3D = _planes.get(tracker_name)
	if tracker == null or anchor == null:
		return

	var kind := _plane_kind(tracker)
	var surface := anchor.get_node(^"Surface") as MeshInstance3D
	# 姿勢と形はトラッカーが持っている。オフセットを通してから貼る。
	surface.transform = tracker.get_mesh_offset()
	surface.mesh = tracker.get_mesh()

	var material := StandardMaterial3D.new()
	material.albedo_color = LABEL_COLORS.get(kind, DEFAULT_COLOR)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = material

	var label := anchor.get_node(^"Label") as Label3D
	label.text = "%s  %.1f×%.1f m" % [kind, tracker.bounds_size.x, tracker.bounds_size.y]
	label.modulate = LABEL_COLORS.get(kind, DEFAULT_COLOR).lightened(0.6)
	label.position = tracker.get_mesh_offset().origin


## ラベル文字列と向きから、この平面の種類を1語で表す。
func _plane_kind(tracker: OpenXRPlaneTracker) -> String:
	var label := tracker.plane_label.to_lower()
	if label in LABEL_COLORS:
		return label

	# runtimeがラベルを出さないこともある。そのときは向きだけで大まかに分ける。
	match tracker.plane_alignment:
		OpenXRSpatialComponentPlaneAlignmentList.PLANE_ALIGNMENT_HORIZONTAL_UPWARD:
			return "上向きの面"
		OpenXRSpatialComponentPlaneAlignmentList.PLANE_ALIGNMENT_HORIZONTAL_DOWNWARD:
			return "下向きの面"
		OpenXRSpatialComponentPlaneAlignmentList.PLANE_ALIGNMENT_VERTICAL:
			return "垂直な面"

	return label if not label.is_empty() else "不明"


func _build_status() -> String:
	if not _is_plane_tracking_supported():
		return "平面検出\nこの端末は平面検出（XR_EXT_spatial_plane_tracking）を\n公開していません"

	if _planes.is_empty():
		return "平面検出\nまだ平面がありません\n端末側の部屋スキャンが済んでいるか確認してください"

	var counts: Dictionary = {}
	for tracker_name in _planes:
		var tracker := XRServer.get_tracker(tracker_name) as OpenXRPlaneTracker
		if tracker == null:
			continue

		var kind := _plane_kind(tracker)
		counts[kind] = int(counts.get(kind, 0)) + 1

	var parts: Array[String] = []
	for kind in counts:
		parts.append("%s:%d" % [kind, counts[kind]])

	return "平面検出\n検出数: %d\n%s" % [_planes.size(), " ".join(parts)]


func _is_plane_tracking_supported() -> bool:
	if not Engine.has_singleton(&"OpenXRSpatialPlaneTrackingCapability"):
		return false

	return Engine.get_singleton(&"OpenXRSpatialPlaneTrackingCapability").is_supported()
