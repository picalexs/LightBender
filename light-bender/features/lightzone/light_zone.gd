@tool
extends Polygon2D

@onready var trigger_zone = $TriggerZone
@onready var hitbox = $TriggerZone/Hitbox
@onready var hole = $Hole # <--- Updated reference

func _process(_delta):
	if Engine.is_editor_hint():
		if hitbox and hole:
			hitbox.polygon = self.polygon
			hole.polygon = self.polygon

func _ready():
	if not Engine.is_editor_hint():
		hitbox.polygon = self.polygon
		hole.polygon = self.polygon
		
		trigger_zone.body_entered.connect(_on_body_entered)
		trigger_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	# has_method is a super safe way to check if the object is our Player
	# without worrying about node names!
	if body.has_method("add_light_zone"):
		body.add_light_zone()

func _on_body_exited(body):
	if body.has_method("remove_light_zone"):
		body.remove_light_zone()
