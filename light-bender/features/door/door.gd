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

var _player_in_zone: bool = false

func _ready() -> void:
	# Just in case the editor didn't catch it, force the color when the game runs
	if has_node("ColorRect"):
		$ColorRect.color = door_color
		
	# If the engine is running the game (not the editor), connect our signals
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

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
	if is_exit_door and _player_in_zone:
		if event.is_action_pressed("lb_select"): # Usually Enter, Space, or 'A' button
			if next_level_path != "":
				print("Loading next level: ", next_level_path)
				BackgroundManager.set_state("level_complete", 3.0)
				get_tree().change_scene_to_file(next_level_path)
			else:
				push_warning("Door Error: No next level path assigned!")

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
