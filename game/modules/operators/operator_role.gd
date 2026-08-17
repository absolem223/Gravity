# operator_role.gd
# Technical Rationale: Abstract base component for operator roles/doctrines.
# Provides the common interface for passive modifiers and active abilities.
# Composed onto OperatorBase via assign_role() — no inheritance depth increase.
# Designed for reuse across Gen1/Gen2/Gen3 doctrines.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name OperatorRole
extends Node

## ──────────────────────────────────────────────
## SIGNALS
## ──────────────────────────────────────────────
signal ability_activated(role_name: String)
signal ability_ready
signal cooldown_tick(remaining: float)

## ──────────────────────────────────────────────
## ROLE IDENTITY (override in derived classes)
## ──────────────────────────────────────────────
@export var role_name: String = "Operator"
@export var description: String = "Generic operator."
@export var icon_placeholder: String = "◈"   ## Unicode icon for HUD placeholder

## ──────────────────────────────────────────────
## ABILITY CONFIGURATION
## ──────────────────────────────────────────────
@export_range(0.0, 60.0, 0.5) var ability_cooldown: float = 10.0

## True when the ability damages/disrupts enemies. Offensive abilities are
## blocked while the operator stands inside its protected spawn room.
@export var is_offensive_ability: bool = false

## ──────────────────────────────────────────────
## RUNTIME STATE
## ──────────────────────────────────────────────
var _cooldown_current: float = 0.0      ## Time remaining before ability is available
var _operator: OperatorBase = null      ## Owning operator (set by assign_to)
var _is_ready: bool = true              ## True when ability can be activated

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	_cooldown_current = 0.0
	_is_ready = true

func _process(delta: float) -> void:
	_process_cooldown(delta)

## ──────────────────────────────────────────────
## PUBLIC API
## ──────────────────────────────────────────────

## Called by OperatorBase.assign_role() — sets the owning operator and applies passives.
func assign_to(op: OperatorBase) -> void:
	_operator = op
	apply_passives()

## Returns true if ability is off cooldown.
func is_ability_ready() -> bool:
	return _is_ready

## Returns cooldown remaining in seconds (0.0 if ready).
func get_cooldown_remaining() -> float:
	return _cooldown_current

## Returns cooldown progress ratio (0.0 = ready, 1.0 = just activated).
func get_cooldown_ratio() -> float:
	if ability_cooldown <= 0.0:
		return 0.0
	return _cooldown_current / ability_cooldown

## External trigger: called by OperatorBase when the ability input is pressed.
func try_activate_ability() -> bool:
	if not _is_ready or _operator == null:
		return false
	if _operator.is_incapacitated:
		return false
	if is_offensive_ability and _operator.is_in_spawn_zone():
		return false
	_activate_ability()
	_start_cooldown()
	ability_activated.emit(role_name)
	return true

## ──────────────────────────────────────────────
## VIRTUAL METHODS — Override in derived roles
## ──────────────────────────────────────────────

## Override: apply passive stat modifications to the operator.
func apply_passives() -> void:
	pass

## Override: implement role-specific active ability logic.
func _activate_ability() -> void:
	pass

## ──────────────────────────────────────────────
## COOLDOWN MANAGEMENT
## ──────────────────────────────────────────────

func _start_cooldown() -> void:
	_cooldown_current = ability_cooldown
	_is_ready = false

func _process_cooldown(delta: float) -> void:
	if _is_ready:
		return
	_cooldown_current = maxf(0.0, _cooldown_current - delta)
	cooldown_tick.emit(_cooldown_current)
	if _cooldown_current <= 0.0:
		_is_ready = true
		ability_ready.emit()
