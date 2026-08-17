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

## True when at least one spare magazine is available.
func has_reserve() -> bool:
	return magazines_remaining > 0

## Removes one magazine from the reserve. Returns false when empty.
func take_magazine() -> bool:
	if magazines_remaining <= 0:
		return false
	magazines_remaining -= 1
	return true

## Restores the reserve to full capacity (respawn / future logistics).
func restock() -> void:
	magazines_remaining = max_magazines
