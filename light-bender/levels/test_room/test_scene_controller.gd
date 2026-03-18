extends Node2D

@export_group("Debug Respawn")
@export var trigger_keycode: int = KEY_O
@export var custom_hold_delay: float = -1.0
@export var reset_velocity_on_respawn: bool = true

@export_group("Spawn")
@export var spawn_marker_path: NodePath

var _spawn_position: Vector2 = Vector2.ZERO

@onready var _player: CharacterBody2D = $Player
@onready var _respawn_transition = $RespawnTransition


func _ready() -> void:
	_cache_spawn_position()
	_connect_transition_signals()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_trigger_event(event):
		return
	_trigger_test_respawn()


func _is_trigger_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event = event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == trigger_keycode


func _trigger_test_respawn() -> void:
	if _respawn_transition == null:
		return
	if _respawn_transition.has_method("is_running") and _respawn_transition.is_running():
		return
	if _respawn_transition.has_method("play_from_target"):
		_respawn_transition.play_from_target(custom_hold_delay)


func _connect_transition_signals() -> void:
	if _respawn_transition == null:
		return
	if not _respawn_transition.has_signal("fully_covered"):
		return
	_respawn_transition.fully_covered.connect(_on_transition_fully_covered)


func _cache_spawn_position() -> void:
	if _player == null:
		return

	_spawn_position = _player.global_position

	if spawn_marker_path.is_empty():
		return

	var marker = get_node_or_null(spawn_marker_path)
	if marker is Node2D:
		_spawn_position = marker.global_position


func _on_transition_fully_covered() -> void:
	if _player == null:
		return

	_player.global_position = _spawn_position
	if reset_velocity_on_respawn:
		_player.velocity = Vector2.ZERO
