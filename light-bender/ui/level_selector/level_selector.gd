extends Control

const LevelNodeScript := preload("res://ui/level_selector/level_node.gd")
const RESET_BUTTON_NORMAL := preload("res://assets/sprites/Reset_Button.png")
const RESET_BUTTON_CONFIRM := preload("res://assets/sprites/Reset_Button_Confirm.png")

@export_group("Graph Layout")
@export var node_size: Vector2 = Vector2(64.0, 64.0)
@export var spacing_x: float = 220.0
@export var start_x: float = 300.0
@export var row_spacing_y: float = 110.0
@export var chapter_y: PackedFloat32Array = PackedFloat32Array([260.0, 530.0, 800.0])

@export_group("Scene Nodes")
@export var graph_lines_path: NodePath = ^"GraphLayer/GraphLines"
@export var level_nodes_path: NodePath = ^"GraphLayer/LevelNodes"
@export var tooltip_path: NodePath = ^"Tooltip"
@export var tooltip_label_path: NodePath = ^"Tooltip/MarginContainer/TipLabel"
@export var reset_button_path: NodePath = ^"ResetSaveButton"

const RESET_CONFIRM_WINDOW := 5.0
var _nodes: Dictionary = {}
var _positions: Dictionary = {}
var _graph_lines: Control
var _level_nodes_root: Control
var _tooltip: PanelContainer
var _tip_label: Label
var _reset_button: BaseButton
var _reset_button_label: Label
var _reset_pending: bool = false
var _reset_timer: Timer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_resolve_scene_nodes()
	_build_graph()
	_refresh_states()


func _resolve_scene_nodes() -> void:
	_graph_lines = get_node_or_null(graph_lines_path) as Control
	_level_nodes_root = get_node_or_null(level_nodes_path) as Control
	_tooltip = get_node_or_null(tooltip_path) as PanelContainer
	_tip_label = get_node_or_null(tooltip_label_path) as Label
	_reset_button = get_node_or_null(reset_button_path) as BaseButton

	if _tooltip != null:
		_tooltip.visible = false
	if _reset_button != null:
		_reset_button.pressed.connect(_on_reset_pressed)
		_reset_button_label = _find_reset_button_label(_reset_button)
		_set_reset_button_text("")
		_apply_reset_button_visuals()

	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.wait_time = RESET_CONFIRM_WINDOW
	_reset_timer.timeout.connect(_clear_reset_confirmation)
	add_child(_reset_timer)


func _build_graph() -> void:
	_nodes.clear()
	_positions.clear()

	if _level_nodes_root == null:
		_level_nodes_root = self
	else:
		for child in _level_nodes_root.get_children():
			child.queue_free()

	for level in LevelManager.LEVELS:
		var id: String = level["id"]
		var col: int = level["col"]
		var row: int = level["row"]
		var chapter: int = level["chapter"]
		var chapter_index: int = chapter - 1

		var cy: float = chapter_y[chapter_index] if chapter_index < chapter_y.size() else 300.0 + chapter_index * 270.0
		var center := Vector2(
			start_x + col * spacing_x,
			cy + row * row_spacing_y
		)
		_positions[id] = center

		var node = LevelNodeScript.new()
		node.level_id = id
		node.level_name = level["name"]
		node.position = center - node_size * 0.5
		node.size = node_size
		node.hovered.connect(_on_hovered)
		node.unhovered.connect(_on_unhovered)
		node.clicked.connect(_on_clicked)
		_level_nodes_root.add_child(node)
		_nodes[id] = node

	_sync_graph_lines()


func _sync_graph_lines() -> void:
	if _graph_lines != null and _graph_lines.has_method("set_graph"):
		_graph_lines.set_graph(LevelManager.LEVELS, _positions, node_size)


func _refresh_states() -> void:
	for id in _nodes:
		var node = _nodes[id]
		if LevelManager.is_completed(id):
			node.set_node_state(node.State.COMPLETED)
		elif LevelManager.is_unlocked(id):
			node.set_node_state(node.State.UNLOCKED)
		else:
			node.set_node_state(node.State.LOCKED)

	if _graph_lines != null:
		if _graph_lines.has_method("refresh"):
			_graph_lines.refresh()
		else:
			_graph_lines.queue_redraw()


