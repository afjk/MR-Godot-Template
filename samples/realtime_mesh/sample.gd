extends Node3D

## リアルタイム環境メッシュ: 深度マップから、毎フレーム更新される環境メッシュを作る。
##
## 必要なもの: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）、
##   `project.godot`の`[shader_globals]`にMeta深度のuniform宣言（設定済み）、
##   OpenXR Vendors plugin
## 対応端末: Quest 3（`XR_META_environment_depth`）
##
## `plane_detection`が事前スキャンの部屋データを読むのに対し、こちらは**その場の
## 深度**から形を作ります。机を動かせばメッシュも動きます。
##
## 要点は、**CPUを一切使わない**ことです。pluginは深度テクスチャと逆行列を
## グローバルシェーダーuniformとして毎フレーム更新しているので、格子メッシュの
## 頂点シェーダーからそれを読んで押し出せば、それだけで環境メッシュになります。
## `realtime_planes`がやっているCPUへの吸い出し（1秒に1回程度が限度）とは、
## 更新頻度もコストも別物です。
##
## 当たり判定には使えません。形がGPU上にしか無いためです。物理に使いたい場合は
## CPU経路が要ります。

## 格子の分割数。頂点数は (SUBDIVIDE + 2)^2 になる。
const SUBDIVIDE := 95
## 頂点を動かすので、元のPlaneMeshのAABBでは視界外と判定されてしまう。
const CULL_MARGIN := 16.0
const MODE_NAMES: Array[String] = ["格子線", "面"]

var _stage: MRStage
## OpenXRMetaEnvironmentDepthExtensionのシングルトン。非対応ならnull。
var _extension: Object
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _mode := 0

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	_start_depth()


func _exit_tree() -> void:
	if _extension != null and bool(_extension.call(&"is_environment_depth_started")):
		_extension.call(&"stop_environment_depth")

	# リグにぶら下げたので、閉じるときに自分で片付ける。
	if is_instance_valid(_mesh):
		_mesh.queue_free()


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_update_view_origin()
	_toggle_mode_on_pinch()
	_status.text = _build_status()


func _start_depth() -> void:
	if not Engine.has_singleton(&"OpenXRMetaEnvironmentDepthExtension"):
		return

	_extension = Engine.get_singleton(&"OpenXRMetaEnvironmentDepthExtension")
	if not bool(_extension.call(&"is_environment_depth_supported")):
		_extension = null
		return

	_extension.call(&"start_environment_depth")
	_create_mesh()


## 押し出す前の格子を作る。位置は頂点シェーダーが全部書き換えるので、
## PlaneMeshの大きさや向きは結果に影響しない。UVだけを使う。
func _create_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_width = SUBDIVIDE
	plane.subdivide_depth = SUBDIVIDE

	_material = ShaderMaterial.new()
	_material.shader = load("res://samples/realtime_mesh/environment_mesh.gdshader")
	_material.set_shader_parameter(&"display_mode", _mode)
	_material.set_shader_parameter(&"grid_step", Vector2.ONE / float(SUBDIVIDE + 1))

	_mesh = MeshInstance3D.new()
	_mesh.mesh = plane
	_mesh.material_override = _material
	_mesh.extra_cull_margin = CULL_MARGIN
	# 逆行列はXRの基準空間を返す。原点の下に置けば、その空間がモデル空間になる。
	_stage.origin.add_child(_mesh)


## カメラの位置を基準空間で渡す。距離の色分けと有効範囲の判定に使われる。
func _update_view_origin() -> void:
	if _material == null:
		return

	var local := _stage.origin.global_transform.affine_inverse() * _stage.camera.global_position
	_material.set_shader_parameter(&"view_origin", local)


func _toggle_mode_on_pinch() -> void:
	if _material == null:
		return

	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if not _stage.is_pinch_just_started(hand):
			continue

		_mode = (_mode + 1) % MODE_NAMES.size()
		_material.set_shader_parameter(&"display_mode", _mode)
		return


func _build_status() -> String:
	if _extension == null:
		return "リアルタイム環境メッシュ\nこの端末は環境深度（XR_META_environment_depth）を\n公開していません"

	if not bool(_extension.call(&"is_environment_depth_started")):
		return "リアルタイム環境メッシュ\n深度の取得を開始できませんでした"

	return (
		"リアルタイム環境メッシュ\n表示: %s（pinchで切替）\n頂点数: %d／CPU処理なし"
		% [MODE_NAMES[_mode], (SUBDIVIDE + 2) * (SUBDIVIDE + 2)]
	)
