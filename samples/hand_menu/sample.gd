extends Node3D

## ハンドメニュー: 手のひらを自分へ向けるとメニューが出るサンプル。
##
## 必要なもの: `xr/openxr/extensions/hand_tracking=true`と、端末側のHand Tracking設定
## 対応端末: 全機種（光学式のHand Trackingが無い端末では、その旨だけ表示します）
##
## MRTKのSolver（HandConstraint）に当たる部分です。要点は3つあります。
##   1. 手のひらの向きを関節の位置から自分で作る
##   2. 出す/消すの閾値をずらし、消えるまでに少し待つ（ちらつき防止）
##   3. 目標姿勢へ毎フレーム少しずつ近づける（追従の滑らかさ）

const MENU_ITEMS: Array[String] = ["置く", "消す", "戻す"]
## 手のひらが自分を向いていると判断する内積。出す方を厳しく、消す方を緩くする。
const FACING_ENTER := 0.72
const FACING_EXIT := 0.45
## 向きを外してからメニューを消すまでの猶予。
const HIDE_DELAY := 0.35
## 手のひらからメニューを浮かせる距離。
const MENU_OFFSET := 0.09
## 追従の速さ。大きいほど手にぴったり付いてくる。
const FOLLOW_SPEED := 12.0
## 手のひらの法線の向き。実機で裏返っていたら符号を入れ替える。
const PALM_SIGN: Array[float] = [1.0, -1.0]

var _stage: MRStage
var _host_hand := -1
var _hide_timer := 0.0
var _selected := 0
var _rows: Array[Label3D] = []

@onready var _menu: Node3D = $Menu
@onready var _status: Label3D = $Status


func _ready() -> void:
	_build_menu()
	_menu.visible = false
	_stage = await SampleBootstrap.stage_async()


func _process(delta: float) -> void:
	if _stage == null:
		return

	var hand := _find_facing_hand()
	if hand >= 0:
		_host_hand = hand
		_hide_timer = 0.0
	elif _host_hand >= 0:
		# すぐには消さない。手が一瞬ぶれただけでメニューが消えると使えない。
		_hide_timer += delta
		if _hide_timer >= HIDE_DELAY:
			_host_hand = -1

	_menu.visible = _host_hand >= 0
	if _menu.visible:
		_follow_palm(_host_hand, delta)
		_update_selection(_host_hand)

	_update_status()


## 手のひらを自分へ向けている手を返す。無ければ-1。
func _find_facing_hand() -> int:
	for hand: int in [MRStage.Hand.LEFT, MRStage.Hand.RIGHT]:
		var normal: Variant = _get_palm_normal(hand)
		if normal == null:
			continue

		var palm: Vector3 = _get_palm_transform(hand).origin
		var to_camera := (_stage.camera.global_position - palm).normalized()
		var facing: float = (normal as Vector3).dot(to_camera)
		# 既に出している手は緩い閾値で判定し、出入りがばたつかないようにする。
		var threshold := FACING_EXIT if hand == _host_hand else FACING_ENTER
		if facing >= threshold:
			return hand

	return -1


## 手のひらの法線。手首・人差し指・小指の付け根が作る面から求める。
func _get_palm_normal(hand: int) -> Variant:
	if not _stage.is_hand_tracking_active(hand):
		return null

	var tracker := _stage.get_hand_tracker(hand)
	var wrist := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST).origin
	var index := (
		tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL).origin
	)
	var pinky := (
		tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PINKY_FINGER_METACARPAL).origin
	)

	var normal := (index - wrist).cross(pinky - wrist)
	if normal.length_squared() < 0.0000001:
		return null

	# 関節の並びは左右で鏡なので、片方は符号を反転する。
	var basis := _stage.origin.global_transform.basis
	return (basis * normal.normalized()).normalized() * PALM_SIGN[hand]


func _get_palm_transform(hand: int) -> Transform3D:
	var tracker := _stage.get_hand_tracker(hand)
	var palm := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
	return _stage.origin.global_transform * palm


func _follow_palm(hand: int, delta: float) -> void:
	var normal: Variant = _get_palm_normal(hand)
	if normal == null:
		return

	var palm := _get_palm_transform(hand)
	var target_position: Vector3 = palm.origin + (normal as Vector3) * MENU_OFFSET

	# 読みやすさを優先し、手の回転ではなくカメラの方を向かせる。
	# Label3Dは+Z側から読めるので、looking_at()にはカメラの反対側の点を渡す。
	var away := target_position * 2.0 - _stage.camera.global_position
	var target := Transform3D(Basis(), target_position).looking_at(away, Vector3.UP)

	# 目標へ毎フレーム一定割合だけ近づける。フレームレートに依らない指数移動。
	var weight := 1.0 - exp(-FOLLOW_SPEED * delta)
	_menu.global_transform = _menu.global_transform.interpolate_with(target, weight)


func _update_selection(hand: int) -> void:
	if not _stage.is_pinch_just_started(hand):
		return

	# 押しっぱなしで回り続けないよう、始まった瞬間のフレームだけ動かす。
	_selected = wrapi(_selected + 1, 0, MENU_ITEMS.size())
	for index in _rows.size():
		_rows[index].modulate = (
			Color(1, 0.85, 0.35) if index == _selected else Color(0.85, 0.9, 1.0)
		)


func _build_menu() -> void:
	var background := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 0.02 + MENU_ITEMS.size() * 0.028, 0.004)
	background.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.09, 0.14, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background.material_override = material
	_menu.add_child(background)

	for index in MENU_ITEMS.size():
		var row := Label3D.new()
		row.text = MENU_ITEMS[index]
		row.font_size = 30
		row.pixel_size = 0.0005
		row.modulate = Color(1, 0.85, 0.35) if index == 0 else Color(0.85, 0.9, 1.0)
		row.position = Vector3(0, (MENU_ITEMS.size() - 1 - index * 2) * 0.014, 0.004)
		_menu.add_child(row)
		_rows.append(row)


func _update_status() -> void:
	if (
		not _stage.is_hand_tracking_active(MRStage.Hand.LEFT)
		and not _stage.is_hand_tracking_active(MRStage.Hand.RIGHT)
	):
		_status.text = "ハンドメニュー\n光学式のHand Trackingが必要です\nコントローラーを置いて手をかざしてください"
		return

	if _host_hand < 0:
		_status.text = "ハンドメニュー\n手のひらを自分へ向けてください"
		return

	var label := "左" if _host_hand == MRStage.Hand.LEFT else "右"
	_status.text = "ハンドメニュー\n%s手に表示中\n選択: %s（pinchで切り替え）" % [label, MENU_ITEMS[_selected]]
