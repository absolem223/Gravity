# test_capture_speed_multiplier.gd
# Comprehensive regression test suite for the Two-Player Capture Speed Bonus.
# Verifies all 12 required edge cases for calculated capture multiplier and actual progress over time.

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func _get_root() -> Window:
	return root

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	print("=== TWO-PLAYER CAPTURE SPEED BONUS TEST ===")

	var hc: HackController = HackController.new()
	hc.hack_speed_percent_per_second = 5.0
	hc.degradation_interval_seconds = 30.0
	_get_root().add_child(hc)

	# --- 1. One allied Operator alone → x1 ---
	hc.register_entry(0, 1)
	_check(hc.get_capture_speed_multiplier(0) == 1.0, "1 allied, 0 enemies -> x1 multiplier")

	# --- 2. Two allied Operators alone → x2 ---
	hc.register_entry(0, 2)
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "2 allied, 0 enemies -> x2 multiplier")

	# --- 3. Three allied Operators alone → x2, NOT x3 ---
	hc.register_entry(0, 3)
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "3 allied, 0 enemies -> x2 multiplier (capped at x2)")

	# --- 4. Two allied Operators + one enemy → x2 ---
	hc.register_exit(0, 3) # back to 2 allied
	hc.register_entry(1, 101) # 1 enemy
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "2 allied, 1 enemy -> x2 multiplier (allied >= 2 && enemy < 2)")

	# --- 5. Two allied Operators + two enemies → x1 ---
	hc.register_entry(1, 102) # 2 enemies
	_check(hc.get_capture_speed_multiplier(0) == 1.0, "2 allied, 2 enemies -> x1 multiplier (enemy >= 2)")

	# --- 6. Three allied Operators + two enemies → x1 ---
	hc.register_entry(0, 3) # 3 allied
	_check(hc.get_capture_speed_multiplier(0) == 1.0, "3 allied, 2 enemies -> x1 multiplier")

	# Clean up presence
	hc.register_exit(0, 1)
	hc.register_exit(0, 2)
	hc.register_exit(0, 3)
	hc.register_exit(1, 101)
	hc.register_exit(1, 102)

	# --- 7. One allied Operator + multiple enemies → contest logic unchanged ---
	hc.register_entry(0, 1)
	hc.register_entry(1, 101)
	hc.register_entry(1, 102)
	hc._evaluate_state()
	_check(hc.get_current_state() == HackController.CoreState.CONTESTED, "1 allied + 2 enemies -> CONTESTED state preserved")
	hc.register_exit(0, 1)
	hc.register_exit(1, 101)
	hc.register_exit(1, 102)

	# --- 8. Operators entering/leaving dynamically → immediate multiplier updates ---
	hc.register_entry(0, 1)
	_check(hc.get_capture_speed_multiplier(0) == 1.0, "Dynamic: 1 allied -> x1")
	hc.register_entry(0, 2)
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "Dynamic: 2nd allied enters -> x2 immediately")
	hc.register_exit(0, 2)
	_check(hc.get_capture_speed_multiplier(0) == 1.0, "Dynamic: 2nd allied exits -> x1 immediately")
	hc.register_exit(0, 1)

	# --- 9. Operators eliminated (is_dead) while inside the area ---
	var test_node: Node3D = Node3D.new()
	_get_root().add_child(test_node)

	var pm_mock: PlayerManager = PlayerManager.new()
	pm_mock.add_to_group("player_manager")
	test_node.add_child(pm_mock)

	var op1: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op1.player_id = 1
	op1.team_id = 0
	pm_mock.add_child(op1)

	var op2: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op2.player_id = 2
	op2.team_id = 0
	pm_mock.add_child(op2)

	hc.register_entry(0, 1)
	hc.register_entry(0, 2)
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "2 living allied operators -> x2 multiplier")

	# Eliminate op2
	op2.health_current = 0.0
	op2.die()
	_check(hc.get_team_presence_count(0) == 1, "Dead operator removed from active presence count (1 active)")
	_check(hc.get_capture_speed_multiplier(0) == 1.0, "Elimination of 2nd operator drops multiplier to x1 immediately")

	hc.register_exit(0, 1)
	hc.register_exit(0, 2)

	# --- 10. Capture beginning with 1 Op, second enters → speed changes from x1 to x2 (actual progress rate doubles) ---
	hc.hack_progress = 0.0
	hc.register_entry(0, 1)
	hc._evaluate_state()
	_check(hc.get_current_state() == HackController.CoreState.HACKING, "1 Op enters -> HACKING state")

	# Process 1 second with 1 Op (speed = 5.0 * 1.0)
	hc._process_hacking(1.0)
	var prog_1s: float = hc.get_progress()
	_check(absf(prog_1s - 5.0) < 0.001, "Progress after 1s with 1 Op is 5.0%% (x1 speed: %.2f%%)" % prog_1s)

	# 2nd Op enters
	op2.respawn(Vector3.ZERO) # Revive op2
	hc.register_entry(0, 2)
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "2nd Op enters -> x2 multiplier active")

	# Process 1 second with 2 Ops (speed = 5.0 * 2.0 = 10.0)
	hc._process_hacking(1.0)
	var prog_2s: float = hc.get_progress()
	var delta_prog: float = prog_2s - prog_1s
	_check(absf(delta_prog - 10.0) < 0.001, "Progress rate doubled to 10.0%%/s after 2nd Op entered (delta: %.2f%%)" % delta_prog)

	# --- 11. Two allied Ops capturing, then second enemy enters → multiplier changes from x2 to x1 ---
	# Note: to test multiplier transition when enemy count changes from 1 to 2,
	# we verify get_capture_speed_multiplier directly
	hc.register_entry(1, 101) # 1 enemy
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "2 allied + 1 enemy -> x2 multiplier")
	hc.register_entry(1, 102) # 2 enemies
	_check(hc.get_capture_speed_multiplier(0) == 1.0, "2 allied + 2 enemies -> x1 multiplier")

	# --- 12. Second enemy leaves → multiplier returns to x2 if >= 2 allied remain ---
	hc.register_exit(1, 102) # 2nd enemy leaves
	_check(hc.get_capture_speed_multiplier(0) == 2.0, "2nd enemy leaves -> x2 multiplier restored")

	test_node.queue_free()
	hc.queue_free()

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
