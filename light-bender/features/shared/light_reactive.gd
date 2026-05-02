extends Area2D

signal light_state_changed(is_in_light: bool)

@export_group("Visual Feedback")
@export var dim_when_dark: bool = true
@export var dark_alpha: float = 0.4

var is_in_light: bool = false:
	set(value):
		if is_in_light != value:
			is_in_light = value
			light_state_changed.emit(is_in_light)
			_update_visuals()

var _active_light_zones: int = 0
var _parent: Node2D
var _original_alpha: float = 1.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = true
	monitorable = true

	_parent = get_parent() as Node2D
	if _parent == null:
		push_warning("LightReactive Error: Parent must be a Node2D!")
		return
	
	if dim_when_dark and _parent is CanvasItem:
		_original_alpha = _parent.modulate.a
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visuals()

func _on_body_entered(_body: Node2D) -> void:
	pass

func _on_body_exited(_body: Node2D) -> void:
	pass

func add_light_zone() -> void:
	_active_light_zones += 1
	is_in_light = true

func remove_light_zone() -> void:
	_active_light_zones = max(_active_light_zones - 1, 0)
	if _active_light_zones == 0:
		is_in_light = false

func can_interact() -> bool:
	return is_in_light

func _update_visuals() -> void:
	if not dim_when_dark or _parent == null or not _parent is CanvasItem:
		return
	
	var target_alpha := _original_alpha if is_in_light else dark_alpha
	_parent.modulate.a = target_alpha
