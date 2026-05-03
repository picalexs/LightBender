extends CanvasLayer

@export var is_in_level: bool = true

const PIXEL_FONT := preload("res://assets/pixelfont.ttf")
const UI_FORM := preload("res://assets/sprites/UI_Form.png")
const BIG_BUTTON := preload("res://assets/sprites/Big_Button.png")
const BIG_BUTTON_HOVER := preload("res://assets/sprites/Big_Button_Hover.png")
const IndicatorSliderScript := preload("res://ui/pause_menu/indicator_slider.gd")
const UI_HIGHLIGHT := preload("res://assets/audio/ui_clicking_3.wav")
const UI_CLICK_1 := preload("res://assets/audio/ui_click_1.wav")
const UI_SLIDER := preload("res://assets/audio/ui_clicking_2.wav")
const UI_SLIDER_VOLUME_DB := -7.5
const UI_SLIDER_REPEAT_COOLDOWN_MS := 55

var _open: bool = false
var _overlay: ColorRect
var _music_slider
var _sfx_slider
var _music_value_label: Label
var _sfx_value_label: Label
var _ui_click_player: AudioStreamPlayer
var _last_slider_sound_time_ms: int = -1000


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _open:
			_close()
		else:
			_show()
		get_viewport().set_input_as_handled()


func _show() -> void:
	_open = true
	_overlay.visible = true
	MusicManager.set_pause_mode(is_in_level)
	BackgroundManager.set_pause_mode(is_in_level)
	if is_in_level:
		get_tree().paused = true
	_sync_slider_values()


func _close() -> void:
	_open = false
	_overlay.visible = false
	MusicManager.set_pause_mode(false)
	BackgroundManager.set_pause_mode(false)
	if is_in_level:
		get_tree().paused = false


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.76)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(860.0, 720.0)
	panel.position = -panel.size * 0.5
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_overlay.add_child(panel)

	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 84)
	mc.add_theme_constant_override("margin_right", 84)
	mc.add_theme_constant_override("margin_top", 64)
	mc.add_theme_constant_override("margin_bottom", 48)
	panel.add_child(mc)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 24)
	mc.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED" if is_in_level else "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(title, 72, Color(1.0, 0.96, 0.80), 3)
	vbox.add_child(title)

	vbox.add_child(_make_rule())

	var btn_resume := _make_button("RESUME" if is_in_level else "CLOSE")
	btn_resume.pressed.connect(_close)
	vbox.add_child(btn_resume)

	var btn_nav := _make_button("LEVEL SELECTOR" if is_in_level else "QUIT GAME", UI_CLICK_1, is_in_level)
	btn_nav.pressed.connect(_on_navigate)
	vbox.add_child(btn_nav)

	vbox.add_child(_make_rule())

	var volume_header := Label.new()
	volume_header.text = "AUDIO"
	volume_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(volume_header, 32, Color(0.86, 0.92, 1.0), 2)
	vbox.add_child(volume_header)

	vbox.add_child(_make_volume_row("MUSIC", true))
	vbox.add_child(_make_volume_row("SFX", false))

	_sync_slider_values()


func _make_panel_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = UI_FORM
	sb.texture_margin_left = 16.0
	sb.texture_margin_top = 16.0
	sb.texture_margin_right = 16.0
	sb.texture_margin_bottom = 16.0
	return sb


func _make_button_style(texture: Texture2D, modulate: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	sb.texture_margin_left = 12.0
	sb.texture_margin_top = 6.0
	sb.texture_margin_right = 12.0
	sb.texture_margin_bottom = 6.0
	sb.modulate_color = modulate
	return sb


func _make_rule() -> HSeparator:
	var sep := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.48, 0.56, 0.74, 0.36)
	ss.content_margin_top = 2.0
	ss.content_margin_bottom = 2.0
	sep.add_theme_stylebox_override("separator", ss)
	return sep


func _make_button(label_text: String, sound_stream: AudioStream = UI_CLICK_1, persistent_sound: bool = false) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 84)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_text(btn, 38, Color(0.96, 0.98, 1.0), 2)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.84, 0.90, 1.0))

	var normal_sb := _make_button_style(BIG_BUTTON, Color(0.82, 0.88, 1.0, 1.0))
	var hover_sb := _make_button_style(BIG_BUTTON_HOVER, Color(1.0, 1.0, 1.0, 1.0))
	var pressed_sb := _make_button_style(BIG_BUTTON_HOVER, Color(0.80, 0.86, 0.96, 1.0))

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size * 0.5)
	_apply_hover_highlight(btn)
	btn.pressed.connect(func() -> void: _play_ui_sound(sound_stream, persistent_sound))
	return btn


