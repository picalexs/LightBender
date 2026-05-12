extends Node

var current_checkpoint: Vector2 = Vector2.ZERO


func _ready() -> void:
	Engine.max_fps = 120
