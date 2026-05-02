extends Node2D

@export_group("Library")
@export var clips: Array = []
@export var bus_name: String = "Master"

@export_group("Playback")
@export var max_polyphony: int = 6

var _clip_lookup: Dictionary = {}
var _cooldowns: Dictionary = {}
var _one_shot_players: Array = []
var _loop_players: Dictionary = {}
var _next_player_index: int = 0


func _ready() -> void:
	_sanitize_configuration()
	_rebuild_clip_lookup()
	_create_one_shot_pool()
	randomize()


func _process(delta: float) -> void:
	_tick_cooldowns(delta)


func play_event(event_name: String) -> bool:
	if event_name == "":
		return false

	var clip = _get_clip(event_name)
	if clip == null:
		return false
	if not _can_trigger(event_name):
		return false

	var stream = clip.get("stream")
	if stream == null:
		return false

	if bool(clip.get("loop")):
		return _start_loop_from_clip(event_name, clip)

	var player = _acquire_one_shot_player()
	if player == null:
		return false

	_configure_player(player, clip)
	player.stream = stream
	player.play()
	_apply_cooldown(event_name, clip)
	return true


func start_event_loop(event_name: String) -> bool:
	if event_name == "":
		return false

	var clip = _get_clip(event_name)
	if clip == null:
		return false

	clip.set("loop", true)
	return play_event(event_name)


func stop_event(event_name: String) -> void:
	if not _loop_players.has(event_name):
		return

	var player = _loop_players[event_name]
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	_loop_players.erase(event_name)


func play_event_persistent(event_name: String) -> bool:
	if event_name == "":
		return false

	var clip = _get_clip(event_name)
	if clip == null:
		return false

	var stream = clip.get("stream")
	if stream == null:
		return false

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus_name
	player.volume_db = float(clip.get("volume_db") if clip.get("volume_db") != null else 0.0)

	var base_pitch := float(clip.get("pitch_scale") if clip.get("pitch_scale") != null else 1.0)
	var randomness: float = max(0.0, float(clip.get("pitch_randomness") if clip.get("pitch_randomness") != null else 0.0))
	if randomness > 0.0:
		base_pitch += randf_range(-randomness, randomness)
	player.pitch_scale = max(0.01, base_pitch)

	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return true


func stop_all_events() -> void:
	for player in _one_shot_players:
		if is_instance_valid(player):
			player.stop()

	for event_name in _loop_players.keys():
		var loop_player = _loop_players[event_name]
		if is_instance_valid(loop_player):
			loop_player.stop()
			loop_player.queue_free()

	_loop_players.clear()


func refresh_library() -> void:
	_rebuild_clip_lookup()


func _exit_tree() -> void:
	stop_all_events()


func _sanitize_configuration() -> void:
	max_polyphony = max(1, max_polyphony)


func _rebuild_clip_lookup() -> void:
	_clip_lookup.clear()
	for clip in clips:
		if clip == null:
			continue

		var event_name = str(clip.get("event_name"))
		if event_name == "":
			continue

		_clip_lookup[event_name] = clip


func _create_one_shot_pool() -> void:
	_one_shot_players.clear()
	for i in range(max_polyphony):
		var player = AudioStreamPlayer2D.new()
		player.name = "OneShot_%d" % i
		player.bus = bus_name
		player.position = Vector2.ZERO
		add_child(player)
		_one_shot_players.append(player)


func _get_clip(event_name: String):
	if _clip_lookup.is_empty() and not clips.is_empty():
		_rebuild_clip_lookup()
	return _clip_lookup.get(event_name, null)


func _acquire_one_shot_player() -> AudioStreamPlayer2D:
	for player in _one_shot_players:
		if not player.playing:
			return player

	if _one_shot_players.is_empty():
		return null

	var player = _one_shot_players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _one_shot_players.size()
	player.stop()
	return player


func _configure_player(player: AudioStreamPlayer2D, clip) -> void:
	player.bus = bus_name
	player.volume_db = float(clip.get("volume_db"))

	var base_pitch = float(clip.get("pitch_scale"))
	var pitch_randomness = max(0.0, float(clip.get("pitch_randomness")))
	if pitch_randomness > 0.0:
		base_pitch += randf_range(-pitch_randomness, pitch_randomness)

	player.pitch_scale = max(0.01, base_pitch)
	player.position = Vector2.ZERO


func _start_loop_from_clip(event_name: String, clip) -> bool:
	var stream = clip.get("stream")
	if stream == null:
		return false

	if _loop_players.has(event_name):
		var existing = _loop_players[event_name]
		if is_instance_valid(existing):
			if not existing.playing:
				_configure_player(existing, clip)
				existing.stream = stream
				existing.play()
			_apply_cooldown(event_name, clip)
			return true
		_loop_players.erase(event_name)

	var loop_player = AudioStreamPlayer2D.new()
	loop_player.name = "Loop_%s" % event_name
	_configure_player(loop_player, clip)
	loop_player.stream = stream
	add_child(loop_player)
	loop_player.play()
	_loop_players[event_name] = loop_player
	_apply_cooldown(event_name, clip)
	return true


func _can_trigger(event_name: String) -> bool:
	if not _cooldowns.has(event_name):
		return true
	return float(_cooldowns[event_name]) <= 0.0


func _apply_cooldown(event_name: String, clip) -> void:
	var cooldown = max(0.0, float(clip.get("retrigger_cooldown")))
	if cooldown > 0.0:
		_cooldowns[event_name] = cooldown


func _tick_cooldowns(delta: float) -> void:
	if _cooldowns.is_empty():
		return

	var keys = _cooldowns.keys()
	for event_name in keys:
		var remaining = float(_cooldowns[event_name]) - delta
		if remaining <= 0.0:
			_cooldowns.erase(event_name)
		else:
			_cooldowns[event_name] = remaining
