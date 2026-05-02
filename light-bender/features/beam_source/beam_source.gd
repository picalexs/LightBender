extends Node2D

## BeamSource — emits a directional beam of light that bounces off mirrors.
##
## Place this node INSIDE the DarkManager CanvasGroup in the scene tree so
## BeamSegment polygons punch holes in the darkness correctly.
##
## Collision notes:
##   The beam raycast uses layer mask 1 (world/walls).
##   Mirrors and LightReceiver nodes must also be on collision layer 1.
##   The player is on layer 2, so the ray ignores them automatically.
##
## How to use:
##   1. Add BeamSource as child of DarkManager.
##   2. Set direction_degrees (0 = right, 90 = down, 180 = left, 270 = up).
##   3. The beam will bounce off any node that has get_reflect_direction().
##   4. The beam will power any node that has receive_beam().

@export_group("Beam")
@export var direction_degrees: float = 0.0
@export var beam_half_width: float = 12.0
@export var max_beam_length: float = 2000.0
@export var max_bounces: int = 4

@export_group("Cone Mirror Output")
## When the beam exits a cone mirror the far end widens by this factor.
@export var cone_spread_factor: float = 3.0

const BEAM_COLLISION_MASK: int = 1  # layer 1 = world + mirrors + receivers

@onready var _segments: Array = []  # BeamSegment pool

var _seg_scene: PackedScene = preload("res://features/beam_source/beam_segment.tscn")

func _ready() -> void:
	# Pre-allocate one segment per possible bounce + origin
	for i in (max_bounces + 1):
		var seg: Node = _seg_scene.instantiate()
		add_child(seg)
		seg.visible = false
		_segments.append(seg)

func _physics_process(_delta: float) -> void:
	# Reset all receivers before tracing
	for node in get_tree().get_nodes_in_group("light_receivers"):
		if node.has_method("reset_beam"):
			node.reset_beam()

	_trace(global_position,
		   Vector2.from_angle(deg_to_rad(direction_degrees)),
		   0, beam_half_width)

func _trace(origin: Vector2, dir: Vector2, depth: int, half_w: float) -> void:
	# Hide all remaining segments if we've reached max depth
	if depth > max_bounces:
		_hide_from(depth)
		return

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		origin,
		origin + dir * max_beam_length,
		BEAM_COLLISION_MASK
	)
	query.collide_with_areas = false  # only StaticBody2D / CharacterBody2D

	var hit := space.intersect_ray(query)
	var end_pt: Vector2 = origin + dir * max_beam_length if hit.is_empty() \
						  else hit["position"]

	# Shape this segment
	var seg = _segments[depth]
	seg.set_segment(origin, end_pt, half_w)
	if not seg.visible:
		seg.visible = true

	if hit.is_empty():
		_hide_from(depth + 1)
		return

	var collider: Node = hit["collider"]

	# --- Mirror ---
	if collider.has_method("get_reflect_direction"):
		var reflected: Vector2 = collider.get_reflect_direction(dir, hit["normal"])
		var out_hw: float = half_w
		var is_cone: bool = collider.get("is_cone_mirror") == true
		if is_cone:
			# Cone mirror: widen the outgoing beam, reshape this segment as trapezoid
			out_hw = half_w * cone_spread_factor
			seg.set_segment(origin, end_pt, half_w, out_hw)
		# Small offset so the next ray doesn't self-intersect with the mirror surface
		_trace(end_pt + reflected * 2.0, reflected, depth + 1, out_hw)
		return

	# --- Light Receiver ---
	if collider.has_method("receive_beam"):
		collider.receive_beam()
		_hide_from(depth + 1)
		return

	# --- Wall / floor: beam stops here ---
	_hide_from(depth + 1)

func _hide_from(start_depth: int) -> void:
	for i in range(start_depth, _segments.size()):
		if _segments[i].has_method("deactivate"):
			_segments[i].deactivate()
		else:
			_segments[i].visible = false
