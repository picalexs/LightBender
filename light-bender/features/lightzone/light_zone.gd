@tool
extends Polygon2D

const LIGHT_AFFECTED_MASK: int = 6

@export var is_on: bool = true
@export_range(0.05, 1.0, 0.01) var core_scale: float = 1.0
@export_range(0.05, 1.0, 0.01) var trigger_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var core_alpha: float = 1.0
@export var penumbra_size: float = 50.0
@export_range(1, 32, 1) var penumbra_steps: int = 8
@export_range(0.0, 1.0, 0.01) var penumbra_alpha: float = 1.0
@export var safe_zone_extra: float = 30.0

@onready var trigger_zone = $TriggerZone
@onready var hitbox = $TriggerZone/Hitbox
@onready var hole = $Hole

var _penumbra_rings: Array[Polygon2D] = []
var _penumbra_expands: Array[float] = []

func toggle_light():
	is_on = !is_on
	_set_light_visible(is_on)
	_sync_current_overlaps()


func set_visual_enabled(enable: bool) -> void:
	_set_light_visible(enable)

func _process(_delta):
	if Engine.is_editor_hint():
		refresh_geometry()
		_set_light_visible(is_on)

func _get_hitbox_polygon() -> PackedVector2Array:
	var trigger_polygon := _get_scaled_polygon(trigger_scale)
	if safe_zone_extra <= 0.0:
		return trigger_polygon
	return _offset_polygon(trigger_polygon, safe_zone_extra)

func _update_editor_penumbra() -> void:
	_sync_penumbra()

func _ready():
	if not Engine.is_editor_hint():
		refresh_geometry()

		trigger_zone.monitoring = true
		trigger_zone.monitorable = true
		trigger_zone.collision_layer = 0
		trigger_zone.collision_mask = LIGHT_AFFECTED_MASK

		trigger_zone.body_entered.connect(_on_body_entered)
		trigger_zone.body_exited.connect(_on_body_exited)
		trigger_zone.area_entered.connect(_on_area_entered)
		trigger_zone.area_exited.connect(_on_area_exited)

		_set_light_visible(is_on)
		_sync_current_overlaps()


func refresh_geometry() -> void:
	if hole:
		hole.polygon = _get_hole_polygon()
		hole.modulate = Color(1.0, 1.0, 1.0, core_alpha)
	if hitbox:
		hitbox.polygon = _get_hitbox_polygon()
	_sync_penumbra()

func _sync_penumbra() -> void:
	var desired_steps := maxi(penumbra_steps, 1) if penumbra_size > 0.0 else 0
	if _penumbra_rings.size() != desired_steps:
		_rebuild_penumbra(desired_steps)

	if desired_steps == 0:
		return

	for i in range(desired_steps):
		var ring := _penumbra_rings[i]
		var expand := _penumbra_expands[i]
		var alpha_scale := float(i + 1) / float(desired_steps)
		ring.polygon = _offset_polygon(hole.polygon, expand)
		ring.color = Color(1.0, 1.0, 1.0, alpha_scale * penumbra_alpha)


func _rebuild_penumbra(steps: int) -> void:
	_clear_penumbra()
	if steps <= 0:
		return

	for i in range(steps, 0, -1):
		var expand := penumbra_size * float(i) / float(steps)
		var ring := Polygon2D.new()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		ring.material = mat
		add_child(ring)
		move_child(ring, hole.get_index())
		_penumbra_rings.append(ring)
		_penumbra_expands.append(expand)


func _clear_penumbra() -> void:
	for ring in _penumbra_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_penumbra_rings.clear()
	_penumbra_expands.clear()

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


func _get_hole_polygon() -> PackedVector2Array:
	return _get_scaled_polygon(core_scale)


func _get_scaled_polygon(scale_value) -> PackedVector2Array:
	var scale := _sanitize_scale(scale_value)
	if scale >= 0.999:
		return polygon
	var center := _compute_centroid(polygon)
	var scaled_polygon := PackedVector2Array()
	for point in polygon:
		scaled_polygon.append(center + (point - center) * scale)
	return scaled_polygon


func _sanitize_scale(scale_value) -> float:
	if typeof(scale_value) == TYPE_FLOAT or typeof(scale_value) == TYPE_INT:
		return clampf(float(scale_value), 0.05, 1.0)
	return 1.0


func _compute_centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var centroid := Vector2.ZERO
	for point in points:
		centroid += point
	return centroid / float(points.size())

func _set_light_visible(v: bool) -> void:
	if hole:
		hole.visible = v
	for ring in _penumbra_rings:
		ring.visible = v


func _sync_current_overlaps() -> void:
	if trigger_zone == null:
		return
	for body in trigger_zone.get_overlapping_bodies():
		if body == null:
			continue
		if is_on:
			_apply_light_to_target(body)
		else:
			_remove_light_from_target(body)
	for area in trigger_zone.get_overlapping_areas():
		if area == null:
			continue
		if is_on:
			_apply_light_to_target(area)
		else:
			_remove_light_from_target(area)


func _apply_light_to_target(target: Node) -> void:
	if target.has_method("add_light_zone_from"):
		target.add_light_zone_from(self)
	elif target.has_method("add_light_zone"):
		target.add_light_zone()


func _remove_light_from_target(target: Node) -> void:
	if target.has_method("remove_light_zone_from"):
		target.remove_light_zone_from(self)
	elif target.has_method("remove_light_zone"):
		target.remove_light_zone()

func _on_body_entered(body):
	if not is_on:
		return
	_apply_light_to_target(body)

func _on_body_exited(body):
	_remove_light_from_target(body)

func _on_area_entered(area: Area2D):
	if not is_on:
		return
	_apply_light_to_target(area)

func _on_area_exited(area: Area2D):
	_remove_light_from_target(area)
