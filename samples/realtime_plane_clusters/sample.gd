extends Node3D

## リアルタイム複数平面検出: 深度から**複数の平面を同時に**見つけ、フレーム間で
## 追跡するサンプル。AR FoundationのARPlaneManagerに一番近いものを自作します。
##
## 必要なもの: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）と
##   OpenXR Vendors plugin
## 対応端末: Quest 3（`XR_META_environment_depth`）
##
## `realtime_planes`は視線の先の1枚だけを推定します。こちらは視界全体を見て、
## 床・机・壁を**別々の平面として**取り出します。手順はARCoreがやっていることと
## 同じです。
##   1. 深度を格子状の点群にする（`DepthGrid`）
##   2. 各点の法線を、隣との差から出す
##   3. 法線と平面までの距離が近い点をまとめる（領域拡張）
##   4. まとまりごとに重心と法線を出し、平面座標へ射影して矩形にする
##   5. 前回の平面と`(法線, 距離)`が近ければ同じ平面とみなし、色と番号を引き継ぐ
##
## Quest 3のOSは平面検出を提供しないので、ここまで自分で書けば同じことができる、
## という実例です。事前スキャンが要らず、机を動かせば追従します。

## 深度を引く間隔。毎フレーム引いてはいけない。
const SAMPLE_INTERVAL := 1.0
## 格子の一辺のサンプル数。増やすと細かくなるが、GDScriptの処理時間が伸びる。
const GRID_STEPS := 48
## 視界の端は歪みとノイズが大きいので少し内側だけを使う。
const NDC_EXTENT := 0.9
const MIN_DISTANCE := 0.2
const MAX_DISTANCE := 4.0
## 法線を出すとき、隣とこれ以上離れていたら物の境目とみなす。
const EDGE_THRESHOLD := 0.2
## 同じ平面とみなす法線の一致度（cos）と、平面からの距離。
const NORMAL_TOLERANCE := 0.94
const PLANE_TOLERANCE := 0.05
## これ未満の点数のまとまりは平面として出さない。
const MIN_CLUSTER := 40
## 表示する平面の数（点数の多い順）。
const MAX_PLANES := 8
## 前回の平面と同じとみなす条件。
const MATCH_NORMAL := 0.90
const MATCH_DISTANCE := 0.12

const PALETTE: Array[Color] = [
	Color(0.25, 0.85, 0.45),
	Color(0.30, 0.55, 0.95),
	Color(0.98, 0.65, 0.20),
	Color(0.70, 0.45, 0.95),
	Color(0.95, 0.35, 0.45),
	Color(0.35, 0.85, 0.90),
]

var _stage: MRStage
## OpenXRMetaEnvironmentDepthExtensionのシングルトン。非対応ならnull。
var _extension: Object
## 検出した平面を並べる入れ物。XROrigin3Dの下に置く。
var _container: Node3D
## 前回の平面。追跡の照合に使う。要素は_make_planeが作る辞書。
var _planes: Array[Dictionary] = []
var _next_id := 1
var _timer := 0.0
var _pending := false
var _message := "深度の取得を待っています"

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	_start_depth()


func _exit_tree() -> void:
	if _extension != null and bool(_extension.call(&"is_environment_depth_started")):
		_extension.call(&"stop_environment_depth")

	if is_instance_valid(_container):
		_container.queue_free()


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


func _start_depth() -> void:
	if not Engine.has_singleton(&"OpenXRMetaEnvironmentDepthExtension"):
		return

	_extension = Engine.get_singleton(&"OpenXRMetaEnvironmentDepthExtension")
	if not bool(_extension.call(&"is_environment_depth_supported")):
		_extension = null
		return

	_extension.call(&"start_environment_depth")

	# 逆行列が返すのはXRの基準空間。原点の下に置けば、そのままローカル座標になる。
	_container = Node3D.new()
	_stage.origin.add_child(_container)


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

	var camera_local := (
		_stage.origin.global_transform.affine_inverse() * _stage.camera.global_position
	)
	var points := DepthGrid.sample(
		image, inverse, GRID_STEPS, NDC_EXTENT, camera_local, MIN_DISTANCE, MAX_DISTANCE
	)
	var normals := _estimate_normals(points, camera_local)
	var found := _grow_regions(points, normals)

	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	if found.size() > MAX_PLANES:
		found.resize(MAX_PLANES)

	_planes = _track(found)
	_message = "" if not _planes.is_empty() else "平面を作れるだけの深度が取れませんでした"
	_redraw()


