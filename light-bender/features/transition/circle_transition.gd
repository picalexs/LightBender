extends CanvasLayer

signal transition_started
signal fully_covered
signal transition_finished

@export_group("Target")
@export var target_path: NodePath
@export var fallback_to_viewport_center: bool = true

@export_group("Timing")
@export var close_duration: float = 0.22
@export var hold_delay: float = 0.25
@export var open_duration: float = 0.22

@export_group("Visual")
@export var edge_softness: float = 2.0
@export var extra_radius_margin: float = 4.0
@export var overlay_layer: int = 100

@export_group("Behavior")
@export var process_while_paused: bool = true

var _is_running: bool = false
var _active_tween: Tween
var _target_node: Node2D
var _tracked_node: Node2D = null

@onready var _overlay: ColorRect = $Overlay


func _process(_delta: float) -> void:
	if _is_running and _tracked_node != null and is_instance_valid(_tracked_node):
		_set_hole_center(_clamp_to_viewport(_world_to_screen(_tracked_node.global_position)))


func _ready() -> void:
	_sanitize_settings()
	layer = overlay_layer
	process_mode = Node.PROCESS_MODE_ALWAYS if process_while_paused else Node.PROCESS_MODE_INHERIT
	_resolve_target()
	_apply_shader_defaults()
	_overlay.visible = false


func play_from_target(custom_hold_delay: float = -1.0) -> void:
	_resolve_target()
	if _target_node != null:
		play_from_world_position(_target_node.global_position, custom_hold_delay)
		return

	var player = _find_player()
	if player != null:
		play_from_world_position(player.global_position, custom_hold_delay)
		return

	if fallback_to_viewport_center:
		play_from_screen_position(_get_viewport_size() * 0.5, custom_hold_delay)


func play_ring_from_target(ring_radius: float = 80.0, ring_hold: float = 0.2, custom_hold_delay: float = -1.0, phase1_dur: float = -1.0, phase2_dur: float = -1.0) -> void:
	_resolve_target()
	if _target_node != null:
		_play_ring_from_screen_pos(_world_to_screen(_target_node.global_position), ring_radius, ring_hold, custom_hold_delay, phase1_dur, phase2_dur)
		_tracked_node = _target_node
		return
	var player = _find_player()
	if player != null:
		_play_ring_from_screen_pos(_world_to_screen(player.global_position), ring_radius, ring_hold, custom_hold_delay, phase1_dur, phase2_dur)
		_tracked_node = player
		return
	if fallback_to_viewport_center:
		_play_ring_from_screen_pos(_get_viewport_size() * 0.5, ring_radius, ring_hold, custom_hold_delay)


func play_ring_from_world_position(world_pos: Vector2, ring_radius: float = 80.0, ring_hold: float = 0.2, custom_hold_delay: float = -1.0, phase1_dur: float = -1.0, phase2_dur: float = -1.0) -> void:
	_play_ring_from_screen_pos(_world_to_screen(world_pos), ring_radius, ring_hold, custom_hold_delay, phase1_dur, phase2_dur)


func play_ring_open_from_target(ring_radius: float = 80.0, ring_hold: float = 0.2, phase1_dur: float = -1.0, phase2_dur: float = -1.0) -> void:
	_resolve_target()
	if _target_node != null:
		_play_ring_open_from_screen_pos(_world_to_screen(_target_node.global_position), ring_radius, ring_hold, phase1_dur, phase2_dur)
		_tracked_node = _target_node
		return
	var player = _find_player()
	if player != null:
		_play_ring_open_from_screen_pos(_world_to_screen(player.global_position), ring_radius, ring_hold, phase1_dur, phase2_dur)
		_tracked_node = player
		return
	if fallback_to_viewport_center:
		_play_ring_open_from_screen_pos(_get_viewport_size() * 0.5, ring_radius, ring_hold, phase1_dur, phase2_dur)


func play_ring_open_from_world_position(world_pos: Vector2, ring_radius: float = 80.0, ring_hold: float = 0.2, phase1_dur: float = -1.0, phase2_dur: float = -1.0) -> void:
	_play_ring_open_from_screen_pos(_world_to_screen(world_pos), ring_radius, ring_hold, phase1_dur, phase2_dur)


