class_name TestAction
extends Action

## Minimal dummy action used to validate the Action System contract.
func _init() -> void:
	action_id = "test_action"
	name = "TestAction"
	category = "test"
	priority = 1
	cooldown_duration = 0.0

func can_execute(_context: ActionContext) -> bool:
	return true

func start(context: ActionContext) -> ActionResult:
	var result: ActionResult = super.start(context)
	return result

func update(_delta: float, context: ActionContext) -> ActionResult:
	return super.update(_delta, context)

func cancel(context: ActionContext) -> ActionResult:
	return super.cancel(context)

func finish(context: ActionContext) -> ActionResult:
	return super.finish(context)
