extends RigidBody2D

const LIGHT_POLYGON_POINTS: int = 64
const HELD_COLLISION_LAYER: int = 2
const ITEM_COLLISION_LAYER: int = 4
const BATTERY_OFF_TEXTURE: Texture2D = preload("res://assets/sprites/Battery_OFF.png")
const BATTERY_ON_TEXTURE: Texture2D = preload("res://assets/sprites/Battery_ON.png")

@export var discharge_time: float = 6.0
@export var max_light_radius: float = 96.0
@export var max_penumbra_size: float = 48.0
@export_range(0.0, 1.0, 0.01) var max_penumbra_alpha: float = 1.0
@export_range(0.0, 1.0) var penumbra_radius_ratio: float = 0.5
@export_range(0.0, 1.0) var low_power_ratio: float = 0.45
@export_range(0.0, 1.0) var flicker_min_visual_ratio: float = 0.18
@export var flicker_speed: float = 20.0
@export var penumbra_transition_speed: float = 10.0

@onready var discharge_light: Node = get_node_or_null("DischargeLight")
@onready var powered_indicator: Node2D = get_node_or_null("PoweredIndicator")
@onready var visual_sprite: Sprite2D = get_node_or_null("VisualSprite")

var active_light_zones: int = 0
var is_in_light: bool = false

var _holder: Node2D = null
var _default_collision_layer: int = 0
var _default_collision_mask: int = 0
var _charge_ratio: float = 1.0
var _flicker_time: float = 0.0
var _discharge_light_relative_transform: Transform2D = Transform2D.IDENTITY
var _current_discharge_radius: float = 0.0
var _base_penumbra_steps: int = 8
var _base_core_scale: float = 1.0
var _base_core_alpha: float = 1.0
var _current_penumbra_size: float = 0.0
var _current_penumbra_alpha: float = 0.0
var _target_penumbra_size: float = 0.0
var _target_penumbra_alpha: float = 0.0
var _current_penumbra_steps: float = 1.0
var _target_penumbra_steps: float = 1.0
var _current_core_scale: float = 1.0
var _current_core_alpha: float = 1.0
var _target_core_scale: float = 1.0
var _target_core_alpha: float = 1.0
var _drop_light_grace_frames: int = 0
var _drop_light_state: bool = false
var _was_in_low_power: bool = false


func _ready() -> void:
	collision_layer = ITEM_COLLISION_LAYER
	collision_mask = 1
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 12.0
	angular_damp = 12.0
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_capture_and_reparent_discharge_light()
	_capture_discharge_style_defaults()
	_set_discharge_enabled(false)
	_update_discharge_radius(max_light_radius)
	_update_penumbra_visual(0.0, true)
	_update_indicator()
	_update_visual_state()


func _physics_process(delta: float) -> void:
	if _holder != null:
		global_position = _holder.global_position
	_sync_discharge_light_transform()

	var was_recharging: bool = is_in_light
	is_in_light = _is_recharging()
	if is_in_light:
		_charge_ratio = 1.0
		_flicker_time = 0.0
		_was_in_low_power = false
		_set_discharge_enabled(true)
		_set_discharge_visual_enabled(true)
		_update_discharge_radius(max_light_radius)
	else:
		if discharge_time <= 0.0:
			_charge_ratio = 0.0
		else:
			_charge_ratio = maxf(_charge_ratio - delta / discharge_time, 0.0)

		if _charge_ratio > 0.0:
			_set_discharge_enabled(true)
			_update_discharge_radius(_get_visual_radius())
			if was_recharging:
				_update_penumbra_visual(0.0, true)
			_update_flicker(delta)
		else:
			_was_in_low_power = false
			_target_penumbra_size = 0.0
			_target_penumbra_alpha = 0.0
			_target_penumbra_steps = 1.0
			_target_core_scale = 1.0
			_target_core_alpha = _base_core_alpha
			_set_discharge_enabled(false)
			_set_discharge_visual_enabled(false)

	_update_penumbra_visual(delta)
	_update_indicator()
	_update_visual_state()


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
	active_light_zones = 0
	_drop_light_grace_frames = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
	_set_physics_state(true)


