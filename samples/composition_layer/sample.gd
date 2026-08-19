extends Node3D

## Composition layer: 文字を**runtimeに直接合成させて**、通常の3D描画より鮮明に
## 出すサンプル。
##
## 必要なもの: なし（Godot coreの`OpenXRCompositionLayerQuad`）
## 対応端末: 全機種（runtimeが非対応なら通常描画に落ちます）
##
## 通常の3D描画では、UIはまず目のレンダーターゲットへ描かれ、そのあと歪み補正で
## 引き伸ばされます。**2回サンプリングされるので細い線や小さい文字がにじみます。**
## composition layerは、その板だけをruntimeへ渡し、最終合成のときに1回だけ
## サンプリングさせます。文字の読みやすさが目に見えて変わります。
##
## 左が composition layer、右が同じ内容の通常描画です。近づいて見比べてください。
##
## 代償もあります。runtimeが合成するので、**3Dシーンの中に入り込めません**
## （前後関係は`sort_order`と`enable_hole_punch`でしか扱えない）。UIパネルや
## 動画の再生には向きますが、ワールドに溶け込ませたい表示には向きません。

const PANEL_SIZE := Vector2(0.5, 0.36)
## 見分けのつく内容。細い線と小さい文字がいちばん差が出る。
const PANEL_TEXT := """[b]%s[/b]

細い線と小さい文字ほど差が出ます。
近づいて、この行を読み比べてください。

0123456789 ILil1 O0 rn m
|||||||||||||||||||||||||||||||||||||||"""
const VIEWPORT_SIZE := Vector2i(1024, 736)

var _stage: MRStage
var _native := false

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	var layer := OpenXRCompositionLayerQuad.new()
	layer.quad_size = PANEL_SIZE
	# パススルーの上に出すので、板の透明部分を抜く。
	layer.alpha_blend = true
	layer.position = Vector3(-0.32, 1.3, -0.9)
	var layer_viewport := _create_viewport("composition layer")
	layer.add_child(layer_viewport)
	layer.layer_viewport = layer_viewport
	add_child(layer)

	_native = layer.is_natively_supported()

	# 比べる相手。同じ内容を普通の板に貼る。
	var plain_viewport := _create_viewport("通常描画")
	add_child(plain_viewport)

	var mesh := QuadMesh.new()
	mesh.size = PANEL_SIZE

	var material := StandardMaterial3D.new()
	material.albedo_texture = plain_viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var plain := MeshInstance3D.new()
	plain.mesh = mesh
	plain.material_override = material
	plain.position = Vector3(0.32, 1.3, -0.9)
	add_child(plain)


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_status.text = _build_status()


## 見分けのつく内容を作る。細い線と小さい文字がいちばん差が出る。
func _create_viewport(title: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var background := ColorRect.new()
	background.color = Color(0.05, 0.07, 0.12, 0.85)
	background.size = VIEWPORT_SIZE
	viewport.add_child(background)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size = Vector2(VIEWPORT_SIZE) - Vector2(48, 48)
	text.position = Vector2(24, 24)
	text.add_theme_font_size_override("normal_font_size", 30)
	text.text = PANEL_TEXT % title

	viewport.add_child(text)

	return viewport


func _build_status() -> String:
	var lines: Array[String] = ["Composition layer"]
	if _native:
		lines.append("runtimeが合成しています（左が鮮明なはず）")
	else:
		lines.append("このruntimeは非対応。左も通常描画に落ちています")

	lines.append("左: composition layer ／ 右: 通常描画")
	return "\n".join(lines)
