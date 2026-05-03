extends PanelContainer

@onready var label: Label = $MarginContainer/Label

const BOUND_PROMPT_SCREEN_GAP := 12.0
const BOUNDS_FALLBACK_HALF_SIZE := Vector2(16.0, 16.0)
const MANUAL_PROMPT_FONT_SIZE := 14
const BOUND_PROMPT_FONT_SIZE := 20
const MANUAL_PROMPT_OUTLINE_SIZE := 3
const BOUND_PROMPT_OUTLINE_SIZE := 2

@export_group("Prompt")
@export var prompt_title: String = ""
@export var action_name: String = "lb_select"
@export var action_verb: String = ""
@export var secondary_action_name: String = ""
@export var secondary_action_verb: String = ""

@export_group("Binding")
@export var auto_bind_to_parent_area: bool = true
@export var bind_area_path: NodePath = NodePath("")

var _player_near: bool = false
var _can_interact: bool = true
var _bound_area: Area2D = null
var _bound_light_reactive: Node = null
var _player_ref: Node2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_setup_visual_style()
	hide()
	if auto_bind_to_parent_area:
		_bind_to_configured_area()
	_refresh_prompt_text()


func _process(_delta: float) -> void:
	if _bound_area != null:
		_sync_bound_area_overlap_state()
		_update_bound_prompt_layout()
	elif not top_level:
		var parent_node2d := get_parent() as Node2D
		if parent_node2d != null:
			rotation = -parent_node2d.rotation


func refresh() -> void:
	_refresh_prompt_text()
	_update_visibility()


func configure_prompt(
		title: String,
		primary_action_name: String,
		primary_action_verb: String,
		extra_action_name: String = "",
		extra_action_verb: String = "",
) -> void:
	prompt_title = title
	action_name = primary_action_name
	action_verb = primary_action_verb
	secondary_action_name = extra_action_name
	secondary_action_verb = extra_action_verb
	_refresh_prompt_text()


func show_manual_prompt(
		title: String,
		primary_action_name: String,
		primary_action_verb: String,
		extra_action_name: String = "",
		extra_action_verb: String = "",
) -> void:
	_apply_manual_prompt_text_style()
	configure_prompt(
		title,
		primary_action_name,
		primary_action_verb,
		extra_action_name,
		extra_action_verb,
	)
	_player_near = true
	_can_interact = true
	_update_visibility()


func hide_manual_prompt() -> void:
	_player_near = false
	hide()


func set_screen_anchor_position(
		screen_position: Vector2,
		screen_offset: Vector2 = Vector2(0.0, -42.0),
) -> void:
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_size()
	size = get_combined_minimum_size()
	position = screen_position + screen_offset + Vector2(-size.x * 0.5, -size.y)
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, 8.0, viewport_size.x - size.x - 8.0)
	position.y = clampf(position.y, 8.0, viewport_size.y - size.y - 8.0)


func _bind_to_configured_area() -> void:
	var area: Area2D = null
	if bind_area_path != NodePath(""):
		area = get_node_or_null(bind_area_path) as Area2D
	else:
		var parent := get_parent()
		if parent is Area2D:
			area = parent as Area2D
	_bind_to_area(area)


func _bind_to_area(area: Area2D) -> void:
	if area == null:
		return
	_bound_area = area
	_bound_area.body_entered.connect(_on_body_entered)
	_bound_area.body_exited.connect(_on_body_exited)
	_bound_light_reactive = _bound_area.get_node_or_null("LightReactive")
	if _bound_light_reactive != null and _bound_light_reactive.has_signal("light_state_changed"):
		_bound_light_reactive.light_state_changed.connect(_on_light_state_changed)
		if _bound_light_reactive.has_method("can_interact"):
			_can_interact = bool(_bound_light_reactive.call("can_interact"))
	call_deferred("_sync_bound_area_overlap_state")


func _refresh_prompt_text() -> void:
	if label == null:
		return

	var lines: PackedStringArray = PackedStringArray()
	var primary_line := _make_action_line(action_name, _resolve_action_verb())
	if primary_line != "":
		lines.append(primary_line)

	var secondary_line := _make_action_line(secondary_action_name, secondary_action_verb)
	if secondary_line != "":
		lines.append(secondary_line)

	label.text = "\n".join(lines)
	reset_size()
	size = get_combined_minimum_size()


func _resolve_prompt_title() -> String:
	if prompt_title != "":
		return prompt_title
	if _bound_area != null and _bound_area.has_method("get_interaction_prompt_title"):
		return str(_bound_area.call("get_interaction_prompt_title"))
	if _bound_area != null:
		return _humanize_identifier(_bound_area.name).to_upper()
	return ""


func _resolve_action_verb() -> String:
	if action_verb != "":
		return action_verb
	if _bound_area != null and _bound_area.has_method("get_interaction_prompt_verb"):
		return str(_bound_area.call("get_interaction_prompt_verb"))
	return "interact"


