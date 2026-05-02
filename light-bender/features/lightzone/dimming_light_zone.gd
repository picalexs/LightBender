@tool
extends Polygon2D

## DimmingLightZone — a polygon-based light zone that can dim or flicker before
## going dark. The polygon defines the LIT area; shrinking it shrinks the light.
##
## DIMMING   — polygon shrinks toward its centroid over dim_duration, then dark.
## FLICKERING — stays lit for light_period, flickers flicker_count times at
##              flicker_speed intervals, then dark for dark_period. Repeats if
##              loop = true.
##
## Child structure (same as LightZone):
##   DimmingLightZone (Polygon2D)  ← this script
##     Hole        (Polygon2D)     ← subtract-blend, no invert_border
##     TriggerZone (Area2D)
##       Hitbox    (CollisionPolygon2D)

enum LightMode {DIMMING, FLICKERING}

@export_group("General")
@export var is_on: bool = true
@export var loop: bool = false
@export var light_mode: LightMode = LightMode.DIMMING

@export_group("Dimming")
@export var dim_duration: float = 8.0
@export var smooth_reverse_loop: bool = true

@export_group("Flickering")
@export var light_period: float = 3.0
@export var dark_period: float = 1.0
@export var flicker_count: int = 2
@export var flicker_speed: float = 0.08

@onready var hole: Polygon2D = $Hole
@onready var trigger_zone: Area2D = $TriggerZone
@onready var hitbox: CollisionPolygon2D = $TriggerZone/Hitbox

var _original_polygon: PackedVector2Array
var _centroid: Vector2

var _elapsed: float = 0.0
var _is_reversing: bool = false

enum FlickerPhase {LIGHT_ON, FLICKERING, DARK}
var _flicker_phase: FlickerPhase = FlickerPhase.LIGHT_ON
var _flicker_elapsed: float = 0.0
var _flicker_toggle_count: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_original_polygon = polygon.duplicate()
	_centroid = _compute_centroid(_original_polygon)

	hole.polygon = polygon
	hitbox.polygon = polygon

	trigger_zone.body_entered.connect(_on_body_entered)
	trigger_zone.body_exited.connect(_on_body_exited)

	if not is_on:
		_apply_instant_off()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if hitbox and hole:
			hitbox.polygon = polygon
			hole.polygon = polygon
		return

	if not is_on:
		return

	match light_mode:
		LightMode.DIMMING:
			_process_dimming(delta)
		LightMode.FLICKERING:
			_process_flickering(delta)

func _process_dimming(delta: float) -> void:
	if _is_reversing:
		_elapsed -= delta
		if _elapsed <= 0.0:
			_elapsed = 0.0
			_is_reversing = false
	else:
		_elapsed += delta

	var t: float = clampf(_elapsed / dim_duration, 0.0, 1.0)
	_update_polygon(t)

	if not _is_reversing and t >= 1.0:
		_turn_off()
		if loop:
			reset_dim()

func _process_flickering(delta: float) -> void:
	match _flicker_phase:
		FlickerPhase.LIGHT_ON:   _tick_flicker_light_on(delta)
		FlickerPhase.FLICKERING: _tick_flicker_flickering(delta)
		FlickerPhase.DARK:       _tick_flicker_dark(delta)

func _tick_flicker_light_on(delta: float) -> void:
	_flicker_elapsed += delta
	if _flicker_elapsed >= light_period:
		_flicker_elapsed = 0.0
		_flicker_toggle_count = 0
		_flicker_phase = FlickerPhase.FLICKERING
		hole.visible = false

func _tick_flicker_flickering(delta: float) -> void:
	_flicker_elapsed += delta
	if _flicker_elapsed >= flicker_speed:
		_flicker_elapsed -= flicker_speed
		_flicker_toggle_count += 1
		if _flicker_toggle_count >= flicker_count * 2:
			_flicker_phase = FlickerPhase.DARK
			_flicker_elapsed = 0.0
			hole.visible = false
			hitbox.set_deferred("disabled", true)
			for body in trigger_zone.get_overlapping_bodies():
				if body.has_method("remove_light_zone"):
					body.remove_light_zone()
			if not loop:
				is_on = false
		else:
			hole.visible = (_flicker_toggle_count % 2 == 1)

func _tick_flicker_dark(delta: float) -> void:
	_flicker_elapsed += delta
	if _flicker_elapsed >= dark_period:
		_flicker_elapsed = 0.0
		_flicker_phase = FlickerPhase.LIGHT_ON
		hole.visible = true
		hitbox.set_deferred("disabled", false)


## Restart from the lit state — works for both DIMMING and FLICKERING.
func reset_dim() -> void:
	if light_mode == LightMode.FLICKERING:
		_flicker_phase = FlickerPhase.LIGHT_ON
		_flicker_elapsed = 0.0
		_flicker_toggle_count = 0
		is_on = true
		if hole:
			hole.visible = true
		if hitbox:
			hitbox.set_deferred("disabled", false)
		return

	if not smooth_reverse_loop:
		_elapsed = 0.0
		_update_polygon(0.0)
	else:
		_is_reversing = true
	is_on = true
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

func _update_polygon(t: float) -> void:
	var new_poly := PackedVector2Array()
	for v: Vector2 in _original_polygon:
		new_poly.append(lerp(v, _centroid, t))
	polygon = new_poly
	if hole:
		hole.polygon = new_poly
	if hitbox:
		hitbox.polygon = new_poly

func _turn_off() -> void:
	is_on = false
	if hole:
		hole.visible = false
	if hitbox:
		hitbox.set_deferred("disabled", true)
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

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_light_zone"):
		body.add_light_zone()

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("remove_light_zone"):
		body.remove_light_zone()
