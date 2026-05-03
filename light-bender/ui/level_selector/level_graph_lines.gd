extends Control

@export_group("Line Appearance")
@export var completed_color: Color = Color(1.0, 1.0, 1.0, 0.96)
@export var pending_color: Color = Color(0.42, 0.42, 0.45, 0.90)
@export_range(1.0, 16.0, 1.0) var pixel_size: float = 6.0
@export_range(0.0, 80.0, 1.0) var connect_inset: float = 24.0
@export_range(0.0, 32.0, 1.0) var fork_port_spacing: float = 10.0

var _positions: Dictionary = {}
var _node_size: Vector2 = Vector2(64.0, 64.0)
var _edges: Array[Dictionary] = []
var _outgoing_ports: Dictionary = {}
var _incoming_ports: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_graph(levels: Array, positions: Dictionary, node_size: Vector2) -> void:
	_positions = positions.duplicate()
	_node_size = node_size
	_edges.clear()

	for level in levels:
		var to_id: String = str(level.get("id", ""))
		if not _positions.has(to_id):
			continue

		for prerequisite in level.get("prerequisites", []):
			var from_id := str(prerequisite)
			if not _positions.has(from_id):
				continue
			_edges.append({
				"from": from_id,
				"to": to_id,
			})

	_rebuild_port_orders()
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _rebuild_port_orders() -> void:
	_outgoing_ports.clear()
	_incoming_ports.clear()

	var outgoing_groups: Dictionary = {}
	var incoming_groups: Dictionary = {}
	for edge in _edges:
		var from_id: String = edge["from"]
		var to_id: String = edge["to"]
		var from_pos: Vector2 = _positions[from_id]
		var to_pos: Vector2 = _positions[to_id]

		var outgoing_key := _port_group_key(from_id, _side_towards(from_pos, to_pos))
		var incoming_key := _port_group_key(to_id, _side_towards(to_pos, from_pos))
		_append_grouped_edge(outgoing_groups, outgoing_key, edge)
		_append_grouped_edge(incoming_groups, incoming_key, edge)

	for key in outgoing_groups:
		var group: Array = outgoing_groups[key]
		group.sort_custom(func(a, b) -> bool:
			return _position_less(_positions[a["to"]], _positions[b["to"]])
		)
		_store_port_order(_outgoing_ports, group)

	for key in incoming_groups:
		var group: Array = incoming_groups[key]
		group.sort_custom(func(a, b) -> bool:
			return _position_less(_positions[a["from"]], _positions[b["from"]])
		)
		_store_port_order(_incoming_ports, group)


func _append_grouped_edge(groups: Dictionary, key: String, edge: Dictionary) -> void:
	if not groups.has(key):
		groups[key] = []
	groups[key].append(edge)


func _store_port_order(port_orders: Dictionary, group: Array) -> void:
	var total := group.size()
	for index in total:
		var edge: Dictionary = group[index]
		port_orders[_edge_key(edge["from"], edge["to"])] = {
			"index": index,
			"total": total,
		}


func _draw() -> void:
	for edge in _edges:
		var from_id: String = edge["from"]
		var to_id: String = edge["to"]
		if not _positions.has(from_id) or not _positions.has(to_id):
			continue

		var from_pos: Vector2 = _positions[from_id]
		var to_pos: Vector2 = _positions[to_id]
		var start_side := _side_towards(from_pos, to_pos)
		var finish_side := _side_towards(to_pos, from_pos)
		var edge_key := _edge_key(from_id, to_id)
		var start := _port_point(from_pos, start_side, _outgoing_ports.get(edge_key, {}))
		var finish := _port_point(to_pos, finish_side, _incoming_ports.get(edge_key, {}))
		var color := completed_color if _is_level_completed(from_id) else pending_color
		_draw_pixel_connection(start, finish, color)


func _port_point(center: Vector2, side: String, port_info: Dictionary) -> Vector2:
	var index := int(port_info.get("index", 0))
	var total := int(port_info.get("total", 1))

	match side:
		"left":
			return center + Vector2(-connect_inset, _distributed_port_offset(index, total, true))
		"right":
			return center + Vector2(connect_inset, _distributed_port_offset(index, total, true))
		"up":
			return center + Vector2(_distributed_port_offset(index, total, false), -connect_inset)
		"down":
			return center + Vector2(_distributed_port_offset(index, total, false), connect_inset)

	return center


