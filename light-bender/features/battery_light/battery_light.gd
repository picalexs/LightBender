extends RigidBody2D

const LIGHT_POLYGON_POINTS: int = 32
const HELD_COLLISION_LAYER: int = 2
const ITEM_COLLISION_LAYER: int = 4
const DISCHARGE_RADIUS_EPS: float = 2.0
const PENUMBRA_SIZE_EPS: float = 0.5
const STYLE_ALPHA_EPS: float = 0.02
const STYLE_SCALE_EPS: float = 0.02
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
@onready var _light_receiver: LightReceiver = get_node_or_null("LightReceiver") as LightReceiver

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
var _was_in_low_power: bool = false
var _applied_penumbra_size: float = -1.0
var _applied_penumbra_alpha: float = -1.0
var _applied_penumbra_steps: int = -1
var _applied_core_scale: float = -1.0
var _applied_core_alpha: float = -1.0


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
	if _light_receiver != null:
		_light_receiver.light_state_changed.connect(_on_light_receiver_state_changed)
	_set_discharge_enabled(false)
	_update_discharge_radius(max_light_radius)
	_update_penumbra_visual(0.0, true)
	refresh_light_state()
	_update_indicator()
	_update_visual_state()


func _physics_process(delta: float) -> void:
	if _holder != null:
		global_position = _holder.global_position
	_sync_discharge_light_transform()

	var was_recharging: bool = is_in_light
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
	_sync_discharge_light_transform()
	refresh_light_state()


func drop() -> void:
	_holder = null
	sleeping = false
	_set_physics_state(false)


func prepare_drop_state(_drop_position: Vector2) -> void:
	pass


func get_held_item_alpha() -> float:
	return 1.0 if _charge_ratio <= 0.0 else 0.55


func get_interaction_prompt_title() -> String:
	return "BATTERY"


func get_interaction_prompt_verb() -> String:
	return "absorb"


func can_show_interact_prompt() -> bool:
	return _holder == null


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

	var clamped_radius := maxf(radius, 0.0)
	if absf(clamped_radius - _current_discharge_radius) < DISCHARGE_RADIUS_EPS:
		return

	_current_discharge_radius = clamped_radius
	var polygon: PackedVector2Array = _make_circle_polygon(clamped_radius, LIGHT_POLYGON_POINTS)
	discharge_light.polygon = polygon
	_apply_penumbra_for_radius(clamped_radius)


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

	_apply_discharge_visual_style(snap)


func _apply_discharge_visual_style(force: bool = false) -> void:
	if discharge_light == null:
		return

	var next_penumbra_size := maxf(_current_penumbra_size, 0.0)
	var next_penumbra_alpha := clampf(_current_penumbra_alpha, 0.0, 1.0)
	var next_penumbra_steps := maxi(int(round(_current_penumbra_steps)), 1)
	var next_core_scale := clampf(_current_core_scale, 0.05, 1.0)
	var next_core_alpha := clampf(_current_core_alpha, 0.0, 1.0)
	var geometry_changed := false

	if "penumbra_size" in discharge_light and (force or _applied_penumbra_size < 0.0 or absf(next_penumbra_size - _applied_penumbra_size) >= PENUMBRA_SIZE_EPS):
		discharge_light.penumbra_size = next_penumbra_size
		_applied_penumbra_size = next_penumbra_size
		geometry_changed = true
	if "penumbra_alpha" in discharge_light and (force or _applied_penumbra_alpha < 0.0 or absf(next_penumbra_alpha - _applied_penumbra_alpha) >= STYLE_ALPHA_EPS):
		discharge_light.penumbra_alpha = next_penumbra_alpha
		_applied_penumbra_alpha = next_penumbra_alpha
		geometry_changed = true
	if "penumbra_steps" in discharge_light and (force or next_penumbra_steps != _applied_penumbra_steps):
		discharge_light.penumbra_steps = next_penumbra_steps
		_applied_penumbra_steps = next_penumbra_steps
		geometry_changed = true
	if "core_scale" in discharge_light and (force or _applied_core_scale < 0.0 or absf(next_core_scale - _applied_core_scale) >= STYLE_SCALE_EPS):
		discharge_light.core_scale = next_core_scale
		_applied_core_scale = next_core_scale
		geometry_changed = true
	if "core_alpha" in discharge_light and (force or _applied_core_alpha < 0.0 or absf(next_core_alpha - _applied_core_alpha) >= STYLE_ALPHA_EPS):
		discharge_light.core_alpha = next_core_alpha
		_applied_core_alpha = next_core_alpha
		geometry_changed = true

	if geometry_changed and discharge_light.has_method("refresh_geometry"):
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


func _owns_light_zone(zone: Node) -> bool:
	return zone != null and zone == discharge_light


func get_owned_light_sources() -> Array[Node]:
	var owned_sources: Array[Node] = []
	if is_instance_valid(discharge_light):
		owned_sources.append(discharge_light)
	return owned_sources


func refresh_light_state() -> void:
	if _light_receiver != null:
		_light_receiver.refresh_light_state()
		active_light_zones = _light_receiver.active_light_zones
		is_in_light = _light_receiver.is_in_light
	_sync_discharge_light_overlaps()


func _on_light_receiver_state_changed(now_in_light: bool) -> void:
	active_light_zones = _light_receiver.active_light_zones if _light_receiver != null else active_light_zones
	is_in_light = now_in_light


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


func _sync_discharge_light_overlaps() -> void:
	if discharge_light != null and discharge_light.has_method("_sync_current_overlaps"):
		discharge_light.call("_sync_current_overlaps")


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
