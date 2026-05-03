extends CanvasLayer

@export_group("Pulse")
@export var pulse_strength_max: float = 0.8
@export var pulse_brightness_max: float = 1.5
@export var pulse_decay_speed: float = 3.0
@export var pulse_duration: float = 0.3

const CHAPTER_SHADERS: Dictionary = {
	1: "res://features/background/background_ch1.gdshader",
	2: "res://features/background/background_ch2.gdshader",
	3: "res://features/background/background_ch3.gdshader",
}

# Each chapter has its own idle/active/level_complete/death presets.
# All float/Color keys must match across chapters — _apply() uses them blindly.
const ALL_PRESETS: Dictionary = {
	# ── Chapter 1: Organic Fluid ─ deep blue/purple, smooth blobs ────────────
	1: {
		"idle": {
			"time_scale":     0.50,
			"flow_speed":     0.30,
			"pixel_size":     6.0,
			"noise_scale":    2.800,
			"warp_strength":  2.500,
			"ridge_strength": 0.35,
			"dot_strength":   0.55,
			"color_bg":       Color(0.004, 0.006, 0.024),
			"color_mid":      Color(0.080, 0.105, 0.500),
			"color_bright":   Color(0.290, 0.390, 0.930),
			"brightness":     0.75,
			"vignette_pow":   0.50,
		},
		"active": {
			"time_scale":     0.62,
			"flow_speed":     0.32,
			"pixel_size":     3.4,
			"noise_scale":    2.000,
			"warp_strength":  2.100,
			"ridge_strength": 0.55,
			"dot_strength":   0.62,
			"color_bg":       Color(0.012, 0.012, 0.030),
			"color_mid":      Color(0.060, 0.120, 0.600),
			"color_bright":   Color(0.700, 0.820, 1.000),
			"brightness":     1.80,
			"vignette_pow":   0.20,
		},
		"level_complete": {
			"time_scale":     0.78,
			"flow_speed":     0.38,
			"pixel_size":     4.1,
			"noise_scale":    2.200,
			"warp_strength":  2.450,
			"ridge_strength": 0.55,
			"dot_strength":   0.42,
			"color_bg":       Color(0.010, 0.022, 0.010),
			"color_mid":      Color(0.022, 0.200, 0.065),
			"color_bright":   Color(0.180, 0.920, 0.380),
			"brightness":     0.80,
			"vignette_pow":   0.25,
		},
		"death": {
			"time_scale":     0.88,
			"flow_speed":     0.40,
			"pixel_size":     4.5,
			"noise_scale":    3.200,
			"warp_strength":  1.700,
			"ridge_strength": 0.65,
			"dot_strength":   0.14,
			"color_bg":       Color(0.025, 0.008, 0.008),
			"color_mid":      Color(0.240, 0.022, 0.022),
			"color_bright":   Color(0.920, 0.160, 0.060),
			"brightness":     0.55,
			"vignette_pow":   0.80,
		},
	},

	# ── Chapter 2: Square Cell Liquid ─ near-black base, electric cyan grid lines ─
	2: {
		"idle": {
			"time_scale":     0.50,
			"flow_speed":     0.20,
			"pixel_size":     4.1,
			"noise_scale":    2.200,
			"warp_strength":  2.20,  # drives subtle border undulation (coeff 0.18)
			"ridge_strength": 0.75,  # border lines are the primary bright accent
			"dot_strength":   0.08,  # tiny center spark, barely visible
			"color_bg":       Color(0.004, 0.010, 0.016),
			"color_mid":      Color(0.012, 0.082, 0.096),
			"color_bright":   Color(0.120, 0.960, 0.880),
			"brightness":     0.94,
			"vignette_pow":   0.34,
		},
		"active": {
			"time_scale":     0.80,
			"flow_speed":     0.35,
			"pixel_size":     3.0,
			"noise_scale":    2.400,
			"warp_strength":  3.00,
			"ridge_strength": 1.00,
			"dot_strength":   0.18,
			"color_bg":       Color(0.005, 0.012, 0.018),
			"color_mid":      Color(0.016, 0.105, 0.116),
			"color_bright":   Color(0.160, 1.000, 0.930),
			"brightness":     1.62,
			"vignette_pow":   0.20,
		},
		"level_complete": {
			"time_scale":     1.35,
			"flow_speed":     0.50,
			"pixel_size":     3.75,
			"noise_scale":    2.200,
			"warp_strength":  3.20,
			"ridge_strength": 0.90,
			"dot_strength":   0.14,
			"color_bg":       Color(0.008, 0.016, 0.004),
			"color_mid":      Color(0.050, 0.126, 0.022),
			"color_bright":   Color(0.560, 0.980, 0.120),
			"brightness":     1.16,
			"vignette_pow":   0.28,
		},
		"death": {
			"time_scale":     1.50,
			"flow_speed":     0.55,
			"pixel_size":     4.1,
			"noise_scale":    3.000,
			"warp_strength":  3.50,
			"ridge_strength": 0.90,
			"dot_strength":   0.14,
			"color_bg":       Color(0.026, 0.004, 0.004),
			"color_mid":      Color(0.240, 0.028, 0.024),
			"color_bright":   Color(1.000, 0.180, 0.120),
			"brightness":     0.92,
			"vignette_pow":   0.58,
		},
	},

	# ── Chapter 3: Lava Lamp Metaballs ─ dark purple, hot-pink blobs ──────────
	3: {
		"idle": {
			"time_scale":     0.50,
			"flow_speed":     0.30,
			"pixel_size":     6.0,
			"noise_scale":    3.000,
			"warp_strength":  2.50,
			"ridge_strength": 0.50,
			"dot_strength":   0.60,
			"color_bg":       Color(0.010, 0.002, 0.018),
			"color_mid":      Color(0.190, 0.030, 0.300),
			"color_bright":   Color(0.920, 0.090, 0.760),
			"brightness":     0.75,
			"vignette_pow":   0.50,
		},
		"active": {
			"time_scale":     0.75,
			"flow_speed":     0.28,
			"pixel_size":     3.4,
			"noise_scale":    2.200,
			"warp_strength":  2.50,
			"ridge_strength": 0.80,
			"dot_strength":   0.55,
			"color_bg":       Color(0.013, 0.004, 0.022),
			"color_mid":      Color(0.160, 0.018, 0.240),
			"color_bright":   Color(1.000, 0.150, 0.880),
			"brightness":     1.65,
			"vignette_pow":   0.22,
		},
		"level_complete": {
			"time_scale":     1.45,
			"flow_speed":     0.48,
			"pixel_size":     4.1,
			"noise_scale":    2.200,
			"warp_strength":  3.00,
			"ridge_strength": 0.70,
			"dot_strength":   0.42,
			"color_bg":       Color(0.004, 0.014, 0.010),
			"color_mid":      Color(0.018, 0.150, 0.090),
			"color_bright":   Color(0.060, 0.960, 0.520),
			"brightness":     0.85,
			"vignette_pow":   0.30,
		},
		"death": {
			"time_scale":     1.60,
			"flow_speed":     0.50,
			"pixel_size":     4.5,
			"noise_scale":    2.400,
			"warp_strength":  3.00,
			"ridge_strength": 0.75,
			"dot_strength":   0.28,
			"color_bg":       Color(0.018, 0.002, 0.010),
			"color_mid":      Color(0.260, 0.008, 0.080),
			"color_bright":   Color(0.980, 0.030, 0.350),
			"brightness":     0.55,
			"vignette_pow":   0.80,
		},
	},
}

