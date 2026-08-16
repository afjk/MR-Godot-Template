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
## 手順は3つだけです。
##   1. 深度マップをCPUへ落とす（`get_environment_depth_map_async`）
##   2. 画面中央付近の点を、逆行列でワールド座標へ戻す
##   3. 戻した点群から重心と法線を出す
##
## 深度マップは毎フレーム更新されるわけではなく、CPUへの転送も安価ではありません。
## ドキュメントの助言どおり、1秒に1回程度の間隔で引きます。

## 深度マップを引く間隔。毎フレーム引いてはいけない。
const SAMPLE_INTERVAL := 0.8
## 画面中央から何割の範囲を見るか。1.0で画面全体。
const PATCH_EXTENT := 0.14
## 一辺あたりのサンプル数。
const PATCH_STEPS := 5
## 面とみなす最短・最長距離。外れ値を捨てる。
const MIN_DISTANCE := 0.2
const MAX_DISTANCE := 5.0

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

	var points := _collect_points(image, inverse)
	_sample_count = points.size()
	if points.size() < 3:
		_message = "面を作れるだけの深度が取れませんでした"
		_plane.visible = false
		return

	_message = ""
	_fit_plane(points)


## 画面中央付近を格子状に拾い、ワールド座標へ戻す。
func _collect_points(image: Image, inverse: Projection) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for row in PATCH_STEPS:
		for column in PATCH_STEPS:
			# -PATCH_EXTENT〜+PATCH_EXTENTの範囲を等分する。
			var offset := Vector2(
				(float(column) / (PATCH_STEPS - 1) - 0.5) * 2.0 * PATCH_EXTENT,
				(float(row) / (PATCH_STEPS - 1) - 0.5) * 2.0 * PATCH_EXTENT
			)
			var uv := Vector2(0.5, 0.5) + offset
			var pixel := Vector2i(int(uv.x * image.get_width()), int(uv.y * image.get_height()))
			var raw := image.get_pixel(pixel.x, pixel.y).r

			var point := _unproject(uv, raw, inverse)
			var distance := point.distance_to(_stage.camera.global_position)
			if distance >= MIN_DISTANCE and distance <= MAX_DISTANCE:
				points.append(point)

	return points


## 深度マップの1点をワールド座標へ戻す。
func _unproject(uv: Vector2, raw_depth: float, inverse: Projection) -> Vector3:
	# UVをNDCへ。yは上下が逆になる。
	# 深度値は0〜1で入っている前提で、GodotのProjectionが使う-1〜1へ広げる。
	var ndc := Vector3(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, raw_depth * 2.0 - 1.0)
	var clip := inverse * Vector4(ndc.x, ndc.y, ndc.z, 1.0)
	if is_zero_approx(clip.w):
		return Vector3.ZERO

	var local := Vector3(clip.x, clip.y, clip.z) / clip.w
	# 行列はXRの基準空間なので、原点の変換を通してワールドへ移す。
	return _stage.origin.global_transform * local


## 点群から重心と法線を出し、板を置く。
func _fit_plane(points: Array[Vector3]) -> void:
	var centroid := Vector3.ZERO
	for point in points:
		centroid += point
	centroid /= points.size()

	# 重心から見た3点ずつの外積を平均する。固有値分解までは要らない。
	var normal := Vector3.ZERO
	for index in points.size():
		var a := points[index] - centroid
		var b := points[(index + 1) % points.size()] - centroid
		var cross := a.cross(b)
		# 向きがばらけるので、最初に得た向きへそろえてから足す。
		if normal != Vector3.ZERO and cross.dot(normal) < 0.0:
			cross = -cross
		normal += cross

	if normal.length_squared() < 0.000001:
		_plane.visible = false
		return

	normal = normal.normalized()
	# 常に自分の方を向くようにそろえる。裏返っていると板が見えない。
	if normal.dot(_stage.camera.global_position - centroid) < 0.0:
		normal = -normal

	_normal = normal
	_distance = centroid.distance_to(_stage.camera.global_position)
	_plane.visible = true
	_plane.global_transform = Transform3D(_basis_from_normal(normal), centroid)


## 法線からPlaneMesh（XZ平面）の姿勢を作る。
func _basis_from_normal(normal: Vector3) -> Basis:
	var up := normal
	var reference := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right := reference.cross(up).normalized()
	return Basis(right, up, right.cross(up).normalized())


func _build_status() -> String:
	if _extension == null:
		return "リアルタイム平面推定\n%s" % _message

	var lines: Array[String] = ["リアルタイム平面推定"]
	if not _message.is_empty():
		lines.append(_message)
		return "\n".join(lines)

	var tilt := "斜め"
	if absf(_normal.dot(Vector3.UP)) > 0.85:
		tilt = "水平"
	elif absf(_normal.dot(Vector3.UP)) < 0.25:
		tilt = "垂直"

	lines.append("見ている面まで: %.2f m（%s）" % [_distance, tilt])
	lines.append("サンプル数: %d / %d" % [_sample_count, PATCH_STEPS * PATCH_STEPS])
	lines.append("%.1f秒ごとに取り直しています" % SAMPLE_INTERVAL)
	return "\n".join(lines)
