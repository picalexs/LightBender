class_name NodeDispatch

## Calls target.method_name with optional param. Warns if method is missing.
static func call_method(
		target: Node,
		method_name: String,
		param: String,
		caller_label: String
) -> void:
	if target == null or method_name == "":
		return
	if not target.has_method(method_name):
		push_warning(caller_label + ": target has no method '" + method_name + "'")
		return
	if param != "":
		target.call(method_name, param)
	else:
		target.call(method_name)
