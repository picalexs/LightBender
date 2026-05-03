extends Control

const LevelNodeScript := preload("res://ui/level_selector/level_node.gd")
const SMALL_BUTTON_NORMAL := preload("res://assets/sprites/Small_Button.png")
const SMALL_BUTTON_HOVER := preload("res://assets/sprites/Small_Button_Hover.png")
const RESET_BUTTON_NORMAL := preload("res://assets/sprites/Reset_Button.png")
const RESET_BUTTON_CONFIRM := preload("res://assets/sprites/Reset_Button_Confirm.png")
const NEXT_LEVEL_SOUND := preload("res://assets/audio/next_level.wav")
const UI_HIGHLIGHT_SOUND := preload("res://assets/audio/ui_clicking_3.wav")
const UI_CLICK_SOUND := preload("res://assets/audio/ui_click_1.wav")
const UI_TRASH_SOUND := preload("res://assets/audio/ui_trash.wav")

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
@export var background_rect_path: NodePath = ^"BackgroundViewport/SubViewport/BackgroundRect"

const RESET_CONFIRM_WINDOW := 5.0
var _nodes: Dictionary = {}
var _positions: Dictionary = {}
var _graph_lines: Control
var _level_nodes_root: Control
var _tooltip: PanelContainer
var _tip_label: Label
var _reset_button: BaseButton
var _reset_button_icon: TextureRect
var _reset_button_label: Label
var _reset_pending: bool = false
var _reset_timer: Timer
var _ui_click_player: AudioStreamPlayer
var _ui_trash_player: AudioStreamPlayer
var _background_material: ShaderMaterial
var _background_base_time_scale: float = 0.15
var _background_motion_tween: Tween = null
var _background_motion_scale: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	MusicManager.set_menu_mode(true)
	MusicManager.set_pause_mode(false)
	BackgroundManager.set_menu_mode(true)
	BackgroundManager.set_pause_mode(false)
	MusicManager.on_level_started()
	_setup_audio()
	_resolve_scene_nodes()
	_start_background_motion_tween()
	_build_graph()
	_refresh_states()


func _resolve_scene_nodes() -> void:
	_graph_lines = get_node_or_null(graph_lines_path) as Control
	_level_nodes_root = get_node_or_null(level_nodes_path) as Control
	_tooltip = get_node_or_null(tooltip_path) as PanelContainer
	_tip_label = get_node_or_null(tooltip_label_path) as Label
	_reset_button = get_node_or_null(reset_button_path) as BaseButton
	_reset_button_icon = get_node_or_null(^"ResetSaveButton/Icon") as TextureRect
	var background_rect := get_node_or_null(background_rect_path) as ColorRect
	if background_rect != null:
		_background_material = background_rect.material as ShaderMaterial
		if _background_material != null:
			_background_base_time_scale = float(_background_material.get_shader_parameter("time_scale"))

	if _tooltip != null:
		_tooltip.visible = false
	if _reset_button != null:
		_reset_button.pressed.connect(_on_reset_pressed)
		_reset_button_label = _find_reset_button_label(_reset_button)
		_set_reset_button_text("")
		_setup_reset_button_presentation()
		_apply_reset_button_visuals()

	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.wait_time = RESET_CONFIRM_WINDOW
	_reset_timer.timeout.connect(_clear_reset_confirmation)
	add_child(_reset_timer)


func _setup_audio() -> void:
	_ui_click_player = AudioStreamPlayer.new()
	_ui_click_player.bus = "SFX"
	add_child(_ui_click_player)

	_ui_trash_player = AudioStreamPlayer.new()
	_ui_trash_player.bus = "SFX"
	add_child(_ui_trash_player)


func _build_graph() -> void:
	_nodes.clear()
	_positions.clear()

	if _level_nodes_root == null:
		_level_nodes_root = self
	else:
		for child in _level_nodes_root.get_children():
			child.queue_free()

	for level in _get_levels():
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
		_graph_lines.set_graph(_get_levels(), _positions, node_size)


func _refresh_states() -> void:
	for id in _nodes:
		var node = _nodes[id]
		if _is_level_completed(id):
			node.set_node_state(node.State.COMPLETED)
		elif _is_level_unlocked(id):
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
		if _is_level_unlocked(level_id) or _is_level_completed(level_id):
			_play_ui_highlight()
		return

	if _is_level_unlocked(level_id) or _is_level_completed(level_id):
		_play_ui_highlight()

	var level := _get_level(level_id)
	if _is_level_completed(level_id):
		_tip_label.text = level.get("name", "???") + "\n[Completed]"
		_tip_label.add_theme_color_override("font_color", Color(0.30, 1.00, 0.55))
	elif _is_level_unlocked(level_id):
		_tip_label.text = level.get("name", "???")
		_tip_label.add_theme_color_override("font_color", Color(0.92, 0.92, 1.00))
	else:
		_tip_label.text = level.get("name", "???")
		_tip_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.78))

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
		_play_trash_sound()
		_reset_progress(false)
		_refresh_states()
		_clear_reset_confirmation()
		return

	_play_ui_click()
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


