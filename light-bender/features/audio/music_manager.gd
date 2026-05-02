extends Node

const TRACKS: Array[String] = [
	"res://assets/audio/music/juanjo_sound_Data Wash.wav",
	"res://assets/audio/music/juanjo_sound_Nineties Nostalgia.wav",
]

const NORMAL_VOLUME_DB: float = -15.0

const DEATH_PITCH: float = .6
const DEATH_PITCH_DURATION: float = .3

const COMPLETE_PITCH_UP: float = 1.3
const COMPLETE_PITCH_UP_DURATION: float = .4
const COMPLETE_PITCH_SETTLE_DURATION: float = 2

const RESPAWN_RECOVER_DURATION: float = 3

var _player: AudioStreamPlayer
var _track_index: int = 0
var _pitch_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = NORMAL_VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_track_finished)


func on_level_started() -> void:
	if _player.is_playing():
		return
	_play_track(_track_index)


func on_death() -> void:
	_kill_pitch_tween()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property(_player, "pitch_scale", DEATH_PITCH, DEATH_PITCH_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func on_respawn() -> void:
	_kill_pitch_tween()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property(_player, "pitch_scale", 1.0, RESPAWN_RECOVER_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func on_level_complete() -> void:
	_kill_pitch_tween()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property(_player, "pitch_scale", COMPLETE_PITCH_UP, COMPLETE_PITCH_UP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pitch_tween.tween_property(_player, "pitch_scale", 1.0, COMPLETE_PITCH_SETTLE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_track_finished() -> void:
	_track_index = (_track_index + 1) % TRACKS.size()
	_play_track(_track_index)


func _play_track(idx: int) -> void:
	_player.stream = load(TRACKS[idx])
	_player.play()


func _kill_pitch_tween() -> void:
	if _pitch_tween != null and _pitch_tween.is_valid():
		_pitch_tween.kill()
	_pitch_tween = null
