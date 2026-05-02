extends RigidBody2D

## MirrorBox — a physics-enabled carriable mirror.
##
## Scene setup:
##   MirrorBox (RigidBody2D)  ← this script, collision layer 1, lock_rotation = true
##     CollisionShape2D       ← thin horizontal rectangle (e.g. 48 x 4)
##     Body (Polygon2D)       ← box visual
##     MirrorLine (Line2D)    ← mirror surface visual
##
## Pickup is handled by PlayerPickupController on the player.
## Starts at 45° diagonal. Rotate with lb_rotate (R) while carried.

## Mirror types
enum MirrorType {FLAT, CONE}

@export var mirror_type: MirrorType = MirrorType.FLAT

## How far in front of the player the mirror hovers (pixels)
@export var carry_forward_offset: float = 32.0
## How high above the player centre the mirror hovers (pixels)
@export var carry_up_offset: float = -16.0

@onready var mirror_line: Line2D = $MirrorLine

var is_cone_mirror: bool # read by BeamSource
var _rotation_index: int = 1 # 0-7 → 0°, 45°, 90° … 315°; 1 = 45° diagonal
var _carrier: Node = null

func _ready() -> void:
	is_cone_mirror = (mirror_type == MirrorType.CONE)
	_apply_rotation()

func _physics_process(_delta: float) -> void:
	if _carrier == null:
		return
	# Follow the carrier, floating in front
	var facing: float = 1.0 if _carrier.get("_facing_right") else -1.0
	global_position = _carrier.global_position \
		+ Vector2(facing * carry_forward_offset, carry_up_offset)

# ── Pickup interface — called by PlayerPickupController ────────────────────────

func pickup(carrier: Node) -> void:
	_carrier = carrier
	freeze = true
	collision_layer = 0
	collision_mask = 0

func drop() -> void:
	_carrier = null
	collision_layer = 1
	collision_mask = 1
	freeze = false

# ── Rotation — called by PlayerPickupController on lb_rotate ──────────────────

func rotate_mirror() -> void:
	_rotation_index = (_rotation_index + 1) % 8
	_apply_rotation()

# ── Mirror surface logic ───────────────────────────────────────────────────────

## Returns the reflected beam direction. Called by BeamSource when a ray hits this body.
func get_reflect_direction(incoming: Vector2, surface_normal: Vector2) -> Vector2:
	# For FLAT mirror: standard geometric reflection
	# For CONE mirror: same reflection direction (spreading is handled by BeamSource)
	return incoming.bounce(surface_normal)

# ── Visual ─────────────────────────────────────────────────────────────────────

func _apply_rotation() -> void:
	rotation_degrees = _rotation_index * 45.0
