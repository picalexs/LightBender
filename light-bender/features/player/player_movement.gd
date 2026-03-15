extends CharacterBody2D

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

# ── Private state ─────────────────────────────────────────────────────────────
var _facing_right: bool = true
var _is_jumping: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_jump_buffer_timer = jump_buffer_time
	elif event.is_action_released("ui_accept") and _is_jumping and velocity.y < 0.0:
		# Variable jump height: cut upward velocity on early release
		velocity.y *= jump_cut_mult
		_is_jumping = false


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_tick_timers(delta, on_floor)
	_apply_gravity(delta, on_floor)
	_try_jump()
	_apply_movement(delta, on_floor)
	_update_facing()
	move_and_slide()
	if is_on_floor() and velocity.y >= 0.0:
		_is_jumping = false


# Counts down coyote window and jump buffer each frame; resets coyote on landing.
func _tick_timers(delta: float, on_floor: bool) -> void:
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	_jump_buffer_timer -= delta


# Scales gravity based on movement phase: apex hang, fast fall, normal fall, or grounded.
func _apply_gravity(delta: float, on_floor: bool) -> void:
	if on_floor:
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
		else:
			g_mult = gravity_mult * fall_gravity_mult
			velocity.y = minf(velocity.y, max_fall_speed)

	velocity += get_gravity() * g_mult * delta


# Fires a jump when both the input buffer and the coyote window are active.
func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	velocity.y = -jump_force
	_is_jumping = true
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	# No release event will come, so apply the cut right now.
	if not Input.is_action_pressed("ui_accept"):
		velocity.y *= jump_cut_mult
		_is_jumping = false


# Physics-based acceleration / deceleration with optional momentum conservation and friction.
func _apply_movement(delta: float, on_floor: bool) -> void:
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


func _update_facing() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir > 0.0 and not _facing_right:
		_flip()
	elif dir < 0.0 and _facing_right:
		_flip()


func _flip() -> void:
	_facing_right = not _facing_right
	_sprite.flip_h = not _sprite.flip_h
