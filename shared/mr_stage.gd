class_name MRStage
extends Node3D

## MRの土台。OpenXRの初期化、パススルー、セッション状態をまとめて受け持つ。
##
## 各サンプルはこのシーンを持ちません。`SampleBootstrap`（Autoload）が、
## シーンに`XROrigin3D`が無ければ実行時に挿します。サンプル側は
## `SampleBootstrap.stage`から参照してください。

## ヘッドセットを外した、またはアプリが背面に回った。
signal focus_lost
## フォーカスが戻った。
signal focus_gained
## runtimeがユーザー姿勢をリセンターした。
signal pose_recentered
## MRを開始できたかが決まった時点で1回だけ発火する。`reason`は失敗時のみ入る。
signal mr_state_decided(active: bool, reason: String)

enum Hand { LEFT, RIGHT }

const HAND_TRACKER_PATHS: Array[StringName] = [
	&"/user/hand_tracker/left",
	&"/user/hand_tracker/right",
]
## 手が見えなくなってから、コントローラー操作へ戻すまでの猶予。
## 片手が一瞬外れただけで出所が切り替わると、ポインタが飛んで操作できなくなる。
const HAND_GRACE := 0.6
## pinchを始めた／離したとみなす指先の距離。離す側を広く取り、指の震えでばたつかせない。
const PINCH_ENTER := 0.022
const PINCH_EXIT := 0.032
## これらのsourceは「runtimeが光学式の手を報告していない」ことを意味する。
const INACTIVE_HAND_SOURCES: Array[int] = [
	XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER,
	XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED,
]

## XRruntimeへ要求する表示リフレッシュレートの上限。
@export var maximum_refresh_rate := 90
## フォーカスを失っている間、シーンツリーを停止するか。
@export var pause_on_focus_loss := true

var xr_interface: OpenXRInterface
## MR（パススルー）を開始できたか。
var is_mr_active := false
## 開始できなかった理由。デスクトップfallback時のみ入る。
var fallback_reason := ""

var _xr_is_focussed := false
var _pinching: Array[bool] = [false, false]
var _pinch_started: Array[bool] = [false, false]
var _hand_grace := 0.0
var _pointer_transform := Transform3D.IDENTITY
var _pointer_from_controller := false

@onready var origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D

@onready var _viewport: Viewport = get_viewport()
@onready var _environment: Environment = $WorldEnvironment.environment
@onready var _aim_controllers: Array[XRController3D] = [
	$XROrigin3D/LeftController,
	$XROrigin3D/RightController,
]
@onready var _grip_controllers: Array[XRController3D] = [
	$XROrigin3D/LeftGripController,
	$XROrigin3D/RightGripController,
]


func _ready() -> void:
	add_to_group(&"mr_stage")
	process_mode = Node.PROCESS_MODE_ALWAYS

	xr_interface = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr_interface == null or not xr_interface.is_initialized():
		_enable_desktop_fallback("OpenXRが初期化されていません")
		return

	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND not in get_supported_blend_modes():
		_enable_desktop_fallback("OpenXRがAlpha environment blendに対応していません")
		return

	xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	_configure_transparent_environment()
	_viewport.use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_configure_foveation()
	_connect_openxr_signals()

	is_mr_active = true
	print("OpenXR: Alpha environment blendでMRを開始しました")
	mr_state_decided.emit(true, "")

	# セッションが既に始まっている場合、session_begunはもう来ないので今applyする。
	_apply_best_refresh_rate()


func _process(delta: float) -> void:
	# pinchとポインタの出所は複数のサンプルが同時に見るので、ここで1回だけ更新する。
	for hand: int in [Hand.LEFT, Hand.RIGHT]:
		_update_pinch(hand)

	_update_pointer(delta)


## その端末で使えるenvironment blend modeの一覧。
func get_supported_blend_modes() -> Array:
	if xr_interface == null:
		return []

	return xr_interface.get_supported_environment_blend_modes()


## blend modeを切り替える。切り替えられたらtrue。
func set_blend_mode(mode: int) -> bool:
	if xr_interface == null or mode not in get_supported_blend_modes():
		return false

	xr_interface.environment_blend_mode = mode
	var transparent := mode == XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	_viewport.transparent_bg = transparent
	_environment.background_color = (
		Color(0, 0, 0, 0) if transparent else Color(0.025, 0.04, 0.065, 1.0)
	)
	return true


## aim poseのコントローラー。レイやポインタの基準に使う。
func get_aim_controller(hand: int) -> XRController3D:
	return _aim_controllers[hand]


## grip poseのコントローラー。手に持つモデルの基準に使う。
func get_grip_controller(hand: int) -> XRController3D:
	return _grip_controllers[hand]


func get_hand_tracker(hand: int) -> XRHandTracker:
	return XRServer.get_tracker(HAND_TRACKER_PATHS[hand]) as XRHandTracker


## 光学式のHand Trackingが実際に効いているか。コントローラー由来の推定手はfalse。
func is_hand_tracking_active(hand: int) -> bool:
	var tracker := get_hand_tracker(hand)
	if tracker == null or not tracker.has_tracking_data:
		return false

	return tracker.hand_tracking_source not in INACTIVE_HAND_SOURCES


## レイを飛ばす元の姿勢。コントローラーのaim pose、または視線。
func get_pointer_transform() -> Transform3D:
	return _pointer_transform


