extends Node

const TRACKS: Array[String] = [
	"res://assets/audio/music/juanjo_sound_Data Wash.wav",
	"res://assets/audio/music/juanjo_sound_Nineties Nostalgia.wav",
]

const NORMAL_VOLUME_DB: float = -15.0
const MENU_PITCH: float = 0.68
const CONTEXT_TWEEN_DURATION: float = 1.1

const DEATH_PITCH: float = .6
const DEATH_PITCH_DURATION: float = .3

const COMPLETE_PITCH_UP: float = 1.3
const COMPLETE_PITCH_UP_DURATION: float = .4
const COMPLETE_PITCH_SETTLE_DURATION: float = 2

const RESPAWN_RECOVER_DURATION: float = 3

var _player: AudioStreamPlayer
var _track_index: int = 0
var _pitch_tween: Tween = null
var _menu_mode: bool = false
var _pause_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = NORMAL_VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_track_finished)


func on_level_started() -> void:
	if _player.is_playing():
		_apply_context_pitch()
		return
	_play_track(_track_index)
	_apply_context_pitch()


func set_menu_mode(enabled: bool) -> void:
	_menu_mode = enabled
	_apply_context_pitch()


func set_pause_mode(enabled: bool) -> void:
	_pause_mode = enabled
	_apply_context_pitch()


func get_menu_pitch_scale() -> float:
	return MENU_PITCH


func get_menu_background_time_scale() -> float:
	return 1.0 - ((1.0 - MENU_PITCH) * 0.55)


func get_context_tween_duration() -> float:
	return CONTEXT_TWEEN_DURATION


func on_death() -> void:
	_kill_pitch_tween()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property(_player, "pitch_scale", DEATH_PITCH, DEATH_PITCH_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func on_respawn() -> void:
	_tween_pitch_to(_get_context_pitch_target(), RESPAWN_RECOVER_DURATION, Tween.TRANS_SINE, Tween.EASE_OUT)


func on_level_complete() -> void:
	_kill_pitch_tween()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property(_player, "pitch_scale", COMPLETE_PITCH_UP, COMPLETE_PITCH_UP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pitch_tween.tween_property(_player, "pitch_scale", _get_context_pitch_target(), COMPLETE_PITCH_SETTLE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_track_finished() -> void:
	_track_index = (_track_index + 1) % TRACKS.size()
	_play_track(_track_index)


func _play_track(idx: int) -> void:
	_player.stream = load(TRACKS[idx])
	_player.play()
	_player.pitch_scale = _get_context_pitch_target()


func _kill_pitch_tween() -> void:
	if _pitch_tween != null and _pitch_tween.is_valid():
		_pitch_tween.kill()
	_pitch_tween = null


func _get_context_pitch_target() -> float:
	return MENU_PITCH if _menu_mode or _pause_mode else 1.0


func _apply_context_pitch(duration: float = CONTEXT_TWEEN_DURATION) -> void:
	_tween_pitch_to(_get_context_pitch_target(), duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)


func _tween_pitch_to(target: float, duration: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> void:
	if _player == null:
		return
	_kill_pitch_tween()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property(_player, "pitch_scale", target, duration) \
		.set_trans(trans).set_ease(ease)
