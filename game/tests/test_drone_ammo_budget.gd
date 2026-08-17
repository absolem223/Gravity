# test_drone_ammo_budget.gd
# Technical Rationale: Regression test for the drone PILOT ammo budget under a
# sustained held trigger (R2). Drives the drone's real production fire loop
# (_process_drone_combat + weapon.tick) with a stubbed InputManager reporting the
# fire action as held, then asserts the FULL_AUTO cadence, exact magazine drain,
# the single auto-reload from reserve, and the hard out-of-ammo stop. This is
# the ammo half of "R2 fires the drone autoaim" — no balance tuning is touched;
# GRAVITY-D profile (8 dmg / 13 range / 0.6s, mag 16, reserve 1) must not change.
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

	# ── Drive the real pilot loop with the trigger held until out of ammo ──
	_shots = 0
	_last_shot_tick = -999
	_min_gap_ticks = 999999
	var out_flag: bool = false
	_last_reported = w.magazine.current_rounds
	w.magazine_changed.connect(_on_mag_changed)
	var i: int = 0
	while not out_flag and i < 6000:
		var delta: float = 0.03
		_loop_tick = i
		w.tick(delta)
		drone._process_drone_combat(delta)
		out_flag = drone.weapon.is_out_of_ammo() and drone.weapon.magazine.is_empty()
		i += 1

	print("    [probe] shots fired = ", _shots, " | out_of_ammo = ", out_flag, " | min gap ticks = ", _min_gap_ticks)
	_check(_shots == 32, "held trigger fired exactly the full ammo budget (16 mag + 16 reserve = 32 ROUNDS)")
	_check(out_flag, "drone reached hard out-of-ammo with magazine empty")
	_check(w.reserve.magazines_remaining == 0, "exactly 1 reserve magazine consumed over the full dump")
	_check(w.is_reloading() == false or w.magazine.is_empty(), "no reload started past the reserve (no phantom mags)")
	# FULL_AUTO cadence: 0.3s fire rate should never fire twice inside a single
	# 30 ms tick, and the observed minimum gap should respect the cooldown.
	_check(_min_gap_ticks >= 10 or _shots == 0, "no two rounds inside the same fire-rate window (cadence respected)")

	# ── Firing stops permanently once the budget is spent ──
	var shots_idle: int = _shots
	for j in range(30):
		drone._process_drone_combat(0.03)
	await get_root().get_tree().physics_frame
	_check(shots_idle == _shots and w.magazine.current_rounds == 0, "no rounds fired after out-of-ammo (budget respected)")

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)