extends RigidBody2D

const ROTATION_STEP_DEGREES: float = 90.0
const ROTATION_STEP_COUNT: int = 4
const HELD_COLLISION_LAYER: int = 2
const ITEM_COLLISION_LAYER: int = 4
const FLASHLIGHT_OFF_TEXTURE: Texture2D = preload("res://assets/sprites/Flashlight_OFF.png")
const FLASHLIGHT_ON_TEXTURE: Texture2D = preload("res://assets/sprites/Flashlight_ON.png")

var active_light_zones: int = 0
var is_in_light: bool = false

@onready var visual_sprite: Sprite2D = get_node_or_null("VisualSprite")
@onready var _light_receiver: LightReceiver = get_node_or_null("LightReceiver") as LightReceiver

var _rotation_index: int = 0
var _holder: Node2D = null
var _default_collision_layer: int = 0
var _default_collision_mask: int = 0
var _controlled_light_zones: Array[Dictionary] = []


func _ready() -> void:
	collision_layer = ITEM_COLLISION_LAYER
	collision_mask = 1
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 12.0
	angular_damp = 12.0
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_rotation_index = _get_rotation_index_from_scene()
	_apply_rotation()
	_capture_and_reparent_light_zones()
	if _light_receiver != null:
		_light_receiver.light_state_changed.connect(_on_light_receiver_state_changed)
	_set_child_light_zones(false)
	refresh_light_state()
	_update_visual_state()


func _physics_process(_delta: float) -> void:
	if _holder != null:
		global_position = _holder.global_position
		_sync_controlled_light_zone_transforms()


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
	_sync_controlled_light_zone_transforms()
	refresh_light_state()


func drop() -> void:
	_holder = null
	sleeping = false
	_set_physics_state(false)


func prepare_drop_state(_drop_position: Vector2) -> void:
	pass


func rotate_mirror() -> void:
	_rotation_index = (_rotation_index + 1) % ROTATION_STEP_COUNT
	_apply_rotation()
	_sync_controlled_light_zone_transforms()
	refresh_light_state()


func _set_child_light_zones(enable: bool) -> void:
	for light_zone_data in _controlled_light_zones:
		var light_zone = light_zone_data.get("node")
		if not is_instance_valid(light_zone):
			continue
		var is_on_value = light_zone.get("is_on")
		if typeof(is_on_value) == TYPE_BOOL and is_on_value != enable:
			light_zone.toggle_light()


func _set_physics_state(is_held: bool) -> void:
	freeze = is_held
	if is_held:
		collision_layer = HELD_COLLISION_LAYER
		collision_mask = 0
	else:
		collision_layer = _default_collision_layer
		collision_mask = _default_collision_mask


func _apply_rotation() -> void:
	rotation_degrees = _rotation_index * ROTATION_STEP_DEGREES


func _update_visual_state() -> void:
	if visual_sprite == null:
		return
	visual_sprite.texture = FLASHLIGHT_ON_TEXTURE if is_in_light else FLASHLIGHT_OFF_TEXTURE


func get_held_item_alpha() -> float:
	return 0.55


func get_interaction_prompt_verb() -> String:
	return "absorb"


func can_show_interact_prompt() -> bool:
	return _holder == null


func _get_rotation_index_from_scene() -> int:
	var snapped_steps := int(round(rotation_degrees / ROTATION_STEP_DEGREES))
	return ((snapped_steps % ROTATION_STEP_COUNT) + ROTATION_STEP_COUNT) % ROTATION_STEP_COUNT


func _owns_light_zone(zone: Node) -> bool:
	if zone == null:
		return false
	for light_zone_data in _controlled_light_zones:
		if light_zone_data.get("node") == zone:
			return true
	return false


func get_owned_light_sources() -> Array[Node]:
	var owned_sources: Array[Node] = []
	for light_zone_data in _controlled_light_zones:
		var light_zone: Node = light_zone_data.get("node")
		if is_instance_valid(light_zone):
			owned_sources.append(light_zone)
	return owned_sources


func refresh_light_state() -> void:
	if _light_receiver != null:
		_light_receiver.refresh_light_state()
		active_light_zones = _light_receiver.active_light_zones
		is_in_light = _light_receiver.is_in_light
	_sync_controlled_light_zone_overlaps()


func _on_light_receiver_state_changed(now_in_light: bool) -> void:
	if _light_receiver != null:
		active_light_zones = _light_receiver.active_light_zones
	is_in_light = now_in_light
	_set_child_light_zones(is_in_light)
	_update_visual_state()


func _capture_and_reparent_light_zones() -> void:
	_controlled_light_zones.clear()
	var dark_manager := get_tree().root.find_child("DarkManager", true, false)
	_collect_light_zones(self, dark_manager)


func _collect_light_zones(node: Node, dark_manager: Node) -> void:
	for child in node.get_children():
		if child.has_method("toggle_light"):
			var light_zone := child as Node2D
			if light_zone == null:
				continue
			var relative_transform := (
				global_transform.affine_inverse() * light_zone.global_transform
			)
			if dark_manager != null and light_zone.get_parent() != dark_manager:
				light_zone.reparent(dark_manager, true)
			_controlled_light_zones.append({
				"node": light_zone,
				"relative_transform": relative_transform,
			})
			continue
		_collect_light_zones(child, dark_manager)


func _sync_controlled_light_zone_transforms() -> void:
	for light_zone_data in _controlled_light_zones:
		var light_zone = light_zone_data.get("node") as Node2D
		if not is_instance_valid(light_zone):
			continue
		var relative_transform: Transform2D = light_zone_data.get("relative_transform")
		light_zone.global_transform = global_transform * relative_transform


func _sync_controlled_light_zone_overlaps() -> void:
	for light_zone_data in _controlled_light_zones:
		var light_zone: Node = light_zone_data.get("node")
		if not is_instance_valid(light_zone):
			continue
		if light_zone.has_method("_sync_current_overlaps"):
			light_zone.call("_sync_current_overlaps")
