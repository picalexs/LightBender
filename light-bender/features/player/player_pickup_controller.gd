extends Area2D

## PlayerPickupController - player mechanic for picking up and dropping carriable items.
## Attach as an Area2D child of the Player.
## collision_layer = 0, collision_mask = 1 to detect pickupable objects on layer 1.
##
## Pickupable items must implement:
##   pickup(carrier: Node) - called when the player picks them up
##   drop() - called when the player drops them
## Optional:
##   rotate_mirror() - called on lb_rotate while holding
##   get_held_item_alpha() -> float - override held transparency
##   get_held_visual_target() -> CanvasItem - override which visual gets carry styling

const HELD_ITEM_SCALE_MULTIPLIER: float = 0.7
const HELD_ITEM_ALPHA: float = 0.55
const PLAYER_CARRY_SCALE_MULTIPLIER: float = 1.08
const DROP_FORWARD_OFFSET: float = 36.0
const DROP_UP_OFFSET: float = -10.0
const DROP_SEARCH_STEP: float = 18.0
const ITEM_DROP_BLOCKING_MASK: int = 4
const META_SCALE_KEY := "_pickup_saved_scale"
const META_MODULATE_KEY := "_pickup_saved_modulate"
const META_Z_INDEX_KEY := "_pickup_saved_z_index"
const HELD_VISUAL_NODE_CANDIDATES := ["VisualSprite", "Sprite2D", "Body"]

var held_item: Node2D = null

var _available_pickupables: Array[Node2D] = []
var _carrier: Node = null
var _squash_stretch: Node = null

func _ready() -> void:
	_carrier = get_parent()
	_squash_stretch = _carrier.get_node_or_null("SquashStretch")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lb_pickup"):
		if held_item != null:
			_do_drop()
		else:
			var item: Node2D = _nearest_pickupable()
			if item != null:
				_do_pickup(item)

	if event.is_action_pressed("lb_rotate") and held_item != null:
		if held_item.has_method("rotate_mirror"):
			held_item.rotate_mirror()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("pickup") and not _available_pickupables.has(body):
		_available_pickupables.append(body)

func _on_body_exited(body: Node2D) -> void:
	_available_pickupables.erase(body)

func _nearest_pickupable() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for item in _available_pickupables:
		if not is_instance_valid(item):
			continue
		var distance_to_item: float = _carrier.global_position.distance_to(item.global_position)
		if distance_to_item < best_distance:
			best_distance = distance_to_item
			best = item
	return best

func _do_pickup(item: Node2D) -> void:
	held_item = item
	item.pickup(_carrier)
	_apply_held_visual(item, true)
	_update_carrier_visual(true)

func _do_drop() -> void:
	if held_item != null:
		var drop_position: Variant = _find_drop_position(held_item)
		if drop_position == null:
			return
		if held_item.has_method("prepare_drop_state"):
			held_item.prepare_drop_state(drop_position)
		_apply_held_visual(held_item, false)
		held_item.drop()
		held_item.global_position = drop_position
		if held_item is RigidBody2D:
			held_item.linear_velocity = Vector2.ZERO
			held_item.angular_velocity = 0.0
	held_item = null
	_update_carrier_visual(false)


func _apply_held_visual(item: Node2D, enable: bool) -> void:
	var visual_target: CanvasItem = _get_held_visual_target(item)
	if visual_target == null:
		return

	if enable:
		_store_held_layer_state(item)
		_store_held_visual_state(visual_target)
		var held_modulate: Color = visual_target.modulate
		held_modulate.a = _get_held_item_alpha(item)
		if visual_target is Node2D:
			visual_target.scale *= HELD_ITEM_SCALE_MULTIPLIER
		visual_target.modulate = held_modulate
		return

	_restore_held_layer_state(item)
	_restore_held_visual_state(visual_target)


func _get_held_item_alpha(item: Node2D) -> float:
	if item != null and item.has_method("get_held_item_alpha"):
		var alpha_value = item.get_held_item_alpha()
		if typeof(alpha_value) == TYPE_FLOAT or typeof(alpha_value) == TYPE_INT:
			return clampf(float(alpha_value), 0.0, 1.0)
	return HELD_ITEM_ALPHA


