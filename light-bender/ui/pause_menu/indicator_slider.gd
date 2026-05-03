extends Control
class_name IndicatorSlider

signal value_changed(value: float)

const INDICATOR_BASE := preload("res://assets/sprites/Level_Icon_Unlocked.png")
const IDLE_OVERLAY := preload("res://assets/sprites/Not_Selected.png")
const HOVER_OVERLAY := preload("res://assets/sprites/Selected_Hover.png")

const PIXEL_SIZE := 6.0
const TRACK_COLOR := Color(0.26, 0.28, 0.34, 0.98)
const FILL_COLOR := Color(0.86, 0.92, 1.00, 0.98)
const INDICATOR_SIZE := Vector2(72.0, 72.0)
const MAX_VALUE := 1.2
const SNAP_VALUE := 1.0
const SNAP_THRESHOLD := 0.025

var _value: float = 0.8
var _is_hovered: bool = false
var _is_dragging: bool = false
var _base_icon: TextureRect
var _overlay_icon: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 88.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_base_icon = _make_icon_rect(INDICATOR_BASE)
	add_child(_base_icon)

	_overlay_icon = _make_icon_rect(IDLE_OVERLAY)
	add_child(_overlay_icon)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sync_indicator()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_indicator()


func set_slider_value(new_value: float, emit_signal: bool = false) -> void:
	var clamped_value := _snap_slider_value(clampf(new_value, 0.0, MAX_VALUE))
	if is_equal_approx(_value, clamped_value):
		return

	_value = clamped_value
	_sync_indicator()
	queue_redraw()

	if emit_signal:
		value_changed.emit(_value)


func get_slider_value() -> float:
	return _value


func _make_icon_rect(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.size = INDICATOR_SIZE
	return icon


func _sync_indicator() -> void:
	if _base_icon == null or _overlay_icon == null:
		return

	var track := _get_track_bounds()
	var center := Vector2(lerpf(track.x, track.y, _value / MAX_VALUE), size.y * 0.5)
	var draw_pos := center - INDICATOR_SIZE * 0.5
	_base_icon.position = draw_pos
	_base_icon.size = INDICATOR_SIZE
	_overlay_icon.position = draw_pos
	_overlay_icon.size = INDICATOR_SIZE
	_overlay_icon.texture = HOVER_OVERLAY if _is_hovered or _is_dragging else IDLE_OVERLAY


func _get_track_bounds() -> Vector2:
	var half_indicator := INDICATOR_SIZE.x * 0.5
	var padding := half_indicator + PIXEL_SIZE
	return Vector2(padding, maxf(padding, size.x - padding))


func _draw() -> void:
	var track := _get_track_bounds()
	var y := floorf(size.y * 0.5 - PIXEL_SIZE)
	var fill_limit := lerpf(track.x, track.y, _value / MAX_VALUE)
	var x := track.x

	while x <= track.y:
		var block_color := FILL_COLOR if x <= fill_limit else TRACK_COLOR
		draw_rect(
			Rect2(Vector2(snappedf(x, 1.0), y), Vector2(PIXEL_SIZE, PIXEL_SIZE)),
			block_color
		)
		x += PIXEL_SIZE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_update_from_local_x(mb.position.x)
			else:
				_is_dragging = false
				_sync_indicator()
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		var motion := event as InputEventMouseMotion
		_update_from_local_x(motion.position.x)
		accept_event()


func _update_from_local_x(local_x: float) -> void:
	var track := _get_track_bounds()
	if is_equal_approx(track.x, track.y):
		return
	var next_ratio := inverse_lerp(track.x, track.y, clampf(local_x, track.x, track.y))
	var next_value := next_ratio * MAX_VALUE
	set_slider_value(next_value, true)


func _snap_slider_value(value: float) -> float:
	if absf(value - SNAP_VALUE) <= SNAP_THRESHOLD:
		return SNAP_VALUE
	return value


func _on_mouse_entered() -> void:
	_is_hovered = true
	_sync_indicator()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_sync_indicator()
