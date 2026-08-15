class_name LauncherPointer
extends Node3D

## ランチャー専用のポインタ。コントローラーのaim poseからレイを飛ばし、
## コントローラーが無ければ視線を使う。決定はコントローラーの`select`アクション、
## Hand Trackingではpinch、デスクトップではマウス左ボタン。
##
## これはランチャーの部品であってサンプルではありません。汎用のポインタは
## `docs/mr_toolkit_design.md`の検討対象です。

## レイが指している対象が変わった。
signal target_changed(target: Node3D)
## 決定された。
signal selected(target: Node3D)

const RAY_LENGTH := 4.0

var _stage: MRStage
var _target: Node3D
var _was_pressed := false

@onready var _ray: RayCast3D = $RayCast3D
@onready var _beam: MeshInstance3D = $Beam
@onready var _cursor: MeshInstance3D = $Cursor


func _process(_delta: float) -> void:
	_stage = SampleBootstrap.stage
	if _stage == null:
		return

	var from_controller := _update_source()
	_ray.force_raycast_update()

	var hit := _ray.get_collider() as Node3D
	if hit != _target:
		_target = hit
		target_changed.emit(_target)

	_update_visuals(from_controller)

	var pressed := _is_select_pressed()
	if pressed and not _was_pressed and _target != null:
		selected.emit(_target)
	_was_pressed = pressed


## 現在レイが指しているもの。指していなければnull。
func get_target() -> Node3D:
	return _target


## レイの出所を決める。コントローラーを使えた場合はtrue。
func _update_source() -> bool:
	for hand: int in [MRStage.Hand.RIGHT, MRStage.Hand.LEFT]:
		var controller := _stage.get_aim_controller(hand)
		if controller.get_is_active() and not _stage.is_hand_tracking_active(hand):
			global_transform = controller.global_transform
			return true

	# コントローラーが無い場合は視線から飛ばす。Hand Trackingではpinchで決定できる。
	global_transform = _stage.camera.global_transform
	return false


func _update_visuals(from_controller: bool) -> void:
	var distance := RAY_LENGTH
	if _ray.is_colliding():
		distance = global_position.distance_to(_ray.get_collision_point())

	# 視線から出すときにビームを描くと視界の中心が潰れるので、カーソルだけにする。
	_beam.visible = from_controller
	_beam.position.z = -distance * 0.5
	_beam.scale.y = distance
	_cursor.visible = _ray.is_colliding()
	_cursor.position.z = -distance


func _is_select_pressed() -> bool:
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if _stage.get_aim_controller(hand).is_button_pressed(&"select"):
			return true
		if _stage.is_pinching(hand):
			return true

	return not _stage.is_mr_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
