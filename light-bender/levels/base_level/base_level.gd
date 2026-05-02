extends Node2D

func _ready() -> void:
	BackgroundManager.set_state("idle", 1.2)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
