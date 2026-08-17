# test_terminal_hack.gd
# Terminal IA capture restoration: verifies the three terminals (A/B/C) are
# independent objectives with their own AICore, that approaching starts the
# hack, progress advances, leaving pauses/degrades, the single SquadHUD widget
# shows the active terminal (name + % + bar) and hides on exit, and that
# completing one hack does not affect the others.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func _new_match() -> Match:
	var m: Match = (load("res://scenes/match.tscn") as PackedScene).instantiate() as Match
	m.intro_enabled = false
	get_root().add_child(m)
	current_scene = m
	return m

func _terminal(m: Match, letter: String) -> Node3D:
	var tm: TerminalManager = m.get_terminal_manager()
	return tm.get_terminal("Terminal_%s" % letter) as Node3D

func _move_into(m: Match, op: OperatorBase, target: Vector3) -> void:
	## Step the operator toward the terminal center so body_entered fires reliably.
	op.velocity = Vector3.ZERO
	for i in range(16):
		var t: float = float(i + 1) / 16.0
		op.global_position = op.global_position.lerp(target, 0.5)
		for _f in range(2):
			await physics_frame

func _operator(m: Match, p_id: int) -> OperatorBase:
	return m.get_player_manager().get_operator(p_id)

func _hud_widget(m: Match) -> HBoxContainer:
	return m.get_squad_hud().get_node_or_null("TopMarginContainer/CoreStrip") as HBoxContainer

func _widget_visible(m: Match) -> bool:
	var w: HBoxContainer = _hud_widget(m)
	return w != null and w.visible

