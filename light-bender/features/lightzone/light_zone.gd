@tool
extends Polygon2D

@export var is_on: bool = true
@export var penumbra_size: float = 50.0
@export var safe_zone_extra: float = 30.0

@onready var trigger_zone = $TriggerZone
@onready var hitbox = $TriggerZone/Hitbox
@onready var hole = $Hole

var _penumbra_rings: Array[Polygon2D] = []

func toggle_light():
	is_on = !is_on
	_set_light_visible(is_on)
	if has_node("TriggerZone/Hitbox"):
		$TriggerZone/Hitbox.set_deferred("disabled", not is_on)

func _process(_delta):
	if Engine.is_editor_hint():
		if hitbox and hole:
			hole.polygon = self.polygon
			hitbox.polygon = _get_hitbox_polygon()
		_update_editor_penumbra()

func _get_hitbox_polygon() -> PackedVector2Array:
	if safe_zone_extra <= 0.0:
		return self.polygon
	return _offset_polygon(self.polygon, safe_zone_extra)

func _update_editor_penumbra() -> void:
	for ring in _penumbra_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_penumbra_rings.clear()
	if penumbra_size > 0.0:
		_build_penumbra()

func _ready():
	if not Engine.is_editor_hint():
		hole.polygon = self.polygon
		_build_penumbra()
		hitbox.polygon = _get_hitbox_polygon()

		trigger_zone.monitoring = true
		trigger_zone.monitorable = true
		trigger_zone.collision_layer = 0
		trigger_zone.collision_mask = 2

		trigger_zone.body_entered.connect(_on_body_entered)
		trigger_zone.body_exited.connect(_on_body_exited)
		trigger_zone.area_entered.connect(_on_area_entered)
		trigger_zone.area_exited.connect(_on_area_exited)

		_set_light_visible(is_on)
		if has_node("TriggerZone/Hitbox"):
			$TriggerZone/Hitbox.set_deferred("disabled", not is_on)

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

func _on_body_entered(body):
	if body.has_method("add_light_zone"):
		body.add_light_zone()

func _on_body_exited(body):
	if body.has_method("remove_light_zone"):
		body.remove_light_zone()

func _on_area_entered(area: Area2D):
	if area.has_method("add_light_zone"):
		area.add_light_zone()

func _on_area_exited(area: Area2D):
	if area.has_method("remove_light_zone"):
		area.remove_light_zone()
