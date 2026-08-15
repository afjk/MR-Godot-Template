extends Node3D

## Hand Tracking: `XRHandTracker`が返す左右26関節を球で表示するサンプル。
##
## 必要なもの: `xr/openxr/extensions/hand_tracking=true`と、端末側のHand Tracking設定
##   （Quest: Meta XR Features > Hand Tracking、PICO/VIVE: 各presetのhand tracking）
## 対応端末: 全機種
##
## 光学式の手と、コントローラーを握った状態でruntimeが推定する手を見分けます。
## 見分けているのは`hand_tracking_source`で、判定は`shared/mr_stage.gd`にあります。

const HAND_COLORS: Array[Color] = [
	Color(0.05, 0.62, 1.0, 1.0),
	Color(1.0, 0.18, 0.12, 1.0),
]
const MARKER_RADIUS := 0.006
const SOURCE_NAMES := {
	XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN: "不明",
	XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED: "光学式",
	XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER: "コントローラー由来",
	XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED: "追跡なし",
}

var _stage: MRStage
var _markers: Array = []

@onready var _status: Label3D = $Status


func _ready() -> void:
	_create_markers()
	_stage = await SampleBootstrap.stage_async()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	var lines: Array[String] = ["Hand Tracking"]
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		lines.append(_update_hand(hand))

	_status.text = "\n".join(lines)


func _create_markers() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = MARKER_RADIUS
	sphere.height = MARKER_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4

	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		var material := StandardMaterial3D.new()
		material.albedo_color = HAND_COLORS[hand]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var hand_markers: Array[MeshInstance3D] = []
		for _joint in XRHandTracker.HAND_JOINT_MAX:
			var marker := MeshInstance3D.new()
			marker.mesh = sphere
			marker.material_override = material
			marker.visible = false
			add_child(marker)
			hand_markers.append(marker)

		_markers.append(hand_markers)


## 片手分の球を更新し、一覧に出す1行を返す。
func _update_hand(hand: int) -> String:
	var tracker := _stage.get_hand_tracker(hand)
	var hand_markers: Array = _markers[hand]
	var label := "左" if hand == MRStage.Hand.LEFT else "右"

	if tracker == null or not tracker.has_tracking_data:
		_hide_markers(hand_markers)
		return "%s: データなし" % label

	var source: String = SOURCE_NAMES.get(tracker.hand_tracking_source, "不明")
	if not _stage.is_hand_tracking_active(hand):
		# コントローラー由来の推定手は、関節が来ていても表示しない。
		_hide_markers(hand_markers)
		return "%s: %s（非表示）" % [label, source]

	var visible_joints := 0
	for joint in XRHandTracker.HAND_JOINT_MAX:
		var marker: MeshInstance3D = hand_markers[joint]
		var flags := tracker.get_hand_joint_flags(joint)
		marker.visible = (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0
		if not marker.visible:
			continue

		visible_joints += 1
		# 関節の姿勢はXROrigin3D基準で返るので、原点の変換を通してから置く。
		var joint_position := tracker.get_hand_joint_transform(joint).origin
		marker.global_position = _stage.origin.global_transform * joint_position
		var radius := maxf(tracker.get_hand_joint_radius(joint), MARKER_RADIUS)
		marker.scale = Vector3.ONE * (radius / MARKER_RADIUS)

	return "%s: %s（%d/%d関節）" % [label, source, visible_joints, XRHandTracker.HAND_JOINT_MAX]


func _hide_markers(hand_markers: Array) -> void:
	for marker: MeshInstance3D in hand_markers:
		marker.visible = false