func _get_held_visual_target(item: Node2D) -> CanvasItem:
	if item == null:
		return null
	if item.has_method("get_held_visual_target"):
		var custom_target: Variant = item.get_held_visual_target()
		if custom_target is CanvasItem:
			return custom_target
	for node_name in HELD_VISUAL_NODE_CANDIDATES:
		var candidate: Node = item.get_node_or_null(node_name)
		if candidate is CanvasItem:
			return candidate
	return item


func _store_held_visual_state(target: CanvasItem) -> void:
	if target is Node2D:
		target.set_meta(META_SCALE_KEY, target.scale)
	target.set_meta(META_MODULATE_KEY, target.modulate)


func _restore_held_visual_state(target: CanvasItem) -> void:
	if target is Node2D and target.has_meta(META_SCALE_KEY):
		target.scale = target.get_meta(META_SCALE_KEY)
		target.remove_meta(META_SCALE_KEY)
	if target.has_meta(META_MODULATE_KEY):
		target.modulate = target.get_meta(META_MODULATE_KEY)
		target.remove_meta(META_MODULATE_KEY)


func _store_held_layer_state(item: Node2D) -> void:
	if item == null:
		return
	item.set_meta(META_Z_INDEX_KEY, item.z_index)
	if _carrier is CanvasItem:
		item.z_index = (_carrier as CanvasItem).z_index + 1


func _restore_held_layer_state(item: Node2D) -> void:
	if item != null and item.has_meta(META_Z_INDEX_KEY):
		item.z_index = item.get_meta(META_Z_INDEX_KEY)
		item.remove_meta(META_Z_INDEX_KEY)


func _update_carrier_visual(is_carrying: bool) -> void:
	if _squash_stretch and _squash_stretch.has_method("set_carry_scale_multiplier"):
		var multiplier: float = PLAYER_CARRY_SCALE_MULTIPLIER if is_carrying else 1.0
		_squash_stretch.set_carry_scale_multiplier(multiplier)


func _get_drop_position() -> Vector2:
	var facing: float = 1.0
	if _carrier != null and _carrier.has_method("get_facing_direction"):
		facing = _carrier.get_facing_direction()
	return _carrier.global_position + Vector2(facing * DROP_FORWARD_OFFSET, DROP_UP_OFFSET)


func _find_drop_position(item: Node2D) -> Variant:
	var base_position: Vector2 = _get_drop_position()
	var facing: float = 1.0
	if _carrier != null and _carrier.has_method("get_facing_direction"):
		facing = _carrier.get_facing_direction()

	for offset in _get_drop_search_offsets(facing):
		var candidate: Vector2 = base_position + offset
		if _can_place_item_at(item, candidate):
			return candidate

	return null


func _get_drop_search_offsets(facing: float) -> Array[Vector2]:
	var forward: float = signf(facing)
	if is_zero_approx(forward):
		forward = 1.0
	return [
		Vector2.ZERO,
		Vector2(forward * DROP_SEARCH_STEP, 0.0),
		Vector2(forward * DROP_SEARCH_STEP * 2.0, 0.0),
		Vector2(forward * DROP_SEARCH_STEP, -DROP_SEARCH_STEP * 0.5),
		Vector2(forward * DROP_SEARCH_STEP, DROP_SEARCH_STEP * 0.5),
		Vector2(0.0, -DROP_SEARCH_STEP),
		Vector2(0.0, DROP_SEARCH_STEP),
	]


func _can_place_item_at(item: Node2D, position: Vector2) -> bool:
	var collision_shape: CollisionShape2D = item.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return true

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(item.global_rotation, position) * collision_shape.transform
	query.collision_mask = ITEM_DROP_BLOCKING_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var space_state: PhysicsDirectSpaceState2D = item.get_world_2d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(query, 8)
	for result in results:
		var collider: Variant = result.get("collider")
		if collider == null or collider == item:
			continue
		if collider is Node and (collider as Node).has_method("pickup"):
			return false

	return true
