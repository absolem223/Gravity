# fire_mode.gd
# Technical Rationale: Fire mode configuration + trigger evaluation for the
# Weapon System Gen 1. Carries the type (SEMI_AUTO / FULL_AUTO / BURST), the
# rate between rounds and the burst size. Kept as pure data/logic so Gen2/Gen3
# weapons and drone weapons can reuse it without modifying the base system.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name FireMode
extends RefCounted

## Fire mode types supported by the base system.
enum Type {
	SEMI_AUTO, ## One round per trigger press.
	FULL_AUTO, ## Continuous fire while the trigger is held.
	BURST      ## Fixed rounds per press, then require a fresh press.
}

## Active fire mode type.
var type: Type = Type.FULL_AUTO
## Seconds between rounds (governs the fire cooldown).
var fire_rate: float = 0.25
## Rounds fired per press in BURST mode.
var burst_size: int = 3

## Burst bookkeeping (BURST only): rounds still owed to the current press.
var _burst_remaining: int = 0

## Evaluates whether a round should be fired this frame given the raw trigger
## state. `was_pressed` must be the previous frame's `pressed` value.
func evaluate_trigger(pressed: bool, was_pressed: bool) -> bool:
	match type:
		Type.SEMI_AUTO:
			return pressed and not was_pressed
		Type.BURST:
			if not pressed:
				_burst_remaining = 0
				return false
			if not was_pressed:
				_burst_remaining = burst_size
			if _burst_remaining > 0:
				_burst_remaining -= 1
				return true
			return false
		_:
			return pressed

## Clears trigger-dependent state (burst counter). Call on reload/reset.
func reset_trigger_state() -> void:
	_burst_remaining = 0

## Human-readable label for the active fire mode.
func get_label() -> String:
	match type:
		Type.SEMI_AUTO: return "SEMI"
		Type.BURST:     return "BURST"
		_:              return "AUTO"
