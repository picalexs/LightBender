extends RigidBody2D

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

@export_group("Behaviour")
@export var trigger_on_change: bool = true

@onready var powered_indicator: Node2D = get_node_or_null("PoweredIndicator")
@onready var visual_sprite: Sprite2D = get_node_or_null("VisualSprite")

var active_light_zones: int = 0
var is_in_light: bool = false

var _holder: Node2D = null
var _default_collision_layer: int = 0
var _default_collision_mask: int = 0
var _was_active: bool = false
var _drop_light_grace_frames: int = 0
var _drop_light_state: bool = false
var _active_light_sources: Dictionary = {}


func _ready() -> void:
	collision_layer = ITEM_COLLISION_LAYER
	collision_mask = 1
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 12.0
	angular_damp = 12.0
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_update_indicator()
	_update_visual_state()


func _physics_process(_delta: float) -> void:
	if _holder != null:
		global_position = _holder.global_position

	is_in_light = _get_current_light_state()

	if trigger_on_change:
		if is_in_light != _was_active:
			_fire_target(is_in_light)
	else:
		_fire_target(is_in_light)

	_was_active = is_in_light
	_update_indicator()
	_update_visual_state()


func add_light_zone() -> void:
	active_light_zones += 1


func remove_light_zone() -> void:
	active_light_zones = maxi(active_light_zones - 1, 0)


func add_light_zone_from(zone: Node) -> void:
	if zone == null:
		return
	_active_light_sources[zone.get_instance_id()] = true
	active_light_zones = _active_light_sources.size()


func remove_light_zone_from(zone: Node) -> void:
	if zone == null:
		return
	_active_light_sources.erase(zone.get_instance_id())
	active_light_zones = _active_light_sources.size()


func pickup(carrier: Node) -> void:
	_holder = carrier as Node2D
	active_light_zones = 0
	_active_light_sources.clear()
	_drop_light_grace_frames = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
	_set_physics_state(true)


func drop() -> void:
	_holder = null
	active_light_zones = 0
	_active_light_sources.clear()
	sleeping = false
	_set_physics_state(false)


func prepare_drop_state(drop_position: Vector2) -> void:
	_drop_light_state = _is_shape_in_external_light(drop_position)
	_drop_light_grace_frames = 2


func get_held_item_alpha() -> float:
	return 0.55


func _fire_target(is_active: bool) -> void:
	if target_node == null:
		return

	var method_name: String = method_when_active if is_active else method_when_inactive
	var parameter: String = param_when_active if is_active else param_when_inactive
	if method_name == "":
		method_name = method_when_active
		parameter = param_when_active
	NodeDispatch.call_method(target_node, method_name, parameter, "ButtonBox")


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


func _is_holder_in_light() -> bool:
	return _holder != null and _holder.get("is_in_light") == true


func _get_current_light_state() -> bool:
	if _holder != null:
		return _is_holder_in_light()
	if active_light_zones <= 0 and _drop_light_grace_frames > 0:
		_drop_light_grace_frames -= 1
		return _drop_light_state
	if active_light_zones > 0:
		return true
	return _is_shape_in_external_light(global_position)


func _is_point_in_external_light(world_position: Vector2) -> bool:
	var dark_manager: Node = get_tree().root.find_child("DarkManager", true, false)
	if dark_manager == null:
		return false
	for candidate in dark_manager.find_children("*", "Polygon2D", true, false):
		if not candidate.has_method("toggle_light"):
			continue
		if candidate.get("is_on") != true:
			continue
		var hitbox: CollisionPolygon2D = candidate.get_node_or_null("TriggerZone/Hitbox") as CollisionPolygon2D
		if hitbox == null:
			continue
		if Geometry2D.is_point_in_polygon(hitbox.to_local(world_position), hitbox.polygon):
			return true
	return false


func _is_shape_in_external_light(world_position: Vector2) -> bool:
	var item_polygon: PackedVector2Array = _get_world_collision_polygon(world_position)
	if item_polygon.is_empty():
		return _is_point_in_external_light(world_position)

	var dark_manager: Node = get_tree().root.find_child("DarkManager", true, false)
	if dark_manager == null:
		return false

	for candidate in dark_manager.find_children("*", "Polygon2D", true, false):
		if not candidate.has_method("toggle_light"):
			continue
		if candidate.get("is_on") != true:
			continue

		var hitbox: CollisionPolygon2D = candidate.get_node_or_null("TriggerZone/Hitbox") as CollisionPolygon2D
		if hitbox == null or hitbox.polygon.is_empty():
			continue

		var light_polygon: PackedVector2Array = _to_world_polygon(hitbox, hitbox.polygon)
		if not Geometry2D.intersect_polygons(item_polygon, light_polygon).is_empty():
			return true
		for point in item_polygon:
			if Geometry2D.is_point_in_polygon(point, light_polygon):
				return true

	return false


func _get_world_collision_polygon(world_position: Vector2) -> PackedVector2Array:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return PackedVector2Array()

	var shape_polygon: PackedVector2Array = _shape_to_polygon(collision_shape.shape)
	if shape_polygon.is_empty():
		return PackedVector2Array()

	var world_transform: Transform2D = Transform2D(global_rotation, world_position) * collision_shape.transform
	return _transform_polygon(world_transform, shape_polygon)


func _shape_to_polygon(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape as RectangleShape2D
		var half_size: Vector2 = rectangle.size * 0.5
		return PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])

	if shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		var points: PackedVector2Array = PackedVector2Array()
		var point_count: int = 16
		for i in range(point_count):
			var angle: float = TAU * float(i) / float(point_count)
			points.append(Vector2.RIGHT.rotated(angle) * circle.radius)
		return points

	return PackedVector2Array()


func _to_world_polygon(node: Node2D, local_polygon: PackedVector2Array) -> PackedVector2Array:
	return _transform_polygon(node.global_transform, local_polygon)


func _transform_polygon(transform: Transform2D, local_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon: PackedVector2Array = PackedVector2Array()
	for point in local_polygon:
		world_polygon.append(transform * point)
	return world_polygon
