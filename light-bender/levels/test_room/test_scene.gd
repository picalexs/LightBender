extends Node2D

func _unhandled_input(event):
	# "ui_cancel" is a default Godot action already mapped to the Escape key!
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		
