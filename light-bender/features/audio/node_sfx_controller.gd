extends Node

@export_group("References")
@export var target_path: NodePath
@export var emitter_path: NodePath

@export_group("Events")
@export var enable_sfx: bool = true
@export var bindings: Array[SfxSignalBinding] = []

var _target: Node
var _emitter: Node


func _ready() -> void:
	_target = get_node_or_null(target_path)
	_emitter = get_node_or_null(emitter_path)
	_connect_signals()


func _connect_signals() -> void:
	if _target == null or _emitter == null:
		return

	for binding in bindings:
		if binding == null or binding.signal_name == "" or binding.event_name == "":
			continue
		if not _target.has_signal(binding.signal_name):
			push_warning("NodeSfxController: '%s' has no signal '%s'" % [_target.name, binding.signal_name])
			continue

		var event: String = binding.event_name
		var is_persistent: bool = bool(binding.get("persistent"))
		var handler := _make_play_handler(event, is_persistent, binding.arg_count)
		_target.connect(binding.signal_name, handler)


func _make_play_handler(event: String, is_persistent: bool, arg_count: int) -> Callable:
	match arg_count:
		1: return func(_a): _play(event, is_persistent)
		2: return func(_a, _b): _play(event, is_persistent)
		3: return func(_a, _b, _c): _play(event, is_persistent)
		_: return func(): _play(event, is_persistent)


func _play(event_name: String, is_persistent: bool = false) -> void:
	if not enable_sfx:
		return
	if _emitter == null:
		return
	if is_persistent and _emitter.has_method("play_event_persistent"):
		_emitter.play_event_persistent(event_name)
	elif _emitter.has_method("play_event"):
		_emitter.play_event(event_name)
