extends StaticBody2D

## LightReceiver — a block that gets "powered" when a beam hits it.
## Works exactly like a Switch but triggered by light instead of player input.
##
## Scene setup:
##   LightReceiver (StaticBody2D)  ← this script, collision layer 1
##     CollisionShape2D            ← solid shape (e.g. 32×32 square)
##     PoweredIndicator (Node2D)   ← optional visual (show when powered)
##
## Add to group "light_receivers" so BeamSource can reset it each frame.
##
## The same target / method wiring as Switch is used, so you can connect a
## LightReceiver to a door, a LightZone's toggle_light, a DimmingLightZone's
## reset_dim, etc.

@export_group("Target Logic")
@export var target_node: Node
@export var method_when_powered: String = "toggle_light"
@export var param_when_powered: String = ""
@export var method_when_unpowered: String = ""
@export var param_when_unpowered: String = ""

@export_group("Behaviour")
## If true the target method is only called once on state change (not every frame).
@export var trigger_on_change: bool = true

@onready var powered_indicator: Node = get_node_or_null("PoweredIndicator")

var is_powered: bool = false
var _was_powered: bool = false
var _beam_hit_this_frame: bool = false

func _ready() -> void:
	add_to_group("light_receivers")

func _physics_process(_delta: float) -> void:
	# is_powered was set (or not) by BeamSource earlier this frame
	is_powered = _beam_hit_this_frame

	if trigger_on_change and is_powered != _was_powered:
		_fire_target(is_powered)

	_was_powered = is_powered
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
	if method == "":
		return
	if not target_node.has_method(method):
		push_warning("LightReceiver: target has no method '%s'" % method)
		return
	if param != "":
		target_node.call(method, param)
	else:
		target_node.call(method)

func _update_indicator() -> void:
	if powered_indicator:
		powered_indicator.visible = is_powered
