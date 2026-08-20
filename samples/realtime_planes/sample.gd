extends Node3D

## リアルタイム平面推定: 見ている先の面を、その場の深度から毎回作り直すサンプル。
##
## 必要なもの: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）と
##   OpenXR Vendors plugin
## 対応端末: Quest 3（`XR_META_environment_depth`）
##
## `plane_detection`は事前スキャン済みの部屋データを読むので、机を動かしても
## 平面は動きません。こちらは**runtimeが毎フレーム作る深度マップ**から、視線の
## 先にある面をその都度推定します。スキャン不要で、動かした物にも追従します。
##
## 手順は3つです。
##   1. 深度マップをCPUへ落とす（`get_environment_depth_map_async`）
##   2. 視界中央付近を格子状に拾い、逆行列でXRの基準空間へ戻す（`DepthGrid`）
##   3. 格子の縦横の接ベクトルから法線を出す
##
## 2の座標変換は`realtime_mesh_collision`と`realtime_plane_clusters`でも同じものが
## 要るので、規約どおり`shared/depth_grid.gd`へ寄せてあります。
##
## 深度マップは毎フレーム更新されるわけではなく、CPUへの転送も安価ではありません。
## ドキュメントの助言どおり、1秒に1回程度の間隔で引きます。

## 深度マップを引く間隔。毎フレーム引いてはいけない。
const SAMPLE_INTERVAL := 0.8
## 画面中央から何割の範囲を見るか。狭いと法線が荒れる。
const PATCH_EXTENT := 0.25
## 一辺あたりのサンプル数。
const PATCH_STEPS := 7
## 面とみなす最短・最長距離。外れ値を捨てる。
const MIN_DISTANCE := 0.2
const MAX_DISTANCE := 5.0
## 中央値からこの割合を超えて離れた点は、別の物体とみなして捨てる。
const OUTLIER_RATIO := 0.25

var _stage: MRStage
var _extension: Object
var _timer := 0.0
var _pending := false
var _message := "深度の取得を待っています"
var _distance := 0.0
var _normal := Vector3.ZERO
var _sample_count := 0

@onready var _plane: MeshInstance3D = $Plane
@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	_plane.visible = false

	if not Engine.has_singleton(&"OpenXRMetaEnvironmentDepthExtension"):
		_message = "この端末は環境深度（XR_META_environment_depth）を公開していません"
		return

	_extension = Engine.get_singleton(&"OpenXRMetaEnvironmentDepthExtension")
	if not bool(_extension.call(&"is_environment_depth_supported")):
		_message = "この端末は環境深度に対応していません"
		_extension = null
		return

	_extension.call(&"start_environment_depth")


func _exit_tree() -> void:
	if _extension != null and bool(_extension.call(&"is_environment_depth_started")):
		_extension.call(&"stop_environment_depth")


func _process(delta: float) -> void:
	if _stage == null:
		return

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

	var grid := _sample_grid(image, inverse)
	if _sample_count < 6:
		_message = "面を作れるだけの深度が取れませんでした"
		_plane.visible = false
		return

	_message = ""
	_fit_plane(grid)


## 視界中央付近を格子状に拾う。格子の並びは法線を出すのに使うので保つ。
func _sample_grid(image: Image, inverse: Projection) -> Array:
	var camera_local := (
		_stage.origin.global_transform.affine_inverse() * _stage.camera.global_position
	)
	var grid := DepthGrid.sample(
		image, inverse, PATCH_STEPS, PATCH_EXTENT, camera_local, MIN_DISTANCE, MAX_DISTANCE
	)

	var distances: Array[float] = []
	_sample_count = 0
	for line: Array in grid:
		for point: Variant in line:
			if point == null:
				continue

			distances.append((point as Vector3).distance_to(camera_local))
			_sample_count += 1

	_reject_outliers(grid, distances, camera_local)
	return grid


## 中央値から大きく離れた点を捨てる。手前の物や穴に引っ張られないようにする。
func _reject_outliers(grid: Array, distances: Array[float], view_origin: Vector3) -> void:
	if distances.size() < 3:
		return

	distances.sort()
	var median := distances[distances.size() / 2]
	for row in grid.size():
		var line: Array = grid[row]
		for column in line.size():
			var point: Variant = line[column]
			if point == null:
				continue

			var distance: float = (point as Vector3).distance_to(view_origin)
			if absf(distance - median) > median * OUTLIER_RATIO:
				line[column] = null
				_sample_count -= 1


## 格子の縦横の接ベクトルから法線を出し、板を置く。
func _fit_plane(grid: Array) -> void:
	var centroid := Vector3.ZERO
	var count := 0
	# 横方向と縦方向の差を平均する。隣同士の外積を足すより、はるかに安定する。
	var tangent_u := Vector3.ZERO
	var tangent_v := Vector3.ZERO

	for row in grid.size():
		var line: Array = grid[row]
		for column in line.size():
			var point: Variant = line[column]
			if point == null:
				continue

			centroid += point
			count += 1

			if column + 1 < line.size() and line[column + 1] != null:
				tangent_u += (line[column + 1] as Vector3) - (point as Vector3)
			if row + 1 < grid.size():
				var below: Variant = (grid[row + 1] as Array)[column]
				if below != null:
					tangent_v += (below as Vector3) - (point as Vector3)

	if count == 0 or tangent_u.length_squared() < 1e-8 or tangent_v.length_squared() < 1e-8:
		_plane.visible = false
		return

	var normal := tangent_u.cross(tangent_v)
	if normal.length_squared() < 1e-8:
		_plane.visible = false
		return

	centroid /= count
	normal = normal.normalized()
	# ここまでの座標はXRの基準空間。カメラも同じ空間へ持ってきて比べる。
	var camera_local := (
		_stage.origin.global_transform.affine_inverse() * _stage.camera.global_position
	)
	# 常に自分の方を向くようにそろえる。裏返っていると板が見えない。
	if normal.dot(camera_local - centroid) < 0.0:
		normal = -normal

	_distance = centroid.distance_to(camera_local)
	# 表示はワールド座標なので、原点の変換を通してから置く。
	var to_world := _stage.origin.global_transform
	_normal = to_world.basis * normal
	_plane.visible = true
	_plane.global_transform = Transform3D(_basis_from_normal(_normal), to_world * centroid)


## 法線からPlaneMesh（XZ平面、+Yが法線）の姿勢を作る。
func _basis_from_normal(normal: Vector3) -> Basis:
	var reference := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right := reference.cross(normal).normalized()
	return Basis(right, normal, right.cross(normal).normalized())


func _build_status() -> String:
	if _extension == null:
		return "リアルタイム平面推定\n%s" % _message

	var lines: Array[String] = ["リアルタイム平面推定"]
	if not _message.is_empty():
		lines.append(_message)
		return "\n".join(lines)

	var tilt := "斜め"
	var vertical := absf(_normal.dot(Vector3.UP))
	if vertical > 0.85:
		tilt = "水平"
	elif vertical < 0.25:
		tilt = "垂直"

	lines.append("見ている面まで: %.2f m（%s）" % [_distance, tilt])
	lines.append("法線: (%.2f, %.2f, %.2f)" % [_normal.x, _normal.y, _normal.z])
	lines.append("サンプル数: %d / %d" % [_sample_count, PATCH_STEPS * PATCH_STEPS])
	return "\n".join(lines)