var _material: ShaderMaterial
var _current_state: Dictionary = {}
var _target_state: Dictionary = {}
var _lerp_speed: float = 2.0
var _current_chapter: int = 0
var _current_state_name: String = "idle"
var _presets: Dictionary = {}
var _applied_parameters: Dictionary = {}

# Pulse state
var _pulse_strength: float = 0.0
var _pulse_brightness: float = 0.0
var _pulse_pos: Vector2 = Vector2(0.5, 0.5)


func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)

	var sub_vp := SubViewport.new()
	sub_vp.size = Vector2i(240, 135)
	sub_vp.transparent_bg = false
	sub_vp.disable_3d = true
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(sub_vp)

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub_vp.add_child(rect)

	_material = ShaderMaterial.new()
	rect.material = _material

	set_chapter(1)


func set_chapter(n: int) -> void:
	if n == _current_chapter:
		return
	_current_chapter = n
	_material.shader = load(CHAPTER_SHADERS[n]) as Shader
	_presets = ALL_PRESETS[n]
	_applied_parameters.clear()

	# Reset pulse params — they live on the shader and are lost after a swap
	_set_shader_parameter("pulse_pos_x", _pulse_pos.x, true)
	_set_shader_parameter("pulse_pos_y", _pulse_pos.y, true)
	_set_shader_parameter("pulse_strength", 0.0, true)
	_set_shader_parameter("pulse_brightness", 0.0, true)

	# Snap (no lerp) to this chapter's version of whatever state we're in
	var snap: Dictionary = _presets.get(_current_state_name, _presets["idle"])
	_current_state = snap.duplicate(false)
	_target_state = _current_state.duplicate(false)
	_apply(_current_state)


