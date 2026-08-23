# ammo_reserve.gd
# Technical Rationale: Reserve ammunition carried as spare magazines (Gen 1).
# A reload swaps the spent magazine for one from this reserve. Kept generic so
# future logistics stations can restock it without changing the base system.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name AmmoReserve
extends RefCounted

## Magazines available in reserve at full capacity.
var max_magazines: int = 3
## Magazines currently available.
var magazines_remaining: int = 3
## When true the reserve never runs dry: reloads keep swapping fresh magazines
## forever (magazines_remaining stays untouched). Per-shot consumption and the
## full reload duration are NOT bypassed — only the finite spare-magazine pool
## is lifted, for actors whose design requires an endless fire→reload→fire
## loop while a valid target exists (e.g. the companion drone). Default false:
## operators keep their finite logistics budget.
var unlimited_magazines: bool = false

## True when at least one spare magazine is available.
func has_reserve() -> bool:
	if unlimited_magazines:
		return true
	return magazines_remaining > 0

## Removes one magazine from the reserve. Returns false when empty.
func take_magazine() -> bool:
	if unlimited_magazines:
		return true
	if magazines_remaining <= 0:
		return false
	magazines_remaining -= 1
	return true

## Restores the reserve to full capacity (respawn / future logistics).
func restock() -> void:
	magazines_remaining = max_magazines
