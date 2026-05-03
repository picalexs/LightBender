extends RigidBody2D

const LIGHT_POLYGON_POINTS: int = 32
const HELD_COLLISION_LAYER: int = 2

@export var discharge_time: float = 6.0
@export var max_light_radius: float = 96.0
@export_range(0.0, 1.0) var low_power_ratio: float = 0.45
@export var flicker_speed: float = 20.0

@onready var discharge_light: Node = get_node_or_null("DischargeLight")
@onready var powered_indicator: Node2D = get_node_or_null("PoweredIndicator")

var active_light_zones: int = 0
var is_in_light: bool = false

var _holder: Node2D = null
var _default_collision_layer: int = 0
var _default_collision_mask: int = 0
var _charge_ratio: float = 1.0
var _flicker_time: float = 0.0
var _discharge_light_relative_transform: Transform2D = Transform2D.IDENTITY


func _ready() -> void:
	collision_layer = 3
	collision_mask = 1
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 12.0
	angular_damp = 12.0
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_capture_and_reparent_discharge_light()
	_set_discharge_enabled(false)
	_update_discharge_radius(max_light_radius)
	_update_indicator()


func _physics_process(delta: float) -> void:
	if _holder != null:
		global_position = _holder.global_position
	_sync_discharge_light_transform()

	is_in_light = active_light_zones > 0
	if is_in_light:
		_charge_ratio = 1.0
		_flicker_time = 0.0
		_set_discharge_enabled(false)
		_set_discharge_alpha(1.0)
	else:
		if discharge_time <= 0.0:
			_charge_ratio = 0.0
		else:
			_charge_ratio = maxf(_charge_ratio - delta / discharge_time, 0.0)

		if _charge_ratio > 0.0:
			_set_discharge_enabled(true)
			_update_discharge_radius(max_light_radius * _charge_ratio)
			_update_flicker(delta)
		else:
			_set_discharge_enabled(false)
			_set_discharge_alpha(1.0)

	_update_indicator()


func add_light_zone() -> void:
	active_light_zones += 1


func remove_light_zone() -> void:
	active_light_zones = maxi(active_light_zones - 1, 0)


func add_light_zone_from(zone: Node) -> void:
	if _owns_light_zone(zone):
		return
	add_light_zone()


func remove_light_zone_from(zone: Node) -> void:
	if _owns_light_zone(zone):
		return
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


func _update_flicker(delta: float) -> void:
	if _charge_ratio > low_power_ratio:
		_set_discharge_alpha(1.0)
		return

	_flicker_time += delta * flicker_speed
	var intensity := 0.55 + 0.45 * absf(sin(_flicker_time))
	_set_discharge_alpha(intensity)


func _set_discharge_enabled(enable: bool) -> void:
	if discharge_light == null or not discharge_light.has_method("toggle_light"):
		return

	var is_on_value = discharge_light.get("is_on")
	if typeof(is_on_value) == TYPE_BOOL and is_on_value != enable:
		discharge_light.toggle_light()


func _set_discharge_alpha(alpha: float) -> void:
	if discharge_light == null:
		return
	discharge_light.modulate = Color(1.0, 1.0, 1.0, alpha)


func _update_discharge_radius(radius: float) -> void:
	if discharge_light == null:
		return

	var polygon := _make_circle_polygon(radius, LIGHT_POLYGON_POINTS)
	discharge_light.polygon = polygon

	var hole := discharge_light.get_node_or_null("Hole") as Polygon2D
	if hole:
		hole.polygon = polygon

	var hitbox := discharge_light.get_node_or_null("TriggerZone/Hitbox") as CollisionPolygon2D
	if hitbox:
		hitbox.polygon = polygon


func _update_indicator() -> void:
	if powered_indicator:
		powered_indicator.visible = _charge_ratio > 0.0


func _set_physics_state(is_held: bool) -> void:
	freeze = is_held
	if is_held:
		collision_layer = HELD_COLLISION_LAYER
		collision_mask = 0
	else:
		collision_layer = _default_collision_layer
		collision_mask = _default_collision_mask


func _owns_light_zone(zone: Node) -> bool:
	return zone != null and zone == discharge_light


func _capture_and_reparent_discharge_light() -> void:
	if discharge_light == null:
		return
	var discharge_light_node := discharge_light as Node2D
	if discharge_light_node == null:
		return
	_discharge_light_relative_transform = global_transform.affine_inverse() * discharge_light_node.global_transform
	var dark_manager := get_tree().root.find_child("DarkManager", true, false)
	if dark_manager != null and discharge_light_node.get_parent() != dark_manager:
		discharge_light_node.reparent(dark_manager, true)


func _sync_discharge_light_transform() -> void:
	var discharge_light_node := discharge_light as Node2D
	if discharge_light_node == null:
		return
	discharge_light_node.global_transform = global_transform * _discharge_light_relative_transform


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
