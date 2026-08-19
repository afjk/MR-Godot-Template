extends Node3D

## 最小構成: 新しいプロジェクトを始めるときの出発点。
##
## 必要なもの: なし（`shared/`の土台だけ）
## 対応端末: 全機種
##
## MRとして成立するために要るものは、すべて`shared/mr_stage.gd`にあります。
## OpenXRの起動、Alpha environment blendの確認、リフレッシュレートの選択、
## フォーカスの喪失と復帰。このサンプルはそこへ立方体を1つ置くだけです。
##
## **自分のプロジェクトを始めるときは、`shared/`とこのフォルダをコピーして、
## `_ready`の中身を書き換えてください。** ほかのサンプルも同じ構造なので、
## 気に入ったものがあればそちらをコピーしても構いません。
##
## 実世界を覆う不透明な床や壁を置かないでください。MRではそれが最大の禁じ手です。

const CUBE_SIZE := 0.2
const CUBE_POSITION := Vector3(0.0, 1.2, -0.8)

var _stage: MRStage


func _ready() -> void:
	# 土台の準備を待つ。ランチャーから開いても、F6で単体実行しても同じ。
	_stage = await SampleBootstrap.stage_async()

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CUBE_SIZE

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.75, 0.95)
	material.roughness = 0.4

	var cube := MeshInstance3D.new()
	cube.mesh = mesh
	cube.material_override = material
	cube.position = CUBE_POSITION
	add_child(cube)


func _process(delta: float) -> void:
	if _stage == null:
		return

	# 動いていることが分かるように回すだけ。消して構いません。
	get_child(0).rotate_y(delta * 0.6)
