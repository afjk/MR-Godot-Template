extends Node3D

@export_enum("Left", "Right") var hand := 0

const HAND_COLORS: Array[Color] = [
	Color(0.05, 0.62, 1.0, 1.0),
	Color(1.0, 0.18, 0.12, 1.0),
]


func _ready() -> void:
	var primary_material := StandardMaterial3D.new()
	primary_material.albedo_color = HAND_COLORS[hand]
	primary_material.metallic = 0.12
	primary_material.roughness = 0.3

	var control_material := StandardMaterial3D.new()
	control_material.albedo_color = Color(0.035, 0.045, 0.055, 1.0)
	control_material.metallic = 0.05
	control_material.roughness = 0.42

	$Handle.material_override = primary_material
	$Body.material_override = primary_material
	$ThumbPad.material_override = control_material
	$Trigger.material_override = control_material

	var thumb_pad_x := absf($ThumbPad.position.x)
	$ThumbPad.position.x = -thumb_pad_x if hand == 0 else thumb_pad_x
