extends Node3D

## 2D UIパネル: GodotのControl（2D UI）を3Dの板に貼り、ポインタで操作するサンプル。
##
## 必要なもの: なし
## 対応端末: 全機種
##
## `SubViewport`に2D UIを描き、そのテクスチャを板に貼ります。ポインタが板に当たった
## 位置をピクセル座標へ直し、マウスの入力イベントとして`SubViewport`へ流し込むと、
## 既存の`Button`や`HSlider`がそのまま動きます。3D用のUIを作り直す必要はありません。

## この板だけに使う物理レイヤー。ランチャー（8）や他のサンプルと混ぜない。
const PANEL_LAYER := 32
const PANEL_SIZE := Vector2(0.48, 0.30)
const RAY_LENGTH := 4.0

var _stage: MRStage
var _was_pressed := false
var _last_pixel := Vector2.ZERO
var _hitting := false
var _count := 0

@onready var _ui: SubViewport = $SubViewport
@onready var _panel: MeshInstance3D = $Panel
@onready var _area: Area3D = $Panel/Area3D
@onready var _cube: MeshInstance3D = $Cube
@onready var _status: Label3D = $Status
@onready var _count_label: Label = $SubViewport/Root/Margin/Rows/CountLabel
@onready var _slider: HSlider = $SubViewport/Root/Margin/Rows/Slider
@onready var _toggle: CheckBox = $SubViewport/Root/Margin/Rows/Toggle
@onready var _ray: RayCast3D = $Pointer/RayCast3D
@onready var _beam: MeshInstance3D = $Pointer/Beam
@onready var _cursor: MeshInstance3D = $Pointer/Cursor
@onready var _pointer: Node3D = $Pointer


func _ready() -> void:
	_area.collision_layer = PANEL_LAYER
	_ray.collision_mask = PANEL_LAYER

	# 板の見た目はSubViewportの描画結果そのもの。
	var material := StandardMaterial3D.new()
	material.albedo_texture = _ui.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_panel.material_override = material

	$SubViewport/Root/Margin/Rows/Buttons/Increase.pressed.connect(_on_step.bind(1))
	$SubViewport/Root/Margin/Rows/Buttons/Decrease.pressed.connect(_on_step.bind(-1))
	_slider.value_changed.connect(_on_slider_changed)
	_toggle.toggled.connect(_on_toggled)
	_update_count_label()

	_stage = await SampleBootstrap.stage_async()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_pointer.global_transform = _stage.get_pointer_transform()
	var from_controller := _stage.is_pointer_from_controller()
	_ray.force_raycast_update()
	_hitting = _ray.is_colliding()

	_update_visuals(from_controller)
	_forward_pointer_to_ui()
	_status.text = "2D UIパネル\n%s" % ("板を指しています" if _hitting else "板の外です")


func _update_visuals(from_controller: bool) -> void:
	var distance := RAY_LENGTH
	if _hitting:
		distance = _pointer.global_position.distance_to(_ray.get_collision_point())

	_beam.visible = from_controller
	_beam.position.z = -distance * 0.5
	_beam.scale.y = distance
	_cursor.visible = _hitting
	_cursor.position.z = -distance


## 板に当たった位置をピクセルへ直し、マウスイベントとしてSubViewportへ流す。
func _forward_pointer_to_ui() -> void:
	var pressed := _hitting and _is_select_pressed()

	if _hitting:
		var pixel := _to_pixel(_ray.get_collision_point())
		if pixel != _last_pixel:
			var motion := InputEventMouseMotion.new()
			motion.position = pixel
			motion.global_position = pixel
			motion.relative = pixel - _last_pixel
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _was_pressed else 0
			_ui.push_input(motion)
			_last_pixel = pixel

	if pressed != _was_pressed:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = _last_pixel
		click.global_position = _last_pixel
		_ui.push_input(click)
		_was_pressed = pressed


func _to_pixel(world_point: Vector3) -> Vector2:
	# 板のローカル座標（中心が原点）をUVに直し、SubViewportの解像度へ掛ける。
	var local := _panel.to_local(world_point)
	var uv := Vector2(local.x / PANEL_SIZE.x + 0.5, 0.5 - local.y / PANEL_SIZE.y)
	return uv * Vector2(_ui.size)


func _is_select_pressed() -> bool:
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if _stage.get_aim_controller(hand).is_button_pressed(&"select"):
			return true
		if _stage.is_pinching(hand):
			return true

	return not _stage.is_mr_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _on_step(step: int) -> void:
	_count += step
	_update_count_label()


func _on_slider_changed(value: float) -> void:
	_cube.scale = Vector3.ONE * value


func _on_toggled(enabled: bool) -> void:
	_cube.visible = enabled


func _update_count_label() -> void:
	_count_label.text = "カウント: %d" % _count
