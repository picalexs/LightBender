## Reusable Trail Effect Script
## Generates ghost afterimages from a target Node2D's sprite while active.
## Generic and works with any Node2D that contains a Sprite2D child.
extends Node2D

# ── Configuration ─────────────────────────────────────────────────────────────
@export_group("Trail Configuration")
@export var target: Node2D
@export var sprite_resource: Sprite2D

@export_group("Spawn & Lifetime")
@export var spawn_interval: float = 0.04
@export var ghost_lifetime: float = 0.3
@export var max_ghosts: int = 20

@export_group("Visual")
@export var ghost_tint: Color = Color.WHITE
@export var ghost_alpha: float = 0.6
@export var scale_fade: bool = true
@export var auto_target_parent: bool = true
@export var z_index_offset: int = -1

# ── Internal state ────────────────────────────────────────────────────────────
var _ghosts: Array = [] # Array of {sprite: Sprite2D, time_alive: float}
var _spawn_timer: float = 0.0
var _is_active: bool = false

# ── Lifecycle ────────────────────────────────────────────────────────────────


func _ready() -> void:
	_sanitize_configuration()

	if target == null and auto_target_parent:
		var parent_node = get_parent()
		if parent_node is Node2D:
			target = parent_node

	_on_target_changed()

	if target == null:
		push_warning("TrailEffect: No target assigned. Script will be inactive.")
	elif not target is Node2D:
		push_error("TrailEffect: Target must be a Node2D. Got: %s" % target.get_class())
		target = null


func _process(delta: float) -> void:
	if _is_active and _is_target_valid() and _is_sprite_valid():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_ghost()
			_spawn_timer = spawn_interval

	# Update existing ghosts: fade and remove dead ones
	for i in range(_ghosts.size() - 1, -1, -1):
		var ghost_data = _ghosts[i]
		if ghost_data["sprite"] == null or not is_instance_valid(ghost_data["sprite"]):
			_ghosts.remove_at(i)
			continue

		ghost_data["time_alive"] += delta

		if ghost_data["time_alive"] >= ghost_lifetime:
			_remove_ghost(i)
		else:
			_update_ghost_fade(ghost_data)


func _exit_tree() -> void:
	_clear_all_ghosts()

# ── Control API ────────────────────────────────────────────────────────────


func start() -> void:
	_sanitize_configuration()

	if target == null:
		push_warning("TrailEffect.start(): No target assigned.")
		return
	if sprite_resource == null:
		_discover_sprite()
		if sprite_resource == null:
			push_error("TrailEffect.start(): Could not find Sprite2D on target.")
			return

	_is_active = true
	_spawn_timer = 0.0


func stop(clear_existing: bool = false) -> void:
	_is_active = false
	if clear_existing:
		_clear_all_ghosts()


func is_active() -> bool:
	return _is_active


func get_ghost_count() -> int:
	return _ghosts.size()


func clear_ghosts() -> void:
	_clear_all_ghosts()


func get_ghosts_for_testing() -> Array:
	return _ghosts

# ── Ghost Management ───────────────────────────────────────────────────────────


func _spawn_ghost() -> void:
	if not _is_sprite_valid():
		return

	# Limit concurrent ghosts
	if _ghosts.size() >= max_ghosts:
		_remove_ghost(0)

	var ghost_sprite = _create_ghost_sprite()
	if ghost_sprite != null:
		_ghosts.append(
			{
				"sprite": ghost_sprite,
				"time_alive": 0.0,
				"base_scale": ghost_sprite.scale,
			},
		)


func _create_ghost_sprite() -> Sprite2D:
	if not _is_sprite_valid():
		return null

	var ghost = Sprite2D.new()
	ghost.texture = sprite_resource.texture
	if ghost.texture == null:
		ghost.queue_free()
		return null

	ghost.top_level = true
	ghost.z_as_relative = false
	ghost.z_index = _get_effective_z_index(sprite_resource) + z_index_offset
	ghost.self_modulate = ghost_tint
	ghost.self_modulate.a = ghost_alpha
	ghost.global_position = sprite_resource.global_position
	ghost.global_rotation = sprite_resource.global_rotation
	ghost.scale = sprite_resource.scale
	ghost.offset = sprite_resource.offset
	ghost.flip_h = sprite_resource.flip_h
	ghost.flip_v = sprite_resource.flip_v

	# Frame support for animated/sprite sheet textures
	if sprite_resource.vframes > 0 and sprite_resource.hframes > 0:
		ghost.vframes = sprite_resource.vframes
		ghost.hframes = sprite_resource.hframes
		ghost.frame = sprite_resource.frame
		ghost.frame_coords = sprite_resource.frame_coords

	add_child(ghost)

	return ghost


func _update_ghost_fade(ghost_data: Dictionary) -> void:
	if ghost_data["sprite"] == null or not is_instance_valid(ghost_data["sprite"]):
		return

	var progress = ghost_data["time_alive"] / ghost_lifetime
	var alpha = ghost_alpha * (1.0 - progress)

	var ghost = ghost_data["sprite"]
	var mod = ghost.self_modulate
	mod.a = alpha
	ghost.self_modulate = mod

	if scale_fade:
		var base_scale = ghost_data.get("base_scale", ghost.scale)
		ghost.scale = base_scale * (1.0 - progress * 0.5)


func _remove_ghost(index: int) -> void:
	if index >= 0 and index < _ghosts.size():
		var ghost_data = _ghosts[index]
		if ghost_data["sprite"] != null and is_instance_valid(ghost_data["sprite"]):
			ghost_data["sprite"].queue_free()
		_ghosts.remove_at(index)


func _clear_all_ghosts() -> void:
	for ghost_data in _ghosts:
		if ghost_data["sprite"] != null and is_instance_valid(ghost_data["sprite"]):
			ghost_data["sprite"].queue_free()
	_ghosts.clear()

# ── Target & Sprite Discovery ──────────────────────────────────────────────────


func _on_target_changed() -> void:
	_clear_all_ghosts()
	if target != null and not target is Node2D:
		push_error("TrailEffect: Target must be a Node2D. Got: %s" % target.get_class())
		target = null
		return

	_discover_sprite()


func _sanitize_configuration() -> void:
	spawn_interval = max(0.01, spawn_interval)
	ghost_lifetime = max(0.01, ghost_lifetime)
	max_ghosts = max(1, max_ghosts)
	ghost_alpha = clamp(ghost_alpha, 0.0, 1.0)


func _discover_sprite() -> void:
	if not _is_target_valid():
		sprite_resource = null
		return

	# Look for first Sprite2D child on target
	for child in target.get_children():
		if child is Sprite2D:
			sprite_resource = child
			return

	# No sprite found
	sprite_resource = null
	var warning_message = "TrailEffect: Could not auto-discover Sprite2D on target '%s'. Assign sprite_resource manually or add a Sprite2D child." % target.name
	push_warning(warning_message)

# ── Validity Helpers ──────────────────────────────────────────────────────────


func _is_target_valid() -> bool:
	return target != null and is_instance_valid(target)


func _is_sprite_valid() -> bool:
	return sprite_resource != null and is_instance_valid(sprite_resource)


func _get_effective_z_index(canvas_item: CanvasItem) -> int:
	var z_total = canvas_item.z_index
	if not canvas_item.z_as_relative:
		return z_total

	var parent = canvas_item.get_parent()
	while parent is CanvasItem:
		var parent_item = parent as CanvasItem
		z_total += parent_item.z_index
		if not parent_item.z_as_relative:
			break
		parent = parent_item.get_parent()

	return z_total
