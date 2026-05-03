extends RigidBody2D

signal toggled(is_active: bool)

const HELD_COLLISION_LAYER: int = 2
const ITEM_COLLISION_LAYER: int = 4
const BUTTON_BOX_OFF_TEXTURE: Texture2D = preload("res://assets/sprites/Button_Box_OFF.png")
const BUTTON_BOX_ON_TEXTURE: Texture2D = preload("res://assets/sprites/Button_Box_ON.png")

@export_group("Target Logic")
@export var target_node: Node
@export var method_when_active: String = "toggle_light"
@export var param_when_active: String = ""
@export var method_when_inactive: String = "toggle_light"
@export var param_when_inactive: String = ""
@export var secondary_target_node: Node
@export var secondary_method_when_active: String = ""
@export var secondary_param_when_active: String = ""
@export var secondary_method_when_inactive: String = ""
@export var secondary_param_when_inactive: String = ""

@export_group("Behaviour")
@export var trigger_on_change: bool = true

@onready var powered_indicator: Node2D = get_node_or_null("PoweredIndicator")
@onready var visual_sprite: Sprite2D = get_node_or_null("VisualSprite")
@onready var _light_receiver: LightReceiver = get_node_or_null("LightReceiver") as LightReceiver

var active_light_zones: int = 0
var is_in_light: bool = false

var _holder: Node2D = null
var _default_collision_layer: int = 0
var _default_collision_mask: int = 0
var _was_active: bool = false


func _ready() -> void:
	collision_layer = ITEM_COLLISION_LAYER
	collision_mask = 1
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 12.0
	angular_damp = 12.0
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	if _light_receiver != null:
		_light_receiver.light_state_changed.connect(_on_light_receiver_state_changed)
	refresh_light_state()
	_update_indicator()
	_update_visual_state()


func _physics_process(_delta: float) -> void:
	if _holder != null:
		global_position = _holder.global_position

	if trigger_on_change:
		if is_in_light != _was_active:
			_fire_target(is_in_light)
			toggled.emit(is_in_light)
	else:
		_fire_target(is_in_light)

	_was_active = is_in_light
	_update_indicator()
	_update_visual_state()


func add_light_zone() -> void:
	if _light_receiver != null:
		_light_receiver.add_light_zone()
		return
	active_light_zones = 1
	is_in_light = true


func remove_light_zone() -> void:
	if _light_receiver != null:
		_light_receiver.remove_light_zone()
		return
	active_light_zones = 0
	is_in_light = false


func add_light_zone_from(zone: Node) -> void:
	if _light_receiver != null:
		_light_receiver.add_light_zone_from(zone)
		return
	add_light_zone()


func remove_light_zone_from(zone: Node) -> void:
	if _light_receiver != null:
		_light_receiver.remove_light_zone_from(zone)
		return
	remove_light_zone()


func pickup(carrier: Node) -> void:
	_holder = carrier as Node2D
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
	_set_physics_state(true)
	if _holder != null:
		global_position = _holder.global_position
	refresh_light_state()


func drop() -> void:
	_holder = null
	sleeping = false
	_set_physics_state(false)


func prepare_drop_state(_drop_position: Vector2) -> void:
	pass


func get_held_item_alpha() -> float:
	return 0.55


func get_interaction_prompt_verb() -> String:
	return "absorb"


func can_show_interact_prompt() -> bool:
	return _holder == null


func _fire_target(is_active: bool) -> void:
	_fire_single_target(
		target_node,
		method_when_active,
		param_when_active,
		method_when_inactive,
		param_when_inactive,
		is_active
	)
	_fire_single_target(
		secondary_target_node,
		secondary_method_when_active,
		secondary_param_when_active,
		secondary_method_when_inactive,
		secondary_param_when_inactive,
		is_active
	)


func _update_indicator() -> void:
	if powered_indicator:
		powered_indicator.visible = is_in_light


func _update_visual_state() -> void:
	if visual_sprite:
		visual_sprite.texture = BUTTON_BOX_ON_TEXTURE if is_in_light else BUTTON_BOX_OFF_TEXTURE


func _set_physics_state(is_held: bool) -> void:
	freeze = is_held
	if is_held:
		collision_layer = HELD_COLLISION_LAYER
		collision_mask = 0
	else:
		collision_layer = _default_collision_layer
		collision_mask = _default_collision_mask


func refresh_light_state() -> void:
	if _light_receiver == null:
		return
	_light_receiver.refresh_light_state()
	active_light_zones = _light_receiver.active_light_zones
	is_in_light = _light_receiver.is_in_light


func _on_light_receiver_state_changed(now_in_light: bool) -> void:
	active_light_zones = _light_receiver.active_light_zones if _light_receiver != null else active_light_zones
	is_in_light = now_in_light


func _fire_single_target(
	target: Node,
	active_method: String,
	active_param: String,
	inactive_method: String,
	inactive_param: String,
	is_active: bool
) -> void:
	if target == null:
		return

	var method_name: String = active_method if is_active else inactive_method
	var parameter: String = active_param if is_active else inactive_param
	if method_name == "":
		method_name = active_method
		parameter = active_param
	if _try_call_stateful_light_target(target, method_name, active_method, inactive_method, is_active):
		return
	NodeDispatch.call_method(target, method_name, parameter, "ButtonBox")


func _try_call_stateful_light_target(
	target: Node,
	method_name: String,
	active_method: String,
	inactive_method: String,
	is_active: bool
) -> bool:
	if method_name != "toggle_light":
		return false
	if active_method != inactive_method:
		return false
	if target == null or not target.has_method("set_light_enabled"):
		return false

	target.call("set_light_enabled", is_active)
	return true