## 各点の法線を、上下左右の隣との差から出す。隣が無い・遠すぎる点は捨てる。
## 近い2点の外積は向きが安定しないので、必ず反対側の隣まで使って差を取ります。
func _estimate_normals(points: Array, view_origin: Vector3) -> Array:
	var normals: Array = []
	for row in GRID_STEPS:
		var line: Array = []
		for column in GRID_STEPS:
			line.append(null)

		normals.append(line)

	for row in range(1, GRID_STEPS - 1):
		for column in range(1, GRID_STEPS - 1):
			var center: Variant = (points[row] as Array)[column]
			if center == null:
				continue

			var left: Variant = (points[row] as Array)[column - 1]
			var right: Variant = (points[row] as Array)[column + 1]
			var up: Variant = (points[row - 1] as Array)[column]
			var down: Variant = (points[row + 1] as Array)[column]
			if left == null or right == null or up == null or down == null:
				continue

			var tangent_u: Vector3 = (right as Vector3) - (left as Vector3)
			var tangent_v: Vector3 = (down as Vector3) - (up as Vector3)
			if tangent_u.length() > EDGE_THRESHOLD or tangent_v.length() > EDGE_THRESHOLD:
				continue

			var normal := tangent_u.cross(tangent_v)
			if normal.length_squared() < 1e-10:
				continue

			normal = normal.normalized()
			# 常に自分の方を向くようにそろえる。以降の比較が符号で崩れなくなる。
			if normal.dot(view_origin - (center as Vector3)) < 0.0:
				normal = -normal

			(normals[row] as Array)[column] = normal

	return normals


## 領域拡張。法線の向きと平面までの距離が近い隣を、種から順にたどってまとめる。
## 格子構造があるので、四方の隣を見るだけで済みます。
func _grow_regions(points: Array, normals: Array) -> Array[Dictionary]:
	# 訪問済みの印。1本の配列にして、行と列から添字を作る。
	# PackedInt32Arrayは値型で、関数に渡すと複製されてしまうのでArrayを使う。
	var visited: Array[bool] = []
	visited.resize(GRID_STEPS * GRID_STEPS)
	visited.fill(false)

	var found: Array[Dictionary] = []
	for row in GRID_STEPS:
		for column in GRID_STEPS:
			if visited[row * GRID_STEPS + column]:
				continue
			if (normals[row] as Array)[column] == null:
				continue

			var members := _flood(points, normals, visited, row, column)
			if members.size() >= MIN_CLUSTER:
				found.append(_make_plane(members))

	return found


## 1つの種から広げて、そのまとまりに入る点を集める。
## 戻り値は{point, normal}の配列。法線は平面を作るときに平均する。
func _flood(
	points: Array, normals: Array, visited: Array[bool], row: int, column: int
) -> Array[Dictionary]:
	var seed_point: Vector3 = (points[row] as Array)[column]
	var seed_normal: Vector3 = (normals[row] as Array)[column]
	var members: Array[Dictionary] = []
	var stack: Array[Vector2i] = [Vector2i(column, row)]
	visited[row * GRID_STEPS + column] = true

	while not stack.is_empty():
		var cell := stack.pop_back() as Vector2i
		var member := {
			"point": (points[cell.y] as Array)[cell.x],
			"normal": (normals[cell.y] as Array)[cell.x],
		}
		members.append(member)

		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + offset
			if next.x < 0 or next.y < 0 or next.x >= GRID_STEPS or next.y >= GRID_STEPS:
				continue

			var index := next.y * GRID_STEPS + next.x
			if visited[index]:
				continue

			var normal: Variant = (normals[next.y] as Array)[next.x]
			if normal == null or (normal as Vector3).dot(seed_normal) < NORMAL_TOLERANCE:
				continue

			var point: Vector3 = (points[next.y] as Array)[next.x]
			if absf((point - seed_point).dot(seed_normal)) > PLANE_TOLERANCE:
				continue

			# 積むときに印を付ける。取り出すときだと同じ点が何度も積まれる。
			visited[index] = true
			stack.append(next)

	return members


