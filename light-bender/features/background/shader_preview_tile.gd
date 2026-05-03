extends PanelContainer

@export var preview_title: String = "Shader Preview"
@export_file("*.gdshader") var shader_path: String = ""
@export var viewport_size: Vector2i = Vector2i(320, 180)

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _path_label: Label = $MarginContainer/VBoxContainer/PathLabel
@onready var _sub_viewport_container: SubViewportContainer = $MarginContainer/VBoxContainer/SubViewportContainer
@onready var _sub_viewport: SubViewport = $MarginContainer/VBoxContainer/SubViewportContainer/SubViewport
@onready var _preview_rect: ColorRect = $MarginContainer/VBoxContainer/SubViewportContainer/SubViewport/PreviewRect


func _ready() -> void:
	_apply_theme()
	_setup_labels()
	_setup_viewport()
	_setup_material()


func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.050, 0.060, 0.100, 0.96)
	panel_style.border_color = Color(0.260, 0.410, 0.720, 0.90)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", panel_style)

	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.920, 0.960, 1.000))

	_path_label.add_theme_font_size_override("font_size", 12)
	_path_label.add_theme_color_override("font_color", Color(0.670, 0.740, 0.860))


func _setup_labels() -> void:
	_title_label.text = preview_title
	_path_label.text = shader_path


func _setup_viewport() -> void:
	var safe_size := Vector2i(maxi(viewport_size.x, 1), maxi(viewport_size.y, 1))
	_sub_viewport_container.stretch = true
	_sub_viewport_container.custom_minimum_size = Vector2(safe_size.x, safe_size.y)
	_sub_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sub_viewport.size = safe_size
	_sub_viewport.disable_3d = true
	_sub_viewport.transparent_bg = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_rect.size = Vector2(safe_size.x, safe_size.y)


func _setup_material() -> void:
	if shader_path.is_empty():
		return

	var shader := load(shader_path) as Shader
	if shader == null:
		push_warning("Could not load shader: %s" % shader_path)
		return

	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = shader
	_preview_rect.material = material
