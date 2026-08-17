extends SceneTree

func _init() -> void:
	print("--- ACTION SYSTEM INTEGRATION TEST ---")
	call_deferred("run_test")

func run_test() -> void:
	print("[1/6] InputManager generates ActionIntent")
	var intent: ActionIntent = ActionIntent.new(
		"player_01",
		"test_action",
		"test_input",
		{"button": "test_key"},
		1,
		Time.get_ticks_msec() * 0.001
	)
	print("[1/6] Intent created: %s -> %s" % [intent.actor_id, intent.requested_action_id])

	print("[2/6] ActionRuntime receives Intent")
	var bus: GameplayEventBus = GameplayEventBus.new()
	bus.event_emitted.connect(func(event_name: String, payload: Dictionary) -> void:
		print("[BUS] %s :: %s" % [event_name, str(payload)])
	)

	var registry: ActionRegistry = ActionRegistry.new()
	var runtime: ActionRuntime = ActionRuntime.new(registry, bus)
	var test_action: TestAction = TestAction.new()
	registry.register(test_action)

	print("[3/6] ActionRegistry resolves TestAction")
	var resolved: Action = runtime.resolve_action(intent)
	print("[3/6] Resolved action: %s" % [resolved.action_id if resolved != null else "null"])

	print("[4/6] TestAction executes can_execute -> start -> finish")
	var result: ActionResult = runtime.submit_intent(intent)
	print("[4/6] ActionResult status: %s | success: %s | reason: %s" % [result.status, result.success, result.reason])

	print("[5/6] ActionResult emitted and bus receives event")
	if result.success:
		print("[5/6] SUCCESS: ActionResult completed successfully.")
	else:
		print("[5/6] FAILURE: ActionResult not successful.")

	print("[6/6] Final verification")
	if resolved != null and result.success:
		print("✓ PASS: Action System integration test completed.")
	else:
		print("✗ FAIL: Action System integration test did not complete cleanly.")

	quit()
