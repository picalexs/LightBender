extends Node

@export_group("Squash & Stretch")
@export var fall_stretch_amount: float = 0.4
@export var stretch_min_fall_speed: float = 90.0
@export var squash_amount: float = 1.2
@export var jump_squash_amount: float = 0.7
@export var recovery_speed: float = 10.0

var _character_body: CharacterBody2D
var _sprite: Node2D
var _target_scale: Vector2 = Vector2.ONE
var _was_on_floor: bool = false
var _landing_timer: float = 0.0
var _last_frame_velocity: float = 0.0
var _carry_scale_multiplier: float = 1.0


func _ready() -> void:
	_character_body = get_parent() as CharacterBody2D
	if not _character_body:
		push_error("SquashStretch: Parent must be a CharacterBody2D")
		return

	_sprite = _character_body.find_child("Sprite2D", true, false)
	if not _sprite:
		push_error("SquashStretch: Could not find Sprite2D child in Player")
		return

	_target_scale = _sprite.scale
	print("SquashStretch: Ready. Sprite found: ", _sprite.name, " Current scale: ", _sprite.scale)


func _physics_process(delta: float) -> void:
	if not _character_body or not _sprite:
		return

	var on_floor := _character_body.is_on_floor()
	var fall_velocity := _character_body.velocity.y

	if on_floor and not _was_on_floor and _last_frame_velocity > 80.0:
		_on_land(_last_frame_velocity)
		_landing_timer = 0.1

	if not on_floor and _was_on_floor and fall_velocity < 0.0:
		_on_jump(abs(fall_velocity))
		_landing_timer = 0.3

	_landing_timer -= delta

	if _landing_timer <= 0.0:
		if fall_velocity > stretch_min_fall_speed:
			var stretch: float = clamp(fall_velocity / 100.0 * fall_stretch_amount, 0.0, 0.4)
			_target_scale.y = 1.0 + stretch
			_target_scale.x = 1.0 - stretch * 0.4
		else:
			_target_scale = Vector2.ONE

	_sprite.scale = _sprite.scale.lerp(
		_target_scale * _carry_scale_multiplier,
		recovery_speed * delta
	)

	_last_frame_velocity = fall_velocity
	_was_on_floor = on_floor


func _on_land(fall_speed: float) -> void:
	_target_scale = Vector2.ONE
	var impact_strength := clampf(fall_speed / 80.0, 0.0, 1.0)
	var squash := squash_amount * impact_strength
	var new_y := maxf(0.3, 1.0 - squash * 0.4)
	_target_scale = Vector2(1.0 + squash * 0.5, new_y)


func _on_jump(jump_velocity: float) -> void:
	var normalized := clampf(jump_velocity / 150.0, 0.0, 1.0)
	var squash_strength := pow(normalized, 2.5)
	var squash := jump_squash_amount * squash_strength
	_target_scale = Vector2(1.0 + squash * 0.2, 1.0 - squash * 0.08)


func set_carry_scale_multiplier(multiplier: float) -> void:
	_carry_scale_multiplier = maxf(multiplier, 0.01)
