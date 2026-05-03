extends Control

signal hovered(level_id: String)
signal unhovered
signal clicked(level_id: String)

enum State { LOCKED, UNLOCKED, COMPLETED, SELECTED }

const LOCKED_ICON  := preload("res://assets/sprites/Level_Icon_Locked.png")
const UNLOCKED_ICON := preload("res://assets/sprites/Level_Icon_Unlocked.png")
const COMPLETED_ICON := preload("res://assets/sprites/Level_Icon_Completed.png")
const IDLE_OVERLAY := preload("res://assets/sprites/Not_Selected.png")
const HOVER_OVERLAY := preload("res://assets/sprites/Selected_Hover.png")

var level_id:   String = ""
var level_name: String = ""
var current_state: State = State.LOCKED
var _base_state: State = State.LOCKED
var _is_hovered: bool = false
var _base_icon: TextureRect
var _overlay_icon: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)
	pivot_offset = size * 0.5
	mouse_filter = MOUSE_FILTER_IGNORE
	_base_icon = _make_icon_rect()
	add_child(_base_icon)
	_overlay_icon = _make_icon_rect()
	add_child(_overlay_icon)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_visuals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _make_icon_rect() -> TextureRect:
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


func set_node_state(s: State) -> void:
	current_state = s
	if s == State.LOCKED:
		_is_hovered = false
	mouse_filter = MOUSE_FILTER_IGNORE if s == State.LOCKED else MOUSE_FILTER_STOP
	match s:
		State.LOCKED, State.UNLOCKED, State.COMPLETED:
			_base_state = s
		State.SELECTED:
			if _base_state == State.LOCKED:
				_base_state = State.UNLOCKED
	_apply_visuals()


func _apply_visuals() -> void:
	if _base_icon == null or _overlay_icon == null:
		return

	match _base_state:
		State.LOCKED:
			_base_icon.texture = LOCKED_ICON
		State.UNLOCKED, State.SELECTED:
			_base_icon.texture = UNLOCKED_ICON
		State.COMPLETED:
			_base_icon.texture = COMPLETED_ICON

	var is_emphasized := current_state == State.SELECTED or _is_hovered
	_overlay_icon.texture = HOVER_OVERLAY if is_emphasized else IDLE_OVERLAY


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			clicked.emit(level_id)


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_visuals()
	hovered.emit(level_id)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_visuals()
	unhovered.emit()
