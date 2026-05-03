class_name LightReceiver
extends Area2D

signal light_state_changed(is_in_light: bool)

const DEFAULT_LIGHT_RECEIVER_LAYER: int = 2

@export_group("Detection")
@export var auto_refresh: bool = false
@export var sync_parent_properties: bool = true

@export_group("Visual Feedback")
@export var dim_when_dark: bool = true
@export var dark_alpha: float = 0.4

var is_in_light: bool = false:
	set(value):
		if is_in_light == value:
			return
		is_in_light = value
		light_state_changed.emit(is_in_light)
		_sync_parent_light_properties()
		_update_visuals()

var active_light_zones: int = 0

var _active_light_sources: Dictionary = {}
var _anonymous_light_zone_count: int = 0
var _parent: Node2D
var _original_alpha: float = 1.0


func _ready() -> void:
	collision_layer = DEFAULT_LIGHT_RECEIVER_LAYER
	collision_mask = 0
	monitoring = true
	monitorable = true

	_parent = get_parent() as Node2D
	if _parent == null:
		push_warning("LightReceiver Error: Parent must be a Node2D.")
		return

	if dim_when_dark and _parent is CanvasItem:
		_original_alpha = (_parent as CanvasItem).modulate.a

	_update_light_state()
	call_deferred("refresh_light_state")


func _physics_process(_delta: float) -> void:
	if auto_refresh:
		refresh_light_state()


func add_light_zone() -> void:
	_anonymous_light_zone_count += 1
	_update_light_state()


func remove_light_zone() -> void:
	_anonymous_light_zone_count = maxi(_anonymous_light_zone_count - 1, 0)
	_update_light_state()


func add_light_zone_from(source: Node) -> void:
	if source == null:
		add_light_zone()
		return
	if not _is_source_usable(source):
		return
	_active_light_sources[source.get_instance_id()] = source
	_update_light_state()


func remove_light_zone_from(source: Node) -> void:
	if source == null:
		remove_light_zone()
		return
	_active_light_sources.erase(source.get_instance_id())
	_update_light_state()


func can_interact() -> bool:
	return is_in_light


func is_in_light_excluding_zone(excluded_zone: Node) -> bool:
	_prune_light_sources()
	for source in _active_light_sources.values():
		if source != excluded_zone:
			return true
	return _anonymous_light_zone_count > 0


func refresh_light_state() -> void:
	var refreshed_sources: Dictionary = {}
	for source in _find_light_sources():
		if not _is_source_usable(source):
			continue
		if _overlaps_light_source(source):
			refreshed_sources[source.get_instance_id()] = source

	_active_light_sources = refreshed_sources
	_anonymous_light_zone_count = 0
	_update_light_state()


func get_receiver_owner() -> Node2D:
	return _parent


func _update_light_state() -> void:
	_prune_light_sources()
	active_light_zones = _anonymous_light_zone_count + _active_light_sources.size()
	var next_is_in_light := active_light_zones > 0
	if is_in_light == next_is_in_light:
		_sync_parent_light_properties()
		return
	is_in_light = next_is_in_light


func _sync_parent_light_properties() -> void:
	if not sync_parent_properties or _parent == null:
		return
	if "active_light_zones" in _parent:
		_parent.set("active_light_zones", active_light_zones)
	if "is_in_light" in _parent:
		_parent.set("is_in_light", is_in_light)


func _prune_light_sources() -> void:
	for source_id in _active_light_sources.keys():
		var source: Node = _active_light_sources[source_id] as Node
		if not is_instance_valid(source) or not _is_light_active(source):
			_active_light_sources.erase(source_id)


func _find_light_sources() -> Array[Node]:
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root

	var sources: Array[Node] = []
	for candidate in root.find_children("*", "Polygon2D", true, false):
		if candidate is Node and candidate.has_method("get_light_hitbox"):
			sources.append(candidate)
	return sources


func _is_source_usable(source: Node) -> bool:
	if not is_instance_valid(source):
		return false
	if _is_owned_light_source(source):
		return false
	return _is_light_active(source)


