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

const HELD_ITEM_SCALE_MULTIPLIER: float = 0.7
const HELD_ITEM_ALPHA: float = 0.45
const PLAYER_CARRY_SCALE_MULTIPLIER: float = 1.08
const DROP_FORWARD_OFFSET: float = 36.0
const DROP_UP_OFFSET: float = -10.0
const META_SCALE_KEY := "_pickup_saved_scale"
const META_MODULATE_KEY := "_pickup_saved_modulate"

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
			var item := _nearest_pickupable()
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
	var best_distance := INF
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
		var drop_position := _get_drop_position()
		_apply_held_visual(held_item, false)
		held_item.drop()
		held_item.global_position = drop_position
		if held_item is RigidBody2D:
			held_item.linear_velocity = Vector2.ZERO
			held_item.angular_velocity = 0.0
	held_item = null
	_update_carrier_visual(false)


func _apply_held_visual(item: Node2D, enable: bool) -> void:
	if enable:
		item.set_meta(META_SCALE_KEY, item.scale)
		item.set_meta(META_MODULATE_KEY, item.modulate)
		var held_modulate := item.modulate
		held_modulate.a = HELD_ITEM_ALPHA
		item.scale *= HELD_ITEM_SCALE_MULTIPLIER
		item.modulate = held_modulate
		return

	if item.has_meta(META_SCALE_KEY):
		item.scale = item.get_meta(META_SCALE_KEY)
		item.remove_meta(META_SCALE_KEY)
	if item.has_meta(META_MODULATE_KEY):
		item.modulate = item.get_meta(META_MODULATE_KEY)
		item.remove_meta(META_MODULATE_KEY)


func _update_carrier_visual(is_carrying: bool) -> void:
	if _squash_stretch and _squash_stretch.has_method("set_carry_scale_multiplier"):
		var multiplier := PLAYER_CARRY_SCALE_MULTIPLIER if is_carrying else 1.0
		_squash_stretch.set_carry_scale_multiplier(multiplier)


func _get_drop_position() -> Vector2:
	var facing := 1.0
	if _carrier != null and _carrier.has_method("get_facing_direction"):
		facing = _carrier.get_facing_direction()
	return _carrier.global_position + Vector2(facing * DROP_FORWARD_OFFSET, DROP_UP_OFFSET)
