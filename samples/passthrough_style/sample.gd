extends Node3D

## パススルーの色調整: 実世界の見え方そのものを、runtime側で加工するサンプル。
##
## 必要なもの: `xr/openxr/extensions/meta/passthrough=true`（設定済み）と
##   OpenXR Vendors plugin
## 対応端末: Quest 3（`XR_FB_passthrough`のstyle系）
##
## 仮想物体に色をかけるのではなく、**パススルー映像そのものを加工します**。
## 合成はruntimeが行うので、アプリ側の描画負荷はゼロです。
##
## pinchで4つの見え方を切り替えます。
##   そのまま     加工なし
##   明るさ・彩度 brightness / contrast / saturation の3値
##   モノクロ     輝度をカーブで階調に置き換える
##   カラーマップ 輝度をグラデーションの色に置き換える（擬似カラー）
##
## **同時に効くフィルタは1つだけ**です。別のフィルタを設定すると前のものは
## 外れます。戻すときは`set_passthrough_filter(PASSTHROUGH_FILTER_DISABLED)`で、
## これだけは専用の呼び出しが要ります。

## OpenXRFbPassthroughExtension.PassthroughFilterの値。
const FILTER_DISABLED := 0

const MODE_NAMES: Array[String] = ["そのまま", "明るさ・彩度", "モノクロ", "カラーマップ"]

var _stage: MRStage
## OpenXRFbPassthroughExtension。非対応ならnull。
var _extension: Object
var _mode := 0
var _color_capable := false

@onready var _status: Label3D = $Status


func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	if not Engine.has_singleton(&"OpenXRFbPassthroughExtension"):
		return

	_extension = Engine.get_singleton(&"OpenXRFbPassthroughExtension")
	if not bool(_extension.call(&"has_passthrough_capability")):
		_extension = null
		return

	_color_capable = bool(_extension.call(&"has_color_passthrough_capability"))


func _exit_tree() -> void:
	# 加工したまま抜けると、次のサンプルまで色が変わったままになる。
	if _extension != null:
		_extension.call(&"set_passthrough_filter", FILTER_DISABLED)


func _process(_delta: float) -> void:
	if _stage == null:
		return

	if _extension != null:
		_cycle_on_pinch()

	_status.text = _build_status()


func _cycle_on_pinch() -> void:
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		if not _stage.is_pinch_just_started(hand):
			continue

		_mode = (_mode + 1) % MODE_NAMES.size()
		_apply()
		return


## フィルタを1つ選んで設定する。設定用の関数を呼ぶと、そのフィルタに切り替わる。
func _apply() -> void:
	match _mode:
		1:
			# 明るさは-100〜100（中立0）、コントラストと彩度は0より大（中立1.0）。
			_extension.call(&"set_brightness_contrast_saturation", 10.0, 1.4, 1.6)
		2:
			_extension.call(&"set_mono_map", _create_contrast_curve())
		3:
			_extension.call(&"set_color_map", _create_gradient())
		_:
			# 無効化だけは専用の呼び出しが要る。
			_extension.call(&"set_passthrough_filter", FILTER_DISABLED)


## 輝度をS字に持ち上げる。中間調が締まって、線画のような見え方になる。
func _create_contrast_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.35, 0.12))
	curve.add_point(Vector2(0.65, 0.88))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


## 輝度を色に置き換える。暗いところを青、明るいところを橙にする擬似カラー。
func _create_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.15, 0.45))
	gradient.set_color(1, Color(1.0, 0.75, 0.35))
	gradient.add_point(0.5, Color(0.35, 0.75, 0.65))
	return gradient


func _build_status() -> String:
	if _extension == null:
		return "パススルーの色調整\nこの端末はパススルーのstyle設定を\n公開していません"

	var lines: Array[String] = ["パススルーの色調整"]
	lines.append("いま: %s（pinchで切替）" % MODE_NAMES[_mode])
	if not _color_capable:
		lines.append("この端末はモノクロパススルーです。色の変化は出ません")

	return "\n".join(lines)