func _is_owned_light_source(source: Node) -> bool:
	if _parent == null or not _parent.has_method("get_owned_light_sources"):
		return false

	var owned_sources: Array = _parent.call("get_owned_light_sources")
	for owned_source in owned_sources:
		if owned_source == source:
			return true
	return false


func _is_light_active(source: Node) -> bool:
	if source.has_method("is_light_active"):
		return bool(source.call("is_light_active"))
	if "is_on" in source:
		return source.get("is_on") == true
	return false


func _overlaps_light_source(source: Node) -> bool:
	var hitbox: CollisionPolygon2D = source.call("get_light_hitbox") as CollisionPolygon2D
	if hitbox == null or hitbox.disabled or hitbox.polygon.is_empty():
		return false

	var light_polygon: PackedVector2Array = _to_world_polygon(hitbox, hitbox.polygon)
	var receiver_polygons := _get_receiver_world_polygons()
	for receiver_polygon in receiver_polygons:
		if _polygons_overlap(receiver_polygon, light_polygon):
			return true

	if receiver_polygons.is_empty() and _parent != null:
		return Geometry2D.is_point_in_polygon(_parent.global_position, light_polygon)

	return false


func _get_receiver_world_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	_append_collision_polygons_from(self, polygons)
	if polygons.is_empty() and _parent != null:
		_append_collision_polygons_from(_parent, polygons)
	return polygons


func _append_collision_polygons_from(node: Node, polygons: Array[PackedVector2Array]) -> void:
	for child in node.get_children():
		if child is CollisionPolygon2D:
			var collision_polygon: CollisionPolygon2D = child as CollisionPolygon2D
			if not collision_polygon.disabled and not collision_polygon.polygon.is_empty():
				polygons.append(_to_world_polygon(collision_polygon, collision_polygon.polygon))
			continue

		if child is CollisionShape2D:
			var collision_shape: CollisionShape2D = child as CollisionShape2D
			if collision_shape.disabled or collision_shape.shape == null:
				continue
			var local_polygon := _shape_to_polygon(collision_shape.shape)
			if not local_polygon.is_empty():
				polygons.append(_to_world_polygon(collision_shape, local_polygon))


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
		return _make_circle_polygon(circle.radius, 24)

	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return _make_capsule_polygon(capsule.radius, capsule.height, 12)

	if shape is ConvexPolygonShape2D:
		var convex: ConvexPolygonShape2D = shape as ConvexPolygonShape2D
		return convex.points

	return PackedVector2Array()


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _make_capsule_polygon(radius: float, height: float, points_per_cap: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var half_straight_height := maxf((height * 0.5) - radius, 0.0)

	for i in range(points_per_cap + 1):
		var angle := PI + PI * float(i) / float(points_per_cap)
		points.append(Vector2(0.0, -half_straight_height) + Vector2(cos(angle), sin(angle)) * radius)

	for i in range(points_per_cap + 1):
		var angle := PI * float(i) / float(points_per_cap)
		points.append(Vector2(0.0, half_straight_height) + Vector2(cos(angle), sin(angle)) * radius)

	return points


func _to_world_polygon(node: Node2D, local_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon: PackedVector2Array = PackedVector2Array()
	for point in local_polygon:
		world_polygon.append(node.global_transform * point)
	return world_polygon


func _polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.is_empty() or b.is_empty():
		return false

	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return true

	for point in a:
		if Geometry2D.is_point_in_polygon(point, b):
			return true

	for point in b:
		if Geometry2D.is_point_in_polygon(point, a):
			return true

	return false


func _update_visuals() -> void:
	if not dim_when_dark or _parent == null or not _parent is CanvasItem:
		return

	var target_alpha := _original_alpha if is_in_light else dark_alpha
	var canvas_item := _parent as CanvasItem
	var target_modulate := canvas_item.modulate
	target_modulate.a = target_alpha
	canvas_item.modulate = target_modulate