func _distributed_port_offset(index: int, total: int, horizontal_side: bool) -> float:
	if total <= 1 or is_zero_approx(fork_port_spacing):
		return 0.0

	var axis_size := _node_size.y if horizontal_side else _node_size.x
	var max_offset := maxf(axis_size * 0.5 - pixel_size, 0.0)
	var centered_index := float(index) - float(total - 1) * 0.5
	var raw_offset := centered_index * fork_port_spacing
	var snapped_offset := snappedf(raw_offset, maxf(pixel_size, 1.0))
	return clampf(snapped_offset, -max_offset, max_offset)


func _draw_pixel_connection(start: Vector2, finish: Vector2, color: Color) -> void:
	if is_equal_approx(start.x, finish.x) or is_equal_approx(start.y, finish.y):
		_draw_pixel_segment(start, finish, color)
		return

	if absf(finish.x - start.x) >= absf(finish.y - start.y):
		var mid_x := snappedf((start.x + finish.x) * 0.5, pixel_size)
		var mid_a := Vector2(mid_x, start.y)
		var mid_b := Vector2(mid_x, finish.y)
		_draw_pixel_segment(start, mid_a, color)
		_draw_pixel_segment(mid_a, mid_b, color)
		_draw_pixel_segment(mid_b, finish, color)
	else:
		var mid_y := snappedf((start.y + finish.y) * 0.5, pixel_size)
		var mid_a := Vector2(start.x, mid_y)
		var mid_b := Vector2(finish.x, mid_y)
		_draw_pixel_segment(start, mid_a, color)
		_draw_pixel_segment(mid_a, mid_b, color)
		_draw_pixel_segment(mid_b, finish, color)


func _draw_pixel_segment(start: Vector2, finish: Vector2, color: Color) -> void:
	if is_equal_approx(start.x, finish.x):
		var dir_y := signf(finish.y - start.y)
		var y := start.y
		while true:
			_draw_pixel_block(Vector2(start.x - pixel_size * 0.5, y - pixel_size * 0.5), color)
			if (dir_y >= 0.0 and y >= finish.y) or (dir_y <= 0.0 and y <= finish.y):
				break
			y = move_toward(y, finish.y, pixel_size)
	elif is_equal_approx(start.y, finish.y):
		var dir_x := signf(finish.x - start.x)
		var x := start.x
		while true:
			_draw_pixel_block(Vector2(x - pixel_size * 0.5, start.y - pixel_size * 0.5), color)
			if (dir_x >= 0.0 and x >= finish.x) or (dir_x <= 0.0 and x <= finish.x):
				break
			x = move_toward(x, finish.x, pixel_size)


func _draw_pixel_block(pos: Vector2, color: Color) -> void:
	var snapped_pos := Vector2(snappedf(pos.x, 1.0), snappedf(pos.y, 1.0))
	draw_rect(Rect2(snapped_pos, Vector2(pixel_size, pixel_size)), color)


func _side_towards(from_pos: Vector2, to_pos: Vector2) -> String:
	var delta := to_pos - from_pos
	if absf(delta.x) >= absf(delta.y):
		return "right" if delta.x >= 0.0 else "left"
	return "down" if delta.y >= 0.0 else "up"


func _position_less(a: Vector2, b: Vector2) -> bool:
	if not is_equal_approx(a.y, b.y):
		return a.y < b.y
	return a.x < b.x


func _port_group_key(level_id: String, side: String) -> String:
	return "%s:%s" % [level_id, side]


func _edge_key(from_id: String, to_id: String) -> String:
	return "%s->%s" % [from_id, to_id]


func _get_level_manager() -> Node:
	return get_node_or_null("/root/LevelManager")


func _is_level_completed(level_id: String) -> bool:
	var level_manager := _get_level_manager()
	return bool(level_manager.call("is_completed", level_id)) if level_manager != null else false
