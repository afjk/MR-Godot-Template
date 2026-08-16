extends Node3D

## 掴んで動かす: pinchまたはgripでオブジェクトを掴み、手について来させるサンプル。
##
## 必要なもの: 手で掴むには`xr/openxr/extensions/hand_tracking=true`。
##   コントローラーはaction mapの`grab`（squeeze）を使う
## 対応端末: 全機種
##
## 掴んだ瞬間の「手に対するオブジェクトの相対姿勢」を1つのTransform3Dとして保存し、
## 以降は毎フレームそれを手の姿勢へ掛け直すだけです。位置と回転を別々に扱うより
## 短く、持ち方がずれません。物理は使っていません。

const CUBE_TITLES: Array[String] = ["赤", "緑", "青"]
const CUBE_COLORS: Array[Color] = [
	Color(0.90, 0.35, 0.25),
	Color(0.35, 0.80, 0.45),
	Color(0.35, 0.55, 0.95),
]
const CUBE_ORIGIN := Vector3(0.0, 1.2, -0.45)
const CUBE_PITCH := 0.18
const CUBE_SIZE := 0.09
## 掴める距離。手の代表点からこの範囲にある中でいちばん近いものを掴む。
const GRAB_DISTANCE := 0.14

var _stage: MRStage
var _cubes: Array[MeshInstance3D] = []
## 手ごとに、掴んでいるオブジェクトの添字と、掴んだ時点の相対姿勢。
var _held: Array[int] = [-1, -1]
var _offsets: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	for index in CUBE_TITLES.size():
		var offset := Vector3((index - 1) * CUBE_PITCH, 0.0, 0.0)
		_cubes.append(_create_cube(index, CUBE_ORIGIN + offset))


func _process(_delta: float) -> void:
	if _stage == null:
		return

	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		_update_hand(hand)

	_update_status()


func _update_hand(hand: int) -> void:
	var pose: Variant = _get_grab_pose(hand)
	if pose == null:
		_held[hand] = -1
		return

	var grab_transform: Transform3D = pose
	if not _is_grabbing(hand):
		_held[hand] = -1
		return

	if _held[hand] < 0:
		_start_grab(hand, grab_transform)
		return

	# 掴んだ瞬間の相対姿勢を、いまの手の姿勢へ掛け直す。
	_cubes[_held[hand]].global_transform = grab_transform * _offsets[hand]


func _start_grab(hand: int, grab_transform: Transform3D) -> void:
	var nearest := -1
	var nearest_distance := GRAB_DISTANCE
	for index in _cubes.size():
		if index in _held:
			continue

		var distance := _cubes[index].global_position.distance_to(grab_transform.origin)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index

	if nearest < 0:
		return

	_held[hand] = nearest
	_offsets[hand] = grab_transform.affine_inverse() * _cubes[nearest].global_transform

	var controller := _stage.get_grip_controller(hand)
	if controller.get_is_active():
		controller.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.08, 0.0)


## 掴む基準になる姿勢。手のひら、無ければgrip poseのコントローラー。
func _get_grab_pose(hand: int) -> Variant:
	if _stage.is_hand_tracking_active(hand):
		var tracker := _stage.get_hand_tracker(hand)
		var joint := XRHandTracker.HAND_JOINT_PALM
		if tracker.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID:
			return _stage.origin.global_transform * tracker.get_hand_joint_transform(joint)

	var controller := _stage.get_grip_controller(hand)
	return controller.global_transform if controller.get_is_active() else null


func _is_grabbing(hand: int) -> bool:
	# 手ならpinch（判定は`shared/mr_stage.gd`）、コントローラーならgripを握る。
	if _stage.is_hand_tracking_active(hand):
		return _stage.is_pinching(hand)

	return _stage.get_grip_controller(hand).is_button_pressed(&"grab")


func _create_cube(index: int, position: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CUBE_SIZE

	var material := StandardMaterial3D.new()
	material.albedo_color = CUBE_COLORS[index]
	material.roughness = 0.35

	var cube := MeshInstance3D.new()
	cube.mesh = mesh
	cube.material_override = material
	cube.position = position
	add_child(cube)

	return cube


func _update_status() -> void:
	var lines: Array[String] = ["掴んで動かす"]
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		var label := "左" if hand == MRStage.Hand.LEFT else "右"
		var how := "pinch" if _stage.is_hand_tracking_active(hand) else "grip"
		if _held[hand] >= 0:
			lines.append("%s（%s）: %sを掴み中" % [label, how, CUBE_TITLES[_held[hand]]])
		else:
			lines.append("%s（%s）: 掴んでいない" % [label, how])

	_status.text = "\n".join(lines)