func run_test() -> void:
	print("== TERMINAL HACK TEST (A/B/C independent + HUD) ==")
	var m: Match = _new_match()
	for i in range(5):
		await physics_frame

	_check(m.get_phase() == Match.Phase.LIVE, "match is LIVE")
	var tm: TerminalManager = m.get_terminal_manager()
	_check(tm != null, "match created a TerminalManager")
	_check(tm.get_terminal_count() == 3, "TerminalManager registered 3 objectives (got %d)" % tm.get_terminal_count())

	for letter: String in ["A", "B", "C"]:
		_check(tm.get_terminal("Terminal_%s" % letter) != null, "Terminal %s has its own AICore" % letter)

	# Baseline: no widget, all IDLE at 0%.
	_check(not _widget_visible(m), "HUD widget hidden at match start")
	_check(tm.get_progress("Terminal_A") == 0.0, "Terminal A starts at 0%")
	_check(tm.get_progress("Terminal_B") == 0.0, "Terminal B starts at 0%")
	_check(tm.get_progress("Terminal_C") == 0.0, "Terminal C starts at 0%")

	var op1: OperatorBase = _operator(m, 1)
	_check(op1 != null, "P1 spawned")

	# Let the CoreCaptureZone startup grace (0.5s) expire before any entry.
	for i in range(45):
		await physics_frame

	# --- Terminal A: enter -> hack starts, widget appears ---
	var ta: Node3D = _terminal(m, "A")
	await _move_into(m, op1, ta.global_position + Vector3(2.0, 1.0, 2.0))
	for i in range(30):
		await physics_frame

	var prog_a: float = tm.get_progress("Terminal_A")
	_check(prog_a > 0.0, "Terminal A progress advances (%.1f%%)" % prog_a)
	_check(tm.get_state("Terminal_A") == HackController.CoreState.HACKING, "Terminal A in HACKING state")
	_check(_widget_visible(m), "HUD widget visible inside Terminal A zone")
	var w: HBoxContainer = _hud_widget(m)
	var title: Label = w.get_node("CoreTitleLabel") as Label
	_check(title.text.contains("TERMINAL A"), "widget shows 'TERMINAL A' ('%s')" % title.text)

	# Independence while A is being hacked.
	_check(tm.get_progress("Terminal_B") == 0.0, "Terminal B still 0% while A is hacked")
	_check(tm.get_progress("Terminal_C") == 0.0, "Terminal C still 0% while A is hacked")
	_check(tm.get_state("Terminal_B") == HackController.CoreState.IDLE, "Terminal B stays IDLE")

	# --- Terminal A: leave -> degrades/pauses, widget hides ---
	await _move_into(m, op1, ta.global_position + Vector3(0.0, 1.0, 9.0))
	for i in range(30):
		await physics_frame
	_check(not _widget_visible(m), "HUD widget hidden after leaving Terminal A zone")
	_check(tm.get_state("Terminal_A") == HackController.CoreState.DEGRADED, "Terminal A degrades after operator leaves")
	var prog_a_left: float = tm.get_progress("Terminal_A")
	_check(prog_a_left > 0.0 and prog_a_left <= prog_a + 0.5, "Terminal A progress paused, not advancing (%.1f%%)" % prog_a_left)

	# --- Terminal B: independent hack while A degrades ---
	var tb: Node3D = _terminal(m, "B")
	await _move_into(m, op1, tb.global_position + Vector3(2.0, 1.0, 2.0))
	for i in range(30):
		await physics_frame
	var prog_b: float = tm.get_progress("Terminal_B")
	_check(prog_b > 0.0, "Terminal B progress advances independently (%.1f%%)" % prog_b)
	_check(tm.get_state("Terminal_B") == HackController.CoreState.HACKING, "Terminal B in HACKING state")
	_check(_widget_visible(m), "widget follows the player to Terminal B")
	title = _hud_widget(m).get_node("CoreTitleLabel") as Label
	_check(title.text.contains("TERMINAL B"), "widget shows 'TERMINAL B' ('%s')" % title.text)

	# Terminal A keeps its own degraded progress (not reset by B activity).
	_check(tm.get_progress("Terminal_A") >= prog_a_left, "Terminal A progress independent of B (%.1f%%)" % tm.get_progress("Terminal_A"))

	# --- Terminal B: complete the hack fast, verify CAPTURED + ownership ---
	var core_b: AICore = tm.get_terminal("Terminal_B")
	core_b.hack_controller.hack_speed_percent_per_second = 30.0
	core_b.hack_controller.capture_threshold_percent = 50.0
	for i in range(260):
		await physics_frame
	_check(tm.get_state("Terminal_B") == HackController.CoreState.CAPTURED, "Terminal B CAPTURED after completing hack")
	_check(tm.get_owning_team("Terminal_B") == 0, "Terminal B owned by attackers (team 0)")
	_check(tm.get_progress("Terminal_B") == 100.0, "Terminal B at 100%")
	_check(tm.get_state("Terminal_C") == HackController.CoreState.IDLE, "Terminal C untouched by B capture")
	_check(tm.get_progress("Terminal_C") == 0.0, "Terminal C still 0%")

	# --- Terminal C: still fully functional after B captured ---
	var tc: Node3D = _terminal(m, "C")
	await _move_into(m, op1, tc.global_position + Vector3(2.0, 1.0, 2.0))
	for i in range(30):
		await physics_frame
	_check(tm.get_state("Terminal_C") == HackController.CoreState.HACKING, "Terminal C hacks independently after B capture")
	_check(tm.get_progress("Terminal_C") > 0.0, "Terminal C progress advances (%.1f%%)" % tm.get_progress("Terminal_C"))
	title = _hud_widget(m).get_node("CoreTitleLabel") as Label
	_check(title.text.contains("TERMINAL C"), "widget follows to Terminal C ('%s')" % title.text)

	# --- Terminal A: can still be hacked after everything ---
	await _move_into(m, op1, ta.global_position + Vector3(2.0, 1.0, 2.0))
	for i in range(30):
		await physics_frame
	_check(tm.get_state("Terminal_A") == HackController.CoreState.HACKING, "Terminal A resumes hacking (reconquest)")

	m.queue_free()
	for i in range(3):
		await physics_frame
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
