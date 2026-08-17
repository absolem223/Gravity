class_name ActionResult
extends RefCounted

## Standardized execution outcome for actions.
enum Status {
	SUCCESS,
	BLOCKED,
	CANCELLED,
	FAILED,
	FINISHED,
	INTERRUPTED,
}

var action_id: String = ""
var status: int = Status.SUCCESS
var success: bool = true
var reason: String = ""
var timestamp: float = 0.0
var diagnostics: Dictionary = {}
var actor_id: String = ""
var interrupting_action_id: String = ""
var cancelled_by: String = ""
var blocked_by: String = ""

func _init(
	action_id_value: String = "",
	status_value: int = Status.SUCCESS,
	success_value: bool = true,
	reason_value: String = "",
	timestamp_value: float = 0.0,
	diagnostics_value: Dictionary = {},
	actor_id_value: String = "",
	interrupting_action_id_value: String = "",
	cancelled_by_value: String = "",
	blocked_by_value: String = ""
) -> void:
	action_id = action_id_value
	status = status_value
	success = success_value
	reason = reason_value
	timestamp = timestamp_value
	diagnostics = diagnostics_value
	actor_id = actor_id_value
	interrupting_action_id = interrupting_action_id_value
	cancelled_by = cancelled_by_value
	blocked_by = blocked_by_value