func _play_ui_click() -> void:
	_play_ui_sound(UI_CLICK_SOUND)


func _play_ui_highlight() -> void:
	_play_ui_sound(UI_HIGHLIGHT_SOUND, true)


func _play_ui_sound(stream: AudioStream, allow_overlap: bool = false) -> void:
	if stream == null:
		return

	if allow_overlap:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.stream = stream
		get_tree().root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
		return

	if _ui_click_player == null:
		return
	_ui_click_player.stream = stream
	_ui_click_player.play()


func _play_trash_sound() -> void:
	if _ui_trash_player == null or UI_TRASH_SOUND == null:
		return
	_ui_trash_player.volume_db = -6.0
	_ui_trash_player.stream = UI_TRASH_SOUND
	_ui_trash_player.play()


func _play_level_start_sound() -> void:
	if NEXT_LEVEL_SOUND == null:
		return

	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = NEXT_LEVEL_SOUND
	player.pitch_scale = maxf(0.01, 0.9 + randf_range(-0.2, 0.2))
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _start_background_motion_tween() -> void:
	if _background_material == null:
		return
	_kill_background_motion_tween()
	_background_motion_tween = create_tween()
	_background_motion_tween.tween_method(
		_set_background_motion_scale,
		_background_motion_scale,
		MusicManager.get_menu_background_time_scale(),
		MusicManager.get_context_tween_duration()
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_background_motion_tween() -> void:
	if _background_motion_tween != null and _background_motion_tween.is_valid():
		_background_motion_tween.kill()
	_background_motion_tween = null


func _apply_background_motion_scale() -> void:
	if _background_material == null:
		return
	_background_material.set_shader_parameter("time_scale", _background_base_time_scale * _background_motion_scale)


func _set_background_motion_scale(value: float) -> void:
	if is_equal_approx(_background_motion_scale, value):
		return
	_background_motion_scale = value
	_apply_background_motion_scale()


func _setup_reset_button_presentation() -> void:
	if _reset_button == null:
		return

	_reset_button.resized.connect(func() -> void:
		_reset_button.pivot_offset = _reset_button.size * 0.5
		if _reset_button_icon != null:
			var icon_size := _reset_button.size - Vector2(16.0, 16.0)
			_reset_button_icon.size = icon_size
			_reset_button_icon.position = (_reset_button.size - icon_size) * 0.5
	)
	_reset_button.mouse_entered.connect(func() -> void:
		_play_ui_highlight()
		_reset_button.scale = Vector2(1.05, 1.05)
		_reset_button.modulate = Color(1.18, 1.18, 1.18, 1.0)
	)
	_reset_button.mouse_exited.connect(func() -> void:
		_reset_button.scale = Vector2.ONE
		_reset_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func _get_level_manager() -> Node:
	return get_node_or_null("/root/LevelManager")


func _get_levels() -> Array:
	var level_manager := _get_level_manager()
	if level_manager == null:
		return []
	return level_manager.get("LEVELS")


func _is_level_completed(level_id: String) -> bool:
	var level_manager := _get_level_manager()
	return bool(level_manager.call("is_completed", level_id)) if level_manager != null else false


func _is_level_unlocked(level_id: String) -> bool:
	var level_manager := _get_level_manager()
	return bool(level_manager.call("is_unlocked", level_id)) if level_manager != null else false


func _get_level(level_id: String) -> Dictionary:
	var level_manager := _get_level_manager()
	return level_manager.call("get_level", level_id) if level_manager != null else {}


func _reset_progress(lock_all: bool) -> void:
	var level_manager := _get_level_manager()
	if level_manager != null:
		level_manager.call("reset_progress", lock_all)


func _apply_reset_button_visuals() -> void:
	if _reset_button == null:
		return

	var texture := RESET_BUTTON_CONFIRM if _reset_pending else RESET_BUTTON_NORMAL
	if _reset_button is TextureButton:
		var texture_button := _reset_button as TextureButton
		texture_button.texture_normal = SMALL_BUTTON_NORMAL
		texture_button.texture_hover = SMALL_BUTTON_HOVER
		texture_button.texture_pressed = SMALL_BUTTON_HOVER
		texture_button.texture_focused = SMALL_BUTTON_HOVER
		if _reset_button_icon != null:
			_reset_button_icon.texture = texture
		return

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
	if _is_level_unlocked(level_id) or _is_level_completed(level_id):
		_play_level_start_sound()
		_launch(level_id)


func _launch(level_id: String) -> void:
	var level := _get_level(level_id)
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
