extends CanvasLayer

# ── Usage ─────────────────────────────────────────────────────────────────────
# BackgroundManager.set_state("idle")           - default
# BackgroundManager.set_state("active")         - ability / interaction
# BackgroundManager.set_state("level_complete") - door reached
# BackgroundManager.set_state("death")          - player died
#
# Add new states by adding entries to PRESETS — all keys lerp automatically.
# ──────────────────────────────────────────────────────────────────────────────

const PRESETS: Dictionary = {

	# Values matched from editor tuning session
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

	# Same blue hue but blown out toward white, slightly faster
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

	# Green, bigger shapes (smaller noise_scale), slower movement
	"level_complete": {
		"time_scale":     0.38,
		"flow_speed":     0.10,
		"pixel_size":     36.0,
		"noise_scale":    1.400,
		"warp_strength":  2.800,
		"ridge_strength": 0.38,
		"dot_strength":   0.50,
		"color_bg":       Color(0.010, 0.022, 0.010),
		"color_mid":      Color(0.022, 0.200, 0.065),
		"color_bright":   Color(0.180, 0.920, 0.380),
		"brightness":     0.55,
		"vignette_pow":   0.25,
	},

	# Red, smaller shapes (bigger noise_scale), faster chaotic movement
	"death": {
		"time_scale":     1.40,
		"flow_speed":     0.70,
		"pixel_size":     12.0,
		"noise_scale":    4.000,
		"warp_strength":  2.000,
		"ridge_strength": 0.65,
		"dot_strength":   0.20,
		"color_bg":       Color(0.025, 0.008, 0.008),
		"color_mid":      Color(0.240, 0.022, 0.022),
		"color_bright":   Color(0.920, 0.160, 0.060),
		"brightness":     0.55,
		"vignette_pow":   0.60,
	},
}

var _material: ShaderMaterial
var _current: Dictionary = {}
var _target: Dictionary = {}
var _lerp_speed: float = 2.0


func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.size = get_viewport().get_visible_rect().size

	var shader := load("res://features/background/background.gdshader") as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader
	rect.material = _material

	_current = _copy(PRESETS["idle"])
	_target  = _copy(PRESETS["idle"])
	_apply(_current)


func set_state(state_name: String, speed: float = 2.0) -> void:
	if not PRESETS.has(state_name):
		push_warning("BackgroundManager: unknown state '%s'" % state_name)
		return
	_target = _copy(PRESETS[state_name])
	_lerp_speed = speed


func _process(delta: float) -> void:
	for key: String in _target:
		var from = _current[key]
		var to   = _target[key]
		_current[key] = from.lerp(to, _lerp_speed * delta) if from is Color \
						else lerpf(from, to, _lerp_speed * delta)
	_apply(_current)


func _apply(p: Dictionary) -> void:
	for key: String in p:
		_material.set_shader_parameter(key, p[key])


func _copy(d: Dictionary) -> Dictionary:
	var c := {}
	for k in d:
		c[k] = d[k]
	return c
