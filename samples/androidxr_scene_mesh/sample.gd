extends Node3D

## Android XRのリアルタイム環境メッシュ: OSが逐次更新する部屋のメッシュを、
## 意味ラベル付きで受け取るサンプル。
##
## 必要なもの: `xr/openxr/extensions/androidxr/scene_meshing=true`（設定済み）、
##   OpenXR Vendors plugin、`android.permission.SCENE_UNDERSTANDING_FINE`
## 対応端末: Android XR（`XR_ANDROID_scene_meshing`）
##
## **実機が無いため未検証です。** コードはOpenXR Vendors同梱のサンプルと
## プラグインのドキュメントに合わせてあります。
##
## Quest 3では、部屋メッシュは事前スキャンのものしか取れず（`scene_mesh`）、
## リアルタイムに欲しければ深度から自作するしかありません（`realtime_mesh`）。
## Android XRは**OSが逐次更新したメッシュを直接くれます**。しかも面ごとに
## 床・壁・天井・机の意味ラベルが付きます。
##
## メッシュは小片（submesh）の集まりとして届き、それぞれに更新状態があります。
##   CREATED   新しく現れた
##   UPDATED   形が変わった
##   UNCHANGED 変化なし（作り直さない）
##   DELETED   消えた
##
## 全部作り直すのではなく、**この状態を見て差分だけ触る**のが要点です。

## メッシュを引く間隔。毎フレームは要らない。
const QUERY_INTERVAL := 0.5
## カメラ前方のどれだけの範囲を問い合わせるか（メートル）。
const QUERY_EXTENTS := Vector3(6.0, 4.0, 6.0)
const QUERY_FORWARD := 3.0

## OpenXRAndroidSceneMeshing.SemanticLabelSetの値。
const SEMANTIC_LABEL_SET_NONE := 0
const SEMANTIC_LABEL_SET_DEFAULT := 1

## OpenXRAndroidSceneSubmeshData.UpdateStateの値。
const UPDATE_STATE_CREATED := 0
const UPDATE_STATE_UNCHANGED := 1
const UPDATE_STATE_UPDATED := 2
const UPDATE_STATE_DELETED := 3

var _stage: MRStage
## OpenXRAndroidSceneMeshing。非対応ならnull。
var _meshing: Object
## submeshのUUID -> 表示しているMeshInstance3D。
var _submeshes: Dictionary = {}
var _timer := 0.0
var _labels_enabled := false

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	_start_meshing()


func _exit_tree() -> void:
	for instance: Node3D in _submeshes.values():
		if is_instance_valid(instance):
			instance.queue_free()

	_submeshes.clear()


func _process(delta: float) -> void:
	if _stage == null:
		return

	_status.text = _build_status()
	if _meshing == null:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_timer = QUERY_INTERVAL
	_query()


func _start_meshing() -> void:
	if not Engine.has_singleton(&"OpenXRAndroidSceneMeshingExtension"):
		return

	var extension := Engine.get_singleton(&"OpenXRAndroidSceneMeshingExtension")
	var supported: Array = extension.call(&"get_supported_semantic_label_sets")

	# 意味ラベルは取れるなら取る。取れない端末では形だけになる。
	var label_set := SEMANTIC_LABEL_SET_NONE
	if supported.has(SEMANTIC_LABEL_SET_DEFAULT):
		label_set = SEMANTIC_LABEL_SET_DEFAULT
		_labels_enabled = true

	var meshing := ClassDB.instantiate(&"OpenXRAndroidSceneMeshing")
	if meshing == null:
		return

	if not bool(meshing.call(&"initialize", label_set, true)):
		return

	_meshing = meshing


## 視線の先を問い合わせ、届いた小片の更新状態に従って差分だけ触る。
func _query() -> void:
	var pose := _stage.camera.global_transform.translated_local(Vector3(0.0, 0.0, -QUERY_FORWARD))
	var results: Dictionary = _meshing.call(&"get_submesh_data", pose, QUERY_EXTENTS)

	for uuid: StringName in results:
		var data: Object = results[uuid]
		var state := int(data.call(&"get_update_state"))

		if state == UPDATE_STATE_DELETED:
			_remove_submesh(uuid)
			continue

		var instance: MeshInstance3D = _submeshes.get(uuid)
		if instance == null:
			instance = _create_instance()
			_submeshes[uuid] = instance

		# 姿勢は毎回入れ直す。動くのは形だけではない。
		instance.transform = data.call(&"get_transform")

		# 変化していない小片のメッシュは作り直さない。ここが効く。
		if state == UPDATE_STATE_UNCHANGED:
			continue

		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.call(&"get_arrays"))
		instance.mesh = mesh


func _create_instance() -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	# 実世界を覆い隠さないよう、必ず半透明にする。
	material.albedo_color = Color(0.45, 0.80, 0.95, 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var instance := MeshInstance3D.new()
	instance.material_override = material
	# 座標はXRの基準空間。原点の下に置けば、そのままローカル座標になる。
	_stage.origin.add_child(instance)
	return instance


func _remove_submesh(uuid: StringName) -> void:
	var instance: Node3D = _submeshes.get(uuid)
	if instance != null:
		instance.queue_free()
		_submeshes.erase(uuid)


func _build_status() -> String:
	if _meshing == null:
		return "Android XRの環境メッシュ\nこの端末はXR_ANDROID_scene_meshingを\n公開していません"

	var lines: Array[String] = ["Android XRの環境メッシュ"]
	lines.append("小片: %d（%.1f秒ごとに更新）" % [_submeshes.size(), QUERY_INTERVAL])
	lines.append("意味ラベル: %s" % ("あり" if _labels_enabled else "なし"))
	return "\n".join(lines)
