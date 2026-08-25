# drone_ai_controller.gd
# Technical Rationale: Minimal autonomy layer for AI-OWNED drones (Etapa 9
# extension). Drives each drone whose operator is flagged is_ai_controlled
# through a 4-state cycle — ESCORT -> SEARCH -> ENGAGE -> RETURN — by assigning
# DroneBase.ai_steering_target, a pure CONTROL seam that retargets the existing
# escort autopilot. The drone never leaves ESCORT mode and never receives new
# stats: movement uses the stock escort velocity math, combat uses the existing
# _process_autonomous_combat pipeline (range + LoS + FULL_AUTO + reload), and
# detection comes from the drone's own VisionCone3D.
#
# Deliberately simple per sprint constraints: no pathfinding, no formations,
# no multi-drone coordination, no target prioritisation beyond "nearest".
# Human-owned drones are never touched.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name DroneAIController
extends Node

## Autonomy states for one AI drone.
enum State { ESCORT, SEARCH, ENGAGE, RETURN }

## ── Tuning seams (vars so tests can shorten cycles deterministically) ──────
## Escort seconds before the drone is sent on a search probe.
var search_trigger_interval: float = 7.0
## Max seconds spent probing one search point.
var search_timeout: float = 8.0
## Search probes stay within this radius of the operator (max_range_from_operator is 28).
var search_max_radius: float = 18.0
## Stand-off distance kept from a locked enemy (< weapon_range 12m so the
## existing autonomous combat can open fire).
var engage_standoff: float = 9.0
## Seconds without cone visibility of the engaged target before giving up.
var target_lose_timeout: float = 3.0
## Distance to the escort anchor that counts as "back home".
var return_arrive_dist: float = 2.5
## Cruise altitude used for AI steering points (matches follow_height_offset).
var think_altitude: float = 2.4

var _match: Match = null
var _player_manager: PlayerManager = null
var _terminal_manager: TerminalManager = null
var _arena: Arena = null

## Per-drone brain state: drone instance_id -> {"state", "point", "timer", "target", "lose"}
var _states: Dictionary = {}

func _ready() -> void:
	set_physics_process(true)

## Binds the controller to the owning Match and its subsystems (mirrors AIController.setup).
func setup(match: Match) -> void:
	_match = match
	if match == null:
		return
	_player_manager = match.get_player_manager()
	_terminal_manager = match.get_terminal_manager()
	_arena = match.get_arena()

func _physics_process(delta: float) -> void:
	tick(delta)

## One controller step. Public so headless tests can drive determinism manually.
func tick(delta: float) -> void:
	if not _active():
		_release_all()
		return
	if _player_manager == null:
		return
	for op: OperatorBase in _player_manager.get_all_operators():
		if not op.is_ai_controlled:
			continue
		var drone: DroneBase = op.drone
		if drone == null or not is_instance_valid(drone) or drone.is_queued_for_deletion():
			continue
		_drive_drone(drone, delta)
	_prune_stale_states()

## Live gate: production requires a live match; harnesses may leave _match null.
func _active() -> bool:
	if _player_manager == null:
		return false
	return _match == null or _match.is_live()

## ──────────────────────────────────────────────
## PER-DRONE FSM
## ──────────────────────────────────────────────

func _drive_drone(drone: DroneBase, delta: float) -> void:
	var op: OperatorBase = drone.operator
	# Safety: operator gone/downed/drone detached -> drop all steering instantly.
	if op == null or not is_instance_valid(op) or op.is_incapacitated:
		drone.ai_steering_target = null
		_states.erase(drone.get_instance_id())
		return

	var id: int = drone.get_instance_id()
	var st: Dictionary = _states.get(id, _fresh_state())

	match int(st["state"]):
		State.ESCORT:
			_tick_escort(drone, st, delta)
		State.SEARCH:
			_tick_search(drone, st, delta)
		State.ENGAGE:
			_tick_engage(drone, st, delta)
		State.RETURN:
			_tick_return(drone, st, delta)

	_states[id] = st

func _tick_escort(drone: DroneBase, st: Dictionary, delta: float) -> void:
	# Stock behaviour: no steering override at all.
	drone.ai_steering_target = null
	st["timer"] = float(st["timer"]) + delta
	if float(st["timer"]) >= search_trigger_interval:
		st["state"] = State.SEARCH
		st["timer"] = 0.0
		st["point"] = _pick_search_point(drone.operator)

func _tick_search(drone: DroneBase, st: Dictionary, delta: float) -> void:
	st["timer"] = float(st["timer"]) + delta
	var point: Vector3 = st["point"]
	drone.ai_steering_target = point

	# Found something? Nearest valid enemy currently in the drone's vision cone.
	var enemy: Node3D = _acquire_visible_enemy(drone)
	if enemy != null:
		st["state"] = State.ENGAGE
		st["target"] = enemy
		st["lose"] = 0.0
		return

	var to_point: Vector3 = point - drone.global_position
	to_point.y = 0.0
	var arrived: bool = to_point.length() < 1.0
	if arrived or float(st["timer"]) >= search_timeout:
		st["state"] = State.RETURN
		st["timer"] = 0.0

