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
			"time_scale":     0.629,
			"flow_speed":     0.206,
			"pixel_size":     24.0,
			"noise_scale":    2.000,
			"warp_strength":  2.500,
			"ridge_strength": 0.361,
			"dot_strength":   0.483,
			"color_bg":       Color(0.010, 0.010, 0.022),
			"color_mid":      Color(0.025, 0.042, 0.270),
			"color_bright":   Color(0.100, 0.320, 1.000),
			"brightness":     0.476,
			"vignette_pow":   0.269,
		},
		"active": {
			"time_scale":     0.90,
			"flow_speed":     0.35,
			"pixel_size":     18.0,
			"noise_scale":    2.000,
			"warp_strength":  2.200,
			"ridge_strength": 0.55,
			"dot_strength":   0.75,
			"color_bg":       Color(0.012, 0.012, 0.030),
			"color_mid":      Color(0.060, 0.120, 0.600),
			"color_bright":   Color(0.700, 0.820, 1.000),
			"brightness":     1.80,
			"vignette_pow":   0.20,
		},
		"level_complete": {
			"time_scale":     1.30,
			"flow_speed":     0.48,
			"pixel_size":     22.0,
			"noise_scale":    2.200,
			"warp_strength":  2.800,
			"ridge_strength": 0.55,
			"dot_strength":   0.55,
			"color_bg":       Color(0.010, 0.022, 0.010),
			"color_mid":      Color(0.022, 0.200, 0.065),
			"color_bright":   Color(0.180, 0.920, 0.380),
			"brightness":     0.80,
			"vignette_pow":   0.25,
		},
		"death": {
			"time_scale":     1.40,
			"flow_speed":     0.50,
			"pixel_size":     24.0,
			"noise_scale":    4.000,
			"warp_strength":  2.000,
			"ridge_strength": 0.65,
			"dot_strength":   0.20,
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
			"pixel_size":     22.0,
			"noise_scale":    2.200,
			"warp_strength":  2.20,  # drives subtle border undulation (coeff 0.18)
			"ridge_strength": 0.75,  # border lines are the primary bright accent
			"dot_strength":   0.08,  # tiny center spark, barely visible
			"color_bg":       Color(0.002, 0.006, 0.010),
			"color_mid":      Color(0.005, 0.055, 0.065),
			"color_bright":   Color(0.040, 0.920, 0.820),
			"brightness":     0.58,
			"vignette_pow":   0.40,
		},
		"active": {
			"time_scale":     0.80,
			"flow_speed":     0.35,
			"pixel_size":     16.0,
			"noise_scale":    2.400,
			"warp_strength":  3.00,
			"ridge_strength": 1.00,
			"dot_strength":   0.18,
			"color_bg":       Color(0.003, 0.008, 0.012),
			"color_mid":      Color(0.008, 0.080, 0.090),
			"color_bright":   Color(0.060, 1.000, 0.900),
			"brightness":     1.20,
			"vignette_pow":   0.22,
		},
		"level_complete": {
			"time_scale":     1.35,
			"flow_speed":     0.50,
			"pixel_size":     20.0,
			"noise_scale":    2.200,
			"warp_strength":  3.20,
			"ridge_strength": 0.90,
			"dot_strength":   0.10,
			"color_bg":       Color(0.005, 0.010, 0.002),
			"color_mid":      Color(0.030, 0.090, 0.010),
			"color_bright":   Color(0.400, 0.920, 0.040),
			"brightness":     0.70,
			"vignette_pow":   0.35,
		},
		"death": {
			"time_scale":     1.50,
			"flow_speed":     0.55,
			"pixel_size":     22.0,
			"noise_scale":    3.000,
			"warp_strength":  3.50,
			"ridge_strength": 0.90,
			"dot_strength":   0.10,
			"color_bg":       Color(0.015, 0.003, 0.001),
			"color_mid":      Color(0.140, 0.012, 0.005),
			"color_bright":   Color(0.950, 0.120, 0.020),
			"brightness":     0.45,
			"vignette_pow":   0.80,
		},
	},

	# ── Chapter 3: Lava Lamp Metaballs ─ dark purple, hot-pink blobs ──────────
	3: {
		"idle": {
			"time_scale":     0.45,
			"flow_speed":     0.16,
			"pixel_size":     24.0,
			"noise_scale":    2.000,
			"warp_strength":  2.00,
			"ridge_strength": 0.55,
			"dot_strength":   0.38,
			"color_bg":       Color(0.010, 0.003, 0.018),
			"color_mid":      Color(0.110, 0.012, 0.180),
			"color_bright":   Color(0.960, 0.090, 0.820),
			"brightness":     0.62,
			"vignette_pow":   0.38,
		},
		"active": {
			"time_scale":     0.75,
			"flow_speed":     0.28,
			"pixel_size":     18.0,
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
			"pixel_size":     22.0,
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
			"pixel_size":     24.0,
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

# Pulse state
var _pulse_strength: float = 0.0
var _pulse_brightness: float = 0.0
var _pulse_pos: Vector2 = Vector2(0.5, 0.5)


func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.size = get_viewport().get_visible_rect().size

	_material = ShaderMaterial.new()
	rect.material = _material

	set_chapter(1)


func set_chapter(n: int) -> void:
	if n == _current_chapter:
		return
	_current_chapter = n
	_material.shader = load(CHAPTER_SHADERS[n]) as Shader
	_presets = ALL_PRESETS[n]

	# Reset pulse params — they live on the shader and are lost after a swap
	_material.set_shader_parameter("pulse_pos_x", _pulse_pos.x)
	_material.set_shader_parameter("pulse_pos_y", _pulse_pos.y)
	_material.set_shader_parameter("pulse_strength", 0.0)
	_material.set_shader_parameter("pulse_brightness", 0.0)

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


func _process(delta: float) -> void:
	for key: String in _target_state:
		var from = _current_state[key]
		var to = _target_state[key]
		_current_state[key] = from.lerp(to, _lerp_speed * delta) if from is Color \
						else lerpf(from, to, _lerp_speed * delta)
	_apply(_current_state)

	if _pulse_strength > 0.0 or _pulse_brightness > 0.0:
		_pulse_strength = max(0.0, _pulse_strength - pulse_decay_speed * delta)
		_pulse_brightness = max(0.0, _pulse_brightness - pulse_decay_speed * 2.0 * delta)
		_material.set_shader_parameter("pulse_strength", _pulse_strength)
		_material.set_shader_parameter("pulse_brightness", _pulse_brightness)


func _apply(p: Dictionary) -> void:
	for key: String in p:
		_material.set_shader_parameter(key, p[key])


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

	_material.set_shader_parameter("pulse_pos_x", _pulse_pos.x)
	_material.set_shader_parameter("pulse_pos_y", _pulse_pos.y)
	_material.set_shader_parameter("pulse_strength", _pulse_strength)
	_material.set_shader_parameter("pulse_brightness", _pulse_brightness)