func drop() -> void:
	_holder = null
	active_light_zones = 0
	sleeping = false
	_set_physics_state(false)


func prepare_drop_state(drop_position: Vector2) -> void:
	_drop_light_state = _is_point_in_external_light(drop_position)
	_drop_light_grace_frames = 2


func get_held_item_alpha() -> float:
	return 1.0 if _charge_ratio <= 0.0 else 0.55


func _update_flicker(delta: float) -> void:
	if _charge_ratio > low_power_ratio:
		_flicker_time = 0.0
		_was_in_low_power = false
		_set_discharge_visual_enabled(true)
		return

	if not _was_in_low_power:
		_was_in_low_power = true
		_update_penumbra_visual(0.0, true)

	_flicker_time += delta * flicker_speed
	var low_power_denominator := maxf(low_power_ratio, 0.001)
	var severity := clampf(1.0 - (_charge_ratio / low_power_denominator), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_flicker_time)
	var cutoff := lerpf(0.995, 0.68, severity)
	_set_discharge_visual_enabled(pulse < cutoff)


func _set_discharge_enabled(enable: bool) -> void:
	if discharge_light == null or not discharge_light.has_method("toggle_light"):
		return

	var is_on_value: Variant = discharge_light.get("is_on")
	if typeof(is_on_value) == TYPE_BOOL and is_on_value != enable:
		discharge_light.toggle_light()


func _set_discharge_visual_enabled(enable: bool) -> void:
	if discharge_light == null:
		return
	if discharge_light.has_method("set_visual_enabled"):
		discharge_light.set_visual_enabled(enable)


func _set_discharge_alpha(alpha: float) -> void:
	if discharge_light == null:
		return
	discharge_light.modulate = Color(1.0, 1.0, 1.0, alpha)


func _update_discharge_radius(radius: float) -> void:
	if discharge_light == null:
		return

	_current_discharge_radius = radius
	var polygon: PackedVector2Array = _make_circle_polygon(radius, LIGHT_POLYGON_POINTS)
	discharge_light.polygon = polygon
	_apply_penumbra_for_radius(radius)


func _apply_penumbra_for_radius(radius: float) -> void:
	var base_penumbra: float = _get_base_penumbra_size(radius)
	_target_penumbra_size = base_penumbra
	_target_penumbra_alpha = max_penumbra_alpha
	_target_penumbra_steps = float(_base_penumbra_steps)
	_target_core_scale = _base_core_scale
	_target_core_alpha = _base_core_alpha


