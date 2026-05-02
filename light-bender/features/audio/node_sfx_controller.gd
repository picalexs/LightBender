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
		var handler: Callable
		match binding.arg_count:
			1: handler = func(_a): _play(event)
			2: handler = func(_a, _b): _play(event)
			3: handler = func(_a, _b, _c): _play(event)
			_: handler = func(): _play(event)

		_target.connect(binding.signal_name, handler)


func _play(event_name: String) -> void:
	if not enable_sfx:
		return
	if _emitter == null:
		return
	if _emitter.has_method("play_event"):
		_emitter.play_event(event_name)
