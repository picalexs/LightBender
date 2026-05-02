extends Area2D

signal toggled(is_active: bool)

@export_group("Interaction")
@export var interact_action: String = "lb_select"

@export_group("Target Logic")
@export var target_node: Node
@export var method_when_on: String = "toggle_light"
@export var parameter_when_on: String = ""
@export var method_when_off: String = "toggle_light"
@export var parameter_when_off: String = ""

var _player_in_zone: bool = false
var _is_active: bool = false

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
		_is_active = !_is_active

		var method_to_call := method_when_on if _is_active else method_when_off
		var param_to_pass := parameter_when_on if _is_active else parameter_when_off
		NodeDispatch.call_method(target_node, method_to_call, param_to_pass, "Switch")
		toggled.emit(_is_active)

		var viewport := get_viewport()
		if viewport != null:
			var screen_pos := viewport.get_canvas_transform() * global_position
			BackgroundManager.trigger_pulse(screen_pos)
