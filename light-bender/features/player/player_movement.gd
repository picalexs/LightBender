extends CharacterBody2D

const DASH_ACTION := "dash"

signal jump_performed(kind: StringName)
signal dash_performed
signal wall_slide_state_changed(is_sliding: bool)

# ── Movement ──────────────────────────────────────────────────────────────────
@export_group("Movement")
@export var move_speed: float = 160.0
@export var acceleration: float = 18.0
@export var deceleration: float = 26.0
@export var accel_in_air: float = 0.5
@export var decel_in_air: float = 0.65
@export var velocity_power: float = 1.0
@export var friction: float = 1.0
@export var conserve_momentum: bool = true

# ── Jump ──────────────────────────────────────────────────────────────────────
@export_group("Jump")
@export var jump_force: float = 300.0
@export_range(0.0, 1.0) var jump_cut_mult: float = 0.15
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15
@export var max_air_jumps: int = 1
@export var double_jump_force: float = 280.0

# ── Slow Fall ────────────────────────────────────────────────────────────────
@export_group("Slow Fall")
@export var slow_fall_gravity_mult: float = 0.32
@export var slow_fall_max_speed: float = 70.0

# ── Apex Feel ─────────────────────────────────────────────────────────────────
@export_group("Jump Feel")
@export var jump_hang_threshold: float = 15.0
@export var jump_hang_accel_mult: float = 4.0
@export var jump_hang_gravity_mult: float = 0.3

# ── Gravity ───────────────────────────────────────────────────────────────────
@export_group("Gravity")
@export var gravity_mult: float = 1.0
@export var fall_gravity_mult: float = 1.7
@export var fast_fall_gravity_mult: float = 2.4
@export var max_fall_speed: float = 240.0
@export var max_fast_fall_speed: float = 400.0

# ── Abilities ─────────────────────────────────────────────────────────────────
@export_group("Abilities")
@export var abilities: PlayerAbilities

# ── Dash ──────────────────────────────────────────────────────────────────────
@export_group("Dash")
@export var dash_speed: float = 360.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.55
@export var dash_zero_vertical_velocity: bool = true
@export var dash_end_speed_mult: float = 0.6
@export var enable_dash_trail: bool = true

# ── Wall Movement ─────────────────────────────────────────────────────────────
@export_group("Wall Movement")
@export var wall_slide_speed: float = 28.0
@export var wall_slide_accel: float = 900.0
@export var wall_jump_force: float = 300.0
@export var wall_jump_horizontal_force: float = 210.0
@export var wall_jump_lock_time: float = 0.12
@export var wall_probe_distance: float = 2.0

# ── Private state ─────────────────────────────────────────────────────────────
var _facing_right: bool = true
var _is_jumping: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _wall_jump_lock_timer: float = 0.0
var _wall_normal: Vector2 = Vector2.ZERO
var _air_jumps_left: int = 0
var _slow_fall_armed: bool = false
var _was_wall_sliding: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _trail_effect = get_node_or_null("TrailEffect")


func _ready() -> void:
	_ensure_abilities()
	_refill_air_jumps()
	_update_dash_trail_state()


func _ensure_abilities() -> void:
	if abilities == null:
		abilities = PlayerAbilities.new()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_jump_buffer_timer = jump_buffer_time
		if _can_arm_slow_fall_on_jump_press():
			_slow_fall_armed = true
	if event.is_action_pressed(DASH_ACTION):
		_try_dash()
	elif event.is_action_released("ui_accept") and _is_jumping and velocity.y < 0.0:
		# Variable jump height: cut upward velocity on early release
		velocity.y *= jump_cut_mult
		_is_jumping = false
	if event.is_action_released("ui_accept"):
		_slow_fall_armed = false


func _physics_process(delta: float) -> void:
	var was_dashing := _is_dashing()
	var on_floor := is_on_floor()
	_tick_timers(delta, on_floor)
	_refresh_wall_contact()
	if was_dashing and not _is_dashing():
		_apply_post_dash_velocity()
	_update_dash_trail_state()

	if _is_dashing():
		_emit_wall_slide_state(false)
		velocity = _dash_direction * dash_speed
		move_and_slide()
		_refresh_wall_contact()
		return

	_apply_gravity(delta, on_floor)
	_try_jump()
	_apply_wall_slide(delta, on_floor)
	_apply_movement(delta, on_floor)
	_update_facing()
	move_and_slide()
	_refresh_wall_contact()
	_emit_wall_slide_state(_is_wall_sliding_now())
	if is_on_floor() and velocity.y >= 0.0:
		_is_jumping = false
		_refill_air_jumps()
		_slow_fall_armed = false