func _make_action_line(input_action_name: String, verb: String) -> String:
	if input_action_name == "":
		return ""
	var key_text := _get_action_key_text(input_action_name)
	if key_text == "":
		key_text = "?"
	if verb == "":
		return "Press [%s]" % key_text
	return "Press [%s] to %s" % [key_text, verb]


func _get_action_key_text(input_action_name: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(input_action_name)
	if events.is_empty():
		return ""

	var event: InputEvent = events[0]
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var keycode: Key = key_event.keycode
		if keycode == KEY_NONE:
			keycode = key_event.physical_keycode
		return OS.get_keycode_string(keycode)

	return event.as_text().get_slice(" (", 0)


func _humanize_identifier(raw_name: String) -> String:
	if raw_name == "":
		return ""
	var humanized := ""
	for i in range(raw_name.length()):
		var character := raw_name.substr(i, 1)
		if i > 0 and character == character.to_upper() and character != character.to_lower():
			var previous := raw_name.substr(i - 1, 1)
			if previous != " " and previous != "_" and previous != "-":
				humanized += " "
		humanized += character
	humanized = humanized.replace("_", " ").replace("-", " ")
	return humanized.strip_edges()


func _setup_visual_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.03, 0.08, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.78, 0.88, 1.0, 0.95)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 5
	panel_style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", panel_style)
	if label != null:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1.0))
	_apply_manual_prompt_text_style()


func _update_visibility() -> void:
	var can_show := _player_near and _can_interact and _can_show_bound_prompt()
	if can_show:
		show()
	else:
		hide()


func _can_show_bound_prompt() -> bool:
	if _bound_area != null and _bound_area.has_method("can_show_interact_prompt"):
		return bool(_bound_area.call("can_show_interact_prompt"))
	return true


func _on_body_entered(body: Node2D) -> void:
	if "Player" in body.name:
		_player_near = true
		_player_ref = body
		_refresh_prompt_text()
		_update_visibility()


func _on_body_exited(body: Node2D) -> void:
	if "Player" in body.name:
		_player_near = false
		_player_ref = null
		_update_visibility()


func _on_light_state_changed(is_in_light: bool) -> void:
	_can_interact = is_in_light
	_update_visibility()


func _sync_bound_area_overlap_state() -> void:
	if _bound_area == null or not is_instance_valid(_bound_area):
		return

	var overlapping_player := _find_player_node()
	if overlapping_player != null and not _is_player_inside_bound_area(overlapping_player):
		overlapping_player = null

	_player_near = overlapping_player != null
	_player_ref = overlapping_player
	_update_visibility()


func _update_bound_prompt_layout() -> void:
	var anchor_node := get_parent() as Node2D
	if anchor_node == null:
		return

	_apply_bound_prompt_text_style()
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	rotation = 0.0
	reset_size()
	size = get_combined_minimum_size()

	var bounds := _get_world_bounds(anchor_node)
	if bounds.size == Vector2.ZERO:
		_set_bound_prompt_screen_anchor(
			anchor_node.global_position - Vector2(0.0, BOUNDS_FALLBACK_HALF_SIZE.y),
		)
		return

	_set_bound_prompt_screen_anchor(Vector2(bounds.get_center().x, bounds.position.y))


func _get_world_bounds(root: Node) -> Rect2:
	var points: Array[Vector2] = []
	_append_world_bound_points(root, points)
	if points.is_empty():
		return Rect2()

	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)

	return Rect2(min_point, max_point - min_point)


func _append_world_bound_points(node: Node, points: Array[Vector2]) -> void:
	if node == self:
		return
	if _bound_area != null and _bound_area != get_parent() and node == _bound_area:
		return

	if node is CollisionShape2D:
		var collision_shape := node as CollisionShape2D
		if not collision_shape.disabled and collision_shape.shape != null:
			_append_transformed_polygon_points(
				collision_shape.global_transform,
				_shape_to_polygon(collision_shape.shape),
				points,
			)
	elif node is CollisionPolygon2D:
		var collision_polygon := node as CollisionPolygon2D
		if not collision_polygon.disabled:
			_append_transformed_polygon_points(
				collision_polygon.global_transform,
				collision_polygon.polygon,
				points,
			)
	elif node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			_append_rect_points(sprite.global_transform, _get_sprite_local_rect(sprite), points)

	for child in node.get_children():
		_append_world_bound_points(child, points)


func _append_rect_points(transform: Transform2D, rect: Rect2, points: Array[Vector2]) -> void:
	if rect.size == Vector2.ZERO:
		return

	var rect_end := rect.position + rect.size
	points.append(transform * rect.position)
	points.append(transform * Vector2(rect_end.x, rect.position.y))
	points.append(transform * rect_end)
	points.append(transform * Vector2(rect.position.x, rect_end.y))


