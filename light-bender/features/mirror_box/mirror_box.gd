extends RigidBody2D

enum MirrorType {FLAT, CONE}

@export var mirror_type: MirrorType = MirrorType.FLAT
@export var carry_forward_offset: float = 32.0
@export var carry_up_offset: float = -16.0

@onready var mirror_line: Line2D = $MirrorLine

var is_cone_mirror: bool
var _rotation_index: int = 1
var _holder: Node = null

func _ready() -> void:
	is_cone_mirror = (mirror_type == MirrorType.CONE)
	_apply_rotation()

func _physics_process(_delta: float) -> void:
	if _holder == null:
		return
	var facing: float = 1.0 if _holder.get("_facing_right") else -1.0
	global_position = _holder.global_position \
		+ Vector2(facing * carry_forward_offset, carry_up_offset)

func pickup(carrier: Node) -> void:
	_holder = carrier
	_set_physics_state(true)

func drop() -> void:
	_holder = null
	_set_physics_state(false)

func _set_physics_state(frozen: bool) -> void:
	freeze = frozen
	collision_layer = 0 if frozen else 1
	collision_mask = 0 if frozen else 1

func rotate_mirror() -> void:
	_rotation_index = (_rotation_index + 1) % 8
	_apply_rotation()

## Returns the reflected beam direction. Called by BeamSource when a ray hits this body.
func get_reflect_direction(incoming: Vector2, surface_normal: Vector2) -> Vector2:
	return incoming.bounce(surface_normal)

func _apply_rotation() -> void:
	rotation_degrees = _rotation_index * 45.0
