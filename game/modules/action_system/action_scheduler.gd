class_name ActionScheduler
extends RefCounted

## Scheduler for action planning and execution authority.
## The scheduler is the only component that decides whether an action may start,
## block, interrupt, cancel or coexist with other active actions.
var registry: ActionRegistry = null
var event_bus: GameplayEventBus = null

var active_actions: Dictionary = {}
var pending_intents: Array[ActionIntent] = []
var cancelled_actions: Dictionary = {}
var finished_actions: Dictionary = {}
var action_states: Dictionary = {}

func _init(registry_value: ActionRegistry = null, event_bus_value: GameplayEventBus = null) -> void:
	registry = registry_value if registry_value != null else ActionRegistry.new()
	event_bus = event_bus_value

func submit_intent(intent: ActionIntent) -> ActionResult:
	if intent == null:
		return _emit_result("", ActionResult.Status.FAILED, false, "Intent is null.", "scheduler.intent.invalid")

	pending_intents.append(intent)
	if event_bus != null:
		event_bus.emit_event("scheduler.intent.received", {
			"intent_id": intent.intent_id,
			"requested_action_id": intent.requested_action_id,
			"actor_id": intent.actor_id,
		})

	var action: Action = registry.resolve(intent)
	if action == null:
		return _emit_result(
			intent.requested_action_id,
			ActionResult.Status.BLOCKED,
			false,
			"No action registered for request.",
			"scheduler.blocked",
			intent)

	if event_bus != null:
		event_bus.emit_event("scheduler.registry.resolved", {
			"action_id": action.action_id,
			"requested_action_id": intent.requested_action_id,
		})

	var context: ActionContext = _build_context(intent)
	if not action.can_execute(context):
		return _emit_result(
			action.action_id,
			ActionResult.Status.BLOCKED,
			false,
			"Execution blocked by validation.",
			"scheduler.blocked",
			intent)

	var authorization: ActionResult = _authorize_action(action, intent)
	if not authorization.success:
		return authorization

	if _should_finish_active_action(action, intent):
		return _finish_active_action(action, context)

	var start_result: ActionResult = action.start(context)
	action_states[action.action_id] = action.execution_state
	if event_bus != null:
		event_bus.emit_event("scheduler.action.started", {
			"action_id": action.action_id,
			"status": start_result.status,
			"success": start_result.success,
		})

	active_actions[action.action_id] = action
	if event_bus != null:
		event_bus.emit_event("scheduler.authorized", {
			"action_id": action.action_id,
			"priority": action.priority,
		})

	## Sustained actions remain ACTIVE until an explicit finish/cancel (e.g. sprint hold).
	## Atomic actions (is_sustained == false) preserve the legacy start -> finish in one frame.
	if not action.is_sustained:
		var finish_result: ActionResult = action.finish(context)
		action_states[action.action_id] = action.execution_state
		finished_actions[action.action_id] = finish_result
		active_actions.erase(action.action_id)
		if event_bus != null:
			event_bus.emit_event("scheduler.action.finished", {
				"action_id": action.action_id,
				"status": finish_result.status,
				"success": finish_result.success,
			})

		return _emit_result(
				action.action_id,
				finish_result.status,
				finish_result.success,
				finish_result.reason,
				"scheduler.action.result",
				intent,
				finish_result)

	return _emit_result(
			action.action_id,
			ActionResult.Status.SUCCESS,
			true,
			"Sustained action started.",
			"scheduler.action.result",
			intent)

func cancel_action(action_id: String, reason: String = "") -> ActionResult:
	var action: Action = active_actions.get(action_id, null)
	if action == null:
		return _emit_result(action_id, ActionResult.Status.FAILED, false, "Action not active.", "scheduler.cancel.failed")

	var context: ActionContext = ActionContext.new()
	var result: ActionResult = action.cancel(context)
	cancelled_actions[action_id] = result
	active_actions.erase(action_id)
	action_states[action_id] = action.execution_state
	if event_bus != null:
		event_bus.emit_event("scheduler.action.cancelled", {
			"action_id": action_id,
			"reason": reason,
			"status": result.status,
		})
	return result

