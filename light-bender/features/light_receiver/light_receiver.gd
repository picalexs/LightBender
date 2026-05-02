extends StaticBody2D

## LightReceiver — powered when a beam hits it. Same target/method wiring as Switch.
## Add to group "light_receivers" so BeamSource can reset it each frame.

@export_group("Target Logic")
@export var target_node: Node
@export var method_when_powered: String = "toggle_light"
@export var param_when_powered: String = ""
@export var method_when_unpowered: String = ""
@export var param_when_unpowered: String = ""

@export_group("Behaviour")
## If true the target method is only called once on state change (not every frame).
@export var trigger_on_change: bool = true

@onready var powered_indicator: Node2D = get_node_or_null("PoweredIndicator")

var _was_powered: bool = false
var _beam_hit_this_frame: bool = false

func _ready() -> void:
	add_to_group("light_receivers")

func _physics_process(_delta: float) -> void:
	if trigger_on_change and _beam_hit_this_frame != _was_powered:
		_fire_target(_beam_hit_this_frame)
	_was_powered = _beam_hit_this_frame
	_update_indicator()

## Called by BeamSource when the ray terminates on this node.
func receive_beam() -> void:
	_beam_hit_this_frame = true

## Called by BeamSource at the START of each frame to clear last frame's state.
func reset_beam() -> void:
	_beam_hit_this_frame = false

func _fire_target(powered: bool) -> void:
	if target_node == null:
		return
	var method := method_when_powered if powered else method_when_unpowered
	var param  := param_when_powered  if powered else param_when_unpowered
	NodeDispatch.call_method(target_node, method, param, "LightReceiver")

func _update_indicator() -> void:
	if powered_indicator:
		powered_indicator.visible = _was_powered
