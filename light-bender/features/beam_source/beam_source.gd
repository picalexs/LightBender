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
const MIRROR_BOUNCE_OFFSET: float = 2.0  # prevents self-intersection on mirror surface

@onready var _segments: Array = []  # BeamSegment pool

var _segment_scene: PackedScene = preload("res://features/beam_source/beam_segment.tscn")

func _ready() -> void:
	for i in (max_bounces + 1):
		var seg: Node = _segment_scene.instantiate()
		add_child(seg)
		seg.visible = false
		_segments.append(seg)

func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("light_receivers"):
		if node.has_method("reset_beam"):
			node.reset_beam()

	_trace(global_position,
		   Vector2.from_angle(deg_to_rad(direction_degrees)),
		   0, beam_half_width)

func _trace(origin: Vector2, dir: Vector2, depth: int, half_w: float) -> void:
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

	var seg = _segments[depth]
	seg.set_segment(origin, end_pt, half_w)
	if not seg.visible:
		seg.visible = true

	if hit.is_empty():
		_hide_from(depth + 1)
		return

	var collider: Node = hit["collider"]

	if collider.has_method("get_reflect_direction"):
		var reflected: Vector2 = collider.get_reflect_direction(dir, hit["normal"])
		var output_half_width: float = half_w
		var is_cone: bool = collider.get("is_cone_mirror", false)
		if is_cone:
			output_half_width = half_w * cone_spread_factor
			seg.set_segment(origin, end_pt, half_w, output_half_width)
		_trace(end_pt + reflected * MIRROR_BOUNCE_OFFSET, reflected, depth + 1, output_half_width)
		return

	if collider.has_method("receive_beam"):
		collider.receive_beam()
		_hide_from(depth + 1)
		return

	_hide_from(depth + 1)

func _hide_from(start_depth: int) -> void:
	for i in range(start_depth, _segments.size()):
		if _segments[i].has_method("deactivate"):
			_segments[i].deactivate()
		else:
			_segments[i].visible = false