## ポインタがコントローラー由来か。視線のときはfalse（ビームを描かない目印にする）。
func is_pointer_from_controller() -> bool:
	return _pointer_from_controller


func _update_pointer(delta: float) -> void:
	# 片手だけ見えていれば手の操作として扱う。もう片方が外れた瞬間に
	# コントローラー扱いへ落ちると、失われた手の古い姿勢からレイが出てしまう。
	var hand_visible := is_hand_tracking_active(Hand.LEFT) or is_hand_tracking_active(Hand.RIGHT)
	_hand_grace = HAND_GRACE if hand_visible else maxf(_hand_grace - delta, 0.0)

	if _hand_grace <= 0.0:
		for hand: int in [Hand.RIGHT, Hand.LEFT]:
			var controller := get_aim_controller(hand)
			if controller.get_is_active():
				_pointer_transform = controller.global_transform
				_pointer_from_controller = true
				return

	# 手で操作している間と、コントローラーが無い間は視線から飛ばす。
	_pointer_transform = camera.global_transform
	_pointer_from_controller = false


## 親指と人差し指がくっついているか。閾値にヒステリシスを入れてある。
func is_pinching(hand: int) -> bool:
	return _pinching[hand]


## このフレームでpinchが始まったか。ボタンの押下に相当する。
func is_pinch_just_started(hand: int) -> bool:
	return _pinch_started[hand]


func _update_pinch(hand: int) -> void:
	var tracker := get_hand_tracker(hand)
	if tracker == null or not is_hand_tracking_active(hand):
		_pinching[hand] = false
		_pinch_started[hand] = false
		return

	var thumb := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP).origin
	var index := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin
	var threshold := PINCH_EXIT if _pinching[hand] else PINCH_ENTER
	var pinching := thumb.distance_to(index) < threshold
	_pinch_started[hand] = pinching and not _pinching[hand]
	_pinching[hand] = pinching


func _configure_foveation() -> void:
	# Forward+とMobileはrendering device経由のVRSでfoveationを行う。
	# このプロジェクトが使うCompatibility rendererにはrendering deviceが無いため、
	# OpenXR側のfoveation設定に頼る。
	if RenderingServer.get_rendering_device() != null:
		_viewport.vrs_mode = Viewport.VRS_XR
	elif int(ProjectSettings.get_setting("xr/openxr/foveation_level", 0)) == 0:
		push_warning("OpenXR: xr/openxr/foveation_levelをHighにしてください。")


func _connect_openxr_signals() -> void:
	xr_interface.session_begun.connect(_on_openxr_session_begun)
	xr_interface.session_visible.connect(_on_openxr_visible_state)
	xr_interface.session_focussed.connect(_on_openxr_focused_state)
	xr_interface.session_stopping.connect(_on_openxr_session_stopping)
	xr_interface.pose_recentered.connect(_on_openxr_pose_recentered)


func _on_openxr_session_begun() -> void:
	_apply_best_refresh_rate()


func _apply_best_refresh_rate() -> void:
	var current_rate := xr_interface.get_display_refresh_rate()

	# runtimeが出す中で、こちらが描く気のある最良のレートを選ぶ。
	var best_rate := current_rate
	for entry in xr_interface.get_available_display_refresh_rates():
		var rate := float(entry)
		if rate > best_rate and rate <= maximum_refresh_rate:
			best_rate = rate

	if best_rate > 0.0 and not is_equal_approx(current_rate, best_rate):
		print("OpenXR: リフレッシュレートを%sにします" % best_rate)
		xr_interface.set_display_refresh_rate(best_rate)
		current_rate = best_rate

	# 物理レートを表示に合わせ、トラッキング姿勢がフレーム境界に乗るようにする。
	if current_rate > 0.0:
		Engine.physics_ticks_per_second = int(roundf(current_rate))


func _on_openxr_visible_state() -> void:
	# 起動時もこの状態を通るため、一度focusを得た後の再訪だけをフォーカス喪失とみなす。
	if not _xr_is_focussed:
		return

	print("OpenXR: フォーカスを失いました")
	_xr_is_focussed = false
	if pause_on_focus_loss:
		# ヘッドセットを外している間は描画も進行も止める。このノードの
		# process_modeはALWAYSなので、復帰の合図は受け取れる。
		get_tree().paused = true
	focus_lost.emit()


func _on_openxr_focused_state() -> void:
	print("OpenXR: フォーカスを得ました")
	_xr_is_focussed = true
	get_tree().paused = false
	focus_gained.emit()


func _on_openxr_session_stopping() -> void:
	print("OpenXR: セッションが停止します")


func _on_openxr_pose_recentered() -> void:
	# 何をどう置き直すかはアプリ次第なので、ここでは中継だけする。
	pose_recentered.emit()


func _configure_transparent_environment() -> void:
	_viewport.transparent_bg = true
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0, 0, 0, 0)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.72, 0.80, 0.90, 1.0)


func _enable_desktop_fallback(reason: String) -> void:
	is_mr_active = false
	fallback_reason = reason
	_viewport.use_xr = false
	_viewport.transparent_bg = false
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.025, 0.04, 0.065, 1.0)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.55, 0.65, 0.82, 1.0)
	push_warning("%s。デスクトップ表示にfallbackします。" % reason)
	mr_state_decided.emit(false, reason)
