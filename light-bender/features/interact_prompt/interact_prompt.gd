extends PanelContainer

@onready var label = $MarginContainer/Label
@export var action_name: String = "lb_select" 

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

# The UI handles its own visibility now!
func _on_body_entered(body: Node2D) -> void:
	if "Player" in body.name:
		show()

func _on_body_exited(body: Node2D) -> void:
	if "Player" in body.name:
		hide()
