extends Node

@export_group("References")
@export var movement_path: NodePath = NodePath("..")
@export var emitter_path: NodePath = NodePath("../SfxEmitter")
@export var respawn_path: NodePath

@export_group("Events")
@export var enable_sfx: bool = true
@export var jump_event: String = "jump"
@export var dash_event: String = "dash"
@export var double_jump_event: String = "double_jump"
@export var wall_jump_event: String = "wall_jump"
@export var wall_slide_loop_event: String = "wall_slide_loop"
@export var death_event: String = "death"

var _movement: Node
var _emitter: Node


func _ready() -> void:
	_movement = get_node_or_null(movement_path)
	_emitter = get_node_or_null(emitter_path)
	_connect_movement_signals()
	_connect_respawn_signals()


func _exit_tree() -> void:
	_stop_event(wall_slide_loop_event)


func _connect_respawn_signals() -> void:
	if respawn_path.is_empty():
		return
	var respawn := get_node_or_null(respawn_path)
	if respawn == null:
		return
	if respawn.has_signal("respawn_requested"):
		respawn.respawn_requested.connect(_on_respawn_requested)


func _on_respawn_requested(_source: StringName) -> void:
	if not enable_sfx:
		return
	_play_event(death_event)


func _connect_movement_signals() -> void:
	if _movement == null:
		return

	if _movement.has_signal("jump_performed"):
		_movement.jump_performed.connect(_on_jump_performed)
	if _movement.has_signal("dash_performed"):
		_movement.dash_performed.connect(_on_dash_performed)
	if _movement.has_signal("wall_slide_state_changed"):
		_movement.wall_slide_state_changed.connect(_on_wall_slide_state_changed)


func _on_jump_performed(kind: StringName) -> void:
	if not enable_sfx:
		return

	if kind == &"double":
		_play_event(double_jump_event if double_jump_event != "" else jump_event)
		return
	if kind == &"wall":
		_play_event(wall_jump_event if wall_jump_event != "" else jump_event)
		return

	_play_event(jump_event)


func _on_dash_performed() -> void:
	if not enable_sfx:
		return
	_play_event(dash_event)


func _on_wall_slide_state_changed(is_sliding: bool) -> void:
	if wall_slide_loop_event == "":
		return

	if not enable_sfx:
		_stop_event(wall_slide_loop_event)
		return

	if is_sliding:
		_start_loop(wall_slide_loop_event)
	else:
		_stop_event(wall_slide_loop_event)


func _play_event(event_name: String) -> void:
	if event_name == "":
		return
	if _emitter == null:
		return
	if _emitter.has_method("play_event"):
		_emitter.play_event(event_name)


func _start_loop(event_name: String) -> void:
	if event_name == "":
		return
	if _emitter == null:
		return
	if _emitter.has_method("start_event_loop"):
		_emitter.start_event_loop(event_name)


func _stop_event(event_name: String) -> void:
	if event_name == "":
		return
	if _emitter == null:
		return
	if _emitter.has_method("stop_event"):
		_emitter.stop_event(event_name)
