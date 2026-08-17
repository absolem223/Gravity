# wreck_salvage.gd
# Technical Rationale: Extends WreckSite with salvage interaction.
# When an operator interacts (enters the Area3D trigger), spawns ResourcePickups and destroys the wreck.
# Does NOT modify WreckSite destruction logic — only adds salvage on top via composition.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name WreckSalvage
extends WreckSite

## ──────────────────────────────────────────────
## SIGNALS
## ──────────────────────────────────────────────
signal salvaged(salvager_id: int, components_spawned: int)

## ──────────────────────────────────────────────
## CONFIGURATION
## ──────────────────────────────────────────────

## Base components generated per salvage event
@export_range(1, 30, 1) var components_per_salvage: int = 8

## Whether the salvage has already been triggered (prevents double-trigger)
var _salvaged: bool = false

## ──────────────────────────────────────────────
## INTERNAL NODES
## ──────────────────────────────────────────────
var _salvage_zone: Area3D = null
var _salvage_label: Label3D = null

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	super._ready()
	_build_salvage_zone()
	_build_salvage_label()
	print("[WreckSalvage] Salvageable wreck at %s — %d components available" % [str(global_position), components_per_salvage])

## ──────────────────────────────────────────────
## SALVAGE AREA CONSTRUCTION
## ──────────────────────────────────────────────

## Creates a separate Area3D for salvage proximity detection.
## This is distinct from the WreckSite StaticBody3D to avoid physics conflicts.
func _build_salvage_zone() -> void:
	_salvage_zone = Area3D.new()
	_salvage_zone.name = "SalvageZone"

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	col.shape = box
	_salvage_zone.add_child(col)

	_salvage_zone.body_entered.connect(_on_salvage_zone_entered)
	add_child(_salvage_zone)

func _build_salvage_label() -> void:
	_salvage_label = Label3D.new()
	_salvage_label.name = "SalvageLabel"
	_salvage_label.text = "⚙ SALVAGE [+%d COMP]" % components_per_salvage
	_salvage_label.font_size = 22
	_salvage_label.position = Vector3(0.0, 1.2, 0.0)
	_salvage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_salvage_label.no_depth_test = true
	_salvage_label.modulate = Color(1.0, 0.6, 0.2)
	add_child(_salvage_label)

## ──────────────────────────────────────────────
## SALVAGE INTERACTION
## ──────────────────────────────────────────────

func _on_salvage_zone_entered(body: Node3D) -> void:
	if _salvaged:
		return

	if body is OperatorBase:
		var op: OperatorBase = body as OperatorBase
		if op.is_incapacitated:
			return

		_salvaged = true

		# Determine yield based on role passive bonus (Engineer gets 1.5x yield)
		var yield_multiplier: float = 1.0
		if op.role != null and op.role.has_method("get_salvage_bonus"):
			yield_multiplier = op.role.get_salvage_bonus()
		
		var final_yield: int = int(float(components_per_salvage) * yield_multiplier)

		## Spawn resource pickups at wreck position (slightly scattered)
		_spawn_salvage_pickups(op.player_id, final_yield)

		salvaged.emit(op.player_id, final_yield)
		print("[WreckSalvage] P%d salvaged wreck — spawned %d components (yield mult: %.1f)" % [op.player_id, final_yield, yield_multiplier])

		## Destroy the wreck immediately after salvage
		dissipated.emit()
		queue_free()

## Spawns resource pickups around the wreck position
func _spawn_salvage_pickups(salvager_id: int, yield_amount: int) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	var rm: ResourceManager = null
	var rm_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_manager")
	if not rm_nodes.is_empty():
		rm = rm_nodes[0] as ResourceManager

	## Split components into 2 pickups for interesting collection gameplay
	var pickup_a: ResourcePickup = ResourcePickup.new()
	pickup_a.resource_type = ResourceInventory.TYPE_MAINTENANCE
	pickup_a.amount = yield_amount / 2
	parent.add_child(pickup_a)
	pickup_a.global_position = global_position + Vector3(-0.6, 0.3, 0.0)
	if rm != null:
		rm.register_pickup(pickup_a)

	var pickup_b: ResourcePickup = ResourcePickup.new()
	pickup_b.resource_type = ResourceInventory.TYPE_MAINTENANCE
	pickup_b.amount = yield_amount - (yield_amount / 2)
	parent.add_child(pickup_b)
	pickup_b.global_position = global_position + Vector3(0.6, 0.3, 0.0)
	if rm != null:
		rm.register_pickup(pickup_b)

	print("[WreckSalvage] Spawned 2 salvage pickups for P%d (total %d)" % [salvager_id, yield_amount])
