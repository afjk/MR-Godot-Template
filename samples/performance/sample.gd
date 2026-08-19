extends Node3D

## 性能の見方: foveationとMSAAを切り替えて、効き方を実機で確かめるサンプル。
##
## 必要なもの: なし（Godot coreのOpenXRInterface）
## 対応端末: 全機種。ベンダー計測値はOpenXR Vendors pluginがある端末のみ
##
## MRの見た目は、ほとんどが**解像度と塗り面積**で決まります。ここで触れる2つが
## いちばん効きます。
##   foveation: 視界の周辺を粗く描く。中心視野は変わらないので効果に対して劣化が
##              見えにくい。dynamicにすると負荷に応じて自動で強弱がつく
##   MSAA:      斜めの線のギザギザを消す。XRでは2xでも効果が大きいが、そのぶん重い
##
## 数字が動かないと違いが分からないので、**負荷をかける立方体**を出しています。
##
## 操作:
##   右手のpinch: foveationの強さを 切／低／中／高 で回す
##   左手のpinch: MSAAを 切／2x／4x で回す

## 負荷をかける立方体の数と配置。
const CUBE_COUNT := 240
const CUBE_SIZE := 0.06
const FIELD := Vector3(3.0, 1.6, 3.0)

const FOVEATION_NAMES: Array[String] = ["切", "低", "中", "高"]
const MSAA_NAMES: Array[String] = ["切", "2x", "4x"]
const MSAA_VALUES: Array[int] = [
	Viewport.MSAA_DISABLED,
	Viewport.MSAA_2X,
	Viewport.MSAA_4X,
]

var _stage: MRStage
var _msaa := 1

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	_spawn_cubes()

	# 起動時の設定に表示を合わせる。
	var viewport := get_viewport()
	_msaa = maxi(MSAA_VALUES.find(viewport.msaa_3d), 0)


func _process(_delta: float) -> void:
	if _stage == null:
		return

	_handle_pinch()
	_status.text = _build_status()


func _handle_pinch() -> void:
	if _stage.xr_interface == null:
		return

	if _stage.is_pinch_just_started(MRStage.Hand.RIGHT):
		# 0が切で、3がいちばん強い。dynamicは切以外のときだけ意味がある。
		var level := (_stage.xr_interface.foveation_level + 1) % FOVEATION_NAMES.size()
		_stage.xr_interface.foveation_level = level
		_stage.xr_interface.foveation_dynamic = level > 0
	elif _stage.is_pinch_just_started(MRStage.Hand.LEFT):
		_msaa = (_msaa + 1) % MSAA_VALUES.size()
		get_viewport().msaa_3d = MSAA_VALUES[_msaa]


## 負荷をかけるための立方体。数を変えると効き方の見え方が変わる。
func _spawn_cubes() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CUBE_SIZE

	var random := RandomNumberGenerator.new()
	random.seed = 20260819

	for index in CUBE_COUNT:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(float(index) / CUBE_COUNT, 0.55, 0.95)
		material.roughness = 0.35

		var cube := MeshInstance3D.new()
		cube.mesh = mesh
		cube.material_override = material
		cube.position = Vector3(
			random.randf_range(-FIELD.x, FIELD.x),
			random.randf_range(0.4, FIELD.y),
			random.randf_range(-FIELD.z, -0.6)
		)
		add_child(cube)


func _build_status() -> String:
	var lines: Array[String] = ["性能の見方"]
	lines.append("FPS: %d" % Engine.get_frames_per_second())

	if _stage.xr_interface != null:
		var level: int = _stage.xr_interface.foveation_level
		(
			lines
			. append(
				(
					"foveation: %s（%s）／右手pinch"
					% [
						FOVEATION_NAMES[level],
						"dynamic" if _stage.xr_interface.foveation_dynamic else "固定",
					]
				)
			)
		)
		lines.append("表示レート: %.0f Hz" % _stage.xr_interface.get_display_refresh_rate())

		var size := _stage.xr_interface.get_render_target_size()
		lines.append("描画解像度: %d×%d（片目）" % [size.x, size.y])

	lines.append("MSAA: %s／左手pinch" % MSAA_NAMES[_msaa])
	lines.append("立方体: %d個" % CUBE_COUNT)
	return "\n".join(lines)
