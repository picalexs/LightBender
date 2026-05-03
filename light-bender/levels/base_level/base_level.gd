extends Node2D

@export_group("Chapter")
@export_range(1, 3) var chapter: int = 1

@export_group("Level")
## Override only if auto-detection from scene path fails.
## Normally left empty — the level ID is looked up from LevelManager.LEVELS
## by matching the scene file path, so no manual entry is needed.
@export var level_id: String = ""

@export_group("Entry Transition")
@export var entry_ring_radius:    float = 80.0
@export var entry_ring_hold:      float = 0.1
@export var entry_phase1_duration: float = -1.0
@export var entry_phase2_duration: float = -1.0


func _ready() -> void:
	BackgroundManager.set_chapter(chapter)
	BackgroundManager.set_state("idle", 1.2)
	MusicManager.on_level_started()
	CircleTransition.play_ring_open_from_target(
		entry_ring_radius, entry_ring_hold, entry_phase1_duration, entry_phase2_duration)
	_connect_exit_doors(self)

	var pm = load("res://ui/pause_menu/pause_menu.tscn").instantiate()
	pm.is_in_level = true
	add_child(pm)


## Call this when the player finishes the level.
## Marks the level completed in LevelManager and saves progress automatically.
func complete_level() -> void:
	var id := _resolve_level_id()
	if id != "":
		LevelManager.mark_completed(id)


# ── Internal ──────────────────────────────────────────────────────────────────

func _resolve_level_id() -> String:
	if level_id != "":
		return level_id
	# Auto-detect by matching scene file path against LevelManager data
	var paths_to_try: Array[String] = []
	var local_path := get_scene_file_path()
	if local_path != "":
		paths_to_try.append(local_path)
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path != "" and current_scene.scene_file_path not in paths_to_try:
		paths_to_try.append(current_scene.scene_file_path)

	for path in paths_to_try:
		for level in LevelManager.LEVELS:
			if level["scene"] == path:
				return level["id"]
	return ""


func _connect_exit_doors(node: Node) -> void:
	for child in node.get_children():
		if child.has_signal("level_transition_started") and child.get("is_exit_door") == true:
			var on_transition := Callable(self, "complete_level")
			if not child.level_transition_started.is_connected(on_transition):
				child.level_transition_started.connect(on_transition)
		_connect_exit_doors(child)
