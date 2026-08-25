# hack_controller.gd
# Technical Rationale: State machine and progress engine for the AI Core hacking mechanic.
# Manages IDLE, HACKING, CONTESTED, DEGRADED, and CAPTURED states with configurable timings.
# Emits all public signals consumed by HUD, audio, IA defensora, and objective systems.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name HackController
extends Node

## ──────────────────────────────────────────────
## SIGNALS (Public API — consumed by HUD, audio, AI, objectives)
## ──────────────────────────────────────────────
signal hack_started(team_id: int)
signal hack_progress_changed(progress: float, team_id: int)
signal hack_contested
signal hack_degrading(progress: float)
signal hack_completed(team_id: int)
signal ownership_changed(new_owner_team: int)

## ──────────────────────────────────────────────
## CORE STATE ENUM
## ──────────────────────────────────────────────
enum CoreState {
	IDLE,       ## No team in perimeter
	HACKING,    ## One team controls the perimeter — progress advances
	CONTESTED,  ## Both teams in perimeter — progress frozen
	DEGRADED,   ## Attacking team left — progress decays at -10% per 30s
	CAPTURED    ## Progress reached 100% — core captured
}

## ──────────────────────────────────────────────
## EXPORTED CONFIGURATION (All timings in seconds, all speeds per second)
## ──────────────────────────────────────────────

## Hack progress speed (% per second) when a team controls the perimeter
@export_range(1.0, 30.0, 0.5) var hack_speed_percent_per_second: float = 5.0

## Degradation speed — applied every degradation_interval_seconds
## Design Decision (Phase 0.5): -10% every 30 seconds. Never instant reset.
@export_range(1.0, 30.0, 0.5) var degradation_percent_per_tick: float = 10.0
@export_range(5.0, 120.0, 1.0) var degradation_interval_seconds: float = 30.0

## Capture threshold (%) required to trigger CAPTURED state
@export_range(50.0, 100.0, 1.0) var capture_threshold_percent: float = 100.0

## Minimum operators needed to contest (each team must have at least this many)
@export_range(1, 4, 1) var min_operators_to_contest: int = 1

## ──────────────────────────────────────────────
## RUNTIME STATE
## ──────────────────────────────────────────────
var current_state: CoreState = CoreState.IDLE
var hack_progress: float = 0.0       ## 0.0 to 100.0
var hacking_team_id: int = -1        ## Team currently hacking (-1 = none)
var owning_team_id: int = -1         ## Team that captured the core (-1 = none)

## Presence tracking: team_id -> operator count in perimeter
var _team_presence: Dictionary = {}

## Degradation accumulator
var _degradation_timer: float = 0.0

## Internal: previous state for change detection
var _previous_state: CoreState = CoreState.IDLE

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	_team_presence.clear()
	current_state = CoreState.IDLE
	hack_progress = 0.0
	print("[HackController] Initialized. hack_speed=%.1f%%/s  degradation=-%.1f%% per %.0fs" % [
		hack_speed_percent_per_second, degradation_percent_per_tick, degradation_interval_seconds
	])

func _process(delta: float) -> void:
	_evaluate_state()
	_process_state_logic(delta)
	_emit_on_state_change()

## ──────────────────────────────────────────────
## PUBLIC API — Called by CoreCaptureZone
## ──────────────────────────────────────────────

## Registers an operator entering the perimeter
func register_entry(team_id: int, operator_id: int) -> void:
	if not _team_presence.has(team_id):
		_team_presence[team_id] = {}
	_team_presence[team_id][operator_id] = true
	print("[HackController] Team %d Operator %d entered perimeter. Presence: %s" % [team_id, operator_id, str(_team_presence)])

## Registers an operator leaving the perimeter
func register_exit(team_id: int, operator_id: int) -> void:
	if _team_presence.has(team_id):
		_team_presence[team_id].erase(operator_id)
		if _team_presence[team_id].is_empty():
			_team_presence.erase(team_id)
	print("[HackController] Team %d Operator %d exited perimeter. Presence: %s" % [team_id, operator_id, str(_team_presence)])

## Returns current progress (0.0–100.0)
func get_progress() -> float:
	return hack_progress

## Returns current state as enum
func get_current_state() -> CoreState:
	return current_state

## Returns the team currently hacking (-1 if none)
func get_hacking_team() -> int:
	return hacking_team_id

## Returns the team that owns the core (-1 if none)
func get_owning_team() -> int:
	return owning_team_id

## Returns presence count for a given team (only counts active, non-dead operators)
func get_team_presence_count(team_id: int) -> int:
	if not _team_presence.has(team_id):
		return 0
	var pm: PlayerManager = null
	if is_inside_tree():
		var pm_nodes: Array[Node] = get_tree().get_nodes_in_group("player_manager")
		if not pm_nodes.is_empty():
			pm = pm_nodes[0] as PlayerManager

	var active_count: int = 0
	for op_id: int in _team_presence[team_id].keys():
		var op: OperatorBase = null
		if pm != null:
			op = pm.get_operator(op_id)
		if op == null and is_inside_tree():
			for p_node: Node in get_tree().get_nodes_in_group("players"):
				if p_node is OperatorBase and not p_node.is_queued_for_deletion():
					var o: OperatorBase = p_node as OperatorBase
					if o.player_id == op_id:
						op = o
						break
		if op != null:
			if not op.is_dead and not op.is_incapacitated:
				active_count += 1
		else:
			active_count += 1
	return active_count

