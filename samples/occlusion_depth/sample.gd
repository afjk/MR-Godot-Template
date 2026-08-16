extends Node3D

## 深度オクルージョン: 実物が仮想物体を隠すサンプル（リアルタイム）。
##
## 必要なもの: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）と
##   OpenXR Vendors plugin
## 対応端末: Quest 3（`XR_META_environment_depth`）。非対応端末では理由を表示します
##
## 部屋のスキャンは要りません。runtimeが毎フレーム作る深度マップを使うので、
## 動いている物や人、後から持ち込んだ物にも効きます。`plane_detection`が
## 事前スキャンのデータを読むのとは、性質がまったく違います。
##
## Godot側は`OpenXRMetaEnvironmentDepth`ノードを置くだけです。深度の比較は
## このノードが描画時に行います。

const CUBE_DISTANCES: Array[float] = [0.6, 1.2, 2.0]
const CUBE_COLORS: Array[Color] = [
	Color(0.95, 0.45, 0.2),
	Color(0.3, 0.8, 0.5),
	Color(0.4, 0.6, 0.95),
]

var _stage: MRStage
## OpenXRMetaEnvironmentDepthExtensionのシングルトン。非対応ならnull。
var _extension: Object
## 深度オクルージョンを描くノード。VisualInstance3Dを継承している。
var _depth_node: Node3D
var _hand_removal := false

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	for index in CUBE_DISTANCES.size():
		_create_cube(index)

	_start_depth()


func _exit_tree() -> void:
	if _extension != null and bool(_extension.call(&"is_environment_depth_started")):
		_extension.call(&"stop_environment_depth")

	if is_instance_valid(_depth_node):
		_depth_node.queue_free()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_toggle_hand_removal_on_pinch()
	_status.text = _build_status()


func _start_depth() -> void:
	if not Engine.has_singleton(&"OpenXRMetaEnvironmentDepthExtension"):
		return

	_extension = Engine.get_singleton(&"OpenXRMetaEnvironmentDepthExtension")
	if not bool(_extension.call(&"is_environment_depth_supported")):
		return

	_extension.call(&"start_environment_depth")

	# ノードを置くと、描画時に深度マップと比較して手前の実物で隠してくれる。
	_depth_node = ClassDB.instantiate(&"OpenXRMetaEnvironmentDepth") as Node3D
	if _depth_node != null:
		_stage.origin.add_child(_depth_node)


## pinchで「手を深度から除く」を切り替える。手が隠す側に回るかどうかが変わる。
func _toggle_hand_removal_on_pinch() -> void:
	if _extension == null or not bool(_extension.call(&"is_hand_removal_supported")):
		return

	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if not _stage.is_pinch_just_started(hand):
			continue

		_hand_removal = not _hand_removal
		_extension.call(&"set_hand_removal_enabled", _hand_removal)
		return


func _create_cube(index: int) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.16

	var material := StandardMaterial3D.new()
	material.albedo_color = CUBE_COLORS[index]
	material.roughness = 0.35

	var cube := MeshInstance3D.new()
	cube.mesh = mesh
	cube.material_override = material
	cube.position = Vector3(0.0, 1.2, -CUBE_DISTANCES[index])
	add_child(cube)

	var label := Label3D.new()
	label.text = "%.1f m" % CUBE_DISTANCES[index]
	label.font_size = 26
	label.pixel_size = 0.0006
	label.outline_size = 14
	label.position = Vector3(0, 0.13, 0)
	cube.add_child(label)


func _build_status() -> String:
	if _extension == null:
		return "深度オクルージョン\nこの端末は環境深度（XR_META_environment_depth）を\n公開していません"

	if not bool(_extension.call(&"is_environment_depth_started")):
		return "深度オクルージョン\n深度の取得を開始できませんでした"

	var lines: Array[String] = [
		"深度オクルージョン",
		"手や物を立方体の手前に出すと隠れます",
	]
	if bool(_extension.call(&"is_hand_removal_supported")):
		lines.append("手を深度から除く: %s（pinchで切替）" % ("ON" if _hand_removal else "OFF"))

	return "\n".join(lines)