func _get_visual_radius() -> float:
	var clamped_ratio: float = clampf(_charge_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return 0.0
	var minimum_ratio: float = clampf(min(flicker_min_visual_ratio, low_power_ratio), 0.0, 1.0)
	return maxf(clamped_ratio, minimum_ratio) * max_light_radius


func _get_base_penumbra_size(radius: float) -> float:
	return minf(max_penumbra_size, radius * penumbra_radius_ratio)


func _set_discharge_penumbra(size: float, alpha: float = max_penumbra_alpha) -> void:
	if discharge_light == null:
		return
	if "penumbra_size" in discharge_light:
		discharge_light.penumbra_size = maxf(size, 0.0)
	if "penumbra_alpha" in discharge_light:
		discharge_light.penumbra_alpha = clampf(alpha, 0.0, 1.0)


func _update_penumbra_visual(delta: float, snap: bool = false) -> void:
	if discharge_light == null:
		return

	if snap:
		_current_penumbra_size = _target_penumbra_size
		_current_penumbra_alpha = _target_penumbra_alpha
		_current_penumbra_steps = _target_penumbra_steps
		_current_core_scale = _target_core_scale
		_current_core_alpha = _target_core_alpha
	else:
		var weight: float = 1.0 - exp(-maxf(penumbra_transition_speed, 0.01) * delta)
		_current_penumbra_size = lerpf(_current_penumbra_size, _target_penumbra_size, weight)
		_current_penumbra_alpha = lerpf(_current_penumbra_alpha, _target_penumbra_alpha, weight)
		_current_penumbra_steps = lerpf(_current_penumbra_steps, _target_penumbra_steps, weight)
		_current_core_scale = lerpf(_current_core_scale, _target_core_scale, weight)
		_current_core_alpha = lerpf(_current_core_alpha, _target_core_alpha, weight)

	_set_discharge_penumbra(_current_penumbra_size, _current_penumbra_alpha)
	_apply_discharge_core_style(_current_penumbra_steps, _current_core_scale, _current_core_alpha)


func _apply_discharge_core_style(step_count: float, core_scale: float, core_alpha: float) -> void:
	if discharge_light == null:
		return
	if "penumbra_steps" in discharge_light:
		discharge_light.penumbra_steps = maxi(int(round(step_count)), 1)
	if "core_scale" in discharge_light:
		discharge_light.core_scale = clampf(core_scale, 0.05, 1.0)
	if "core_alpha" in discharge_light:
		discharge_light.core_alpha = clampf(core_alpha, 0.0, 1.0)
	if discharge_light.has_method("refresh_geometry"):
		discharge_light.refresh_geometry()


func _capture_discharge_style_defaults() -> void:
	if discharge_light == null:
		return
	_base_penumbra_steps = maxi(int(discharge_light.get("penumbra_steps")), 1)
	_base_core_scale = clampf(float(discharge_light.get("core_scale")), 0.05, 1.0)
	_base_core_alpha = clampf(float(discharge_light.get("core_alpha")), 0.0, 1.0)
	_current_penumbra_steps = float(_base_penumbra_steps)
	_target_penumbra_steps = _current_penumbra_steps
	_current_core_scale = _base_core_scale
	_target_core_scale = _base_core_scale
	_current_core_alpha = _base_core_alpha
	_target_core_alpha = _base_core_alpha


func _update_indicator() -> void:
	if powered_indicator:
		powered_indicator.visible = _charge_ratio > 0.0


func _update_visual_state() -> void:
	if visual_sprite == null:
		return
	visual_sprite.texture = BATTERY_ON_TEXTURE if _charge_ratio > 0.0 else BATTERY_OFF_TEXTURE


func _set_physics_state(is_held: bool) -> void:
	freeze = is_held
	if is_held:
		collision_layer = HELD_COLLISION_LAYER
		collision_mask = 0
	else:
		collision_layer = _default_collision_layer
		collision_mask = _default_collision_mask


func _is_recharging() -> bool:
	if active_light_zones > 0 or _is_holder_in_light():
		return true
	if _holder == null and _drop_light_grace_frames > 0:
		_drop_light_grace_frames -= 1
		return _drop_light_state
	return false


func _is_holder_in_light() -> bool:
	if _holder == null:
		return false
	if _holder.has_method("is_in_light_excluding_zone"):
		return _holder.is_in_light_excluding_zone(discharge_light)
	return _holder.get("is_in_light") == true


func _owns_light_zone(zone: Node) -> bool:
	return zone != null and zone == discharge_light


func _is_point_in_external_light(world_position: Vector2) -> bool:
	var dark_manager: Node = get_tree().root.find_child("DarkManager", true, false)
	if dark_manager == null:
		return false
	for candidate in dark_manager.find_children("*", "Polygon2D", true, false):
		if candidate == discharge_light:
			continue
		if not candidate.has_method("toggle_light"):
			continue
		if candidate.get("is_on") != true:
			continue
		var hitbox := candidate.get_node_or_null("TriggerZone/Hitbox") as CollisionPolygon2D
		if hitbox == null:
			continue
		if Geometry2D.is_point_in_polygon(hitbox.to_local(world_position), hitbox.polygon):
			return true
	return false


func _capture_and_reparent_discharge_light() -> void:
	if discharge_light == null:
		return
	var discharge_light_node: Node2D = discharge_light as Node2D
	if discharge_light_node == null:
		return
	_discharge_light_relative_transform = global_transform.affine_inverse() * discharge_light_node.global_transform
	var dark_manager: Node = get_tree().root.find_child("DarkManager", true, false)
	if dark_manager != null and discharge_light_node.get_parent() != dark_manager:
		discharge_light_node.reparent(dark_manager, true)


func _sync_discharge_light_transform() -> void:
	var discharge_light_node: Node2D = discharge_light as Node2D
	if discharge_light_node == null:
		return
	discharge_light_node.global_transform = global_transform * _discharge_light_relative_transform


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
