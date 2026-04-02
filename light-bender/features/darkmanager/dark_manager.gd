extends CanvasGroup

@onready var color_rect = $GlobalDark

func _ready() -> void:
	if color_rect:
		color_rect.color.a = 1.0
