extends Node3D

## セッションの扱い: リフレッシュレートの選択、フォーカスの喪失と復帰、recenterを見る。
##
## 必要なもの: なし
## 対応端末: 全機種
##
## セッションの購読自体は`shared/mr_stage.gd`が行い、ここでは受け取った出来事を
## 並べます。ヘッドセットを外す、ホームへ戻る、リセンターすると行が増えます。

const MAX_EVENTS := 6

var _stage: MRStage
var _events: Array[String] = []
var _started_at := 0.0

@onready var _status: Label3D = $Status
@onready var _log: Label3D = $Log


func _ready() -> void:
	_started_at = _now()
	_stage = await SampleBootstrap.stage_async()
	_stage.focus_lost.connect(_on_focus_lost)
	_stage.focus_gained.connect(_on_focus_gained)
	_stage.pose_recentered.connect(_on_pose_recentered)
	_add_event("サンプル開始")


func _process(_delta: float) -> void:
	_status.text = _build_status()


func _build_status() -> String:
	var lines: Array[String] = ["セッションの扱い"]
	if _stage == null or not _stage.is_mr_active:
		lines.append("MR: 無効（デスクトップ表示）")
		lines.append("物理レート: %d Hz" % Engine.physics_ticks_per_second)
		return "\n".join(lines)

	var xr := _stage.xr_interface
	lines.append("現在のレート: %.1f Hz" % xr.get_display_refresh_rate())

	var rates: Array[String] = []
	for entry in xr.get_available_display_refresh_rates():
		rates.append("%.0f" % float(entry))
	lines.append("選べるレート: %s" % ("報告なし" if rates.is_empty() else " / ".join(rates)))

	lines.append("上限設定: %d Hz" % _stage.maximum_refresh_rate)
	lines.append("物理レート: %d Hz" % Engine.physics_ticks_per_second)
	lines.append("描画FPS: %d" % Engine.get_frames_per_second())
	return "\n".join(lines)


func _on_focus_lost() -> void:
	_add_event("フォーカス喪失（ヘッドセットを外した／背面に回った）")


func _on_focus_gained() -> void:
	_add_event("フォーカス復帰")


func _on_pose_recentered() -> void:
	_add_event("recenter（runtimeが姿勢をリセットした）")


func _add_event(text: String) -> void:
	_events.append("%6.1fs  %s" % [_now() - _started_at, text])
	if _events.size() > MAX_EVENTS:
		_events.remove_at(0)

	_log.text = "\n".join(_events)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
