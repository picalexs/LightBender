extends Area2D

@export var owner_node_path: NodePath = ^".."


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true


func get_interaction_prompt_verb() -> String:
	var owner_node := _get_owner_node()
	if owner_node != null and owner_node.has_method("get_interaction_prompt_verb"):
		return str(owner_node.call("get_interaction_prompt_verb"))
	return "absorb"


func can_show_interact_prompt() -> bool:
	var owner_node := _get_owner_node()
	if owner_node != null and owner_node.has_method("can_show_interact_prompt"):
		if not bool(owner_node.call("can_show_interact_prompt")):
			return false
	return _has_clear_player_pickup_path(owner_node)


func _get_owner_node() -> Node:
	return get_node_or_null(owner_node_path)


func _has_clear_player_pickup_path(owner_node: Node) -> bool:
	if owner_node == null or not (owner_node is Node2D):
		return false

	var player := _find_player_node()
	if player == null:
		return false

	var pickup_controller := player.get_node_or_null("PickupController")
	if pickup_controller != null and pickup_controller.has_method("_has_clear_pickup_path"):
		return bool(pickup_controller.call("_has_clear_pickup_path", owner_node))

	return true


func _find_player_node() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null

	var search_root := tree.current_scene if tree.current_scene != null else tree.root
	if search_root == null:
		return null

	var player := search_root.find_child("Player", true, false)
	if player is Node2D:
		return player as Node2D

	return null
