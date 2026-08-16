extends Node3D

## 遠隔ポインタ: レイで離れた対象を指して選び、手を近づけるとレイを引っ込める。
##
## 必要なもの: なし（Hand Trackingがあれば視線＋pinchでも選べる）
## 対応端末: 全機種
##
## MRTKのInteraction Mode Managerに相当する「近接と遠隔の切り替え」を、
## 最小の形で入れています。手が対象の近くにあるときはレイを消し、近くのものを
## 直接選ぶ扱いにします。遠隔と近接が同時に効くと、意図しない方が反応します。
##
## レイをどこから飛ばすか（コントローラーか視線か）は`shared/mr_stage.gd`が持ちます。
## 全サンプルとランチャーで同じ判断にしないと、手が片方外れたときの挙動がばらつきます。

const TARGET_TITLES: Array[String] = ["対象 A", "対象 B", "対象 C"]
const TARGET_ORIGIN := Vector3(0.0, 1.3, -1.8)
const TARGET_PITCH := 0.5
const TARGET_SIZE := 0.18
## ランチャーのUI（レイヤー8）と混ざらないよう、このサンプル専用のレイヤーを使う。
const TARGET_LAYER := 16
const RAY_LENGTH := 4.0
## 手がこの距離まで近づいたら近接扱いにしてレイを消す。
const NEAR_DISTANCE := 0.25

const COLOR_IDLE := Color(0.12, 0.20, 0.30, 0.95)
const COLOR_HOVER := Color(0.16, 0.42, 0.72, 0.98)
const COLOR_SELECTED := Color(0.95, 0.45, 0.15, 1.0)

var _stage: MRStage
var _targets: Array[MeshInstance3D] = []
var _counts: Array[int] = []
var _hovered := -1
var _near := false
var _was_pressed := false

@onready var _status: Label3D = $Status
@onready var _pointer: Node3D = $Pointer
@onready var _ray: RayCast3D = $Pointer/RayCast3D
@onready var _beam: MeshInstance3D = $Pointer/Beam
@onready var _cursor: MeshInstance3D = $Pointer/Cursor


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	for index in TARGET_TITLES.size():
		var offset := Vector3((index - 1) * TARGET_PITCH, 0.0, 0.0)
		_targets.append(_create_target(TARGET_TITLES[index], TARGET_ORIGIN + offset))
		_counts.append(0)


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_pointer.global_transform = _stage.get_pointer_transform()
	var from_controller := _stage.is_pointer_from_controller()
	_ray.force_raycast_update()

	# 近接が成立していれば、レイの結果より近くの対象を優先する。
	var near_index := _find_near_target()
	_near = near_index >= 0
	_hovered = near_index if _near else _find_ray_target()

	_update_visuals(from_controller)
	_update_selection()
	_update_status()


func _find_ray_target() -> int:
	var area := _ray.get_collider() as Node3D
	if area == null:
		return -1

	return _targets.find(area.get_parent() as MeshInstance3D)


## 手が近くにある対象を探す。無ければ-1。
func _find_near_target() -> int:
	var nearest := -1
	var nearest_distance := NEAR_DISTANCE
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		var point: Variant = _get_hand_point(hand)
		if point == null:
			continue

		for index in _targets.size():
			var distance: float = _targets[index].global_position.distance_to(point)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = index

	return nearest


func _get_hand_point(hand: int) -> Variant:
	if not _stage.is_hand_tracking_active(hand):
		return null

	var tracker := _stage.get_hand_tracker(hand)
	var joint := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
	if not (tracker.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID):
		return null

	return _stage.origin.global_transform * tracker.get_hand_joint_transform(joint).origin


func _update_visuals(from_controller: bool) -> void:
	var distance := RAY_LENGTH
	if _ray.is_colliding():
		distance = _pointer.global_position.distance_to(_ray.get_collision_point())

	# 近接中はレイを消す。視線から出すときもビームは描かない。
	_beam.visible = from_controller and not _near
	_beam.position.z = -distance * 0.5
	_beam.scale.y = distance
	_cursor.visible = _ray.is_colliding() and not _near
	_cursor.position.z = -distance

	for index in _targets.size():
		var material := _targets[index].material_override as StandardMaterial3D
		if index == _hovered:
			material.albedo_color = COLOR_HOVER
		elif _counts[index] % 2 == 1:
			material.albedo_color = COLOR_SELECTED
		else:
			material.albedo_color = COLOR_IDLE


func _update_selection() -> void:
	var pressed := _is_select_pressed()
	if pressed and not _was_pressed and _hovered >= 0:
		_counts[_hovered] += 1

	_was_pressed = pressed


func _is_select_pressed() -> bool:
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if _stage.get_aim_controller(hand).is_button_pressed(&"select"):
			return true
		if _stage.is_pinching(hand):
			return true

	return false


func _create_target(title: String, position: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * TARGET_SIZE

	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_IDLE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var target := MeshInstance3D.new()
	target.mesh = mesh
	target.material_override = material
	target.position = position
	add_child(target)

	var label := Label3D.new()
	label.text = title
	label.font_size = 28
	label.pixel_size = 0.0006
	label.position = Vector3(0, TARGET_SIZE * 0.75, 0)
	target.add_child(label)

	var area := Area3D.new()
	area.collision_layer = TARGET_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * TARGET_SIZE
	shape.shape = box
	area.add_child(shape)
	target.add_child(area)

	return target


func _update_status() -> void:
	var mode := "近接（レイは停止）" if _near else "遠隔（レイ）"
	var hovered := TARGET_TITLES[_hovered] if _hovered >= 0 else "なし"
	var counts: Array[String] = []
	for index in _counts.size():
		counts.append("%s:%d" % [TARGET_TITLES[index].right(1), _counts[index]])

	_status.text = "遠隔ポインタ\nモード: %s\n指している: %s\n選んだ回数 %s" % [mode, hovered, " ".join(counts)]
