extends Node3D

## サンプル一覧。`samples/samples.tres`を読んで項目を並べ、選ばれたシーンを
## `SampleHost`の下に挿す。サンプルを閉じると一覧へ戻る。
##
## ランチャーはサンプルではないので、サンプルの規約（1テーマ・1スクリプト・
## 200行以内）の対象外です。

const LIBRARY_PATH := "res://samples/samples.tres"
const ITEM_WIDTH := 0.62
const ITEM_PITCH := 0.088
const ITEM_FONT_SIZE := 44
## 一覧全体をこの高さに収める。サンプルが増えたら間隔と文字を詰める。
const MENU_MAX_HEIGHT := 0.72
## 一番上の項目からタイトルまでの間隔。項目数で高さが変わるので実行時に置く。
const TITLE_GAP := 0.07
## ランチャーの当たり判定だけに使う物理レイヤー。サンプル側と衝突させない。
const UI_LAYER := 8

var _entries: Array[SampleInfo] = []
var _items: Array[Node3D] = []
var _highlighted: Node3D
var _current_sample: Node
var _stage: MRStage

@onready var _menu: Node3D = $Menu
@onready var _title: Label3D = $Menu/Title
@onready var _status: Label3D = $Menu/Status
@onready var _back: Node3D = $Back
@onready var _host: Node3D = $SampleHost
@onready var _pointer: LauncherPointer = $Pointer


func _ready() -> void:
	_pointer.target_changed.connect(_on_target_changed)
	_pointer.selected.connect(_on_selected)

	var library := load(LIBRARY_PATH) as SampleLibrary
	if library == null:
		push_error("サンプル一覧を読み込めませんでした: %s" % LIBRARY_PATH)
	else:
		_entries = library.get_entries()

	_build_menu()
	_build_back_item()
	_show_menu()

	_stage = await SampleBootstrap.stage_async()
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	# デスクトップfallbackでは視線しか動かせないので、キーボードでも選べるようにする。
	if _stage != null and _stage.is_mr_active:
		return

	if event.is_action_pressed(&"ui_down"):
		_move_focus(1)
	elif event.is_action_pressed(&"ui_up"):
		_move_focus(-1)
	elif event.is_action_pressed(&"ui_accept") and _highlighted != null:
		_on_selected(_highlighted)


func _build_menu() -> void:
	# 項目数が増えても視界に収まるよう、間隔と文字を必要なだけ詰める。
	var pitch := minf(ITEM_PITCH, MENU_MAX_HEIGHT / maxf(_entries.size(), 1.0))
	var row_scale := pitch / ITEM_PITCH
	var top := (_entries.size() - 1) * pitch * 0.5

	# タイトルは一番上の項目より上へ逃がす。項目数で高さが変わるため実行時に置く。
	_status.position.y = top + TITLE_GAP
	_title.position.y = _status.position.y + 0.06

	for index in _entries.size():
		var info := _entries[index]
		var item := _create_item(info.title, info.get_devices_text(), row_scale)
		item.position = Vector3(0, top - index * pitch, 0)
		item.get_node(^"Area").set_meta(&"sample_index", index)
		_menu.add_child(item)
		_items.append(item)


func _build_back_item() -> void:
	var item := _create_item("サンプル一覧へ戻る", "", 1.0)
	item.get_node(^"Area").set_meta(&"back", true)
	_back.add_child(item)


