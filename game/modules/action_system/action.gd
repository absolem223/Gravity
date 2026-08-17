class_name Action
extends RefCounted

## Base contract for every concrete action.
## Implementations are registered in the registry and executed by the runtime.
signal action_state_changed(new_state: int)

var action_id: String = ""
var name: String = ""
var category: String = ""
var priority: int = 0
var execution_state: int = ActionState.State.IDLE
var is_interruptible: bool = true
var is_cancellable: bool = true
var cooldown_duration: float = 0.0
## If true, the action stays ACTIVE after start() until an explicit finish/cancel.
## Default false preserves the legacy start -> immediate finish atomic behaviour.
var is_sustained: bool = false
var blocking_actions: Array[String] = []
var compatible_actions: Array[String] = []

func _init(
	action_id_value: String = "",
	name_value: String = "",
	category_value: String = "",
	priority_value: int = 0,
	cooldown_duration_value: float = 0.0
) -> void:
	action_id = action_id_value
	name = name_value
	category = category_value
	priority = priority_value
	cooldown_duration = cooldown_duration_value

func can_execute(_context: ActionContext) -> bool:
	return true

func start(_context: ActionContext) -> ActionResult:
	execution_state = ActionState.State.ACTIVE
	action_state_changed.emit(execution_state)
	return ActionResult.new(
		action_id,
		ActionResult.Status.SUCCESS,
		true,
		"Action started.",
		Time.get_ticks_msec() * 0.001,
		{},
		"")

func update(_delta: float, _context: ActionContext) -> ActionResult:
	return ActionResult.new(
		action_id,
		ActionResult.Status.SUCCESS,
		true,
		"Action updated.",
		Time.get_ticks_msec() * 0.001,
		{},
		"")

func cancel(_context: ActionContext) -> ActionResult:
	execution_state = ActionState.State.CANCELLED
	action_state_changed.emit(execution_state)
	return ActionResult.new(
		action_id,
		ActionResult.Status.CANCELLED,
		false,
		"Action cancelled.",
		Time.get_ticks_msec() * 0.001,
		{},
		"")

func finish(_context: ActionContext) -> ActionResult:
	execution_state = ActionState.State.FINISHED
	action_state_changed.emit(execution_state)
	return ActionResult.new(
		action_id,
		ActionResult.Status.FINISHED,
		true,
		"Action finished.",
		Time.get_ticks_msec() * 0.001,
		{},
		"")
