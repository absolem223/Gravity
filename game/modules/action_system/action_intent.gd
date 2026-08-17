class_name ActionIntent
extends RefCounted

## A semantic request emitted by the input layer.
var actor_id: String = ""
var intent_id: String = ""
var requested_action_id: String = ""
var source: String = ""
var payload: Dictionary = {}
var priority: int = 0
var timestamp: float = 0.0

func _init(
	actor_id_value: String = "",
	requested_action_id_value: String = "",
	source_value: String = "",
	payload_value: Dictionary = {},
	priority_value: int = 0,
	timestamp_value: float = 0.0
) -> void:
	actor_id = actor_id_value
	intent_id = "%s_%s" % [actor_id_value, str(Time.get_ticks_msec())]
	requested_action_id = requested_action_id_value
	source = source_value
	payload = payload_value
	priority = priority_value
	timestamp = timestamp_value

func get_actor_id() -> String:
	return actor_id

func get_requested_action_id() -> String:
	return requested_action_id

func get_payload() -> Dictionary:
	return payload

func get_priority() -> int:
	return priority