# Counts down coyote window and jump buffer each frame; resets coyote on landing.
func _tick_timers(delta: float, on_floor: bool) -> void:
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	_jump_buffer_timer -= delta
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
	_wall_jump_lock_timer = maxf(0.0, _wall_jump_lock_timer - delta)


# Scales gravity based on movement phase: apex hang, fast fall, normal fall, or grounded.
func _apply_gravity(delta: float, on_floor: bool) -> void:
	if on_floor or _is_dashing():
		return

	var g_mult := gravity_mult

	if _is_jumping and velocity.y < 0.0 and absf(velocity.y) < jump_hang_threshold:
		# Near apex: lighter gravity for a floaty hang
		g_mult = gravity_mult * jump_hang_gravity_mult
	elif velocity.y > 0.0:
		# Falling
		if Input.is_action_pressed("ui_down"):
			g_mult = gravity_mult * fast_fall_gravity_mult
			velocity.y = minf(velocity.y, max_fast_fall_speed)
		elif _can_slow_fall():
			g_mult = gravity_mult * slow_fall_gravity_mult
			velocity.y = minf(velocity.y, slow_fall_max_speed)
		else:
			g_mult = gravity_mult * fall_gravity_mult
			velocity.y = minf(velocity.y, max_fall_speed)

	velocity += get_gravity() * g_mult * delta


# Fires a jump when both the input buffer and the coyote window are active.
func _try_jump() -> void:
	# Jump can only happen after a real jump press
	if _jump_buffer_timer <= 0.0:
		return

	if _coyote_timer > 0.0:
		_do_ground_jump()
		return

	if _can_wall_jump():
		_do_wall_jump()
		return

	if _can_double_jump():
		_do_double_jump()


func _do_ground_jump() -> void:
	velocity.y = -jump_force
	_is_jumping = true
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jump_performed.emit(&"ground")
	# No release event will come, so apply the cut right now.
	if not Input.is_action_pressed("ui_accept"):
		velocity.y *= jump_cut_mult
		_is_jumping = false


func _do_wall_jump() -> void:
	var jump_normal_x := _wall_normal.x
	if absf(jump_normal_x) < 0.01:
		jump_normal_x = -1.0 if _facing_right else 1.0

	velocity.x = jump_normal_x * wall_jump_horizontal_force
	velocity.y = -wall_jump_force
	_is_jumping = true
	_wall_jump_lock_timer = wall_jump_lock_time
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jump_performed.emit(&"wall")


func _do_double_jump() -> void:
	velocity.y = -double_jump_force
	_is_jumping = true
	_jump_buffer_timer = 0.0
	_air_jumps_left = max(0, _air_jumps_left - 1)
	jump_performed.emit(&"double")
	if not Input.is_action_pressed("ui_accept"):
		velocity.y *= jump_cut_mult
		_is_jumping = false


# Physics-based acceleration / deceleration with optional momentum conservation and friction.
func _apply_movement(delta: float, on_floor: bool) -> void:
	if _is_dashing():
		return

	var dir := Input.get_axis("ui_left", "ui_right")
	var target_speed := dir * move_speed

	var accel_rate: float
	if on_floor:
		accel_rate = acceleration if absf(target_speed) > 0.01 else deceleration
	else:
		if absf(target_speed) > 0.01:
			accel_rate = acceleration * accel_in_air
		else:
			accel_rate = deceleration * decel_in_air

	# At the apex: snappier acceleration only — no speed-target boost to avoid
	# the apex multiplier locking in a higher speed via momentum conservation.
	if _is_jumping and absf(velocity.y) < jump_hang_threshold:
		accel_rate *= jump_hang_accel_mult

	# Preserve speed when already moving faster than input in the same direction (air only)
	if conserve_momentum \
	and not on_floor \
	and absf(velocity.x) > absf(target_speed) \
	and signf(velocity.x) == signf(target_speed) \
	and absf(target_speed) > 0.01:
		accel_rate = 0.0

	# Raw Euler (velocity.x += step * delta) overshoots when accel_rate * delta > 1.
	var speed_dif := target_speed - velocity.x
	var step := pow(absf(speed_dif) * accel_rate, velocity_power) * delta
	velocity.x = move_toward(velocity.x, target_speed, step)

	# Ground friction when idle
	if on_floor and absf(dir) < 0.01:
		var fric := minf(absf(velocity.x), friction)
		velocity.x -= signf(velocity.x) * fric


func _apply_wall_slide(delta: float, on_floor: bool) -> void:
	if on_floor or not _can_wall_slide():
		return
	if velocity.y <= 0.0:
		return

	var slowed := move_toward(velocity.y, wall_slide_speed, wall_slide_accel * delta)
	velocity.y = minf(slowed, wall_slide_speed)