func set_state(state_name: String, speed: float = 2.0) -> void:
	if not _presets.has(state_name):
		push_warning("BackgroundManager: unknown state '%s'" % state_name)
		return
	_current_state_name = state_name
	_target_state = _presets[state_name].duplicate(false)
	_lerp_speed = speed


func snap_to_state(state_name: String) -> void:
	if not _presets.has(state_name):
		push_warning("BackgroundManager: unknown state '%s'" % state_name)
		return
	_current_state_name = state_name
	_current_state = _presets[state_name].duplicate(false)
	_target_state = _current_state.duplicate(false)
	_apply(_current_state)


func _process(delta: float) -> void:
	for key: String in _target_state:
		var from = _current_state[key]
		var to = _target_state[key]
		var next = _get_next_state_value(from, to, delta)
		if next == _current_state[key]:
			continue
		_current_state[key] = next
		_set_shader_parameter(key, next)

	if _pulse_strength > 0.0 or _pulse_brightness > 0.0:
		var next_pulse_strength: float = maxf(0.0, _pulse_strength - pulse_decay_speed * delta)
		var next_pulse_brightness: float = maxf(0.0, _pulse_brightness - pulse_decay_speed * 2.0 * delta)
		if next_pulse_strength != _pulse_strength:
			_pulse_strength = next_pulse_strength
			_set_shader_parameter("pulse_strength", _pulse_strength)
		if next_pulse_brightness != _pulse_brightness:
			_pulse_brightness = next_pulse_brightness
			_set_shader_parameter("pulse_brightness", _pulse_brightness)


func _apply(p: Dictionary) -> void:
	for key: String in p:
		_set_shader_parameter(key, p[key], true)


func trigger_pulse(screen_pos: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var viewport = get_viewport()
	if viewport == null:
		return

	var viewport_size = viewport.get_visible_rect().size

	if screen_pos.x < 0.0:
		screen_pos = viewport_size * 0.5

	_pulse_pos = screen_pos / viewport_size
	_pulse_strength = pulse_strength_max
	_pulse_brightness = pulse_brightness_max

	_set_shader_parameter("pulse_pos_x", _pulse_pos.x)
	_set_shader_parameter("pulse_pos_y", _pulse_pos.y)
	_set_shader_parameter("pulse_strength", _pulse_strength)
	_set_shader_parameter("pulse_brightness", _pulse_brightness)


func _get_next_state_value(from: Variant, to: Variant, delta: float) -> Variant:
	if from is Color and to is Color:
		var from_color := from as Color
		var to_color := to as Color
		if _colors_are_close(from_color, to_color):
			return to_color
		var next_color := from_color.lerp(to_color, _lerp_speed * delta)
		return to_color if _colors_are_close(next_color, to_color) else next_color

	var from_float := float(from)
	var to_float := float(to)
	if is_equal_approx(from_float, to_float) or absf(from_float - to_float) <= 0.001:
		return to_float
	var next_float := lerpf(from_float, to_float, _lerp_speed * delta)
	return to_float if absf(next_float - to_float) <= 0.001 else next_float


func _colors_are_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 0.001 \
		and absf(a.g - b.g) <= 0.001 \
		and absf(a.b - b.b) <= 0.001 \
		and absf(a.a - b.a) <= 0.001


func _set_shader_parameter(key: String, value: Variant, force: bool = false) -> void:
	if not force and _applied_parameters.has(key) and _applied_parameters[key] == value:
		return
	_material.set_shader_parameter(key, value)
	_applied_parameters[key] = value
