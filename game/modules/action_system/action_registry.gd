class_name ActionRegistry
extends RefCounted

## Catalog of action implementations.
var registered_actions: Dictionary = {}

func register(action: Action) -> bool:
	if action == null:
		return false
	if action.action_id.is_empty():
		return false
	registered_actions[action.action_id] = action
	return true

func unregister(action_id: String) -> bool:
	if not registered_actions.has(action_id):
		return false
	registered_actions.erase(action_id)
	return true

func resolve(intent: ActionIntent) -> Action:
	if intent == null:
		return null
	if not registered_actions.has(intent.requested_action_id):
		return null
	return registered_actions.get(intent.requested_action_id, null)

func get_action(action_id: String) -> Action:
	return registered_actions.get(action_id, null)

func list_actions() -> Array[Action]:
	var actions: Array[Action] = []
	for action: Action in registered_actions.values():
		actions.append(action)
	return actions

func has_action(action_id: String) -> bool:
	return registered_actions.has(action_id)
