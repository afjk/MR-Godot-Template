extends Node3D

## コントローラーモデル: runtimeが提供するコントローラーの3Dモデルを表示するサンプル。
##
## 必要なもの: `xr/openxr/extensions/render_model=true`、Meta経路は加えて
##   `xr/openxr/extensions/meta/render_model=true`とQuest presetのRender Model
## 対応端末: 全機種（非対応なら球マーカーへ落ちる）
##
## モデルを供給するextensionは2種類あり、どちらを公開するかはruntimeによります。
##   XR_EXT_render_model … Godot 4.6 core（`OpenXRRenderModelManager`）
##   XR_FB_render_model  … OpenXR Vendors plugin（`OpenXRFbRenderModel`）
## そのため両方を用意し、実際にモデルを返した方を毎フレーム採用します。

const HAND_COLORS: Array[Color] = [
	Color(0.05, 0.62, 1.0, 1.0),
	Color(1.0, 0.18, 0.12, 1.0),
]
const MARKER_RADIUS := 0.018

var _stage: MRStage
var _core_managers: Array[OpenXRRenderModelManager] = []
var _meta_models: Array[Node3D] = []
var _fallback_markers: Array[MeshInstance3D] = []
## 掃除するために、grip controllerへぶら下げたノードを覚えておく。
var _attached: Array[Node] = []

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	var core_active := _is_core_render_model_active()
	var meta_available := ClassDB.class_exists(&"OpenXRFbRenderModel")

	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		var grip := _stage.get_grip_controller(hand)
		_core_managers.append(_attach_core_manager(grip, hand))

		# 片手だけ生成できない場合に添字がずれないよう、失敗もnullとして詰める。
		var model: Node3D = _attach_meta_model(grip, hand) if meta_available else null
		meta_available = meta_available and model != null
		_meta_models.append(model)
		_fallback_markers.append(_attach_marker(grip, hand))

	print("OpenXR: render models - core %s, Meta %s" % [core_active, meta_available])


func _exit_tree() -> void:
	# grip controllerはリグ側のノードなので、ぶら下げたものは自分で片付ける。
	for node in _attached:
		if is_instance_valid(node):
			node.queue_free()

	_attached.clear()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	var lines: Array[String] = ["コントローラーモデル"]
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		lines.append(_update_hand(hand))

	_status.text = "\n".join(lines)


func _update_hand(hand: int) -> String:
	var label := "左" if hand == MRStage.Hand.LEFT else "右"
	var hand_tracking := _stage.is_hand_tracking_active(hand)
	var grip := _stage.get_grip_controller(hand)
	var tracked := grip.get_is_active() and not hand_tracking

	var core_model := _core_managers[hand].get_child_count() > 0
	var meta_model := false
	var model: Node3D = _meta_models[hand] if hand < _meta_models.size() else null
	if model != null:
		meta_model = bool(model.call(&"has_render_model_node"))
		# 両方のextensionを公開するruntimeもある。1つの手に2つ描かない。
		model.visible = tracked and meta_model and not core_model

	_core_managers[hand].visible = tracked
	_fallback_markers[hand].visible = tracked and not core_model and not meta_model

	if hand_tracking:
		return "%s: Hand Tracking中" % label
	if not grip.get_is_active():
		return "%s: 追跡なし" % label
	if core_model:
		return "%s: coreのモデル" % label
	if meta_model:
		return "%s: Metaのモデル" % label

	return "%s: 球マーカー（モデル非対応）" % label


func _is_core_render_model_active() -> bool:
	if not Engine.has_singleton(&"OpenXRRenderModelExtension"):
		return false

	return Engine.get_singleton(&"OpenXRRenderModelExtension").is_active()


func _attach_core_manager(grip: XRController3D, hand: int) -> OpenXRRenderModelManager:
	var manager := OpenXRRenderModelManager.new()
	# tracker 2 = 左コントローラー、3 = 右コントローラー。
	manager.tracker = 2 + hand
	manager.make_local_to_pose = "grip"
	grip.add_child(manager)
	_attached.append(manager)
	return manager


func _attach_meta_model(grip: XRController3D, hand: int) -> Node3D:
	# pluginが無い環境でもこのサンプルが読めるよう、class名から生成する。
	var model := ClassDB.instantiate(&"OpenXRFbRenderModel") as Node3D
	if model == null:
		return null

	model.set(&"render_model_type", hand)
	grip.add_child(model)
	_attached.append(model)
	return model


func _attach_marker(grip: XRController3D, hand: int) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = MARKER_RADIUS
	sphere.height = MARKER_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6

	var material := StandardMaterial3D.new()
	material.albedo_color = HAND_COLORS[hand]
	material.metallic = 0.12
	material.roughness = 0.3

	var marker := MeshInstance3D.new()
	marker.mesh = sphere
	marker.material_override = material
	marker.visible = false
	grip.add_child(marker)
	_attached.append(marker)
	return marker
