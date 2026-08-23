# test_drone_ammo_budget.gd
# Technical Rationale: Regression test for the drone ammo model under a
# sustained held trigger (R2). Drives the drone's real production fire loop
# (_process_drone_combat + weapon.tick) with a stubbed InputManager reporting the
# fire action as held, then asserts the FULL_AUTO cadence, the magazine drain +
# auto-reload cycle, and the UNLIMITED reserve contract: the companion drone's
# spare-magazine pool never runs dry (reserve_unlimited = true), so sustained
# fire continues indefinitely across reloads while per-shot consumption, the
# full reload duration and the fire-rate window stay fully enforced. Finite
# out-of-ammo behaviour remains an OPERATOR-side concern and is covered by the
# combat tests. No balance tuning is touched; GRAVITY-D profile
# (8 dmg / 13 range / 0.6s, mag 16, reserve 1) must not change.
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

## Ammo observer: counts rounds consumed (drops) and skips magazine refills.
var _shots: int = 0
var _last_shot_tick: int = -999
var _min_gap_ticks: int = 999999
var _last_reported: int = -1
var _loop_tick: int = 0
var _refills: int = 0

func _on_reload_finished() -> void:
	_refills += 1

func _on_mag_changed(rounds: int, _cap: int) -> void:
	if rounds > _last_reported:
		_last_reported = rounds
		return
	var n: int = _last_reported - rounds
	_last_reported = rounds
	var gap_ticks: int = _loop_tick - _last_shot_tick
	if _last_shot_tick >= 0 and gap_ticks < _min_gap_ticks:
		_min_gap_ticks = gap_ticks
	_last_shot_tick = _loop_tick
	_shots += n

## Minimal InputManager stub: reports "fire" as continuously held so the drone's
## pilot loop believes the R2 trigger is pressed (headless has no physical pad).
class HeldFireInput:
	extends InputManager
	func is_action_pressed(_player_id: int, _suffix: String) -> bool:
		return true

func run_test() -> void:
	print("== DRONE AMMO BUDGET TEST (held-trigger full-auto) ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = 1
	op.team_id = OperatorBase.TEAM_ATTACKERS
	op.position = Vector3(-4.0, 0.0, 0.0)
	root.add_child(op)
	var held_fire: HeldFireInput = HeldFireInput.new()
	root.add_child(held_fire)
	op._input_manager = held_fire

	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.operator = op
	drone.position = Vector3(-2.0, 0.6, 0.0)
	root.add_child(drone)

	for i in range(8):
		await get_root().get_tree().physics_frame
	drone.set_mode(DroneBase.DroneMode.STATIONARY)
	await get_root().get_tree().physics_frame

	var w: WeaponBase = drone.weapon
	_check(w != null and w.weapon_name == "GRAVITY-D", "drone weapon is GRAVITY-D")
	_check(w != null and w.fire_mode.type == FireMode.Type.FULL_AUTO, "drone is FULL_AUTO (hold R2 -> continuous fire)")
	_check(w != null and w.magazine.capacity == 16 and w.magazine.current_rounds == 16, "drone starts with mag 16/16")
	_check(w != null and w.reserve.max_magazines == 1 and w.reserve.magazines_remaining == 1, "drone starts with 1 reserve magazine")
	_check(w != null and w.reserve.unlimited_magazines, "drone reserve is UNLIMITED (companion sustains autonomous fire)")

	# ── Drive the real pilot loop with the trigger held well past the old
	#    finite budget (16 mag + 1 reserve = 32 rounds) to prove sustained fire ──
	_shots = 0
	_last_shot_tick = -999
	_min_gap_ticks = 999999
	_last_reported = w.magazine.current_rounds
	w.magazine_changed.connect(_on_mag_changed)
	w.reload_finished.connect(_on_reload_finished)
	var i: int = 0
	while i < 4000 and _shots < 40:
		var delta: float = 0.03
		_loop_tick = i
		w.tick(delta)
		drone._process_drone_combat(delta)
		i += 1

	print("    [probe] shots fired = ", _shots, " | reloads = ", _refills, " | min gap ticks = ", _min_gap_ticks)
	_check(_shots >= 40, "held trigger fires PAST the old finite budget (>= 40 rounds, unlimited reserve)")
	_check(_refills >= 2, "auto-reload cycled at least twice (magazine refilled from reserve)")
	_check(w.reserve.magazines_remaining == w.reserve.max_magazines, "spare-magazine counter untouched by unlimited mode (take_magazine no-ops)")
	_check(w.is_out_of_ammo() == false, "drone NEVER reaches hard out-of-ammo while reserve is unlimited")
	# FULL_AUTO cadence: the fire rate window should never fire twice inside a
	# single 30 ms tick, and the observed minimum gap should respect the cooldown.
	_check(_min_gap_ticks >= 10 or _shots == 0, "no two rounds inside the same fire-rate window (cadence respected)")

	# ── Firing continues indefinitely: shots keep growing after the budget mark ──
	var shots_before_idle: int = _shots
	var grew: bool = false
	for j in range(400):
		w.tick(0.03)
		drone._process_drone_combat(0.03)
		if _shots > shots_before_idle:
			grew = true
			break
	_check(grew, "fire continues past the 32-round legacy budget (sustained loop)")
	_check(w.magazine.current_rounds > 0 or w.is_reloading(), "magazine active or reloading (never stuck empty)")

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)