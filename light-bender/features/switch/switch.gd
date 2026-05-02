extends Area2D

@export_group("Interaction")
@export var interact_action: String = "lb_select"

@export_group("Target Logic")
@export var target_node: Node
@export var method_when_on: String = "toggle_light"
@export var parameter_when_on: String = "" # <--- NEW!
@export var method_when_off: String = "toggle_light"
@export var parameter_when_off: String = "" # <--- NEW!

var _player_in_zone: bool = false
var is_on: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if "Player" in body.name:
		_player_in_zone = true

func _on_body_exited(body: Node2D) -> void:
	if "Player" in body.name:
		_player_in_zone = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_zone and event.is_action_pressed(interact_action):
		is_on = !is_on
			
		if target_node:
			var method_to_call = method_when_on if is_on else method_when_off
			var param_to_pass = parameter_when_on if is_on else parameter_when_off
			
			if method_to_call != "":
				if target_node.has_method(method_to_call):
					# If we typed a parameter in the Inspector, send it! 
					if param_to_pass != "":
						target_node.call(method_to_call, param_to_pass)
					# Otherwise, just call the function normally
					else:
						target_node.call(method_to_call)
				else:
					push_warning("Switch Error: Target doesn't have function: " + method_to_call)

		# Pulse background at switch world position
		var viewport = get_viewport()
		if viewport != null:
			var screen_pos = viewport.get_canvas_transform() * global_position
			BackgroundManager.trigger_pulse(screen_pos)
