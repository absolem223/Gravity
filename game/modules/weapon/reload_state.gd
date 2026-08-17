# reload_state.gd
# Technical Rationale: Reload state machine (IDLE / RELOADING) with configurable
# duration and progress tracking. The weapon triggers automatic reloads when a
# magazine empties; this class only tracks the process itself.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name ReloadState
extends RefCounted

enum Status {
	IDLE,
	RELOADING
}

## Total reload duration in seconds.
var reload_duration: float = 2.0
## Active status.
var status: Status = Status.IDLE

var _elapsed: float = 0.0

## True while a reload is in progress.
func is_reloading() -> bool:
	return status == Status.RELOADING

## Starts a reload from zero elapsed time.
func start() -> void:
	status = Status.RELOADING
	_elapsed = 0.0

## Advances the reload by `delta` seconds. Returns true when the reload
## completes during this tick.
func update(delta: float) -> bool:
	if status != Status.RELOADING:
		return false
	_elapsed += delta
	if _elapsed >= reload_duration:
		finish()
		return true
	return false

## Completes the reload and returns to IDLE.
func finish() -> void:
	status = Status.IDLE
	_elapsed = 0.0

## Interrupts the reload (e.g. operator death).
func cancel() -> void:
	status = Status.IDLE
	_elapsed = 0.0

## Reload progress in the 0.0 .. 1.0 range (0.0 when idle).
func get_progress() -> float:
	if status != Status.RELOADING:
		return 0.0
	return clampf(_elapsed / maxf(0.001, reload_duration), 0.0, 1.0)
