@tool
extends Polygon2D

## BeamSegment — one straight section of a light beam.
## Replicates LightZone structure: same hole + hitbox pattern so
## the player gains/loses floor collision inside the beam just like
## inside any other LightZone.
##
## Scene structure (mirrors light_zone.tscn exactly):
##   BeamSegment (Polygon2D)  ← this script
##     Hole        (Polygon2D)            — punches hole in dark manager
##     TriggerZone (Area2D)               — detects player enter/exit
##       Hitbox    (CollisionPolygon2D)   — enables floor physics

@onready var hole: Polygon2D = $Hole
@onready var trigger_zone: Area2D = $TriggerZone
@onready var hitbox: CollisionPolygon2D = $TriggerZone/Hitbox

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	trigger_zone.body_entered.connect(_on_body_entered)
	trigger_zone.body_exited.connect(_on_body_exited)

## Called every frame by BeamSource with world-space start/end points.
## start_half_w / end_half_w let you make a cone (trapezoid) shape.
func set_segment(from: Vector2, to: Vector2,
		start_half_w: float, end_half_w: float = -1.0) -> void:
	if end_half_w < 0.0:
		end_half_w = start_half_w

	var dir := (to - from)
	if dir.length_squared() < 1.0:
		return  # zero-length segment, skip

	var perp := dir.normalized().rotated(PI * 0.5)

	# Convert global points to this node's local space
	var lf := to_local(from)
	var lt := to_local(to)
	var lperp := (to_local(from + perp) - lf).normalized()

	var pts := PackedVector2Array([
		lf + lperp * start_half_w,
		lt + lperp * end_half_w,
		lt - lperp * end_half_w,
		lf - lperp * start_half_w,
	])

	polygon = pts
	if hole:
		hole.polygon = pts
	if hitbox:
		hitbox.polygon = pts

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_light_zone"):
		body.add_light_zone()

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("remove_light_zone"):
		body.remove_light_zone()

## When this segment becomes invisible (beam no longer reaches here),
## notify any bodies that were inside so they lose their light zone count.
func deactivate() -> void:
	if not visible:
		return
	visible = false
	for body in trigger_zone.get_overlapping_bodies():
		if body.has_method("remove_light_zone"):
			body.remove_light_zone()
