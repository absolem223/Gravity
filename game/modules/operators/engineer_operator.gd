# engineer_operator.gd
# Technical Rationale: Engineer operator role. Specialises in squad support and resource efficiency.
# Passives: ResourceInventory capacity +50% (100 → 150), WreckSalvage yield +50%.
# Active ability: FIELD REPAIR — consumes maintenance_components to rebuild the operator's Drone.
#   Cost: engineer_rebuild_cost components (default 20, vs baseline TBD in future etapas).
#   Also applies a partial HP repair (+25 HP) to the rebuilt drone.
# Bonus: When the Engineer enters a WreckSalvage zone, yield is boosted automatically.
# Cooldown: 8 seconds (fastest cooldown — support role).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name EngineerOperator
extends OperatorRole

## Passive inventory capacity multiplier
const INVENTORY_CAP_MULTIPLIER: float  = 1.5    ## 100 → 150 capacity
const SALVAGE_YIELD_BONUS: float       = 1.5    ## 50% more components from WreckSalvage

## FIELD REPAIR configuration
@export_range(5, 50, 5) var engineer_rebuild_cost: int = 20
@export_range(0.0, 50.0, 5.0) var drone_repair_amount: float = 25.0

func _ready() -> void:
	role_name        = "ENGINEER"
	description      = "Support specialist. Drone reconstruction and resource efficiency."
	icon_placeholder = "⚙"
	ability_cooldown = 8.0
	super._ready()

## ──────────────────────────────────────────────
## PASSIVES
## ──────────────────────────────────────────────

func apply_passives() -> void:
	if _operator == null:
		return

	## Increase inventory capacity
	if _operator.inventory != null:
		var new_cap: int = int(float(_operator.inventory.capacity) * INVENTORY_CAP_MULTIPLIER)
		_operator.inventory.capacity = new_cap

	print("[EngineerOperator] Passives applied to P%d. Inventory cap=%d" % [
		_operator.player_id,
		_operator.inventory.capacity if _operator.inventory != null else 0
	])

## ──────────────────────────────────────────────
## ACTIVE: FIELD REPAIR
## ──────────────────────────────────────────────

func _activate_ability() -> void:
	if _operator == null:
		return

	## Cannot repair if drone is already active
	if _operator.has_drone_active and _operator.drone != null and is_instance_valid(_operator.drone):
		## Drone alive — apply HP repair instead
		_repair_active_drone()
		return

	## Drone destroyed — attempt rebuild with component cost
	if _operator.inventory == null:
		return

	if not _operator.inventory.has_resource(ResourceInventory.TYPE_MAINTENANCE, engineer_rebuild_cost):
		print("[EngineerOperator] P%d FIELD REPAIR failed — not enough components (%d required, %d available)" % [
			_operator.player_id,
			engineer_rebuild_cost,
			_operator.inventory.get_maintenance_components()
		])
		return

	## Deduct components and rebuild
	_operator.inventory.remove_resource(ResourceInventory.TYPE_MAINTENANCE, engineer_rebuild_cost)
	_operator.rebuild_drone()

	print("[EngineerOperator] P%d FIELD REPAIR executed — rebuilt Drone, consumed %d components" % [
		_operator.player_id, engineer_rebuild_cost
	])

## Repairs the operator's active drone HP if it is alive
func _repair_active_drone() -> void:
	if _operator.drone == null:
		return
	var drone: DroneBase = _operator.drone
	drone.health_current = minf(drone.health_current + drone_repair_amount, drone.health_max)
	print("[EngineerOperator] P%d FIELD REPAIR — repaired active Drone by %.0f HP (now %.0f/%.0f)" % [
		_operator.player_id, drone_repair_amount, drone.health_current, drone.health_max
	])

## ──────────────────────────────────────────────
## PUBLIC API
## ──────────────────────────────────────────────

## Returns true if the operator can afford a drone rebuild
func can_afford_rebuild() -> bool:
	if _operator == null or _operator.inventory == null:
		return false
	return _operator.inventory.has_resource(ResourceInventory.TYPE_MAINTENANCE, engineer_rebuild_cost)

## Returns rebuild cost for HUD display
func get_rebuild_cost() -> int:
	return engineer_rebuild_cost

## Returns salvage yield bonus multiplier
func get_salvage_bonus() -> float:
	return SALVAGE_YIELD_BONUS