func _append_transformed_polygon_points(
		transform: Transform2D,
		polygon: PackedVector2Array,
		points: Array[Vector2],
) -> void:
	for point in polygon:
		points.append(transform * point)


func _find_player_node() -> Node2D:
	if _player_ref != null and is_instance_valid(_player_ref):
		return _player_ref

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


func _is_player_inside_bound_area(player: Node2D) -> bool:
	if player == null or _bound_area == null or not is_instance_valid(_bound_area):
		return false

	var polygons: Array[PackedVector2Array] = []
	_collect_bound_area_polygons(_bound_area, polygons)
	if polygons.is_empty():
		return player.global_position.distance_to(_bound_area.global_position) <= 24.0

	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(player.global_position, polygon):
			return true

	return false


func _collect_bound_area_polygons(node: Node, polygons: Array[PackedVector2Array]) -> void:
	for child in node.get_children():
		if child is CollisionPolygon2D:
			var collision_polygon := child as CollisionPolygon2D
			if not collision_polygon.disabled and not collision_polygon.polygon.is_empty():
				polygons.append(_to_world_polygon(collision_polygon, collision_polygon.polygon))
			continue

		if child is CollisionShape2D:
			var collision_shape := child as CollisionShape2D
			if collision_shape.disabled or collision_shape.shape == null:
				continue
			var polygon := _shape_to_polygon(collision_shape.shape)
			if not polygon.is_empty():
				polygons.append(_to_world_polygon(collision_shape, polygon))
			continue

		_collect_bound_area_polygons(child, polygons)


func _set_bound_prompt_screen_anchor(world_anchor: Vector2) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var canvas_transform := viewport.get_canvas_transform()
	var screen_anchor := canvas_transform * world_anchor
	var screen_top_left := screen_anchor + Vector2(-size.x * 0.5, -(size.y + BOUND_PROMPT_SCREEN_GAP))
	var viewport_size := get_viewport_rect().size
	screen_top_left.x = clampf(screen_top_left.x, 8.0, viewport_size.x - size.x - 8.0)
	screen_top_left.y = clampf(screen_top_left.y, 8.0, viewport_size.y - size.y - 8.0)
	position = canvas_transform.affine_inverse() * screen_top_left
	scale = _get_inverse_canvas_scale(canvas_transform)


func _get_inverse_canvas_scale(canvas_transform: Transform2D) -> Vector2:
	var canvas_scale := Vector2(canvas_transform.x.length(), canvas_transform.y.length())
	return Vector2(
		1.0 / maxf(canvas_scale.x, 0.001),
		1.0 / maxf(canvas_scale.y, 0.001),
	)


func _to_world_polygon(node: Node2D, local_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon: PackedVector2Array = PackedVector2Array()
	for point in local_polygon:
		world_polygon.append(node.global_transform * point)
	return world_polygon


func _apply_manual_prompt_text_style() -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", MANUAL_PROMPT_FONT_SIZE)
	label.add_theme_constant_override("outline_size", MANUAL_PROMPT_OUTLINE_SIZE)


func _apply_bound_prompt_text_style() -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", BOUND_PROMPT_FONT_SIZE)
	label.add_theme_constant_override("outline_size", BOUND_PROMPT_OUTLINE_SIZE)


func _get_sprite_local_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()

	var frame_columns := maxi(sprite.hframes, 1)
	var frame_rows := maxi(sprite.vframes, 1)
	var frame_size := sprite.texture.get_size() / Vector2(frame_columns, frame_rows)
	var rect_position := sprite.offset
	if sprite.centered:
		rect_position -= frame_size * 0.5

	return Rect2(rect_position, frame_size)


func _shape_to_polygon(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		return PackedVector2Array(
			[
				Vector2(-half_size.x, -half_size.y),
				Vector2(half_size.x, -half_size.y),
				Vector2(half_size.x, half_size.y),
				Vector2(-half_size.x, half_size.y),
			],
		)

	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return _make_circle_polygon(circle.radius, 20)

	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return _make_capsule_polygon(capsule.radius, capsule.height, 10)

	if shape is ConvexPolygonShape2D:
		var convex := shape as ConvexPolygonShape2D
		return convex.points

	return PackedVector2Array()


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _make_capsule_polygon(radius: float, height: float, points_per_cap: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var half_straight_height := maxf((height * 0.5) - radius, 0.0)

	for i in range(points_per_cap + 1):
		var angle := PI + PI * float(i) / float(points_per_cap)
		points.append(
			Vector2(0.0, -half_straight_height) + Vector2(cos(angle), sin(angle)) * radius,
		)

	for i in range(points_per_cap + 1):
		var angle := PI * float(i) / float(points_per_cap)
		points.append(
			Vector2(0.0, half_straight_height) + Vector2(cos(angle), sin(angle)) * radius,
		)

	return points
