extends Node3D

## 部屋の要素1つぶんの見た目と当たり判定。`OpenXRFbSceneManager`が、検出した
## 要素ごとにこのシーンを作り、`setup_scene`を1回だけ呼びます。
##
## このシーンは`XRAnchor3D`の子として置かれるので、**位置合わせは書きません**。
## 姿勢はアンカーが追従します。
##
## 引数の型は`OpenXRFbSpatialEntity`ですが、pluginが無い環境でもスクリプトが
## 読めるように`Object`で受け、`call()`で叩いています。

const LABEL_COLORS := {
	"floor": Color(0.25, 0.85, 0.45),
	"ceiling": Color(0.70, 0.45, 0.95),
	"wall_face": Color(0.30, 0.55, 0.95),
	"invisible_wall_face": Color(0.30, 0.55, 0.95),
	"table": Color(0.98, 0.65, 0.20),
	"couch": Color(0.98, 0.45, 0.35),
	"bed": Color(0.95, 0.35, 0.55),
	"storage": Color(0.85, 0.75, 0.35),
	"screen": Color(0.35, 0.85, 0.90),
	"door_frame": Color(0.95, 0.55, 0.25),
	"window_frame": Color(0.55, 0.85, 0.95),
	"global_mesh": Color(0.60, 0.70, 0.80),
}
const DEFAULT_COLOR := Color(0.75, 0.80, 0.88)

## この要素が部屋全体のメッシュかどうか。ランチャー側の集計に使う。
var is_global_mesh := false


func setup_scene(entity: Object) -> void:
	var labels := PackedStringArray(entity.call(&"get_semantic_labels"))
	var kind := labels[0] if labels.size() > 0 else "other"
	is_global_mesh = kind == "global_mesh"

	# 当たり判定。要素が形を持たない場合はnullが返る。
	var shape := entity.call(&"create_collision_shape") as Node
	if shape != null:
		var body := StaticBody3D.new()
		add_child(body)
		body.add_child(shape)

	# 見た目。三角形メッシュがあればそれを、無ければ境界の箱や板を作ってくれる。
	var mesh := entity.call(&"create_mesh_instance") as MeshInstance3D
	if mesh != null:
		mesh.material_override = _create_material(kind)
		add_child(mesh)

	if is_global_mesh:
		# 部屋全体のメッシュにラベルは要らない。要素ごとの表示だけにする。
		return

	add_child(_create_label(kind, labels))


func _create_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# 実世界を覆い隠さないよう、必ず半透明にする。
	material.albedo_color = Color(LABEL_COLORS.get(kind, DEFAULT_COLOR), 0.30)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _create_label(kind: String, labels: PackedStringArray) -> Label3D:
	var label := Label3D.new()
	label.text = ", ".join(labels) if not labels.is_empty() else "other"
	label.modulate = Color(LABEL_COLORS.get(kind, DEFAULT_COLOR)).lightened(0.5)
	label.font_size = 26
	label.pixel_size = 0.0008
	label.outline_size = 14
	label.render_priority = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label
