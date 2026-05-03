extends Control

const PreviewTileScene := preload("res://features/background/shader_preview_tile.tscn")
const PREVIEW_SHADERS := [
	{
		"title": "Base Background",
		"path": "res://features/background/background.gdshader",
	},
	{
		"title": "Chapter 1",
		"path": "res://features/background/background_ch1.gdshader",
	},
	{
		"title": "Chapter 2",
		"path": "res://features/background/background_ch2.gdshader",
	},
	{
		"title": "Chapter 3",
		"path": "res://features/background/background_ch3.gdshader",
	},
	{
		"title": "Menu Background",
		"path": "res://features/background/background_menu.gdshader",
	},
]

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _help_label: Label = $MarginContainer/VBoxContainer/HelpLabel
@onready var _preview_grid: GridContainer = $MarginContainer/VBoxContainer/PreviewGrid


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_labels()
	_build_previews()
	_update_grid_columns()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_grid_columns()


func _style_labels() -> void:
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.940, 0.970, 1.000))
	_help_label.add_theme_font_size_override("font_size", 14)
	_help_label.add_theme_color_override("font_color", Color(0.760, 0.820, 0.900))
	_help_label.text = "Run this scene with F6. While it is running, open the Remote tree, pick a PreviewRect, then tweak Material > Shader Parameters. Each tile has its own ShaderMaterial."


func _build_previews() -> void:
	for child in _preview_grid.get_children():
		child.queue_free()

	for shader_data: Dictionary in PREVIEW_SHADERS:
		var preview = PreviewTileScene.instantiate()
		preview.name = "%sPreview" % shader_data["title"].replace(" ", "")
		preview.preview_title = shader_data["title"]
		preview.shader_path = shader_data["path"]
		preview.viewport_size = Vector2i(320, 180)
		_preview_grid.add_child(preview)


func _update_grid_columns() -> void:
	var width := size.x
	if width >= 1700.0:
		_preview_grid.columns = 3
	elif width >= 1050.0:
		_preview_grid.columns = 2
	else:
		_preview_grid.columns = 1
