# weapon_base.gd
# Technical Rationale: Weapon System Gen 1 (Vertical Slice). Aggregates the
# Magazine, AmmoReserve, ReloadState and FireMode components into one
# self-contained weapon. All gameplay values are configured through configure()
# (or the operator's exported tuning) — no hardcoded numbers.
#
# This class is the ammo / reload / fire-mode authority: it answers "may I
# fire?", consumes rounds and drives the automatic reload. The operator owns
# the actual hitscan + damage pipeline and asks this weapon for permission.
#
# Because it is fully configured and component-based, Gen2/Gen3 weapons,
# alternate weapon types and drone weapons can be built by configuring or
# subclassing this base without modifying the operator or fire logic.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name WeaponBase
extends RefCounted

## Signals (observed by HUD, tests and future systems).
signal weapon_state_changed
signal magazine_changed(rounds: int, capacity: int)
signal reserve_changed(magazines: int)
signal reload_started(duration: float)
signal reload_finished
signal reload_ticked(progress: float)
signal out_of_ammo

## Combat profile (Gen 1 reads these; Gen2+ can override per instance).
var weapon_name: String = "GRAVITY-1"
var base_damage: float = 18.0
var range: float = 20.0

## Composed components.
var magazine: Magazine = null
var reserve: AmmoReserve = null
var reload: ReloadState = null
var fire_mode: FireMode = null

var _configured: bool = false
var _out_ammo_reported: bool = false

func _init() -> void:
	magazine = Magazine.new()
	reserve = AmmoReserve.new()
	reload = ReloadState.new()
	fire_mode = FireMode.new()

## Applies the full configuration. Every gameplay value must come through this
## (or the operator's exported tuning) — nothing is hardcoded here.
func configure(config: Dictionary) -> void:
	weapon_name = config.get("weapon_name", weapon_name)
	base_damage = config.get("base_damage", base_damage)
	range = config.get("range", range)
	magazine.capacity = config.get("magazine_capacity", magazine.capacity)
	magazine.current_rounds = mini(magazine.capacity, magazine.current_rounds)
	reserve.max_magazines = config.get("magazines_initial", reserve.max_magazines)
	reserve.unlimited_magazines = config.get("reserve_unlimited", reserve.unlimited_magazines)
	reload.reload_duration = config.get("reload_duration", reload.reload_duration)
	fire_mode.type = config.get("fire_mode_type", fire_mode.type)
	fire_mode.fire_rate = config.get("fire_rate", fire_mode.fire_rate)
	fire_mode.burst_size = config.get("burst_size", fire_mode.burst_size)
	_configured = true

## Full ammo reset (initial spawn / respawn).
func reset() -> void:
	magazine.reload_full()
	reserve.restock()
	reload.cancel()
	fire_mode.reset_trigger_state()
	_out_ammo_reported = false
	_emit_all()

## True when a round can be fired right now.
func can_fire() -> bool:
	if not _configured:
		return true
	if reload.is_reloading():
		return false
	if magazine.is_empty():
		return false
	if is_out_of_ammo():
		return false
	return true

## Attempts to consume one round. Automatically starts the reload when the
## magazine empties. Returns false when the weapon cannot fire right now
## (reloading, empty, or out of ammunition).
func try_consume_round() -> bool:
	if not can_fire():
		_trigger_auto_reload()
		return false
	if not magazine.consume_round():
		_trigger_auto_reload()
		return false
	magazine_changed.emit(magazine.current_rounds, magazine.capacity)
	weapon_state_changed.emit()
	if magazine.is_empty():
		_trigger_auto_reload()
	return true

## Advances timers (reload). Call every physics frame from the owning actor.
func tick(delta: float) -> void:
	if not _configured or not reload.is_reloading():
		return
	var finished: bool = reload.update(delta)
	reload_ticked.emit(reload.get_progress())
	if finished:
		_finish_reload()

## True while a reload is in progress.
func is_reloading() -> bool:
	return reload.is_reloading()

## True when the magazine is empty and no reserve magazines remain.
func is_out_of_ammo() -> bool:
	return magazine.is_empty() and not reserve.has_reserve()

## Reload progress in the 0.0 .. 1.0 range (0.0 when idle).
func get_reload_progress() -> float:
	return reload.get_progress()

## Interrupts any active reload (e.g. operator death).
func cancel_reload() -> void:
	if reload.is_reloading():
		reload.cancel()
		weapon_state_changed.emit()

func _trigger_auto_reload() -> void:
	if not _configured or reload.is_reloading():
		return
	if not magazine.is_empty():
		return
	if not reserve.has_reserve():
		if not _out_ammo_reported:
			_out_ammo_reported = true
			out_of_ammo.emit()
			weapon_state_changed.emit()
		return
	reload.start()
	reload_started.emit(reload.reload_duration)
	weapon_state_changed.emit()

func _finish_reload() -> void:
	magazine.reload_full()
	reserve.take_magazine()
	_out_ammo_reported = false
	reserve_changed.emit(reserve.magazines_remaining)
	magazine_changed.emit(magazine.current_rounds, magazine.capacity)
	reload_finished.emit()
	weapon_state_changed.emit()

func _emit_all() -> void:
	magazine_changed.emit(magazine.current_rounds, magazine.capacity)
	reserve_changed.emit(reserve.magazines_remaining)
	weapon_state_changed.emit()
