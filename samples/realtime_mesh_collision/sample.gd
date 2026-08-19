extends Node3D

## リアルタイム環境メッシュの当たり判定: 深度からcollisionを作り、実際の床や机で
## ボールを跳ねさせるサンプル。
##
## 必要なもの: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）と
##   OpenXR Vendors plugin
## 対応端末: Quest 3（`XR_META_environment_depth`）
##
## `realtime_mesh`は頂点シェーダーで毎フレーム押し出すので速いかわりに、形が
## GPU上にしかなく**物理には使えません**。当たり判定が要るなら、深度をCPUへ
## 落として`ConcavePolygonShape3D`を作るしかありません。
##
## 代償は更新頻度です。GPUからCPUへの転送は安価ではなく、深度マップ自体も毎
## フレーム更新されるわけではないため、1秒に1回程度が限度です。動いている物には
## 追いつきませんが、床・壁・机のような動かない面には十分間に合います。
##
## pinchでボールを投げます。

## 深度を引く間隔。毎フレーム引いてはいけない。
const SAMPLE_INTERVAL := 1.0
## 格子の一辺のサンプル数。増やすと形は細かくなるが、GDScriptの処理時間が伸びる。
const GRID_STEPS := 40
## 視界の端は歪みとノイズが大きいので少し内側だけを使う。
const NDC_EXTENT := 0.9
## 面とみなす最短・最長距離。Metaの資料では有効範囲は約0.2〜4m。
const MIN_DISTANCE := 0.2
const MAX_DISTANCE := 4.0
## 隣の点とこれ以上離れていたら、物の境目とみなして三角形を張らない。
const EDGE_THRESHOLD := 0.2

const BALL_RADIUS := 0.05
const BALL_SPEED := 3.0
const MAX_BALLS := 12

var _stage: MRStage
## OpenXRMetaEnvironmentDepthExtensionのシングルトン。非対応ならnull。
var _extension: Object
var _body: StaticBody3D
var _collision: CollisionShape3D
var _surface: MeshInstance3D
var _balls: Array[RigidBody3D] = []
var _timer := 0.0
var _pending := false
var _triangle_count := 0
var _message := "深度の取得を待っています"

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	_start_depth()


func _exit_tree() -> void:
	if _extension != null and bool(_extension.call(&"is_environment_depth_started")):
		_extension.call(&"stop_environment_depth")

	# リグにぶら下げたので、閉じるときに自分で片付ける。
	if is_instance_valid(_body):
		_body.queue_free()


func _process(delta: float) -> void:
	if _stage == null:
		return

	_throw_ball_on_pinch()
	_status.text = _build_status()
	if _extension == null or _pending:
		return

	if not bool(_extension.call(&"is_environment_depth_started")):
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_timer = SAMPLE_INTERVAL
	_pending = true
	_extension.call(&"get_environment_depth_map_async", _on_depth_map)


func _start_depth() -> void:
	if not Engine.has_singleton(&"OpenXRMetaEnvironmentDepthExtension"):
		return

	_extension = Engine.get_singleton(&"OpenXRMetaEnvironmentDepthExtension")
	if not bool(_extension.call(&"is_environment_depth_supported")):
		_extension = null
		return

	_extension.call(&"start_environment_depth")
	_create_body()


## collisionと表示を入れる箱を作る。逆行列が返すのはXRの基準空間なので、
## XROrigin3Dの直下に置いてローカル座標をそのまま使う。
func _create_body() -> void:
	_body = StaticBody3D.new()
	_collision = CollisionShape3D.new()
	_body.add_child(_collision)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.75, 0.95, 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_surface = MeshInstance3D.new()
	_surface.material_override = material
	_body.add_child(_surface)

	_stage.origin.add_child(_body)


## 深度マップが届いた。左右ぶんの辞書が配列で渡る。片目だけ使えば十分。
func _on_depth_map(eyes: Array) -> void:
	_pending = false
	if eyes.is_empty():
		_message = "深度マップが空でした"
		return

	var eye: Dictionary = eyes[0]
	var image: Image = eye.get("image")
	var inverse: Projection = eye.get("depth_inverse_projection_view", Projection())
	if image == null:
		_message = "深度マップに画像がありません"
		return

	_rebuild(_sample_grid(image, inverse))


## 深度画像を格子状に間引いて、基準空間の点にする。並びは三角形を張るのに使う。
func _sample_grid(image: Image, inverse: Projection) -> Array:
	var camera_local := (
		_stage.origin.global_transform.affine_inverse() * _stage.camera.global_position
	)
	return DepthGrid.sample(
		image, inverse, GRID_STEPS, NDC_EXTENT, camera_local, MIN_DISTANCE, MAX_DISTANCE
	)


## 格子から三角形を張り、collisionと表示メッシュを作り直す。
func _rebuild(grid: Array) -> void:
	var faces := PackedVector3Array()
	for row in GRID_STEPS - 1:
		for column in GRID_STEPS - 1:
			var a: Variant = (grid[row] as Array)[column]
			var b: Variant = (grid[row] as Array)[column + 1]
			var c: Variant = (grid[row + 1] as Array)[column]
			var d: Variant = (grid[row + 1] as Array)[column + 1]
			if a == null or b == null or c == null or d == null:
				continue

			# 手前の物と奥の壁をまたぐ四角は、板のように引き伸ばされるので捨てる。
			if not _is_continuous(a, b, c, d):
				continue

			faces.append_array([a, b, c])
			faces.append_array([b, d, c])

	_triangle_count = faces.size() / 3
	if _triangle_count == 0:
		_message = "面を作れるだけの深度が取れませんでした"
		_collision.shape = null
		_surface.mesh = null
		return

	_message = ""

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	_collision.shape = shape

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_surface.mesh = mesh


## 四隅が同じ面に乗っているか。深度が飛んでいたら三角形を張らない。
func _is_continuous(a: Variant, b: Variant, c: Variant, d: Variant) -> bool:
	var origin: Vector3 = a
	for other: Vector3 in [b, c, d]:
		if origin.distance_to(other) > EDGE_THRESHOLD:
			return false

	return true


func _throw_ball_on_pinch() -> void:
	if _body == null:
		return

	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if not _stage.is_pinch_just_started(hand):
			continue

		_throw_ball()
		return


func _throw_ball() -> void:
	var ball := RigidBody3D.new()
	var shape := SphereShape3D.new()
	shape.radius = BALL_RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ball.add_child(collision)

	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	mesh.height = BALL_RADIUS * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.98, 0.6, 0.2)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	ball.add_child(visual)

	var pointer := _stage.get_pointer_transform()
	add_child(ball)
	ball.global_transform = Transform3D(Basis(), pointer.origin)
	# 見ている向きへ投げる。-Zが前。
	ball.linear_velocity = -pointer.basis.z * BALL_SPEED

	_balls.append(ball)
	if _balls.size() > MAX_BALLS:
		var oldest := _balls.pop_front() as RigidBody3D
		if is_instance_valid(oldest):
			oldest.queue_free()


func _build_status() -> String:
	if _extension == null:
		return "環境メッシュの当たり判定\nこの端末は環境深度（XR_META_environment_depth）を\n公開していません"

	if not bool(_extension.call(&"is_environment_depth_started")):
		return "環境メッシュの当たり判定\n深度の取得を開始できませんでした"

	if not _message.is_empty():
		return "環境メッシュの当たり判定\n%s" % _message

	return (
		"環境メッシュの当たり判定\n三角形: %d（%.1f秒ごとに作り直し）\npinchでボールを投げる（%d個まで）"
		% [_triangle_count, SAMPLE_INTERVAL, MAX_BALLS]
	)
