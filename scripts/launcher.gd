extends Node3D

## サンプル一覧。`samples/samples.tres`を読んで項目を並べ、選ばれたシーンを
## `SampleHost`の下に挿す。サンプルを閉じると一覧へ戻る。
##
## ランチャーはサンプルではないので、サンプルの規約（1テーマ・1スクリプト・
## 200行以内）の対象外です。

const LIBRARY_PATH := "res://samples/samples.tres"
const ITEM_WIDTH := 0.62
const ITEM_HEIGHT := 0.075
const ITEM_PITCH := 0.088
## ランチャーの当たり判定だけに使う物理レイヤー。サンプル側と衝突させない。
const UI_LAYER := 8

var _entries: Array[SampleInfo] = []
var _items: Array[Node3D] = []
var _highlighted: Node3D
var _current_sample: Node
var _stage: MRStage

@onready var _menu: Node3D = $Menu
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
	var top := (_entries.size() - 1) * ITEM_PITCH * 0.5
	for index in _entries.size():
		var info := _entries[index]
		var item := _create_item(info.title, info.get_devices_text())
		item.position = Vector3(0, top - index * ITEM_PITCH, 0)
		item.get_node(^"Area").set_meta(&"sample_index", index)
		_menu.add_child(item)
		_items.append(item)


func _build_back_item() -> void:
	var item := _create_item("サンプル一覧へ戻る", "")
	item.get_node(^"Area").set_meta(&"back", true)
	_back.add_child(item)


func _create_item(text: String, note: String) -> Node3D:
	var item := Node3D.new()

	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ITEM_WIDTH, ITEM_HEIGHT, 0.008)
	panel.mesh = mesh
	panel.material_override = _create_panel_material(false)
	panel.name = "Panel"
	item.add_child(panel)

	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = 0.0007
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector3(-ITEM_WIDTH * 0.5 + 0.025, 0, 0.006)
	item.add_child(label)

	if not note.is_empty():
		var note_label := Label3D.new()
		note_label.text = note
		note_label.font_size = 30
		note_label.pixel_size = 0.0007
		note_label.modulate = Color(0.68, 0.78, 0.9)
		note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note_label.position = Vector3(ITEM_WIDTH * 0.5 - 0.025, 0, 0.006)
		item.add_child(note_label)

	var area := Area3D.new()
	area.name = "Area"
	area.collision_layer = UI_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ITEM_WIDTH, ITEM_HEIGHT, 0.03)
	shape.shape = box
	area.add_child(shape)
	item.add_child(area)

	return item


func _create_panel_material(highlighted: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = (
		Color(0.16, 0.42, 0.72, 0.92) if highlighted else Color(0.06, 0.09, 0.14, 0.82)
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	if area == null:
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
	_set_highlight(null)


func _close_sample() -> void:
	if _current_sample != null:
		_current_sample.queue_free()
		_current_sample = null

	_show_menu()


func _show_menu() -> void:
	_menu.visible = true
	_back.visible = false
	_update_status()


func _update_status() -> void:
	if _stage == null:
		_status.text = ""
	elif _stage.is_mr_active:
		_status.text = "MR: 有効"
	else:
		_status.text = "MR: 無効（%s）" % _stage.fallback_reason