func _on_hovered(level_id: String) -> void:
	if _tooltip == null or _tip_label == null:
		return

	var level := LevelManager.get_level(level_id)
	if LevelManager.is_completed(level_id):
		_tip_label.text = level.get("name", "???") + "\n[Completed]"
		_tip_label.add_theme_color_override("font_color", Color(0.30, 1.00, 0.55))
	elif LevelManager.is_unlocked(level_id):
		_tip_label.text = level.get("name", "???")
		_tip_label.add_theme_color_override("font_color", Color(0.92, 0.92, 1.00))
	else:
		_tip_label.text = "???"
		_tip_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))

	_tooltip.reset_size()
	var tooltip_size := _tooltip.get_combined_minimum_size()
	_tooltip.size = tooltip_size
	var center: Vector2 = _positions.get(level_id, Vector2.ZERO)
	_tooltip.position = center + Vector2(-tooltip_size.x * 0.5, -node_size.y * 0.5 - tooltip_size.y - 16.0)
	var viewport_size := get_viewport_rect().size
	_tooltip.position.x = clampf(_tooltip.position.x, 4.0, viewport_size.x - tooltip_size.x - 4.0)
	_tooltip.position.y = clampf(_tooltip.position.y, 4.0, viewport_size.y - tooltip_size.y - 4.0)
	_tooltip.visible = true


func _on_unhovered() -> void:
	if _tooltip != null:
		_tooltip.visible = false


func _on_reset_pressed() -> void:
	if _tooltip != null:
		_tooltip.visible = false

	if _reset_pending:
		LevelManager.reset_progress(false)
		_refresh_states()
		_clear_reset_confirmation()
		return

	_reset_pending = true
	_apply_reset_button_visuals()
	_reset_timer.start()


func _clear_reset_confirmation() -> void:
	if _reset_timer != null:
		_reset_timer.stop()
	_reset_pending = false
	_apply_reset_button_visuals()


func _find_reset_button_label(button: BaseButton) -> Label:
	for child in button.get_children():
		if child is Label:
			return child as Label
	return null


func _set_reset_button_text(text: String) -> void:
	if _reset_button is Button:
		(_reset_button as Button).text = text
	elif _reset_button_label != null:
		_reset_button_label.text = text


func _apply_reset_button_visuals() -> void:
	if _reset_button == null:
		return

	var texture := RESET_BUTTON_CONFIRM if _reset_pending else RESET_BUTTON_NORMAL
	var normal_style := _make_reset_button_style(texture, Color(1, 1, 1, 1))
	var hover_style := _make_reset_button_style(texture, Color(1, 1, 1, 1))
	var pressed_style := _make_reset_button_style(texture, Color(0.82, 0.82, 0.82, 1))

	_reset_button.add_theme_stylebox_override("normal", normal_style)
	_reset_button.add_theme_stylebox_override("hover", hover_style)
	_reset_button.add_theme_stylebox_override("pressed", pressed_style)
	_reset_button.add_theme_stylebox_override("focus", hover_style)


func _make_reset_button_style(texture: Texture2D, modulate: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	sb.texture_margin_left = 4.0
	sb.texture_margin_top = 4.0
	sb.texture_margin_right = 4.0
	sb.texture_margin_bottom = 4.0
	sb.modulate_color = modulate
	return sb


func _on_clicked(level_id: String) -> void:
	if LevelManager.is_unlocked(level_id) or LevelManager.is_completed(level_id):
		_launch(level_id)


func _launch(level_id: String) -> void:
	var level := LevelManager.get_level(level_id)
	var scene_path: String = level.get("scene", "")
	if scene_path == "":
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in _nodes:
		_nodes[id].mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp_center := get_viewport().get_visible_rect().size * 0.5
	CircleTransition.play_close_from_screen_position(vp_center)
	await CircleTransition.fully_covered
	get_tree().change_scene_to_file(scene_path)
