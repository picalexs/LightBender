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

const INTERACT_PROMPT_SCENE := preload("res://features/interact_prompt/interact_prompt.tscn")
const INTERACTION_WOOSH_STREAM := preload("res://assets/audio/woosh.wav")
const INTERACTION_WOOSH_REVERSE_STREAM := preload("res://assets/audio/woosh_reverse.wav")
const HELD_ITEM_SCALE_MULTIPLIER: float = 0.7
const HELD_ITEM_ALPHA: float = 0.55
const PLAYER_CARRY_SCALE_MULTIPLIER: float = 1.08
const DROP_FORWARD_OFFSET: float = 18.0
const DROP_UP_OFFSET: float = 0.0
const DROP_SEARCH_STEP: float = 10.0
const ITEM_DROP_BLOCKING_MASK: int = 5
const PICKUP_LINE_OF_SIGHT_MASK: int = 1
const META_SCALE_KEY := "_pickup_saved_scale"
const META_MODULATE_KEY := "_pickup_saved_modulate"
const META_Z_INDEX_KEY := "_pickup_saved_z_index"
const HELD_VISUAL_NODE_CANDIDATES := ["VisualSprite", "Sprite2D", "Body"]
const PICKUP_PROMPT_OFFSET := Vector2(0.0, -52.0)

@export_group("Audio")
@export var sfx_emitter_path: NodePath = NodePath("../SfxEmitter")
@export var pickup_sfx_volume_db: float = 0.0
@export var drop_sfx_volume_db: float = 0.0

var held_item: Node2D = null

var _available_pickupables: Array[Node2D] = []
var _carrier: Node = null
var _squash_stretch: Node = null
var _sfx_emitter: Node = null
var _pickup_prompt_layer: CanvasLayer = null
var _pickup_prompt: PanelContainer = null

func _ready() -> void:
	_carrier = get_parent()
	_squash_stretch = _carrier.get_node_or_null("SquashStretch")
	_sfx_emitter = get_node_or_null(sfx_emitter_path)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_pickup_prompt()


func _process(_delta: float) -> void:
	_update_pickup_prompt()


func _exit_tree() -> void:
	if _pickup_prompt_layer != null and is_instance_valid(_pickup_prompt_layer):
		_pickup_prompt_layer.queue_free()
		_pickup_prompt_layer = null
	if _pickup_prompt != null and is_instance_valid(_pickup_prompt):
		_pickup_prompt.queue_free()
		_pickup_prompt = null

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
	_update_pickup_prompt()

func _on_body_exited(body: Node2D) -> void:
	_available_pickupables.erase(body)
	_update_pickup_prompt()

func _nearest_pickupable() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for item in _available_pickupables:
		if not is_instance_valid(item):
			continue
		if not _has_clear_pickup_path(item):
			continue
		var distance_to_item: float = _carrier.global_position.distance_to(item.global_position)
		if distance_to_item < best_distance:
			best_distance = distance_to_item
			best = item
	return best


func _has_clear_pickup_path(item: Node2D) -> bool:
	if item == null or _carrier == null:
		return false

	var world_2d := get_world_2d()
	if world_2d == null:
		return true

	var query := PhysicsRayQueryParameters2D.create(_carrier.global_position, item.global_position, PICKUP_LINE_OF_SIGHT_MASK)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [_carrier.get_rid(), item.get_rid(), get_rid()]

	var hit: Dictionary = world_2d.direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _do_pickup(item: Node2D) -> void:
	held_item = item
	_play_interaction_sfx(INTERACTION_WOOSH_STREAM, pickup_sfx_volume_db)
	item.pickup(_carrier)
	_apply_held_visual(item, true)
	_update_carrier_visual(true)
	_update_pickup_prompt()

func _do_drop() -> void:
	if held_item != null:
		var drop_position: Variant = _find_drop_position(held_item)
		if drop_position == null:
			return
		_play_interaction_sfx(INTERACTION_WOOSH_REVERSE_STREAM, drop_sfx_volume_db)
		_apply_held_visual(held_item, false)
		held_item.drop()
		held_item.global_position = drop_position
		if held_item is RigidBody2D:
			held_item.linear_velocity = Vector2.ZERO
			held_item.angular_velocity = 0.0
		if held_item.has_method("refresh_light_state"):
			held_item.refresh_light_state()
	held_item = null
	_update_carrier_visual(false)
	_update_pickup_prompt()


func _create_pickup_prompt() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_pickup_prompt_layer = CanvasLayer.new()
	_pickup_prompt_layer.layer = 120
	_pickup_prompt = INTERACT_PROMPT_SCENE.instantiate() as PanelContainer
	if _pickup_prompt == null:
		return
	_pickup_prompt.set("auto_bind_to_parent_area", false)
	_pickup_prompt.hide()
	call_deferred("_mount_pickup_prompt")


func _mount_pickup_prompt() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if _pickup_prompt_layer == null or not is_instance_valid(_pickup_prompt_layer):
		return
	if _pickup_prompt == null or not is_instance_valid(_pickup_prompt):
		return

	if _pickup_prompt_layer.get_parent() == null:
		tree.root.add_child(_pickup_prompt_layer)
	if _pickup_prompt.get_parent() == null:
		_pickup_prompt_layer.add_child(_pickup_prompt)


func _update_pickup_prompt() -> void:
	if _pickup_prompt == null or not is_instance_valid(_pickup_prompt):
		return

	if held_item != null and is_instance_valid(held_item):
		_show_pickup_prompt(
			"",
			held_item.global_position,
			"lb_pickup",
			"drop",
			"lb_rotate" if held_item.has_method("rotate_mirror") else "",
			"rotate" if held_item.has_method("rotate_mirror") else ""
		)
		return

	if _pickup_prompt.has_method("hide_manual_prompt"):
		_pickup_prompt.call("hide_manual_prompt")


func _show_pickup_prompt(
	title: String,
	world_position: Vector2,
	primary_action_name: String,
	primary_verb: String,
	secondary_action_name: String = "",
	secondary_verb: String = ""
) -> void:
	if _pickup_prompt == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen_position := viewport.get_canvas_transform() * world_position
	_pickup_prompt.call(
		"show_manual_prompt",
		title,
		primary_action_name,
		primary_verb,
		secondary_action_name,
		secondary_verb
	)
	_pickup_prompt.call("set_screen_anchor_position", screen_position, PICKUP_PROMPT_OFFSET)


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
		Vector2(0.0, DROP_SEARCH_STEP * 0.5),
		Vector2(-forward * DROP_SEARCH_STEP * 0.5, 0.0),
		Vector2(0.0, -DROP_SEARCH_STEP * 0.5),
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
		return false

	return true


func _play_interaction_sfx(stream: AudioStream, volume_db: float) -> void:
	if _sfx_emitter == null or stream == null:
		return
	if _sfx_emitter.has_method("play_stream"):
		_sfx_emitter.play_stream(stream, volume_db)
