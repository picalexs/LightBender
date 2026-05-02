@tool
extends Area2D

@export_group("Visuals")
# The 'set(value)' block runs automatically every time you touch the color wheel in the Inspector
@export var door_color: Color = Color.WHITE:
	set(value):
		door_color = value
		# Safely check if the ColorRect exists before trying to paint it
		if has_node("ColorRect"):
			$ColorRect.color = door_color

@export_group("Door Type")
@export var is_exit_door: bool = false
@export_file("*.tscn") var next_level_path: String

@export_group("Dependencies")
# Drag your level's RespawnManager node into this slot in the Inspector!
@export var respawn_manager: Node

@export_group("Transition")
# Drag your level's CircleTransition node into this slot!
@export var transition: Node
@export var transition_delay: float = 0.5
@export var ring_radius: float = 80.0
@export var ring_hold_time: float = 0.2
@export var ring_close_to_duration: float = 0.44
@export var ring_close_from_duration: float = 0.33

var _player_in_zone: bool = false
var _transitioning: bool = false

func _ready() -> void:
	# Just in case the editor didn't catch it, force the color when the game runs
	if has_node("ColorRect"):
		$ColorRect.color = door_color
		
	# If the engine is running the game (not the editor), connect our signals
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		# Auto-find transition if not assigned in inspector
		if transition == null:
			var root = get_tree().current_scene
			if root != null:
				transition = root.find_child("CircleTransition", true, false)

func _on_body_entered(body: Node2D) -> void:
	# Safely check if the body is the Player
	if "Player" in body.name:
		_player_in_zone = true
		
		# If this is a CHECKPOINT door, update the Respawn Manager
		if not is_exit_door:
			_set_as_checkpoint()

func _on_body_exited(body: Node2D) -> void:
	if "Player" in body.name:
		_player_in_zone = false

func _unhandled_input(event: InputEvent) -> void:
	# If this is an EXIT door, wait for the player to press interact
	if is_exit_door and _player_in_zone and not _transitioning:
		if event.is_action_pressed("lb_select"): # Usually Enter, Space, or 'A' button
			if next_level_path != "":
				_start_level_transition()
			else:
				push_warning("Door Error: No next level path assigned!")


func _start_level_transition() -> void:
	_transitioning = true
	print("Loading next level: ", next_level_path)
	BackgroundManager.set_state("level_complete", 3.0)

	# Play transition if available — ring variant zooms into door then closes fully
	if transition != null and transition.has_method("play_ring_from_world_position"):
		transition.fully_covered.connect(_on_transition_fully_covered, CONNECT_ONE_SHOT)
		transition.call("play_ring_from_world_position", global_position, ring_radius, ring_hold_time, transition_delay, ring_close_to_duration, ring_close_from_duration)
	elif transition != null and transition.has_method("play_from_target"):
		transition.fully_covered.connect(_on_transition_fully_covered, CONNECT_ONE_SHOT)
		transition.play_from_target(transition_delay)
	else:
		# No transition, change scene immediately
		get_tree().change_scene_to_file(next_level_path)


func _on_transition_fully_covered() -> void:
	get_tree().change_scene_to_file(next_level_path)

func _set_as_checkpoint() -> void:
	if respawn_manager == null:
		push_warning("Door Error: No RespawnManager assigned to this door!")
		return
		
	# STEP 1: Check if the teammate's script is using a dedicated Marker2D
	var marker_path = respawn_manager.get("spawn_marker_path")
	if marker_path and not marker_path.is_empty():
		var marker = respawn_manager.get_node_or_null(marker_path)
		if marker is Node2D:
			# Physically move the manager's marker to this door's exact location!
			marker.global_position = self.global_position
			
	# STEP 2: Tell the manager to re-cache the position.
	# (If no marker was used, it will just grab the Player's current position inside the door, 
	# which also works perfectly!)
	if respawn_manager.has_method("refresh_spawn_position"):
		respawn_manager.refresh_spawn_position()
		print("Checkpoint successfully updated at Door!")