func _play_ring_open_from_screen_pos(screen_pos: Vector2, ring_radius: float, ring_hold: float, phase1_dur: float = -1.0, phase2_dur: float = -1.0) -> void:
	_sanitize_settings()
	_kill_active_tween()

	var clamped_center = _clamp_to_viewport(screen_pos)
	var max_radius = _radius_to_cover_viewport(clamped_center)
	var ring_open_dur := phase1_dur if phase1_dur > 0.0 else open_duration * 1.5
	var ring_expand_dur := phase2_dur if phase2_dur > 0.0 else open_duration * 2.0

	_overlay.visible = true
	_set_hole_center(clamped_center)
	_set_hole_radius(0.0)

	_is_running = true
	transition_started.emit()

	_active_tween = create_tween()
	_active_tween.tween_method(_set_hole_radius, 0.0, ring_radius, ring_open_dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(ring_hold)
	_active_tween.tween_method(_set_hole_radius, ring_radius, max_radius, ring_expand_dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(_on_transition_finished)


func _play_ring_from_screen_pos(screen_pos: Vector2, ring_radius: float, ring_hold: float, custom_hold_delay: float, phase1_dur: float = -1.0, phase2_dur: float = -1.0) -> void:
	_sanitize_settings()
	_kill_active_tween()

	var clamped_center = _clamp_to_viewport(screen_pos)
	var max_radius = _radius_to_cover_viewport(clamped_center)
	var effective_hold = hold_delay if custom_hold_delay < 0.0 else max(0.0, custom_hold_delay)
	var ring_form_dur := phase1_dur if phase1_dur > 0.0 else close_duration * 2.0
	var ring_close_dur := phase2_dur if phase2_dur > 0.0 else close_duration * 1.5

	_overlay.visible = true
	_set_hole_center(clamped_center)
	_set_hole_radius(max_radius)

	_is_running = true
	transition_started.emit()

	_active_tween = create_tween()
	_active_tween.tween_method(_set_hole_radius, max_radius, ring_radius, ring_form_dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(ring_hold)
	_active_tween.tween_method(_set_hole_radius, ring_radius, 0.0, ring_close_dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(_on_fully_covered)
	if effective_hold > 0.0:
		_active_tween.tween_interval(effective_hold)
	_active_tween.tween_method(_set_hole_radius, 0.0, max_radius, open_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_callback(_on_transition_finished)


func play_from_world_position(world_position: Vector2, custom_hold_delay: float = -1.0) -> void:
	var screen_position = _world_to_screen(world_position)
	play_from_screen_position(screen_position, custom_hold_delay)


func play_from_screen_position(screen_position: Vector2, custom_hold_delay: float = -1.0) -> void:
	_sanitize_settings()
	_kill_active_tween()

	var clamped_center = _clamp_to_viewport(screen_position)
	var max_radius = _radius_to_cover_viewport(clamped_center)
	var effective_hold = hold_delay if custom_hold_delay < 0.0 else max(0.0, custom_hold_delay)

	_overlay.visible = true
	_set_hole_center(clamped_center)
	_set_hole_radius(max_radius)

	_is_running = true
	transition_started.emit()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_method(_set_hole_radius, max_radius, 0.0, close_duration)
	_active_tween.tween_callback(_on_fully_covered)
	if effective_hold > 0.0:
		_active_tween.tween_interval(effective_hold)
	_active_tween.tween_method(_set_hole_radius, 0.0, max_radius, open_duration)
	_active_tween.tween_callback(_on_transition_finished)


func play_open(custom_center: Vector2 = Vector2.ZERO) -> void:
	_sanitize_settings()
	_kill_active_tween()

	var center: Vector2
	if custom_center == Vector2.ZERO:
		center = _get_viewport_size() * 0.5
	else:
		center = _clamp_to_viewport(custom_center)
	var max_radius = _radius_to_cover_viewport(center)

	_overlay.visible = true
	_set_hole_center(center)
	_set_hole_radius(0.0)

	_is_running = true
	transition_started.emit()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_method(_set_hole_radius, 0.0, max_radius, open_duration)
	_active_tween.tween_callback(_on_transition_finished)


func is_running() -> bool:
	return _is_running


func _on_fully_covered() -> void:
	fully_covered.emit()


func _on_transition_finished() -> void:
	_is_running = false
	_active_tween = null
	_tracked_node = null
	_overlay.visible = false
	transition_finished.emit()


func _resolve_target() -> void:
	_target_node = null
	if target_path.is_empty():
		return

	var candidate = get_node_or_null(target_path)
	if candidate is Node2D:
		_target_node = candidate as Node2D


func _find_player() -> Node2D:
	var candidate: Node
	candidate = get_node_or_null(NodePath("/root/BaseLevel/Player"))
	if candidate is Node2D:
		return candidate as Node2D
	candidate = get_node_or_null(NodePath("../Player"))
	if candidate is Node2D:
		return candidate as Node2D
	candidate = get_node_or_null(NodePath("../../Player"))
	if candidate is Node2D:
		return candidate as Node2D
	var root = get_tree().current_scene
	if root != null:
		candidate = root.find_child("Player", true, false)
		if candidate is Node2D:
			return candidate as Node2D
	return null


func _sanitize_settings() -> void:
	close_duration = max(0.01, close_duration)
	hold_delay = max(0.0, hold_delay)
	open_duration = max(0.01, open_duration)
	edge_softness = max(0.0, edge_softness)
	extra_radius_margin = max(0.0, extra_radius_margin)


func _apply_shader_defaults() -> void:
	var material = _get_shader_material()
	if material == null:
		return
	var vp_size = _get_viewport_size()
	material.set_shader_parameter("edge_softness", edge_softness)
	material.set_shader_parameter("hole_center", vp_size * 0.5)
	material.set_shader_parameter("hole_radius", 0.0)
	material.set_shader_parameter("viewport_size", vp_size)


func _get_shader_material() -> ShaderMaterial:
	return _overlay.material as ShaderMaterial


func _set_hole_center(screen_position: Vector2) -> void:
	var material = _get_shader_material()
	if material == null:
		return
	material.set_shader_parameter("hole_center", screen_position)
	material.set_shader_parameter("edge_softness", edge_softness)
	material.set_shader_parameter("viewport_size", _get_viewport_size())


func _set_hole_radius(radius: float) -> void:
	var material = _get_shader_material()
	if material == null:
		return
	material.set_shader_parameter("hole_radius", radius)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position


func _clamp_to_viewport(screen_position: Vector2) -> Vector2:
	var viewport_size = _get_viewport_size()
	return Vector2(
		clamp(screen_position.x, 0.0, viewport_size.x),
		clamp(screen_position.y, 0.0, viewport_size.y),
	)


func _radius_to_cover_viewport(center: Vector2) -> float:
	var viewport_size = _get_viewport_size()
	var corners = [
		Vector2.ZERO,
		Vector2(viewport_size.x, 0.0),
		Vector2(0.0, viewport_size.y),
		viewport_size,
	]

	var max_distance = 0.0
	for corner in corners:
		max_distance = max(max_distance, center.distance_to(corner))

	return max_distance + extra_radius_margin


func _get_viewport_size() -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size


func _kill_active_tween() -> void:
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
	_tracked_node = null


func _exit_tree() -> void:
	_kill_active_tween()
