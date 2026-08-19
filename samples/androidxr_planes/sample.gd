extends Node3D

## Android XRのリアルタイム平面検出: OSが逐次見つけた平面を、そのまま受け取る
## サンプル。**AR Foundationの`ARPlaneManager`と同じ挙動になる唯一の経路**です。
##
## 必要なもの: `xr/openxr/extensions/androidxr/trackables=true`（設定済み）、
##   OpenXR Vendors plugin、`android.permission.SCENE_UNDERSTANDING_COARSE`
## 対応端末: Android XR（`XR_ANDROID_trackables`）
##
## **実機が無いため未検証です。** コードはOpenXR Vendors同梱のサンプルと
## プラグインのドキュメントに合わせてあります。
##
## Quest 3との違いが要点です。Quest 3の`plane_detection`が返すのは事前スキャン
## した部屋のデータで、机を動かしても平面は動きません（[調査メモ](../../docs/realtime_spatial_investigation.md)）。
## Android XRはOSが見た端から平面を作り、更新し、消します。スキャンは要りません。
##
## 平面は`XRServer`にトラッカーとして現れます。取り方は`plane_detection`と同じで、
## 違うのは**動き続けること**と、`get_subsumed_by_plane()`があることです。

## OpenXRAndroidTrackablePlaneTracker.PlaneLabelの値。
const LABEL_COLORS := {
	0: Color(0.75, 0.80, 0.88, 0.24),  # unknown
	1: Color(0.30, 0.55, 0.95, 0.26),  # wall
	2: Color(0.25, 0.85, 0.45, 0.30),  # floor
	3: Color(0.70, 0.45, 0.95, 0.24),  # ceiling
	4: Color(0.98, 0.65, 0.20, 0.32),  # table
}
const LABEL_NAMES := {0: "不明", 1: "壁", 2: "床", 3: "天井", 4: "机"}
## 当たり判定に持たせる厚み。
const SHAPE_THICKNESS := 0.05

var _stage: MRStage
## OpenXRAndroidTrackablesExtension。非対応ならnull。
var _extension: Object
## tracker名 -> 平面を表示しているXRAnchor3D。
var _planes: Dictionary = {}
var _connected := false

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	if not Engine.has_singleton(&"OpenXRAndroidTrackablesExtension"):
		return

	_extension = Engine.get_singleton(&"OpenXRAndroidTrackablesExtension")
	if not bool(_extension.call(&"is_trackables_supported")):
		_extension = null


func _exit_tree() -> void:
	if _connected:
		XRServer.tracker_added.disconnect(_on_tracker_added)
		XRServer.tracker_removed.disconnect(_on_tracker_removed)

	# リグにぶら下げたので、閉じるときに自分で片付ける。
	for anchor: Node3D in _planes.values():
		if is_instance_valid(anchor):
			anchor.queue_free()

	_planes.clear()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_start_when_permitted()
	_status.text = _build_status()


## 権限はpluginが起動時に要求します。降りるまで購読を始めません。
func _start_when_permitted() -> void:
	if _extension == null or _connected:
		return

	if not bool(_extension.call(&"are_permissions_granted")):
		return

	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_removed.connect(_on_tracker_removed)
	_connected = true

	# 探索は既定で60フレームごとに自動で走る。ここでは反応を優先して短くする。
	_extension.call(&"set_plane_tracker_discovery_cooldown", 15)
	for tracker_name in XRServer.get_trackers(XRServer.TRACKER_ANCHOR):
		_add_plane(tracker_name)


func _on_tracker_added(tracker_name: StringName, type: int) -> void:
	if type == XRServer.TRACKER_ANCHOR:
		_add_plane(tracker_name)


func _on_tracker_removed(tracker_name: StringName, _type: int) -> void:
	_remove_plane(tracker_name)


func _add_plane(tracker_name: StringName) -> void:
	var tracker := _plane_tracker(tracker_name)
	if tracker == null or _planes.has(tracker_name):
		return

	# 大きい平面に吸収された平面は出さない。二重に見えて邪魔になる。
	if tracker.call(&"get_subsumed_by_plane") != null:
		return

	var anchor := XRAnchor3D.new()
	anchor.tracker = tracker_name

	var body := StaticBody3D.new()
	body.name = "Body"
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	body.add_child(collision)
	anchor.add_child(body)

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

	# XRAnchor3Dはトラッカーの姿勢を自分のローカル変換にするので、
	# XROrigin3Dの下に置かないと原点が動いたときにずれる。
	_stage.origin.add_child(anchor)
	_planes[tracker_name] = anchor

	# 形は動き続ける。更新の合図を購読しておく。
	tracker.connect(&"updated", _update_plane.bind(tracker_name))
	_update_plane(tracker_name)


func _remove_plane(tracker_name: StringName) -> void:
	var anchor: Node3D = _planes.get(tracker_name)
	if anchor != null:
		anchor.queue_free()
		_planes.erase(tracker_name)


func _update_plane(tracker_name: StringName) -> void:
	var tracker := _plane_tracker(tracker_name)
	var anchor: Node3D = _planes.get(tracker_name)
	if tracker == null or anchor == null:
		return

	# 追跡中に他の平面へ吸収されることがある。そうなったら消す。
	if tracker.call(&"get_subsumed_by_plane") != null:
		_remove_plane(tracker_name)
		return

	var label_id := int(tracker.call(&"get_plane_label"))
	var color: Color = LABEL_COLORS.get(label_id, LABEL_COLORS[0])

	var surface := anchor.get_node(^"Surface") as MeshInstance3D
	surface.mesh = tracker.call(&"get_mesh")

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = material

	var collision := anchor.get_node(^"Body/Shape") as CollisionShape3D
	collision.shape = tracker.call(&"get_shape", SHAPE_THICKNESS)

	var extents: Vector2 = tracker.call(&"get_extents")
	var text := anchor.get_node(^"Label") as Label3D
	text.text = "%s  %.1f×%.1f m" % [LABEL_NAMES.get(label_id, "不明"), extents.x, extents.y]
	text.modulate = color.lightened(0.6)


## pluginが無い環境でもスクリプトが読めるよう、型を書かずに`is_class`で選り分ける。
## anchor種別にはアンカーやマーカーのトラッカーも混ざるので、判定は必須。
func _plane_tracker(tracker_name: StringName) -> Object:
	var tracker := XRServer.get_tracker(tracker_name)
	if tracker == null or not tracker.is_class(&"OpenXRAndroidTrackablePlaneTracker"):
		return null

	return tracker


func _build_status() -> String:
	if _extension == null:
		return "Android XRの平面検出\nこの端末はXR_ANDROID_trackablesを\n公開していません"

	if not _connected:
		return "Android XRの平面検出\n空間認識の権限を待っています"

	if _planes.is_empty():
		return "Android XRの平面検出\nまだ平面がありません\n周りを見回してください（スキャンは不要です）"

	var counts: Dictionary = {}
	for tracker_name in _planes:
		var tracker := _plane_tracker(tracker_name)
		if tracker == null:
			continue

		var name_of: String = LABEL_NAMES.get(int(tracker.call(&"get_plane_label")), "不明")
		counts[name_of] = int(counts.get(name_of, 0)) + 1

	var parts: Array[String] = []
	for name_of in counts:
		parts.append("%s:%d" % [name_of, counts[name_of]])

	return "Android XRの平面検出\n検出数: %d\n%s" % [_planes.size(), " ".join(parts)]
