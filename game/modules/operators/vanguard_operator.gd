# vanguard_operator.gd
# Technical Rationale: Vanguard operator role. Specialises in front-line durability.
# Passives: HP +50% (100 → 150), incoming damage mitigation 20% (via operator.damage_mitigation),
#           revive restore_hp_ratio increased to 0.7 (vs 0.5 base).
# Active ability: FORTIFY — 5-second window of +40% extra damage mitigation (total 60%).
# Cooldown: 20 seconds.
# Does NOT modify movement speed, weapon range, or drone behaviour.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name VanguardOperator
extends OperatorRole

## Passive HP multiplier
const HP_MULTIPLIER: float           = 1.5    ## 100 → 150 HP
const BASE_MITIGATION: float         = 0.20   ## 20% permanent damage reduction
const REVIVE_HP_RATIO: float         = 0.70   ## Revives at 70% HP (vs 50% base)

## FORTIFY ability configuration
@export_range(1.0, 15.0, 0.5) var fortify_duration: float = 5.0
@export var fortify_extra_mitigation: float = 0.40  ## +40% during FORTIFY (total 60%)

## Runtime state
var _fortify_active: bool    = false
var _fortify_timer: float    = 0.0

func _ready() -> void:
	role_name        = "VANGUARD"
	description      = "Front-line specialist. Increased HP and damage resistance."
	icon_placeholder = "⬡"
	ability_cooldown = 20.0
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	_process_fortify(delta)

## ──────────────────────────────────────────────
## PASSIVES
## ──────────────────────────────────────────────

func apply_passives() -> void:
	if _operator == null:
		return
	## Increase max HP
	_operator.health_max     *= HP_MULTIPLIER
	_operator.health_current  = _operator.health_max
	## Apply base damage mitigation
	_operator.damage_mitigation = BASE_MITIGATION
	print("[VanguardOperator] Passives applied to P%d. HP=%.0f Mitigation=%.0f%%" % [
		_operator.player_id,
		_operator.health_max,
		BASE_MITIGATION * 100.0
	])

## ──────────────────────────────────────────────
## ACTIVE: FORTIFY
## ──────────────────────────────────────────────

func _activate_ability() -> void:
	if _fortify_active:
		return
	_fortify_active = true
	_fortify_timer  = fortify_duration
	if _operator != null:
		_operator.damage_mitigation = BASE_MITIGATION + fortify_extra_mitigation
	print("[VanguardOperator] P%d FORTIFY activated — %.0f%% total mitigation for %.1fs" % [
		_operator.player_id if _operator != null else 0,
		(BASE_MITIGATION + fortify_extra_mitigation) * 100.0,
		fortify_duration
	])

func _process_fortify(delta: float) -> void:
	if not _fortify_active:
		return
	_fortify_timer -= delta
	if _fortify_timer <= 0.0:
		_fortify_active = false
		if _operator != null:
			_operator.damage_mitigation = BASE_MITIGATION  ## Return to base passive
		print("[VanguardOperator] P%d FORTIFY expired — reverted to base %.0f%% mitigation" % [
			_operator.player_id if _operator != null else 0,
			BASE_MITIGATION * 100.0
		])

## Public query for HUD
func is_fortify_active() -> bool:
	return _fortify_active

func get_fortify_remaining() -> float:
	return _fortify_timer
