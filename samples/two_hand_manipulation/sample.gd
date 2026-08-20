extends Node3D

## 両手操作: 両手で掴んで回転・拡縮するサンプル。
##
## 必要なもの: 手で掴むには`xr/openxr/extensions/hand_tracking=true`。
##   コントローラーはaction mapの`grab`（squeeze）を使う
## 対応端末: 全機種
##
## 掴んだ瞬間の「両手を結ぶベクトル」と「そのときの姿勢」を覚えておき、毎フレーム
## 差分を掛け直します。両手の距離の比が倍率、ベクトルの向きの差が回転です。
## 片手だけのときは`grab_object`と同じく相対姿勢の掛け直しになります。
##
## 制約: 手のひねり（両手を軸周りに回す動き）は見ていません。MRTKの
## ObjectManipulatorはこれも扱いますが、ここでは短さを優先しています。

const OBJECT_SIZE := 0.22
## 掴める距離。オブジェクトの表面からの余裕。
const GRAB_MARGIN := 0.12
## 倍率の下限と上限。MRTKのconstraintに当たる部分。
const MIN_SCALE := 0.4
const MAX_SCALE := 2.5

var _stage: MRStage
var _held: Array[bool] = [false, false]
## 片手のとき: 掴んだ瞬間の相対姿勢。
var _one_hand_offset := Transform3D.IDENTITY
## 両手のとき: 掴んだ瞬間の両手ベクトル・中点・姿勢・倍率。
var _start_vector := Vector3.ZERO
var _start_center := Vector3.ZERO
var _start_transform := Transform3D.IDENTITY
var _start_scale := 1.0
## いまの倍率（起動時を1.0とする）。
var _scale := 1.0
var _hold_count := 0

@onready var _object: MeshInstance3D = $Object
@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		_update_hold(hand)

	var count := _count_held()
	if count != _hold_count:
		# 手の数が変わったら、いまの姿勢を基準にして持ち直す。
		_hold_count = count
		_rebase(count)

	if count == 2:
		_apply_two_hand()
	elif count == 1:
		_apply_one_hand(_first_held())

	_update_status(count)


func _update_hold(hand: int) -> void:
	var pose: Variant = _get_hand_pose(hand)
	if pose == null or not _is_grabbing(hand):
		_held[hand] = false
		return

	if _held[hand]:
		return

	# 掴み始めだけ距離を見る。掴んだ後は手が離れても持ち続ける。
	var reach := OBJECT_SIZE * _scale * 0.5 + GRAB_MARGIN
	if (pose as Transform3D).origin.distance_to(_object.global_position) > reach:
		return

	_held[hand] = true
	var controller := _stage.get_grip_controller(hand)
	if controller.get_is_active():
		controller.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.08, 0.0)


func _rebase(count: int) -> void:
	if count == 2:
		var left: Variant = _get_hand_pose(MRStage.Hand.LEFT)
		var right: Variant = _get_hand_pose(MRStage.Hand.RIGHT)
		if left == null or right == null:
			return

		_start_vector = (right as Transform3D).origin - (left as Transform3D).origin
		_start_center = ((left as Transform3D).origin + (right as Transform3D).origin) * 0.5
		_start_transform = _object.global_transform
		_start_scale = _scale
	elif count == 1:
		var pose: Variant = _get_hand_pose(_first_held())
		if pose == null:
			return

		_one_hand_offset = (pose as Transform3D).affine_inverse() * _object.global_transform


func _apply_one_hand(hand: int) -> void:
	var pose: Variant = _get_hand_pose(hand)
	if pose == null:
		return

	_object.global_transform = (pose as Transform3D) * _one_hand_offset


func _apply_two_hand() -> void:
	var left_pose: Variant = _get_hand_pose(MRStage.Hand.LEFT)
	var right_pose: Variant = _get_hand_pose(MRStage.Hand.RIGHT)
	if left_pose == null or right_pose == null:
		return

	var left := (left_pose as Transform3D).origin
	var right := (right_pose as Transform3D).origin
	var vector := right - left
	if vector.length() < 0.02 or _start_vector.length() < 0.02:
		return

	# 距離の比が倍率。制約を先に効かせてから、実際に掛ける比を出し直す。
	var wanted := _start_scale * vector.length() / _start_vector.length()
	_scale = clampf(wanted, MIN_SCALE, MAX_SCALE)
	var factor := _scale / _start_scale

	# ベクトルの向きの差が回転。最短の弧で回す。
	var rotation := Basis(Quaternion(_start_vector.normalized(), vector.normalized()))

	# 中点を基準に、掴んだ瞬間の姿勢へ回転と倍率を掛け直す。
	var center := (left + right) * 0.5
	var offset := rotation * ((_start_transform.origin - _start_center) * factor)
	var basis := rotation * _start_transform.basis.scaled(Vector3.ONE * factor)
	_object.global_transform = Transform3D(basis, center + offset)


## 掴む基準になる姿勢。手のひら、無ければgrip poseのコントローラー。
func _get_hand_pose(hand: int) -> Variant:
	if _stage.is_hand_tracking_active(hand):
		var tracker := _stage.get_hand_tracker(hand)
		var joint := XRHandTracker.HAND_JOINT_PALM
		if tracker.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID:
			return _stage.origin.global_transform * tracker.get_hand_joint_transform(joint)

	var controller := _stage.get_grip_controller(hand)
	return controller.global_transform if controller.get_is_active() else null


func _is_grabbing(hand: int) -> bool:
	if _stage.is_hand_tracking_active(hand):
		return _stage.is_pinching(hand)

	return _stage.get_grip_controller(hand).is_button_pressed(&"grab")


func _count_held() -> int:
	return int(_held[MRStage.Hand.LEFT]) + int(_held[MRStage.Hand.RIGHT])


func _first_held() -> int:
	return MRStage.Hand.LEFT if _held[MRStage.Hand.LEFT] else MRStage.Hand.RIGHT


func _update_status(count: int) -> void:
	var mode := "両手: 回転と拡縮"
	if count == 1:
		mode = "片手: 移動と回転"
	elif count == 0:
		mode = "掴んでいない"

	var limit := ""
	if is_equal_approx(_scale, MIN_SCALE) or is_equal_approx(_scale, MAX_SCALE):
		limit = "（制約に到達）"

	_status.text = (
		"両手操作\n%s\n倍率: %.2f倍%s\n制約: %.1f〜%.1f倍" % [mode, _scale, limit, MIN_SCALE, MAX_SCALE]
	)
