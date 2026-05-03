@tool
extends Polygon2D

const LIGHT_AFFECTED_MASK: int = 6

enum LightMode {DIMMING, FLICKERING}

@export_group("General")
@export var is_on: bool = true
@export var loop: bool = false
@export var light_mode: LightMode = LightMode.DIMMING

@export_group("Dimming")
@export var dim_duration: float = 8.0
@export var smooth_reverse_loop: bool = true

@export_group("Penumbra")
@export var penumbra_size: float = 50.0
@export var safe_zone_extra: float = 30.0

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

var _penumbra_rings: Array[Polygon2D] = []
var _penumbra_expands: Array[float] = []

var _elapsed: float = 0.0
var _is_reversing: bool = false

enum FlickerPhase {LIGHT_ON, FLICKERING, DARK}
var _flicker_phase: FlickerPhase = FlickerPhase.LIGHT_ON
var _flicker_elapsed: float = 0.0
var _flicker_toggle_count: int = 0


func _get_hitbox_polygon() -> PackedVector2Array:
	if safe_zone_extra <= 0.0:
		return polygon
	return _offset_polygon(polygon, safe_zone_extra)

func _update_editor_penumbra() -> void:
	for ring in _penumbra_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_penumbra_rings.clear()
	if penumbra_size > 0.0:
		_build_penumbra()

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_original_polygon = polygon.duplicate()
	_centroid = _compute_centroid(_original_polygon)

	hole.polygon = polygon
	_build_penumbra()
	hitbox.polygon = _get_hitbox_polygon()
	trigger_zone.collision_mask = LIGHT_AFFECTED_MASK

	trigger_zone.body_entered.connect(_on_body_entered)
	trigger_zone.body_exited.connect(_on_body_exited)
	trigger_zone.area_entered.connect(_on_area_entered)
	trigger_zone.area_exited.connect(_on_area_exited)

	if not is_on:
		_apply_instant_off()
	else:
		_sync_current_overlaps()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if hitbox and hole:
			hole.polygon = polygon
			hitbox.polygon = _get_hitbox_polygon()
		_update_editor_penumbra()
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
		FlickerPhase.LIGHT_ON: _tick_flicker_light_on(delta)
		FlickerPhase.FLICKERING: _tick_flicker_flickering(delta)
		FlickerPhase.DARK: _tick_flicker_dark(delta)

func _tick_flicker_light_on(delta: float) -> void:
	_flicker_elapsed += delta
	if _flicker_elapsed >= light_period:
		_flicker_elapsed = 0.0
		_flicker_toggle_count = 0
		_flicker_phase = FlickerPhase.FLICKERING
		_set_light_visible(false)

func _tick_flicker_flickering(delta: float) -> void:
	_flicker_elapsed += delta
	if _flicker_elapsed >= flicker_speed:
		_flicker_elapsed -= flicker_speed
		_flicker_toggle_count += 1
		if _flicker_toggle_count >= flicker_count * 2:
			_flicker_phase = FlickerPhase.DARK
			_flicker_elapsed = 0.0
			_set_light_visible(false)
			hitbox.set_deferred("disabled", true)
			_sync_current_overlaps(false)
			if not loop:
				is_on = false
		else:
			_set_light_visible(_flicker_toggle_count % 2 == 1)

func _tick_flicker_dark(delta: float) -> void:
	_flicker_elapsed += delta
	if _flicker_elapsed >= dark_period:
		_flicker_elapsed = 0.0
		_flicker_phase = FlickerPhase.LIGHT_ON
		_set_light_visible(true)
		hitbox.set_deferred("disabled", false)


func reset_dim() -> void:
	if light_mode == LightMode.FLICKERING:
		_flicker_phase = FlickerPhase.LIGHT_ON
		_flicker_elapsed = 0.0
		_flicker_toggle_count = 0
		is_on = true
		_set_light_visible(true)
		if hitbox:
			hitbox.set_deferred("disabled", false)
		_sync_current_overlaps(true)
		return

	if not smooth_reverse_loop:
		_elapsed = 0.0
		_update_polygon(0.0)
	else:
		_is_reversing = true
	is_on = true
	_set_light_visible(true)
	if hitbox:
		hitbox.set_deferred("disabled", false)
	_sync_current_overlaps(true)

func toggle_light() -> void:
	if is_on:
		_turn_off()
	else:
		reset_dim()

