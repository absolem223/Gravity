# recon_operator.gd
# Technical Rationale: Recon operator role. Specialises in information gathering.
# Passives: VisionCone3D view_range +25% (16m → 20m), FOV +25% (90° → 112.5°),
#           scan_interval halved (0.1s → 0.05s) for more frequent target updates.
# Active ability: MARK TARGETS — all currently detected targets are "pinged" into
#           SquadVisionRegistry with a 5s persistence timer, visible to all squad members
#           even after leaving the Recon's personal cone.
# Cooldown: 12 seconds.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name ReconOperator
extends OperatorRole

## Passive vision enhancement constants
const VISION_RANGE_BONUS_MULTIPLIER: float  = 1.25   ## +25% range (16m → 20m)
const VISION_FOV_BONUS_MULTIPLIER: float    = 1.25   ## +25% FOV  (90° → 112.5°)
const SCAN_INTERVAL_MULTIPLIER: float       = 0.5    ## Twice as frequent scans

## Duration (seconds) that marked targets remain in squad registry after leaving cone
@export_range(2.0, 15.0, 0.5) var mark_duration: float = 5.0

## Track marked targets and their expiry timers {Node3D → float}
var _marked_targets: Dictionary = {}

## Reference to the squad vision registry (auto-discovered)
var _squad_registry: SquadVisionRegistry = null

func _ready() -> void:
	role_name        = "RECON"
	description      = "Information specialist. Extended vision and target marking."
	icon_placeholder = "◉"
	ability_cooldown = 12.0
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	_process_mark_timers(delta)

## ──────────────────────────────────────────────
## PASSIVES
## ──────────────────────────────────────────────

func apply_passives() -> void:
	if _operator == null or _operator.vision_cone == null:
		return
	_operator.vision_cone.view_range           *= VISION_RANGE_BONUS_MULTIPLIER
	_operator.vision_cone.field_of_view_degrees *= VISION_FOV_BONUS_MULTIPLIER
	_operator.vision_cone.scan_interval        *= SCAN_INTERVAL_MULTIPLIER
	_squad_registry = _find_squad_registry()
	print("[ReconOperator] Passives applied to P%d. Range=%.1fm FOV=%.1f°" % [
		_operator.player_id,
		_operator.vision_cone.view_range,
		_operator.vision_cone.field_of_view_degrees
	])

## ──────────────────────────────────────────────
## ACTIVE: MARK TARGETS
## ──────────────────────────────────────────────

func _activate_ability() -> void:
	if _operator == null or _operator.vision_cone == null:
		return
	var targets: Array[Node3D] = _operator.vision_cone.get_detected_targets()
	for t: Node3D in targets:
		_marked_targets[t] = mark_duration
	print("[ReconOperator] P%d MARK TARGETS — %d targets marked for %.1fs" % [
		_operator.player_id, targets.size(), mark_duration
	])

## Ticks down mark timers and removes expired marks
func _process_mark_timers(delta: float) -> void:
	var expired: Array[Node3D] = []
	for target: Node3D in _marked_targets.keys():
		var remaining: float = _marked_targets[target] - delta
		if remaining <= 0.0 or not is_instance_valid(target):
			expired.append(target)
		else:
			_marked_targets[target] = remaining
	for t: Node3D in expired:
		_marked_targets.erase(t)

## Returns array of currently marked targets (for HUD or SquadVisionRegistry)
func get_marked_targets() -> Array[Node3D]:
	return Array(_marked_targets.keys())

## Returns remaining mark time for a specific target (0.0 if not marked)
func get_mark_remaining(target: Node3D) -> float:
	return _marked_targets.get(target, 0.0)

func _find_squad_registry() -> SquadVisionRegistry:
	if _operator == null:
		return null
	var nodes: Array[Node] = _operator.get_tree().get_nodes_in_group("squad_vision_registry")
	if not nodes.is_empty():
		return nodes[0] as SquadVisionRegistry
	return null
