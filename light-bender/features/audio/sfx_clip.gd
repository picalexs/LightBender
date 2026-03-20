extends Resource
class_name SfxClip

@export var event_name: String = ""
@export var stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_scale: float = 1.0
@export var pitch_randomness: float = 0.0
@export var retrigger_cooldown: float = 0.0
@export var loop: bool = false
