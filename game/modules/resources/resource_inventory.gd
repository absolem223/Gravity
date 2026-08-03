# resource_inventory.gd
# Technical Rationale: Per-operator inventory for maintenance components.
# Independently tracks resource amounts per slot with configurable max capacity.
# Emits signals consumed by HUD — no HUD logic inside.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name ResourceInventory
extends Node

## ──────────────────────────────────────────────
## SIGNALS
## ──────────────────────────────────────────────
signal inventory_changed(resource_type: String, current: int, capacity: int)

## ──────────────────────────────────────────────
## RESOURCE TYPE CONSTANTS
## ──────────────────────────────────────────────
const TYPE_MAINTENANCE: String = "maintenance_components"

## ──────────────────────────────────────────────
## CONFIGURATION
## ──────────────────────────────────────────────
@export_range(10, 500, 10) var capacity: int = 100

## ──────────────────────────────────────────────
## INTERNAL STORAGE
## resource_type (String) -> amount (int)
## ──────────────────────────────────────────────
var _slots: Dictionary = {}

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	_slots[TYPE_MAINTENANCE] = 0
	print("[ResourceInventory] Initialized. Capacity: %d" % capacity)

## ──────────────────────────────────────────────
## PUBLIC API
## ──────────────────────────────────────────────

## Adds the given amount of resource_type. Returns the amount actually added (capped by capacity).
func add_resource(resource_type: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if not _slots.has(resource_type):
		_slots[resource_type] = 0

	var current: int = _slots[resource_type]
	var space_left: int = capacity - current
	var amount_added: int = mini(amount, space_left)

	if amount_added <= 0:
		print("[ResourceInventory] Full — cannot add %s (cap: %d)" % [resource_type, capacity])
		return 0

	_slots[resource_type] = current + amount_added
	inventory_changed.emit(resource_type, _slots[resource_type], capacity)
	print("[ResourceInventory] Added %d %s (total: %d / %d)" % [amount_added, resource_type, _slots[resource_type], capacity])
	return amount_added

## Removes the given amount of resource_type. Returns the amount actually removed.
func remove_resource(resource_type: String, amount: int) -> int:
	if amount <= 0 or not _slots.has(resource_type):
		return 0

	var current: int = _slots[resource_type]
	var amount_removed: int = mini(amount, current)
	_slots[resource_type] = current - amount_removed
	inventory_changed.emit(resource_type, _slots[resource_type], capacity)
	return amount_removed

## Returns true if there are at least `amount` units of resource_type.
func has_resource(resource_type: String, amount: int = 1) -> bool:
	if not _slots.has(resource_type):
		return false
	return _slots[resource_type] >= amount

## Returns the current amount of resource_type (0 if not tracked).
func get_amount(resource_type: String) -> int:
	return _slots.get(resource_type, 0)

## Returns the used amount of the primary resource (maintenance_components).
func get_maintenance_components() -> int:
	return get_amount(TYPE_MAINTENANCE)

## Returns remaining space for a given resource_type.
func get_space_remaining(resource_type: String) -> int:
	return capacity - _slots.get(resource_type, 0)

## Clears all resources from all slots.
func clear() -> void:
	for key: String in _slots.keys():
		_slots[key] = 0
		inventory_changed.emit(key, 0, capacity)
	print("[ResourceInventory] Inventory cleared.")

## Returns a copy of the full slot dictionary (read-only snapshot).
func get_all_resources() -> Dictionary:
	return _slots.duplicate()
