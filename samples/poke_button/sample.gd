extends Node3D

## 押せるボタン: 指先やコントローラーでボタンを押し込むサンプル。
##
## 必要なもの: 指で押すには`xr/openxr/extensions/hand_tracking=true`
## 対応端末: 全機種（Hand Trackingが無ければコントローラーの先端で押せる）
##
## 押し込み量を1つの値として持ち、板の沈み込み・色・押下判定をすべてそこから
## 作ります。押す位置と離す位置をずらして（ヒステリシス）、指の震えで連打に
## ならないようにしています。

const BUTTON_TITLES: Array[String] = ["ボタン A", "ボタン B", "ボタン C"]
const BUTTON_SIZE := Vector2(0.14, 0.06)
const BUTTON_ORIGIN := Vector3(0.0, 1.25, -0.45)
const BUTTON_PITCH := 0.17
## 板が沈み込める最大の深さ。
const MAX_DEPTH := 0.014
## ここまで押し込んだら押下、ここまで戻ったら解除。差がヒステリシス。
const PRESS_DEPTH := 0.011
const RELEASE_DEPTH := 0.005
## 前面からこの距離まで近づいたらホバー扱い。
const HOVER_DISTANCE := 0.03

const COLOR_IDLE := Color(0.10, 0.16, 0.24, 0.94)
const COLOR_HOVER := Color(0.16, 0.42, 0.72, 0.96)
const COLOR_PRESSED := Color(0.16, 0.70, 0.52, 1.0)


## 1つのボタンの見た目と状態。
class PokeButton:
	var root: Node3D
	var plate: MeshInstance3D
	var label: Label3D
	var title := ""
	var depth := 0.0
	var pressed := false
	var hovered := false
	var count := 0


var _stage: MRStage
var _buttons: Array[PokeButton] = []

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	for index in BUTTON_TITLES.size():
		var offset := Vector3((index - 1) * BUTTON_PITCH, 0.0, 0.0)
		_buttons.append(_create_button(BUTTON_TITLES[index], BUTTON_ORIGIN + offset))


func _process(_delta: float) -> void:
	if _stage == null:
		return

	var points := _collect_poke_points()
	for button in _buttons:
		_update_button(button, points)

	_update_status(points)


## 押すのに使う点を左右ぶんそろえる。取れない手はnullを入れて添字を保つ。
func _collect_poke_points() -> Array:
	var points: Array = []
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		points.append(_get_finger_tip(hand))

	return points


func _get_finger_tip(hand: int) -> Variant:
	# 光学式の手があれば人差し指の先、無ければコントローラーの位置で押す。
	if _stage.is_hand_tracking_active(hand):
		var tracker := _stage.get_hand_tracker(hand)
		var joint := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
		if tracker.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID:
			var local := tracker.get_hand_joint_transform(joint).origin
			return _stage.origin.global_transform * local

	var controller := _stage.get_aim_controller(hand)
	return controller.global_position if controller.get_is_active() else null


func _update_button(button: PokeButton, points: Array) -> void:
	var depth := 0.0
	var hovered := false
	var pressing_hand := -1

	for hand in points.size():
		var point: Variant = points[hand]
		if point == null:
			continue

		# ボタンのローカル座標へ移すと、面内かどうかと押し込み量が同時に出る。
		var local: Vector3 = button.root.to_local(point)
		if absf(local.x) > BUTTON_SIZE.x * 0.5 or absf(local.y) > BUTTON_SIZE.y * 0.5:
			continue
		# 手前すぎる（未接触）ときと、裏側へ抜けたときは無視する。
		if local.z > HOVER_DISTANCE or local.z < -0.08:
			continue

		hovered = true
		var candidate := clampf(-local.z, 0.0, MAX_DEPTH)
		if candidate > depth:
			depth = candidate
			pressing_hand = hand

	button.depth = depth
	button.hovered = hovered
	button.plate.position.z = -depth

	if not button.pressed and depth >= PRESS_DEPTH:
		button.pressed = true
		button.count += 1
		_on_pressed(button, pressing_hand)
	elif button.pressed and depth <= RELEASE_DEPTH:
		button.pressed = false

	var material := button.plate.material_override as StandardMaterial3D
	material.albedo_color = _plate_color(button)
	button.label.text = "%s  %d回" % [button.title, button.count]


func _on_pressed(_button: PokeButton, hand: int) -> void:
	if hand < 0:
		return

	# 押したのがコントローラーなら短く振動させる。手で押した場合は何も起きない。
	var controller := _stage.get_aim_controller(hand)
	if controller.get_is_active():
		controller.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.06, 0.0)


func _plate_color(button: PokeButton) -> Color:
	if button.pressed:
		return COLOR_PRESSED

	if not button.hovered:
		return COLOR_IDLE

	# ホバー中は押し込み量に応じて色を寄せる。selectednessの最小版。
	return COLOR_HOVER.lerp(COLOR_PRESSED, button.depth / MAX_DEPTH)


func _create_button(title: String, position: Vector3) -> PokeButton:
	var button := PokeButton.new()
	button.title = title

	button.root = Node3D.new()
	button.root.position = position
	add_child(button.root)

	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(BUTTON_SIZE.x, BUTTON_SIZE.y, 0.006)
	back.mesh = back_mesh
	back.position.z = -MAX_DEPTH - 0.008
	var back_material := StandardMaterial3D.new()
	back_material.albedo_color = Color(0.03, 0.05, 0.08, 0.7)
	back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back.material_override = back_material
	button.root.add_child(back)

	button.plate = MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(BUTTON_SIZE.x * 0.94, BUTTON_SIZE.y * 0.86, 0.012)
	button.plate.mesh = plate_mesh
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = COLOR_IDLE
	plate_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	button.plate.material_override = plate_material
	button.root.add_child(button.plate)

	button.label = Label3D.new()
	button.label.text = title
	button.label.font_size = 32
	button.label.pixel_size = 0.0006
	button.label.position.z = 0.008
	button.plate.add_child(button.label)

	return button


func _update_status(points: Array) -> void:
	var sources: Array[String] = []
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		var label := "左" if hand == MRStage.Hand.LEFT else "右"
		if points[hand] == null:
			sources.append("%s: なし" % label)
		elif _stage.is_hand_tracking_active(hand):
			sources.append("%s: 指先" % label)
		else:
			sources.append("%s: コントローラー" % label)

	_status.text = "押せるボタン\n%s" % " / ".join(sources)