func set_light_enabled(enable: bool) -> void:
	if enable:
		reset_dim()
	else:
		_turn_off()

func is_light_active() -> bool:
	return is_on and hitbox != null and not hitbox.disabled

func get_light_hitbox() -> CollisionPolygon2D:
	return hitbox

func _update_polygon(t: float) -> void:
	var new_poly := PackedVector2Array()
	for v: Vector2 in _original_polygon:
		new_poly.append(lerp(v, _centroid, t))
	polygon = new_poly
	if hole:
		hole.polygon = new_poly
	if hitbox:
		hitbox.polygon = _get_hitbox_polygon()
	for j in range(_penumbra_rings.size()):
		_penumbra_rings[j].polygon = _offset_polygon(new_poly, _penumbra_expands[j])

func _turn_off() -> void:
	is_on = false
	_set_light_visible(false)
	if hitbox:
		hitbox.set_deferred("disabled", true)
	_sync_current_overlaps(false)

func _apply_instant_off() -> void:
	is_on = false
	_set_light_visible(false)
	if hitbox:
		hitbox.disabled = true

func _build_penumbra() -> void:
	if penumbra_size <= 0.0:
		return
	var steps := 8
	for i in range(steps, 0, -1):
		var expand := penumbra_size * float(i) / float(steps)
		var a := float(steps - i + 1) / float(steps)
		var ring := Polygon2D.new()
		ring.polygon = _offset_polygon(hole.polygon, expand)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		ring.material = mat
		ring.color = Color(1.0, 1.0, 1.0, a)
		add_child(ring)
		move_child(ring, hole.get_index())
		_penumbra_rings.append(ring)
		_penumbra_expands.append(expand)

func _offset_polygon(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var n := poly.size()
	var result := PackedVector2Array()
	for i in range(n):
		var prev := poly[(i - 1 + n) % n]
		var curr := poly[i]
		var next := poly[(i + 1) % n]
		var e1 := (curr - prev).normalized()
		var e2 := (next - curr).normalized()
		var n1 := Vector2(-e1.y, e1.x)
		var n2 := Vector2(-e2.y, e2.x)
		var bisector := (n1 + n2).normalized()
		var dot := n1.dot(bisector)
		var miter_scale: float = 1.0 / max(dot, 0.1)
		result.append(curr + bisector * amount * miter_scale)
	return result

func _set_light_visible(v: bool) -> void:
	if hole:
		hole.visible = v
	for ring in _penumbra_rings:
		ring.visible = v

func _compute_centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	return c / float(pts.size())

func _on_body_entered(body: Node2D) -> void:
	if not is_light_active():
		return
	_apply_light_to_target(body)

func _on_body_exited(body: Node2D) -> void:
	_remove_light_from_target(body)


func _on_area_entered(area: Area2D) -> void:
	if not is_light_active():
		return
	_apply_light_to_target(area)


func _on_area_exited(area: Area2D) -> void:
	_remove_light_from_target(area)


func _sync_current_overlaps(force_active: Variant = null) -> void:
	if trigger_zone == null:
		return

	var should_apply := is_light_active() if force_active == null else bool(force_active)
	for body in trigger_zone.get_overlapping_bodies():
		if should_apply:
			_apply_light_to_target(body)
		else:
			_remove_light_from_target(body)
	for area in trigger_zone.get_overlapping_areas():
		if should_apply:
			_apply_light_to_target(area)
		else:
			_remove_light_from_target(area)


func _apply_light_to_target(target: Node) -> void:
	if _target_has_light_receiver(target):
		if target is LightReceiver:
			target.add_light_zone_from(self)
		return

	if target.has_method("add_light_zone_from"):
		target.add_light_zone_from(self)
	elif target.has_method("add_light_zone"):
		target.add_light_zone()


func _remove_light_from_target(target: Node) -> void:
	if _target_has_light_receiver(target):
		if target is LightReceiver:
			target.remove_light_zone_from(self)
		return

	if target.has_method("remove_light_zone_from"):
		target.remove_light_zone_from(self)
	elif target.has_method("remove_light_zone"):
		target.remove_light_zone()


func _target_has_light_receiver(target: Node) -> bool:
	if target == null:
		return false
	if target is LightReceiver:
		return true
	for child in target.get_children():
		if child is LightReceiver:
			return true
	return false
