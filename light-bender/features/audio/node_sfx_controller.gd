extends Node

@export_group("References")
@export var target_path: NodePath
@export var emitter_path: NodePath

@export_group("Events")
@export var enable_sfx: bool = true
@export var bindings: Array = []

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
		if binding == null:
			continue
		var raw_signal_name = binding.get("signal_name")
		var raw_event_name = binding.get("event_name")
		var signal_name := "" if raw_signal_name == null else str(raw_signal_name)
		var event_name := "" if raw_event_name == null else str(raw_event_name)
		if signal_name == "" or event_name == "":
			continue
		if not _target.has_signal(signal_name):
			push_warning("NodeSfxController: '%s' has no signal '%s'" % [_target.name, signal_name])
			continue

		var raw_persistent = binding.get("persistent")
		var raw_arg_count = binding.get("arg_count")
		var is_persistent: bool = bool(raw_persistent) if raw_persistent != null else false
		var arg_count := int(raw_arg_count) if raw_arg_count != null else 0
		var handler := _make_play_handler(event_name, is_persistent, arg_count)
		_target.connect(signal_name, handler)


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