func _is_pressing_toward_wall() -> bool:
	var dir := Input.get_axis("ui_left", "ui_right")
	if absf(dir) < 0.01:
		return false
	return dir * _wall_normal.x < -0.1


func _can_wall_slide() -> bool:
	if abilities == null or not abilities.can_wall_slide:
		return false
	if _wall_jump_lock_timer > 0.0:
		return false
	if _wall_normal == Vector2.ZERO or is_on_floor():
		return false
	return _is_pressing_toward_wall()


func _can_wall_jump() -> bool:
	if abilities == null or not abilities.can_wall_jump:
		return false
	if _wall_jump_lock_timer > 0.0:
		return false
	if is_on_floor() or _wall_normal == Vector2.ZERO:
		return false
	return true


func _can_double_jump() -> bool:
	if abilities == null or not abilities.can_double_jump:
		return false
	if is_on_floor() or _is_dashing():
		return false
	return _air_jumps_left > 0


func _can_slow_fall() -> bool:
	if abilities == null or not abilities.can_slow_fall:
		return false
	if is_on_floor() or _is_dashing() or velocity.y <= 0.0:
		return false
	if not _slow_fall_armed:
		return false
	if _can_wall_slide():
		return false
	return Input.is_action_pressed("ui_accept")


func _can_arm_slow_fall_on_jump_press() -> bool:
	if abilities == null or not abilities.can_slow_fall:
		return false
	if is_on_floor() or _is_dashing():
		return false
	if _can_wall_slide():
		return false
	# If double jump exists, slow-fall can only be armed after it is spent.
	if abilities.can_double_jump and max_air_jumps > 0 and _air_jumps_left > 0:
		return false
	return true


func _try_dash() -> void:
	if abilities == null or not abilities.can_dash:
		return
	if _dash_cooldown_timer > 0.0 or _is_dashing():
		return

	var input_x := Input.get_axis("ui_left", "ui_right")
	var dash_x := signf(input_x)
	if absf(dash_x) < 0.01:
		dash_x = 1.0 if _facing_right else -1.0

	_dash_direction = Vector2(dash_x, 0.0)
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_wall_jump_lock_timer = 0.0
	dash_performed.emit()
	if dash_zero_vertical_velocity:
		velocity.y = 0.0


func _is_dashing() -> bool:
	return _dash_timer > 0.0


func _apply_post_dash_velocity() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if absf(dir) > 0.01:
		velocity.x = dir * move_speed * dash_end_speed_mult
	else:
		velocity.x = 0.0


func _update_dash_trail_state() -> void:
	if _trail_effect == null:
		return

	if not enable_dash_trail:
		_trail_effect.stop(false)
		return

	if _is_dashing():
		if not _trail_effect.is_active():
			_trail_effect.start()
	elif _trail_effect.is_active():
		_trail_effect.stop(false)


func _is_wall_sliding_now() -> bool:
	if _is_dashing():
		return false
	if is_on_floor():
		return false
	if not _can_wall_slide():
		return false
	return velocity.y > 0.0


func _emit_wall_slide_state(is_wall_sliding: bool) -> void:
	if is_wall_sliding == _was_wall_sliding:
		return
	_was_wall_sliding = is_wall_sliding
	wall_slide_state_changed.emit(is_wall_sliding)


func _refresh_wall_contact() -> void:
	var left_hit := test_move(global_transform, Vector2(-wall_probe_distance, 0.0))
	var right_hit := test_move(global_transform, Vector2(wall_probe_distance, 0.0))

	if left_hit and not right_hit:
		_wall_normal = Vector2(1.0, 0.0)
		return
	if right_hit and not left_hit:
		_wall_normal = Vector2(-1.0, 0.0)
		return

	_wall_normal = get_wall_normal() if is_on_wall() else Vector2.ZERO


func set_dash_enabled(enabled: bool) -> void:
	_ensure_abilities()
	abilities.can_dash = enabled


func set_wall_jump_enabled(enabled: bool) -> void:
	_ensure_abilities()
	abilities.can_wall_jump = enabled


func set_wall_slide_enabled(enabled: bool) -> void:
	_ensure_abilities()
	abilities.can_wall_slide = enabled


func set_double_jump_enabled(enabled: bool) -> void:
	_ensure_abilities()
	abilities.can_double_jump = enabled


func set_slow_fall_enabled(enabled: bool) -> void:
	_ensure_abilities()
	abilities.can_slow_fall = enabled


func _refill_air_jumps() -> void:
	_air_jumps_left = maxi(0, max_air_jumps)


func _update_facing() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir > 0.0 and not _facing_right:
		_flip()
	elif dir < 0.0 and _facing_right:
		_flip()


func _flip() -> void:
	_facing_right = not _facing_right
	_sprite.flip_h = not _sprite.flip_h