func _tick_engage(drone: DroneBase, st: Dictionary, delta: float) -> void:
	var target: Node3D = st["target"]
	var op: OperatorBase = drone.operator
	var valid: bool = target != null and is_instance_valid(target) and not target.is_queued_for_deletion()
	if valid and target is OperatorBase:
		valid = not (target as OperatorBase).is_incapacitated and (target as OperatorBase).team_id != op.team_id
	if not valid:
		st["state"] = State.RETURN
		st["target"] = null
		st["timer"] = 0.0
		drone.ai_steering_target = null
		return

	# Track visibility through the SAME cone that acquired the target; after
	# target_lose_timeout without seeing it, break off and go home.
	var cone: VisionCone3D = drone.vision_cone
	if cone != null and not cone.is_target_visible(target):
		st["lose"] = float(st["lose"]) + delta
		if float(st["lose"]) >= target_lose_timeout:
			st["state"] = State.RETURN
			st["target"] = null
			st["timer"] = 0.0
			drone.ai_steering_target = null
			return
	else:
		st["lose"] = 0.0

	# Stand-off manoeuvre: close in until engage_standoff, then hold position.
	# The existing autonomous combat aims the hull and fires once inside its
	# weapon range with LoS — this layer only decides WHERE to hover.
	var tpos: Vector3 = target.global_position
	var away: Vector3 = drone.global_position - tpos
	away.y = 0.0
	var dist: float = away.length()
	if dist > engage_standoff + 1.0:
		st["point"] = tpos + (away / maxf(dist, 0.01)) * engage_standoff
	else:
		st["point"] = Vector3(drone.global_position.x, think_altitude, drone.global_position.z)
	st["point"].y = think_altitude
	drone.ai_steering_target = st["point"]

func _tick_return(drone: DroneBase, st: Dictionary, _delta: float) -> void:
	var op: OperatorBase = drone.operator
	var anchor: Vector3 = op.global_position + (op.global_transform.basis.z * drone.follow_distance) + Vector3(0.0, drone.follow_height_offset, 0.0)
	drone.ai_steering_target = anchor
	var offset: Vector3 = anchor - drone.global_position
	offset.y = 0.0
	if offset.length() <= return_arrive_dist:
		st["state"] = State.ESCORT
		st["timer"] = 0.0
		st["target"] = null
		# Seamless handover to the stock escort autopilot.
		drone.ai_steering_target = null

## ──────────────────────────────────────────────
## HELPERS
## ──────────────────────────────────────────────

## Nearest valid ENEMY OPERATOR currently inside the drone's vision cone.
## (Cones scan ["players","enemies"]; drones are not in those groups, so enemy
## drones are not detectable — an existing engine-wide limitation, unchanged.)
func _acquire_visible_enemy(drone: DroneBase) -> Node3D:
	var cone: VisionCone3D = drone.vision_cone
	if cone == null:
		return null
	var my_team: int = drone.operator.team_id
	var best: Node3D = null
	var best_dist: float = INF
	for t: Node3D in cone.get_detected_targets():
		if t == null or not is_instance_valid(t) or t.is_queued_for_deletion():
			continue
		if not (t is OperatorBase):
			continue
		var enemy_op: OperatorBase = t as OperatorBase
		if enemy_op.team_id == my_team or enemy_op.is_incapacitated:
			continue
		var d: float = drone.global_position.distance_squared_to(enemy_op.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy_op
	return best

## Probe direction: toward the nearest terminal not owned by our team (same
## doctrine as AIController._select_objective), else the arena centre.
func _pick_search_point(op: OperatorBase) -> Vector3:
	var goal: Vector3 = Vector3.ZERO
	var best_d: float = INF
	if _terminal_manager != null:
		for core: AICore in _terminal_manager.get_terminals():
			if core == null:
				continue
			if core.get_owning_team() == op.team_id:
				continue
			var d: float = op.global_position.distance_squared_to(core.global_position)
			if d < best_d:
				best_d = d
				goal = core.global_position
	var dir: Vector3 = goal - op.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var point: Vector3 = op.global_position + dir * search_max_radius
	point.x += randf_range(-3.0, 3.0)
	point.z += randf_range(-3.0, 3.0)
	point.y = think_altitude
	return point

func _fresh_state() -> Dictionary:
	return {"state": State.ESCORT, "point": Vector3.ZERO, "timer": 0.0, "target": null, "lose": 0.0}

## Drops state entries whose drone vanished; also clears any lingering override.
func _prune_stale_states() -> void:
	var stale: Array[int] = []
	for id: int in _states.keys():
		var found: bool = false
		if _player_manager != null:
			for op: OperatorBase in _player_manager.get_all_operators():
				if op.drone != null and is_instance_valid(op.drone) and op.drone.get_instance_id() == id:
					found = true
					break
		if not found:
			stale.append(id)
	for id: int in stale:
		_states.erase(id)

## Full release: clears every steering override (match end / teardown).
func _release_all() -> void:
	if _states.is_empty():
		return
	if _player_manager != null:
		for op: OperatorBase in _player_manager.get_all_operators():
			if op.drone != null and is_instance_valid(op.drone) and _states.has(op.drone.get_instance_id()):
				op.drone.ai_steering_target = null
	_states.clear()
