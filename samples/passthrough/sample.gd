extends Node3D

## パススルー: MRの開始条件と、environment blend modeの違いを見るサンプル。
##
## 必要なもの: `xr/openxr/environment_blend_mode`と、端末ごとのpassthrough設定
##   （Quest: Meta XR Features > Passthrough、PICO/VIVE: 各presetのpassthrough）
## 対応端末: 全機種（Alpha blend非対応ならデスクトップ表示にfallbackする）
##
## MRを開始する処理そのものは`shared/mr_stage.gd`にあります。全サンプルが必要と
## するためです。このサンプルは、その結果を読み、blend modeを切り替えて違いを示します。

## 何秒ごとにblend modeを切り替えるか。
const TOGGLE_INTERVAL := 5.0
const MODE_NAMES := {
	XRInterface.XR_ENV_BLEND_MODE_OPAQUE: "OPAQUE（実世界を隠す）",
	XRInterface.XR_ENV_BLEND_MODE_ADDITIVE: "ADDITIVE（加算合成）",
	XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND: "ALPHA_BLEND（パススルー）",
}

var _stage: MRStage
var _modes: Array[int] = []
var _mode_index := 0
var _elapsed := 0.0

@onready var _cube: MeshInstance3D = $Cube
@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()

	# 切り替えて見せられるのは、その端末が実際に対応しているmodeだけ。
	for mode: int in _stage.get_supported_blend_modes():
		if mode in MODE_NAMES:
			_modes.append(mode)

	_mode_index = maxi(_modes.find(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND), 0)
	_update_status()


func _process(delta: float) -> void:
	_cube.rotate_y(delta * 0.55)
	_cube.rotate_x(delta * 0.18)

	if _stage == null or not _stage.is_mr_active or _modes.size() < 2:
		return

	_elapsed += delta
	if _elapsed >= TOGGLE_INTERVAL:
		_elapsed = 0.0
		_mode_index = wrapi(_mode_index + 1, 0, _modes.size())
		_stage.set_blend_mode(_modes[_mode_index])

	_update_status()


func _exit_tree() -> void:
	# 次のサンプルへパススルーのまま戻す。
	if _stage != null and _stage.is_mr_active:
		_stage.set_blend_mode(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND)


func _update_status() -> void:
	if _stage == null:
		_status.text = "MRの土台が見つかりません"
		return

	if not _stage.is_mr_active:
		_status.text = "MR: 無効\n理由: %s\nデスクトップ表示です" % _stage.fallback_reason
		return

	var lines: Array[String] = []
	lines.append("MR: 有効")
	lines.append("現在: %s" % MODE_NAMES.get(_modes[_mode_index], "不明"))

	var names: Array[String] = []
	for mode in _modes:
		names.append(str(MODE_NAMES[mode]).split("（")[0])
	lines.append("対応: %s" % " / ".join(names))

	if _modes.size() >= 2:
		lines.append("%.1f秒後に切り替えます" % (TOGGLE_INTERVAL - _elapsed))

	_status.text = "\n".join(lines)
