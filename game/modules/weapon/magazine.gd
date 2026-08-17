# magazine.gd
# Technical Rationale: Ammo magazine (Gen 1). Tracks loaded rounds vs capacity.
# Pure data/logic so it can be reused by player weapons, Gen2/Gen3 weapons and
# drone weapons without coupling to any node or scene.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name Magazine
extends RefCounted

## Maximum rounds the magazine can hold.
var capacity: int = 30
## Rounds currently loaded.
var current_rounds: int = 30

## Refills the magazine to full capacity.
func reload_full() -> void:
	current_rounds = capacity

## Consumes one round. Returns false when the magazine is already empty.
func consume_round() -> bool:
	if current_rounds <= 0:
		return false
	current_rounds -= 1
	return true

## True when no rounds are loaded.
func is_empty() -> bool:
	return current_rounds <= 0

## True when the magazine is at full capacity.
func is_full() -> bool:
	return current_rounds >= capacity

## Fraction of capacity still loaded (0.0 .. 1.0).
func get_fill_ratio() -> float:
	return float(current_rounds) / float(maxi(1, capacity))
