# terminal_manager.gd
# Technical Rationale: Generic coordinator for capturable objectives (Terminal IA).
# Registers AICore instances, aggregates their signals with the objective's id,
# and forwards state/presence/progress to Match and SquadHUD. Contains NO
# terminal-specific logic — terminals own their logic; this node only coordinates.
# Adding a new objective = instantiate another AICore; no code change here.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name TerminalManager
extends Node

## ──────────────────────────────────────────────
## SIGNALS (terminal_id-prefixed aggregation for Match / HUD)
## ──────────────────────────────────────────────
signal terminal_registered(terminal_id: String)
signal terminal_hack_started(terminal_id: String, team_id: int)
signal terminal_progress_changed(terminal_id: String, progress: float, team_id: int)
signal terminal_contested(terminal_id: String)
signal terminal_degrading(terminal_id: String, progress: float)
signal terminal_completed(terminal_id: String, team_id: int)
signal terminal_ownership_changed(terminal_id: String, new_owner_team: int)
signal terminal_state_changed(terminal_id: String, state: HackController.CoreState)
signal terminal_presence_changed(terminal_id: String, active: bool)

## Registered objectives: terminal_id -> AICore
var _terminals: Dictionary = {}

## ──────────────────────────────────────────────
## REGISTRATION
## ──────────────────────────────────────────────

## Registers an AICore as a managed objective and re-emits its signals with id.
func register_terminal(core: AICore) -> void:
	if core == null:
		return
	if core.terminal_id.is_empty():
		push_warning("[TerminalManager] Ignoring AICore '%s': terminal_id is empty." % core.name)
		return
	if _terminals.has(core.terminal_id):
		push_warning("[TerminalManager] Duplicate terminal_id '%s' ignored." % core.terminal_id)
		return

	_terminals[core.terminal_id] = core

	core.hack_started.connect(func(team: int) -> void:
		terminal_hack_started.emit(core.terminal_id, team)
	)
	core.hack_progress_changed.connect(func(progress: float, team: int) -> void:
		terminal_progress_changed.emit(core.terminal_id, progress, team)
	)
	core.hack_contested.connect(func() -> void:
		terminal_contested.emit(core.terminal_id)
	)
	core.hack_degrading.connect(func(progress: float) -> void:
		terminal_degrading.emit(core.terminal_id, progress)
	)
	core.hack_completed.connect(func(team: int) -> void:
		terminal_completed.emit(core.terminal_id, team)
	)
	core.ownership_changed.connect(func(new_owner: int) -> void:
		terminal_ownership_changed.emit(core.terminal_id, new_owner)
	)
	core.state_changed.connect(func(state: HackController.CoreState) -> void:
		terminal_state_changed.emit(core.terminal_id, state)
	)
	core.presence_changed.connect(func(active: bool) -> void:
		terminal_presence_changed.emit(core.terminal_id, active)
	)

	terminal_registered.emit(core.terminal_id)
	print("[TerminalManager] Registered objective '%s' (%s). Total objectives: %d" % [
		core.terminal_id, core.terminal_display_name, _terminals.size()
	])

## Discovers and registers all AICore instances currently in the tree.
## Call after the Arena has been instantiated.
func register_all_from_group() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("ai_core"):
		if node is AICore and not node.is_queued_for_deletion():
			register_terminal(node as AICore)

## ──────────────────────────────────────────────
## QUERIES (state read-only — no terminal logic here)
## ──────────────────────────────────────────────

func get_terminal(terminal_id: String) -> AICore:
	return _terminals.get(terminal_id, null) as AICore

func get_terminals() -> Array[AICore]:
	return _terminals.values()

func get_terminal_ids() -> Array[String]:
	return _terminals.keys()

func get_terminal_count() -> int:
	return _terminals.size()

func get_progress(terminal_id: String) -> float:
	var core: AICore = get_terminal(terminal_id)
	return core.get_progress() if core != null else 0.0

func get_state(terminal_id: String) -> HackController.CoreState:
	var core: AICore = get_terminal(terminal_id)
	return core.get_current_state() if core != null else HackController.CoreState.IDLE

func get_owning_team(terminal_id: String) -> int:
	var core: AICore = get_terminal(terminal_id)
	return core.get_owning_team() if core != null else -1

## True when at least one objective has been fully captured.
func is_any_captured() -> bool:
	for core: AICore in _terminals.values():
		if core.get_current_state() == HackController.CoreState.CAPTURED:
			return true
	return false

## True when every registered objective is fully captured.
func are_all_captured() -> bool:
	if _terminals.is_empty():
		return false
	for core: AICore in _terminals.values():
		if core.get_current_state() != HackController.CoreState.CAPTURED:
			return false
	return true
