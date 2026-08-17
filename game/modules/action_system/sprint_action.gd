class_name SprintAction
extends Action

## Concrete Sprint implementation executed through the Action System.
## It only mutates the owning operator's sprint state and does not embed
## sprint-specific gameplay rules in OperatorBase.
func _init() -> void:
	action_id = "sprint"
	name = "SprintAction"
	category = "movement"
	priority = 10
	cooldown_duration = 0.0
	is_sustained = true

func can_execute(context: ActionContext) -> bool:
	if context == null:
		return false
	if context.actor == null:
		return false
	return context.actor is OperatorBase

func start(context: ActionContext) -> ActionResult:
	var actor: OperatorBase = context.actor as OperatorBase
	if actor != null:
		actor.is_sprinting = true
		if actor.is_crouching:
			actor.is_crouching = false
		actor._update_crouch_visual()
	execution_state = ActionState.State.ACTIVE
	action_state_changed.emit(execution_state)
	return ActionResult.new(
		action_id,
		ActionResult.Status.SUCCESS,
		true,
		"Sprint started.",
		Time.get_ticks_msec() * 0.001,
		{},
		"player_%02d" % actor.player_id if actor != null else "")

func update(_delta: float, context: ActionContext) -> ActionResult:
	return super.update(_delta, context)

func cancel(context: ActionContext) -> ActionResult:
	var actor: OperatorBase = context.actor as OperatorBase
	if actor != null:
		actor.is_sprinting = false
	execution_state = ActionState.State.CANCELLED
	action_state_changed.emit(execution_state)
	return ActionResult.new(
		action_id,
		ActionResult.Status.CANCELLED,
		false,
		"Sprint cancelled.",
		Time.get_ticks_msec() * 0.001,
		{},
		"player_%02d" % actor.player_id if actor != null else "")

func finish(context: ActionContext) -> ActionResult:
	var actor: OperatorBase = context.actor as OperatorBase
	if actor != null:
		actor.is_sprinting = false
	execution_state = ActionState.State.FINISHED
	action_state_changed.emit(execution_state)
	return ActionResult.new(
		action_id,
		ActionResult.Status.FINISHED,
		true,
		"Sprint finished.",
		Time.get_ticks_msec() * 0.001,
		{},
		"player_%02d" % actor.player_id if actor != null else "")