## まとまりから平面を作る。重心と法線を出し、平面座標へ射影して矩形にする。
func _make_plane(members: Array[Dictionary]) -> Dictionary:
	var centroid := Vector3.ZERO
	var normal := Vector3.ZERO
	for member in members:
		centroid += member.point
		normal += member.normal

	centroid /= members.size()
	# 点ごとの法線は既に出してあるので、平均するだけでよい。共分散は要らない。
	normal = normal.normalized() if normal.length_squared() > 1e-10 else Vector3.UP

	var basis := _basis_from_normal(normal)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for member in members:
		var local: Vector3 = member.point - centroid
		var uv := Vector2(local.dot(basis.x), local.dot(basis.z))
		minimum = minimum.min(uv)
		maximum = maximum.max(uv)

	var center := (minimum + maximum) * 0.5
	return {
		"id": 0,
		"normal": normal,
		"origin": centroid + basis.x * center.x + basis.z * center.y,
		"basis": basis,
		"size": maximum - minimum,
		"distance": normal.dot(centroid),
		"count": members.size(),
	}


## 法線からPlaneMesh（XZ平面、+Yが法線）の姿勢を作る。
func _basis_from_normal(normal: Vector3) -> Basis:
	var reference := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right := reference.cross(normal).normalized()
	return Basis(right, normal, right.cross(normal).normalized())


## 前回の平面と照合して番号を引き継ぐ。番号が変わると色も変わってしまうので、
## 同じ面が同じ色のまま残るかどうかが、追跡できているかの目印になります。
func _track(found: Array[Dictionary]) -> Array[Dictionary]:
	var used: Array[int] = []
	for plane in found:
		for previous in _planes:
			if previous.id in used:
				continue
			if (plane.normal as Vector3).dot(previous.normal) < MATCH_NORMAL:
				continue
			if absf(plane.distance - previous.distance) > MATCH_DISTANCE:
				continue

			plane.id = previous.id
			used.append(previous.id)
			break

		if plane.id == 0:
			plane.id = _next_id
			_next_id += 1

	return found


func _redraw() -> void:
	if _container == null:
		return

	for child in _container.get_children():
		child.queue_free()

	for plane in _planes:
		_container.add_child(_create_quad(plane))
		_container.add_child(_create_label(plane))


func _create_quad(plane: Dictionary) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = plane.size

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(_color_of(plane), 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var surface := MeshInstance3D.new()
	surface.mesh = mesh
	surface.material_override = material
	surface.transform = Transform3D(plane.basis, plane.origin)
	return surface


## ラベルは板の姿勢を継がせたくないので、板の子ではなく入れ物の直下に置く。
func _create_label(plane: Dictionary) -> Label3D:
	var label := Label3D.new()
	label.text = (
		"#%d %s %.1f×%.1f m" % [plane.id, _alignment_name(plane.normal), plane.size.x, plane.size.y]
	)
	label.modulate = _color_of(plane).lightened(0.5)
	label.font_size = 26
	label.pixel_size = 0.0008
	label.outline_size = 14
	label.render_priority = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = plane.origin
	return label


func _color_of(plane: Dictionary) -> Color:
	return PALETTE[int(plane.id) % PALETTE.size()]


func _alignment_name(normal: Vector3) -> String:
	var vertical := absf(normal.dot(Vector3.UP))
	if vertical > 0.85:
		return "水平"
	if vertical < 0.25:
		return "垂直"

	return "斜め"


func _build_status() -> String:
	if _extension == null:
		return "リアルタイム複数平面検出\nこの端末は環境深度（XR_META_environment_depth）を\n公開していません"

	if not bool(_extension.call(&"is_environment_depth_started")):
		return "リアルタイム複数平面検出\n深度の取得を開始できませんでした"

	if not _message.is_empty():
		return "リアルタイム複数平面検出\n%s" % _message

	return "リアルタイム複数平面検出\n平面: %d枚（%.1f秒ごとに検出）\n同じ面なら色と番号が保たれます" % [_planes.size(), SAMPLE_INTERVAL]