func _make_volume_row(label_text: String, is_music: bool) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(124, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_text(lbl, 30, Color(0.86, 0.90, 1.0), 2)
	hbox.add_child(lbl)

	var slider = IndicatorSliderScript.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 92)
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(92, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_text(value_label, 24, Color(1.0, 0.96, 0.82), 2)
	hbox.add_child(value_label)

	if is_music:
		_music_slider = slider
		_music_value_label = value_label
		slider.value_changed.connect(_on_music_slider_changed)
	else:
		_sfx_slider = slider
		_sfx_value_label = value_label
		slider.value_changed.connect(_on_sfx_slider_changed)
	slider.interaction_started.connect(_on_slider_interaction_started)
	slider.hover_started.connect(_on_slider_hover_started)
	slider.step_crossed.connect(_on_slider_step_crossed)

	return row


func _style_text(control: Control, font_size: int, font_color: Color, outline_size: int = 1) -> void:
	control.add_theme_font_override("font", PIXEL_FONT)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", font_color)
	control.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12, 1.0))
	control.add_theme_constant_override("outline_size", outline_size)


func _setup_audio() -> void:
	_ui_click_player = AudioStreamPlayer.new()
	_ui_click_player.bus = "SFX"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_click_player)


func _play_ui_sound(stream: AudioStream, persistent: bool = false, allow_overlap: bool = false, volume_db: float = 0.0) -> void:
	if stream == null:
		return

	if persistent or allow_overlap:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.stream = stream
		player.volume_db = volume_db
		get_tree().root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
		return

	if _ui_click_player == null:
		return
	_ui_click_player.stream = stream
	_ui_click_player.volume_db = volume_db
	_ui_click_player.play()


func _apply_hover_highlight(control: Control) -> void:
	control.mouse_entered.connect(func() -> void:
		_play_ui_sound(UI_HIGHLIGHT, false, true)
		control.scale = Vector2(1.015, 1.015)
		control.modulate = Color(1.04, 1.04, 1.04, 1.0)
	)
	control.mouse_exited.connect(func() -> void:
		control.scale = Vector2.ONE
		control.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func _get_level_manager() -> Node:
	return get_node_or_null("/root/LevelManager")


func _sync_slider_values() -> void:
	var level_manager := _get_level_manager()
	var music_volume := float(level_manager.get("music_volume")) if level_manager != null else 0.8
	var sfx_volume := float(level_manager.get("sfx_volume")) if level_manager != null else 0.8
	if _music_slider != null:
		_music_slider.set_slider_value(music_volume)
		_music_value_label.text = _format_slider_percent(music_volume)
	if _sfx_slider != null:
		_sfx_slider.set_slider_value(sfx_volume)
		_sfx_value_label.text = _format_slider_percent(sfx_volume)


func _format_slider_percent(value: float) -> String:
	return "%d%%" % int(roundf(value * 100.0))


func _on_music_slider_changed(value: float) -> void:
	_music_value_label.text = _format_slider_percent(value)
	var level_manager := _get_level_manager()
	if level_manager != null:
		level_manager.call("set_music_volume", value)


func _on_sfx_slider_changed(value: float) -> void:
	_sfx_value_label.text = _format_slider_percent(value)
	var level_manager := _get_level_manager()
	if level_manager != null:
		level_manager.call("set_sfx_volume", value)


func _on_slider_interaction_started() -> void:
	_play_slider_sound(true)


func _on_slider_hover_started() -> void:
	_play_ui_sound(UI_HIGHLIGHT, false, true)


func _on_slider_step_crossed() -> void:
	_play_slider_sound()


func _play_slider_sound(ignore_cooldown: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if not ignore_cooldown and now - _last_slider_sound_time_ms < UI_SLIDER_REPEAT_COOLDOWN_MS:
		return
	_last_slider_sound_time_ms = now
	_play_ui_sound(UI_SLIDER, false, true, UI_SLIDER_VOLUME_DB)


func _on_navigate() -> void:
	_close()
	if is_in_level:
		_go_to_level_selector()
	else:
		get_tree().quit()


func _go_to_level_selector() -> void:
	var vp_center := get_viewport().get_visible_rect().size * 0.5
	CircleTransition.play_from_screen_position(vp_center)
	await CircleTransition.fully_covered
	get_tree().change_scene_to_file("res://ui/level_selector/level_selector.tscn")