func _create_item(text: String, note: String, row_scale: float) -> Node3D:
	var item := Node3D.new()
	var height := ITEM_PITCH * 0.85 * row_scale

	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ITEM_WIDTH, height, 0.008)
	panel.mesh = mesh
	panel.material_override = _create_panel_material(false)
	panel.name = "Panel"
	item.add_child(panel)

	var label := _create_label(text, int(ITEM_FONT_SIZE * row_scale), Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector3(-ITEM_WIDTH * 0.5 + 0.025, 0, 0.012)
	item.add_child(label)

	if not note.is_empty():
		var note_label := _create_label(note, int(30 * row_scale), Color(0.86, 0.92, 1.0))
		note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note_label.position = Vector3(ITEM_WIDTH * 0.5 - 0.025, 0, 0.012)
		item.add_child(note_label)

	var area := Area3D.new()
	area.name = "Area"
	area.collision_layer = UI_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ITEM_WIDTH, height, 0.03)
	shape.shape = box
	area.add_child(shape)
	item.add_child(area)

	return item


## 半透明の板と文字が同じ場所にあると描画順が入れ替わり、文字が板の色に沈む。
## 板より手前へ出したうえで、描画優先度でも前に出す。
func _create_label(text: String, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0007
	label.modulate = color
	label.outline_size = 18
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.render_priority = 2
	label.outline_render_priority = 1
	return label


func _create_panel_material(highlighted: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = (
		Color(0.16, 0.42, 0.72, 0.96) if highlighted else Color(0.05, 0.07, 0.11, 0.92)
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.render_priority = -1
	return material


func _on_target_changed(target: Node3D) -> void:
	_set_highlight(target.get_parent() as Node3D if target != null else null)


func _set_highlight(item: Node3D) -> void:
	if item == _highlighted:
		return

	if _highlighted != null:
		_apply_highlight(_highlighted, false)
	_highlighted = item
	if _highlighted != null:
		_apply_highlight(_highlighted, true)


func _apply_highlight(item: Node3D, highlighted: bool) -> void:
	var panel := item.get_node_or_null(^"Panel") as MeshInstance3D
	if panel != null:
		panel.material_override = _create_panel_material(highlighted)


func _move_focus(step: int) -> void:
	if _items.is_empty() or not _menu.visible:
		return

	var index := _items.find(_highlighted)
	index = wrapi(index + step, 0, _items.size()) if index >= 0 else 0
	_set_highlight(_items[index])


func _on_selected(target: Node3D) -> void:
	# ポインタからはArea3Dが、キーボード操作からは項目のルートが渡る。
	var area: Node = target
	if not area.has_meta(&"sample_index") and not area.has_meta(&"back"):
		area = area.get_node_or_null(^"Area")
	if area == null or not area.is_visible_in_tree():
		return

	if area.has_meta(&"back"):
		_close_sample()
	elif area.has_meta(&"sample_index"):
		_open_sample(int(area.get_meta(&"sample_index")))


func _open_sample(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return

	var info := _entries[index]
	var packed := load(info.scene) as PackedScene
	if packed == null:
		push_error("サンプルを読み込めませんでした: %s" % info.scene)
		return

	_close_sample()
	_current_sample = packed.instantiate()
	_host.add_child(_current_sample)
	_menu.visible = false
	_back.visible = true
	# visibleを落としてもArea3Dは物理空間に残る。当たり判定も一緒に外さないと、
	# 見えていない項目をレイが拾って誤爆する。
	_set_pickable(_menu, false)
	_set_pickable(_back, true)
	_set_highlight(null)


func _close_sample() -> void:
	if _current_sample != null:
		_current_sample.queue_free()
		_current_sample = null

	_show_menu()


func _show_menu() -> void:
	_menu.visible = true
	_back.visible = false
	_set_pickable(_menu, true)
	_set_pickable(_back, false)
	_update_status()


## 配下の項目をレイで拾える状態にするか切り替える。
func _set_pickable(root: Node3D, pickable: bool) -> void:
	for item in root.get_children():
		var area := item.get_node_or_null(^"Area") as Area3D
		if area != null:
			area.collision_layer = UI_LAYER if pickable else 0


func _update_status() -> void:
	if _stage == null:
		_status.text = ""
	elif _stage.is_mr_active:
		_status.text = "MR: 有効"
	else:
		_status.text = "MR: 無効（%s）" % _stage.fallback_reason
