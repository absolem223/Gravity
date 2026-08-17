class_name ActionRuntime
extends RefCounted

## Thin facade: receives intents and delegates planning/execution to ActionScheduler.
var registry: ActionRegistry = null
var event_bus: GameplayEventBus = null
var scheduler: ActionScheduler = null
var active_actions: Dictionary = {}
var action_states: Dictionary = {}

signal action_requested(intent: ActionIntent)
signal action_started(action: Action)
signal action_updated(action: Action)
signal action_cancelled(action: Action)
signal action_finished(action: Action)
signal action_blocked(intent: ActionIntent)
signal action_failed(action: Action, reason: String)

func _init(registry_value: ActionRegistry = null, event_bus_value: GameplayEventBus = null) -> void:
	registry = registry_value if registry_value != null else ActionRegistry.new()
	event_bus = event_bus_value
	scheduler = ActionScheduler.new(registry, event_bus)

func submit_intent(intent: ActionIntent) -> ActionResult:
	action_requested.emit(intent)
	var result: ActionResult = scheduler.submit_intent(intent)
	active_actions = scheduler.active_actions
	action_states = scheduler.action_states
	return result

func resolve_action(intent: ActionIntent) -> Action:
	if registry == null:
		return null
	return registry.resolve(intent)

func register_action(action: Action) -> bool:
	if registry == null:
		return false
	return registry.register(action)

func unregister_action(action_id: String) -> bool:
	if registry == null:
		return false
	return registry.unregister(action_id)

func cancel_action(action_id: String, reason: String = "") -> ActionResult:
	return scheduler.cancel_action(action_id, reason)

func get_active_actions() -> Array[Action]:
	return scheduler.get_active_actions()

func get_action_state(action_id: String) -> int:
	return scheduler.get_action_state(action_id)

func get_registry() -> ActionRegistry:
	return registry
