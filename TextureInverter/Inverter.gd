extends Control


@onready var dispatcher: Node = $Dispatcher

func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key_event : InputEventKey = event as InputEventKey
	
	if not key_event.pressed: return
	if key_event.keycode != KEY_SPACE: return
	
	if dispatcher and dispatcher.has_method("dispatch"):
		dispatcher.call("dispatch")
	else:
		printerr("Dispatcher doesn't exist or has no dispatch function")
