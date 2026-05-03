extends Node

signal respawn_requested(source: StringName)
signal respawn_completed(source: StringName)

const SOURCE_MANUAL: StringName = &"manual"
const SOURCE_FALL: StringName = &"fall_limit"

@export_group("Nodes")
@export var player_path: NodePath = ^"../Player"
@export var transition_path: NodePath = ^"../RespawnTransition"
@export var spawn_marker_path: NodePath

@export_group("Manual Trigger")
@export var force_respawn_enabled: bool = true
@export var force_respawn_keycode: int = KEY_P
@export var restart_level_enabled: bool = true
@export var restart_level_keycode: int = KEY_O

@export_group("Automatic Trigger")
@export var fall_limit_enabled: bool = true
@export var fall_limit_y: float = 300.0

@export_group("Behavior")
@export var custom_hold_delay: float = -1.0
@export var reset_velocity_on_respawn: bool = true
@export_subgroup("Ring Open")
@export var ring_open_radius: float = 80.0
@export var ring_open_hold: float = 0.05
@export var ring_open_phase1_dur: float = -1.0
@export var ring_open_phase2_dur: float = -1.0

var _spawn_position: Vector2 = Vector2.ZERO
var _pending_respawn_source: StringName = &""

@onready var _player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D
var _respawn_transition: Node = null


func _ready() -> void:
	if not transition_path.is_empty():
		_respawn_transition = get_node_or_null(transition_path)
	if _respawn_transition == null:
		_respawn_transition = get_node_or_null("/root/CircleTransition")
	_cache_spawn_position()
	_connect_transition_signals()


func _unhandled_input(event: InputEvent) -> void:
	if restart_level_enabled and _is_restart_level_event(event):
		_restart_level()
		return
	if not force_respawn_enabled:
		return
	if not _is_force_respawn_event(event):
		return
	request_respawn(SOURCE_MANUAL)


func _physics_process(_delta: float) -> void:
	if not fall_limit_enabled or _player == null:
		return
	if _player.global_position.y > fall_limit_y:
		request_respawn(SOURCE_FALL)


func request_respawn(source: StringName = SOURCE_MANUAL) -> void:
	if _player == null or _has_pending_respawn():
		return
	if _is_transition_running():
		return

	BackgroundManager.set_state("death", 4.0)
	MusicManager.on_death()
	_pending_respawn_source = source
	respawn_requested.emit(source)

	if _respawn_transition != null and _respawn_transition.has_method("play_close_from_target"):
		_respawn_transition.play_close_from_target(custom_hold_delay)
		return

	if _respawn_transition != null and _respawn_transition.has_method("play_from_target"):
		_respawn_transition.play_from_target(custom_hold_delay)
		return

	_finish_respawn()


func refresh_spawn_position() -> void:
	_cache_spawn_position()


func _is_force_respawn_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == force_respawn_keycode

func _is_restart_level_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == restart_level_keycode

func _restart_level() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_warning("RespawnController: Cannot restart level, current_scene is null")
		return
	get_tree().reload_current_scene()


func _connect_transition_signals() -> void:
	if _respawn_transition == null:
		return
	if not _respawn_transition.has_signal("fully_covered"):
		return
	_respawn_transition.fully_covered.connect(_on_transition_fully_covered)


func _cache_spawn_position() -> void:
	_spawn_position = _get_spawn_position()

func _get_spawn_position() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	if not spawn_marker_path.is_empty():
		var marker = get_node_or_null(spawn_marker_path)
		if marker is Node2D:
			return (marker as Node2D).global_position
	return _player.global_position


func _is_transition_running() -> bool:
	return _respawn_transition != null \
		and _respawn_transition.has_method("is_running") \
		and _respawn_transition.is_running()


func _has_pending_respawn() -> bool:
	return _pending_respawn_source != &""


func _on_transition_fully_covered() -> void:
	if not _has_pending_respawn():
		return
	var hold: float = custom_hold_delay
	if hold < 0.0:
		if _respawn_transition != null and "hold_delay" in _respawn_transition:
			hold = _respawn_transition.hold_delay
		else:
			hold = 0.5
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	_finish_respawn()


func _finish_respawn() -> void:
	if _player == null:
		_pending_respawn_source = &""
		return

	var source := _pending_respawn_source
	_pending_respawn_source = &""

	_player.global_position = _spawn_position
	if reset_velocity_on_respawn:
		_player.velocity = Vector2.ZERO

	# Let physics/light overlap state settle before we reveal the world again.
	await get_tree().physics_frame

	BackgroundManager.set_state("idle", 1.5)
	MusicManager.on_respawn()

	if _respawn_transition != null and _respawn_transition.has_method("play_ring_open_from_target"):
		_respawn_transition.play_ring_open_from_target(ring_open_radius, ring_open_hold, ring_open_phase1_dur, ring_open_phase2_dur)

	respawn_completed.emit(source)
