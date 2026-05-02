extends StaticBody2D

## MirrorBox — a carriable mirror the player picks up and drops.
##
## Scene setup:
##   MirrorBox (StaticBody2D)  ← this script, collision layer 1
##     CollisionShape2D        ← thin rectangle (e.g. 6 x 48)
##     PickupZone (Area2D)     ← slightly larger, mask 2 (player layer)
##       CollisionShape2D      ← pickup radius (e.g. circle r=36)
##     MirrorLine (Line2D)     ← visual; two points e.g. (-24,0) and (24,0)
##
## Controls:
##   lb_pickup  (F) — pick up / drop
##   lb_rotate  (R) — rotate 45° clockwise while carrying

## Mirror types
enum MirrorType { FLAT, CONE }

@export var mirror_type: MirrorType = MirrorType.FLAT

## How far in front of the player the mirror hovers (pixels)
@export var carry_forward_offset: float = 32.0
## How high above the player centre the mirror hovers (pixels)
@export var carry_up_offset: float = -16.0

@onready var pickup_zone: Area2D = $PickupZone
@onready var mirror_line: Line2D = $MirrorLine  # optional visual

var is_cone_mirror: bool  # read by BeamSource
var _rotation_index: int = 0  # 0-7 → 0°, 45°, 90° … 315°
var _carrier: Node = null
var _player_in_zone: bool = false

func _ready() -> void:
	is_cone_mirror = (mirror_type == MirrorType.CONE)
	pickup_zone.body_entered.connect(_on_pickup_entered)
	pickup_zone.body_exited.connect(_on_pickup_exited)
	_apply_rotation()

func _physics_process(_delta: float) -> void:
	if _carrier == null:
		return
	# Float in front of the player
	var facing: float = 1.0 if _carrier.get("_facing_right") else -1.0
	global_position = _carrier.global_position \
		+ Vector2(facing * carry_forward_offset, carry_up_offset)

func _unhandled_input(event: InputEvent) -> void:
	# Pick up / drop
	if event.is_action_pressed("lb_pickup"):
		if _carrier != null:
			_drop()
		elif _player_in_zone:
			_pick_up()

	# Rotate while carried
	if event.is_action_pressed("lb_rotate") and _carrier != null:
		_rotation_index = (_rotation_index + 1) % 8
		_apply_rotation()

# ── Carry helpers ─────────────────────────────────────────────────────────────

func _pick_up() -> void:
	# Find the player body that is in the pickup zone
	for body in pickup_zone.get_overlapping_bodies():
		if "Player" in body.name:
			# Drop any mirror the player is already holding
			var prev = body.get("held_mirror")
			if prev and prev != self and prev.has_method("_drop"):
				prev._drop()
			_carrier = body
			body.set("held_mirror", self)
			return

func _drop() -> void:
	if _carrier != null:
		_carrier.set("held_mirror", null)
	_carrier = null

# ── Pickup zone tracking ───────────────────────────────────────────────────────

func _on_pickup_entered(body: Node2D) -> void:
	if "Player" in body.name:
		_player_in_zone = true

func _on_pickup_exited(body: Node2D) -> void:
	if "Player" in body.name:
		_player_in_zone = false
		# Auto-drop if player walks too far away
		if _carrier == body:
			_drop()

# ── Mirror surface logic ───────────────────────────────────────────────────────

## Returns the reflected beam direction. Called by BeamSource when a ray hits this body.
func get_reflect_direction(incoming: Vector2, surface_normal: Vector2) -> Vector2:
	# For FLAT mirror: standard geometric reflection
	# For CONE mirror: same reflection direction (spreading is handled by BeamSource)
	return incoming.bounce(surface_normal)

# ── Visual ─────────────────────────────────────────────────────────────────────

func _apply_rotation() -> void:
	rotation_degrees = _rotation_index * 45.0