func get_active_actions() -> Array[Action]:
	var actions: Array[Action] = []
	for action: Action in active_actions.values():
		actions.append(action)
	return actions

func get_action_state(action_id: String) -> int:
	return action_states.get(action_id, ActionState.State.IDLE)

func _authorize_action(action: Action, intent: ActionIntent) -> ActionResult:
	for active_action: Action in active_actions.values():
		if not _is_compatible(action, active_action):
			if _should_interrupt(active_action, action):
				cancel_action(active_action.action_id, "Interrupted by higher priority action.")
				continue
			return _emit_result(
				action.action_id,
				ActionResult.Status.BLOCKED,
				false,
				"Action blocked by active exclusivity.",
				"scheduler.blocked",
				intent)
	return ActionResult.new(
		action.action_id,
		ActionResult.Status.SUCCESS,
		true,
		"Action authorized.",
		Time.get_ticks_msec() * 0.001,
		{},
		intent.actor_id if intent != null else "")

func _is_compatible(candidate: Action, active: Action) -> bool:
	if active == null or candidate == null:
		return false
	if candidate.action_id in active.blocking_actions:
		return false
	if active.action_id in candidate.blocking_actions:
		return false
	if candidate.action_id in active.compatible_actions:
		return true
	if active.action_id in candidate.compatible_actions:
		return true
	return true

func _should_interrupt(active: Action, candidate: Action) -> bool:
	if active == null or candidate == null:
		return false
	if not active.is_interruptible or not candidate.is_interruptible:
		return false
	return candidate.priority > active.priority

func _should_finish_active_action(action: Action, intent: ActionIntent) -> bool:
	if intent == null:
		return false
	if not intent.payload.has("pressed"):
		return false
	return intent.payload.get("pressed", true) == false and active_actions.has(action.action_id)

func _finish_active_action(action: Action, context: ActionContext) -> ActionResult:
	var active_action: Action = active_actions.get(action.action_id, null)
	if active_action == null:
		return _emit_result(action.action_id, ActionResult.Status.FINISHED, true, "No active action to finish.", "scheduler.finished")

	var finish_result: ActionResult = active_action.finish(context)
	action_states[action.action_id] = active_action.execution_state
	finished_actions[action.action_id] = finish_result
	active_actions.erase(action.action_id)
	if event_bus != null:
		event_bus.emit_event("scheduler.action.finished", {
			"action_id": action.action_id,
			"status": finish_result.status,
			"success": finish_result.success,
		})
	return _emit_result(
		action.action_id,
		finish_result.status,
		finish_result.success,
		finish_result.reason,
		"scheduler.action.result",
		null,
		finish_result)

func _build_context(intent: ActionIntent) -> ActionContext:
	var actor: Node = null
	var metadata: Dictionary = {}
	if intent != null:
		metadata = intent.payload
		actor = intent.payload.get("actor", null)
	return ActionContext.new(
		actor,
		{},
		null,
		null,
		null,
		{},
		0.0,
		Time.get_ticks_msec() * 0.001,
		metadata)

func _emit_result(
	action_id: String,
	status: int,
	success: bool,
	reason: String,
	event_name: String,
	intent: ActionIntent = null,
	result: ActionResult = null
) -> ActionResult:
	var result_obj: ActionResult = result if result != null else ActionResult.new(
		action_id,
		status,
		success,
		reason,
		Time.get_ticks_msec() * 0.001,
		{},
		intent.actor_id if intent != null else "")
	if event_bus != null:
		event_bus.emit_event(event_name, {
			"action_id": action_id,
			"status": status,
			"success": success,
			"reason": reason,
		})
	return result_obj
