@tool
extends Polygon2D

## DimmingLightZone — a LightZone whose polygon shrinks toward its centroid
## over dim_duration seconds, then goes dark.
##
## Drop-in replacement for a regular LightZone .tscn (same child structure):
##   DimmingLightZone (Polygon2D)  ← this script
##     Hole        (Polygon2D)
##     TriggerZone (Area2D)
##       Hitbox    (CollisionPolygon2D)
##
## Wiring: the Switch or LightReceiver can call reset_dim() or toggle_light()
## on this node, same as a normal LightZone.

@export_group("Dimming")
@export var is_on: bool = true
@export var dim_duration: float = 8.0   # seconds until fully dark
@export var loop: bool = false          # auto-restart after going dark?

@onready var hole: Polygon2D            = $Hole
@onready var trigger_zone: Area2D       = $TriggerZone
@onready var hitbox: CollisionPolygon2D = $TriggerZone/Hitbox

var _original_polygon: PackedVector2Array
var _centroid: Vector2
var _elapsed: float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_original_polygon = polygon.duplicate()
	_centroid = _compute_centroid(_original_polygon)

	hole.polygon   = polygon
	hitbox.polygon = polygon

	trigger_zone.body_entered.connect(_on_body_entered)
	trigger_zone.body_exited.connect(_on_body_exited)

	if not is_on:
		_apply_instant_off()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Keep children in sync while editing
		if hitbox and hole:
			hitbox.polygon = polygon
			hole.polygon   = polygon
		return

	if not is_on:
		return

	_elapsed += delta
	var t: float = clampf(_elapsed / dim_duration, 0.0, 1.0)
	_update_polygon(t)

	if t >= 1.0:
		_turn_off()
		if loop:
			reset_dim()

# ── Public API (callable by Switch / LightReceiver) ───────────────────────────

## Restart the dimming countdown from the original polygon shape.
func reset_dim() -> void:
	_elapsed = 0.0
	is_on = true
	_update_polygon(0.0)
	if hole:
		hole.visible = true
	if hitbox:
		hitbox.set_deferred("disabled", false)

## Toggle: if on → off immediately; if off → reset and restart.
func toggle_light() -> void:
	if is_on:
		_turn_off()
	else:
		reset_dim()

# ── Internals ─────────────────────────────────────────────────────────────────

func _update_polygon(t: float) -> void:
	var new_poly := PackedVector2Array()
	for v: Vector2 in _original_polygon:
		new_poly.append(lerp(v, _centroid, t))
	polygon       = new_poly
	if hole:
		hole.polygon   = new_poly
	if hitbox:
		hitbox.polygon = new_poly

func _turn_off() -> void:
	is_on = false
	if hole:
		hole.visible = false
	if hitbox:
		hitbox.set_deferred("disabled", true)
	# Notify bodies still inside so they lose their light zone count
	for body in trigger_zone.get_overlapping_bodies():
		if body.has_method("remove_light_zone"):
			body.remove_light_zone()

func _apply_instant_off() -> void:
	is_on = false
	if hole:
		hole.visible = false
	if hitbox:
		hitbox.disabled = true

func _compute_centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	return c / float(pts.size())

# ── LightZone body tracking ───────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_light_zone"):
		body.add_light_zone()

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("remove_light_zone"):
		body.remove_light_zone()
