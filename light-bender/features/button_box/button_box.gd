extends RigidBody2D

const HELD_COLLISION_LAYER: int = 2

@export_group("Target Logic")
@export var target_node: Node
@export var method_when_active: String = "toggle_light"
@export var param_when_active: String = ""
@export var method_when_inactive: String = ""
@export var param_when_inactive: String = ""

@export_group("Behaviour")
@export var trigger_on_change: bool = true

@onready var powered_indicator: Node2D = get_node_or_null("PoweredIndicator")

var active_light_zones: int = 0
var is_in_light: bool = false

var _holder: Node2D = null
var _default_collision_layer: int = 0
var _default_collision_mask: int = 0
var _was_active: bool = false


func _ready() -> void:
	collision_layer = 3
	collision_mask = 1
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 12.0
	angular_damp = 12.0
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_update_indicator()


func _physics_process(_delta: float) -> void:
	if _holder != null:
		global_position = _holder.global_position

	is_in_light = active_light_zones > 0

	if trigger_on_change:
		if is_in_light != _was_active:
			_fire_target(is_in_light)
	else:
		_fire_target(is_in_light)

	_was_active = is_in_light
	_update_indicator()


func add_light_zone() -> void:
	active_light_zones += 1


func remove_light_zone() -> void:
	active_light_zones = maxi(active_light_zones - 1, 0)


func add_light_zone_from(_zone: Node) -> void:
	add_light_zone()


func remove_light_zone_from(_zone: Node) -> void:
	remove_light_zone()


func pickup(carrier: Node) -> void:
	_holder = carrier as Node2D
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
	_set_physics_state(true)


func drop() -> void:
	_holder = null
	sleeping = false
	_set_physics_state(false)


func _fire_target(is_active: bool) -> void:
	if target_node == null:
		return

	var method_name := method_when_active if is_active else method_when_inactive
	var parameter := param_when_active if is_active else param_when_inactive
	NodeDispatch.call_method(target_node, method_name, parameter, "ButtonBox")


func _update_indicator() -> void:
	if powered_indicator:
		powered_indicator.visible = is_in_light


func _set_physics_state(is_held: bool) -> void:
	freeze = is_held
	if is_held:
		collision_layer = HELD_COLLISION_LAYER
		collision_mask = 0
	else:
		collision_layer = _default_collision_layer
		collision_mask = _default_collision_mask