## Returns array of all teams with presence in the perimeter
func get_present_teams() -> Array[int]:
	var teams: Array[int] = []
	for k: int in _team_presence.keys():
		if get_team_presence_count(k) >= min_operators_to_contest:
			teams.append(k)
	return teams

## Returns the capture speed multiplier (1.0 or 2.0) for a team based on perimeter presence.
## 2.0x if allied_count >= 2 and enemy_count < 2; otherwise 1.0x.
func get_capture_speed_multiplier(team_id: int) -> float:
	var allied_count: int = get_team_presence_count(team_id)
	var enemy_count: int = 0
	for t: int in _team_presence.keys():
		if t != team_id:
			enemy_count += get_team_presence_count(t)
	return 2.0 if (allied_count >= 2 and enemy_count < 2) else 1.0

## ──────────────────────────────────────────────
## STATE EVALUATION LOGIC
## ──────────────────────────────────────────────

## Determines which state should be active based on perimeter presence.
## A CAPTURED core stays captured while its owner is present, but a RIVAL team
## entering the perimeter can re-capture it: the hack restarts from 0% and the
## owner changes once the rival reaches the threshold (Supremacy reset rule).
func _evaluate_state() -> void:
	var present_teams: Array[int] = get_present_teams()
	var team_count: int = present_teams.size()

	if team_count == 0:
		## No teams present
		if current_state == CoreState.CAPTURED:
			return  ## Captured cores persist with no presence
		if hack_progress > 0.0 and current_state != CoreState.IDLE:
			## Progress exists — must degrade
			current_state = CoreState.DEGRADED
		else:
			current_state = CoreState.IDLE
			hacking_team_id = -1
		return

	if current_state == CoreState.CAPTURED:
		## Owning team present alone -> stays captured.
		if team_count == 1 and present_teams[0] == owning_team_id:
			return
		## Owner + rival (or pure rival): re-capture is now possible.
		if team_count >= 2:
			current_state = CoreState.CONTESTED
		else:
			## A single rival team starts a fresh re-hack from 0%.
			hack_progress = 0.0
			hacking_team_id = present_teams[0]
			current_state = CoreState.HACKING
		return

	if team_count == 1:
		## One team controls — HACKING
		hacking_team_id = present_teams[0]
		current_state = CoreState.HACKING
		_degradation_timer = 0.0  ## Reset degradation timer when hacking resumes

	elif team_count >= 2:
		## Multiple teams — CONTESTED
		current_state = CoreState.CONTESTED

## ──────────────────────────────────────────────
## STATE LOGIC PROCESSING
## ──────────────────────────────────────────────

func _process_state_logic(delta: float) -> void:
	match current_state:
		CoreState.IDLE:
			_process_idle()
		CoreState.HACKING:
			_process_hacking(delta)
		CoreState.CONTESTED:
			_process_contested()
		CoreState.DEGRADED:
			_process_degraded(delta)
		CoreState.CAPTURED:
			pass  ## No processing — game event handled at transition

func _process_idle() -> void:
	pass  ## Progress stable at 0 or previous value — no action

func _process_hacking(delta: float) -> void:
	var multiplier: float = get_capture_speed_multiplier(hacking_team_id)
	hack_progress += hack_speed_percent_per_second * multiplier * delta
	hack_progress = minf(hack_progress, capture_threshold_percent)
	hack_progress_changed.emit(hack_progress, hacking_team_id)

	if hack_progress >= capture_threshold_percent:
		_transition_to_captured()

func _process_contested() -> void:
	## Progress frozen — emit contested signal for HUD polling
	hack_contested.emit()

func _process_degraded(delta: float) -> void:
	_degradation_timer += delta
	if _degradation_timer >= degradation_interval_seconds:
		_degradation_timer -= degradation_interval_seconds
		hack_progress = maxf(0.0, hack_progress - degradation_percent_per_tick)
		hack_degrading.emit(hack_progress)
		hack_progress_changed.emit(hack_progress, hacking_team_id)
		print("[HackController] DEGRADATION tick — progress now %.1f%%" % hack_progress)

		if hack_progress <= 0.0:
			current_state = CoreState.IDLE
			hacking_team_id = -1

## ──────────────────────────────────────────────
## STATE TRANSITIONS
## ──────────────────────────────────────────────

func _transition_to_captured() -> void:
	current_state = CoreState.CAPTURED
	var prev_owner: int = owning_team_id
	owning_team_id = hacking_team_id
	hack_progress = 100.0

	print("[HackController] *** CORE CAPTURED by Team %d ***" % owning_team_id)
	hack_completed.emit(owning_team_id)

	if prev_owner != owning_team_id:
		ownership_changed.emit(owning_team_id)

## ──────────────────────────────────────────────
## STATE CHANGE SIGNAL EMISSION
## ──────────────────────────────────────────────

## Emits hack_started when transitioning into HACKING from another state
func _emit_on_state_change() -> void:
	if current_state == CoreState.HACKING and _previous_state != CoreState.HACKING:
		hack_started.emit(hacking_team_id)
	_previous_state = current_state
