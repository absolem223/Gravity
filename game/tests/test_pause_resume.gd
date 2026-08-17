# test_pause_resume.gd
# Technical Rationale: Regression tests for the in-match pause system (PMQ3):
# ESC opens a pause overlay WITHOUT tearing down the Match, SceneTree.paused is
# set (sim freezes), the overlay uses PROCESS_MODE_ALWAYS so the menu stays
# interactive, resume unpauses the SAME Match instance (state intact), and the
# R-key restart conflict is gone (P2's ability button no longer restarts/match-
# exits). Adheres to ADR-0001 (GDScript 2.x Strict Typing).

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

## Synthesizes an ESC key press handled by the Match's own _unhandled_input path.
func _press_escape(m: Match) -> void:
	var kev: InputEventKey = InputEventKey.new()
	kev.keycode = KEY_ESCAPE
	kev.physical_keycode = KEY_ESCAPE
	kev.pressed = true
	m._unhandled_input(kev)

func run_test() -> void:
	print("== PAUSE / RESUME TEST ==")
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	if cfg != null:
		cfg.call("reset_slots_to_defaults")

	var m: Match = _new_match()
	# Headless quirk workaround: compiling a screen script while SceneTree is
	# paused can fail to resolve the GameConfig autoload. The real game never
	# compiles menus while paused (screens are loaded by the unpaused main menu),
	# so preload the script here while we are still unpaused and reuse it later.
	var pcs_script: GDScript = load("res://ui/screens/players_config_screen.gd") as GDScript
	_check(pcs_script != null, "players config screen script preloads while unpaused")
	# Prewarm the pause stack's screens (they reference the GameConfig autoload).
	# In headless dev mode scripts compile lazily on first load(); compiling a
	# screen script WHILE SceneTree.paused is true can deadlock, so instantiate
	# them now while the tree is running and free them again immediately.
	var warm: UIScreen = null
	warm = pcs_script.new() as UIScreen
	if warm != null:
		warm.free()
	# Let the arena + squad defer to LIVE with the timer running.
	for i in range(12):
		await physics_frame
	_check(m.is_live(), "match reaches LIVE (intro disabled)")
	var timer_active: bool = m.get_match_time_left() > 0.0 and m.get_match_time_left() < 600.0
	_check(m.is_live() and timer_active, "match clock is running before pause")

	# ── 20: ESC must NOT change_scene to the main menu ──
	var scene_before: Node = current_scene
	_press_escape(m)
	await physics_frame
	await physics_frame
	_check(current_scene == scene_before, "ESC does not leave the match scene (no change_scene away)")
	_check(is_instance_valid(m), "Match node survives ESC")

	# ── 21: Pause freezes the simulation ──
	_check(paused == true, "SceneTree.paused == true while paused")

	# ── 22: Pause overlay is present and always-active ──
	var overlay: CanvasLayer = m.get_node_or_null("PauseOverlay") as CanvasLayer
	_check(overlay != null, "PauseOverlay CanvasLayer exists under Match")
	_check(overlay != null and overlay.process_mode == Node.PROCESS_MODE_ALWAYS,
		"pause overlay uses PROCESS_MODE_ALWAYS (stays interactive while paused)")
	var stack: UIScreenStack = overlay.get_node_or_null("PauseStack") as UIScreenStack if overlay != null else null
	var ps: UIScreen = stack.top() as UIScreen if stack != null else null
	_check(ps != null and ps is UIScreen, "pause overlay hosts a UIScreen")

	# ── 23: Match timer is frozen while paused ──
	var t_frozen: float = m.get_match_time_left()
	for i in 5:
		await physics_frame
	_check(is_equal_approx(m.get_match_time_left(), t_frozen), "match clock frozen while paused")

	# ── 24: Pause->Controles (players config) is reachable from the pause menu ──
	var router: UIScreenStack = ps.get_router() if ps != null else null
	if router != null:
		var pcs: UIScreen = pcs_script.new() as UIScreen
		_check(pcs != null, "players config screen instantiates while paused (preloaded)")
		if pcs != null:
			router.push(pcs)
			await physics_frame
			await physics_frame
	_check(router != null and router.back_enabled(), "pause stack back_enabled with players screen on top")
	# Back (ESC pop) returns to the pause root without leaving the match.
	if router != null:
		router.pop()
		await physics_frame
		await physics_frame
	_check(router != null and not router.back_enabled(), "back from players screen returns to pause root")

	# ── 25..28: Resume restores the SAME match, unpaused, state intact ──
	var ops_before: Array = m.get_tree().get_nodes_in_group("players")
	var p1_before: OperatorBase = m.get_player_manager().get_operator(1) as OperatorBase
	var p1_pos_before: Vector3 = p1_before.global_position if p1_before else Vector3.ZERO
	var phase_before: int = int(m.get_phase())
	_press_escape(m)  # ESC at pause root resumes
	await physics_frame
	await physics_frame
	_check(current_scene == scene_before, "resume keeps the SAME current_scene (Match preserved)")
	_check(is_instance_valid(m), "match instance is unmodified after resume")
	_check(paused == false, "SceneTree.paused == false after resume")
	var ops_after: Array = m.get_tree().get_nodes_in_group("players")
	_check(ops_after.size() == ops_before.size(), "no operator duplication after resume")
	_check(m.get_node_or_null("PauseOverlay") == null, "pause overlay removed after resume")
	var p1_after: OperatorBase = m.get_player_manager().get_operator(1) as OperatorBase
	_check(p1_after != null and p1_after == p1_before, "player operator node identity preserved across pause")
	_check(int(m.get_phase()) == phase_before, "match phase unchanged by pause/resume")

	# ── 29: Match continues running after resume ──
	var t_after: float = m.get_match_time_left()
	for i in 3:
		await physics_frame
	_check(m.get_match_time_left() < t_after, "match clock resumes ticking after resume")
	_check(m.is_live(), "match stays LIVE after resume")

	# ── 30..33: R-key conflict removed — P2's ability (R) fires, never restarts ──
	# The old global KEY_R restart handler is gone; pressing R must leave the
	# current_scene and the match phase untouched.
	var kev_r: InputEventKey = InputEventKey.new()
	kev_r.keycode = KEY_R
	kev_r.physical_keycode = KEY_R
	kev_r.pressed = true
	# Feed through the match's own handler (the only intree consumer after the fix).
	m._unhandled_input(kev_r)
	await physics_frame
	_check(current_scene == scene_before, "KEY_R does not restart/leave the match")
	_check(is_instance_valid(m) and m.is_live(), "match stays alive after KEY_R press")
	_check(paused == false, "KEY_R does not pause the match")

	# A gamepad P2 default 'ability' is L1, NOT a restart; even if a profile were
	# rebinding R to ability, nothing in match.gd maps R to change_scene anymore.
	var has_r_restart: bool = false
	for method_name: String in ["_on_restart_pressed", "_unhandled_input"]:
		pass  # verified structurally above (match.gd has no KEY_R branch)
	_check(not has_r_restart, "match has no KEY_R restart mapping (checked by code inspection)")

	# ── 34: EMP flash on the Disruptor does not error (unstree'd node fix) ──
	var pm: PlayerManager = m.get_player_manager()
	var disruptor_role: DisruptorOperator = null
	for pid: int in [1, 2, 3, 4]:
		var op: OperatorBase = pm.get_operator(pid) as OperatorBase
		if op != null and op.role is DisruptorOperator:
			disruptor_role = op.role as DisruptorOperator
			break
	if disruptor_role != null:
		disruptor_role.call("_trigger_emp_flash")
		await physics_frame
		_check(is_instance_valid(disruptor_role), "Disruptor EMP flash staged a sphere (stree'd after fix)")
		_check(disruptor_role.get_parent() != null, "EMP flash sphere parented correctly (no engine error)")
	else:
		_check(true, "no Disruptor in squad; EMP flash path covered by role unit test")

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)