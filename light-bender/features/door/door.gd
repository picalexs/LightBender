@tool
extends Area2D

signal player_entered
signal level_transition_started

@export_group("Visuals")
@export var door_color: Color = Color.WHITE:
	set(value):
		door_color = value
		_apply_color()

@export_group("Door Type")
@export var is_exit_door: bool = false
@export_file("*.tscn") var next_level_path: String

@export_group("Dependencies")
@export var respawn_manager: Node

@export_group("Transition")
@export var transition: Node
@export var transition_delay: float = 0.5
@export var ring_radius: float = 80.0
@export var ring_hold_time: float = 0.2
@export var ring_close_to_duration: float = 0.44
@export var ring_close_from_duration: float = 0.33

var _is_player_inside: bool = false
var _transitioning: bool = false

@onready var _light_reactive: Node = $LightReactive

func _ready() -> void:
	_apply_color()

	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		if transition == null:
			transition = get_node_or_null("/root/CircleTransition")

func _apply_color() -> void:
	if has_node("ColorRect"):
		$ColorRect.color = door_color

func _on_body_entered(body: Node2D) -> void:
	if "Player" in body.name:
		_is_player_inside = true
		player_entered.emit()
		if not is_exit_door:
			_set_as_checkpoint()

func _on_body_exited(body: Node2D) -> void:
	if "Player" in body.name:
		_is_player_inside = false

func _unhandled_input(event: InputEvent) -> void:
	if is_exit_door and _is_player_inside and not _transitioning:
		if _light_reactive != null and not _light_reactive.can_interact():
			return
		if event.is_action_pressed("lb_select"):
			if next_level_path != "":
				_start_level_transition()
			else:
				push_warning("Door Error: No next level path assigned!")


func _start_level_transition() -> void:
	_transitioning = true
	level_transition_started.emit()
	BackgroundManager.set_state("level_complete", 3.0)
	MusicManager.on_level_complete()

	if transition != null and transition.has_method("play_ring_from_target"):
		transition.fully_covered.connect(_on_transition_fully_covered, CONNECT_ONE_SHOT)
		transition.call("play_ring_from_target", ring_radius, ring_hold_time, transition_delay, ring_close_to_duration, ring_close_from_duration)
	elif transition != null and transition.has_method("play_from_target"):
		transition.fully_covered.connect(_on_transition_fully_covered, CONNECT_ONE_SHOT)
		transition.play_from_target(transition_delay)
	else:
		get_tree().change_scene_to_file(next_level_path)


func _on_transition_fully_covered() -> void:
	get_tree().change_scene_to_file(next_level_path)


func get_interaction_prompt_title() -> String:
	return "EXIT DOOR"


func get_interaction_prompt_verb() -> String:
	return "enter"


func can_show_interact_prompt() -> bool:
	return is_exit_door and not _transitioning


func _set_as_checkpoint() -> void:
	if respawn_manager == null:
		push_warning("Door Error: No RespawnManager assigned to this door!")
		return

	var marker_path = respawn_manager.get("spawn_marker_path")
	if marker_path and not marker_path.is_empty():
		var marker = respawn_manager.get_node_or_null(marker_path)
		if marker is Node2D:
			marker.global_position = self.global_position

	if respawn_manager.has_method("refresh_spawn_position"):
		respawn_manager.refresh_spawn_position()
