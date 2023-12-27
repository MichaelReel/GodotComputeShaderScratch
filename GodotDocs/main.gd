extends Node2D


@onready var dispatcher: Node = $Dispatcher

func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key_event := event as InputEventKey
	
	if not key_event.pressed: return
	if key_event.keycode != KEY_SPACE: return
		
	if dispatcher.has_method("dispatch"):
		dispatcher.call("dispatch")
