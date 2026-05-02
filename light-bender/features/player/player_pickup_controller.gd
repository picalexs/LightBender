extends Area2D

## PlayerPickupController — player mechanic for picking up and dropping carriable items.
## Attach as an Area2D child of the Player.
## collision_layer = 0, collision_mask = 1 to detect pickupable objects on layer 1.
##
## Pickupable items must implement:
##   pickup(carrier: Node) — called when the player picks them up
##   drop()               — called when the player drops them
## Optional:
##   rotate_mirror()      — called on lb_rotate while holding

var held_item: Node = null

var _available_pickupables: Array = []
var _carrier: Node = null

func _ready() -> void:
	_carrier = get_parent()
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
	if held_item == body:
		_do_drop()

func _nearest_pickupable() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for item in _available_pickupables:
		if not is_instance_valid(item):
			continue
		var d: float = _carrier.global_position.distance_to(item.global_position)
		if d < best_dist:
			best_dist = d
			best = item
	return best

func _do_pickup(item: Node) -> void:
	held_item = item
	item.pickup(_carrier)

func _do_drop() -> void:
	if held_item != null:
		held_item.drop()
	held_item = null
