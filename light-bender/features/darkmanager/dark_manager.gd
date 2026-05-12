@tool
extends CanvasGroup

@export var viewport_padding: float = 256.0

@onready var color_rect: ColorRect = $GlobalDark


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_dark_overlay()


func _process(_delta: float) -> void:
	_update_dark_overlay()


func _update_dark_overlay() -> void:
	if color_rect == null:
		return

	color_rect.color.a = 1.0

	var viewport := get_viewport()
	if viewport == null:
		return

	var visible_rect := viewport.get_visible_rect()
	var inverse_canvas := viewport.get_canvas_transform().affine_inverse()
	var top_left: Vector2 = inverse_canvas * visible_rect.position
	var bottom_right: Vector2 = inverse_canvas * visible_rect.end
	var padding := Vector2.ONE * maxf(0.0, viewport_padding)
	var min_point := Vector2(minf(top_left.x, bottom_right.x), minf(top_left.y, bottom_right.y)) - padding
	var max_point := Vector2(maxf(top_left.x, bottom_right.x), maxf(top_left.y, bottom_right.y)) + padding

	color_rect.position = min_point
	color_rect.size = max_point - min_point
