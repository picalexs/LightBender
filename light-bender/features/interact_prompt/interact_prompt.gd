extends PanelContainer

@onready var label = $MarginContainer/Label
@export var action_name: String = "lb_select"

var _player_near: bool = false
var _can_interact: bool = true

func _ready() -> void:
	# 1. Ensure we always start invisible
	hide()
	update_key_text()

	# 2. THE PLUG-AND-PLAY MAGIC
	# Grab whatever node this UI was attached to
	var parent = get_parent()

	# Check if the parent is an Area2D (like our Door or Switch)
	if parent is Area2D:
		# Wire the parent's physics signals directly into this UI script!
		parent.body_entered.connect(_on_body_entered)
		parent.body_exited.connect(_on_body_exited)

		# Connect to LightReactive if it exists
		var light_reactive = parent.get_node_or_null("LightReactive")
		if light_reactive:
			light_reactive.light_state_changed.connect(_on_light_state_changed)
			_can_interact = light_reactive.can_interact()
	else:
		push_warning("InteractPrompt Error: My parent is not an Area2D!")

func update_key_text() -> void:
	var events = InputMap.action_get_events(action_name)
	
	if events.size() > 0:
		var event = events[0]
		var key_name = ""
		
		# Check if the input is a Keyboard Key
		if event is InputEventKey:
			# Figure out if we are using a physical scancode or a regular keycode
			var keycode = event.keycode
			if keycode == KEY_NONE:
				keycode = event.physical_keycode
				
			# Ask the OS for the clean name (e.g., "E", "Space", "Enter")
			key_name = OS.get_keycode_string(keycode)
		else:
			# This strips the messy controller strings down to the basics
			key_name = event.as_text().get_slice(" (", 0)
			
		label.text = "Press [" + key_name + "]"
	else:
		label.text = "Press [?]"

func _update_visibility() -> void:
	if _player_near and _can_interact:
		show()
	else:
		hide()

func _on_body_entered(body: Node2D) -> void:
	if "Player" in body.name:
		_player_near = true
		_update_visibility()

func _on_body_exited(body: Node2D) -> void:
	if "Player" in body.name:
		_player_near = false
		_update_visibility()

func _on_light_state_changed(is_in_light: bool) -> void:
	_can_interact = is_in_light
	_update_visibility()
