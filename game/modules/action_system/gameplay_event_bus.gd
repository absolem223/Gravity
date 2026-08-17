class_name GameplayEventBus
extends RefCounted

## Decoupled event stream for runtime/UI/audio/particles observers.
signal event_emitted(event_name: String, payload: Dictionary)

func emit_event(event_name: String, payload: Dictionary = {}) -> void:
	event_emitted.emit(event_name, payload)
