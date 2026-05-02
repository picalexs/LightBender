extends Area2D

## Hazard (spikes / lava)
## Only deadly when the player is in a light zone.
## In darkness the player has no collision with layer 1, so they pass right through.
## The hazard Area2D still detects the overlap, but skips the kill if the player is dark.
##
## Scene setup:
##   Hazard (Area2D)  ← this script, collision layer 1, mask 2
##     CollisionShape2D  ← shape matching the hazard visual

@export var respawn_controller: Node

var _players_inside: Array[Node] = []
var _is_killing: bool = false  # guard against double-kill in same frame

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	# Handle the case where light turns ON while player is already inside
	if _is_killing:
		return
	for body in _players_inside:
		if _body_is_in_light(body):
			_kill_player(body)
			return

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_players_inside.append(body)
	if _body_is_in_light(body):
		_kill_player(body)

func _on_body_exited(body: Node2D) -> void:
	_players_inside.erase(body)

func _is_player(body: Node) -> bool:
	return "Player" in body.name

func _body_is_in_light(body: Node) -> bool:
	# Read the player's own is_in_light flag (set by LightZone system)
	return body.get("is_in_light") == true

func _kill_player(body: Node) -> void:
	_is_killing = true
	var controller = _find_respawn_controller(body)
	if controller and controller.has_method("request_respawn"):
		controller.request_respawn(&"hazard")
	await get_tree().process_frame
	_is_killing = false

func _find_respawn_controller(player: Node) -> Node:
	if respawn_controller:
		return respawn_controller
	# Walk up to the level root and search for RespawnController
	var root = get_tree().current_scene
	return _search_for_method(root, "request_respawn")

func _search_for_method(node: Node, method: String) -> Node:
	for child in node.get_children():
		if child.has_method(method):
			return child
		var found = _search_for_method(child, method)
		if found:
			return found
	return null
