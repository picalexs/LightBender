extends Node2D

@export_group("Entry Transition")
@export var entry_ring_radius: float = 80.0
@export var entry_ring_hold: float = 0.1
@export var entry_phase1_duration: float = -1.0
@export var entry_phase2_duration: float = -1.0

func _ready() -> void:
	BackgroundManager.set_state("idle", 1.2)
	CircleTransition.play_ring_open_from_target(entry_ring_radius, entry_ring_hold, entry_phase1_duration, entry_phase2_duration)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
