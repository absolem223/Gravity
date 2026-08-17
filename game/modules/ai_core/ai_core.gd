# ai_core.gd
# Technical Rationale: Root orchestrator for the AI Core system.
# Composes HackController, CoreCaptureZone, and CoreStatusDisplay into a self-contained module.
# Map integration: instantiate this node and place it on the CorePlatform. No other coupling required.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name AICore
extends Node3D

## ──────────────────────────────────────────────
## SIGNALS (re-exported from HackController for external consumers)
## ──────────────────────────────────────────────
signal hack_started(team_id: int)
signal hack_progress_changed(progress: float, team_id: int)
signal hack_contested
signal hack_degrading(progress: float)
signal hack_completed(team_id: int)
signal ownership_changed(new_owner_team: int)
signal state_changed(state: HackController.CoreState)
signal presence_changed(active: bool)

## ──────────────────────────────────────────────
## EXPORTED CONFIGURATION (forwarded to child modules)
## ──────────────────────────────────────────────

## Hack speed (%/s) when team controls perimeter
@export_range(1.0, 30.0, 0.5) var hack_speed_percent_per_second: float = 5.0

## Degradation: -% per tick
@export_range(1.0, 30.0, 0.5) var degradation_percent_per_tick: float = 10.0

## Degradation interval in seconds
@export_range(5.0, 120.0, 1.0) var degradation_interval_seconds: float = 30.0

## Capture threshold (100% = full core)
@export_range(50.0, 100.0, 1.0) var capture_threshold_percent: float = 100.0

## Perimeter physical size (XZ half-extents in meters)
@export var perimeter_size: Vector3 = Vector3(10.0, 3.0, 10.0)

## Unique objective identifier (empty for single-core sandbox usage).
@export var terminal_id: String = ""

## Display name shown by the HUD ("Terminal A", "Terminal B", ...).
@export var terminal_display_name: String = "TERMINAL"

## Build the self-contained CoreStatusDisplay panel. Disable when a central
## HUD widget (SquadHUD) is responsible for showing terminal progress.
@export var build_status_display: bool = true

## Build the module's own glowing core box. Disable when the host terminal
## already provides its own visual core mesh (bound via bind_core_visual()).
@export var build_core_visual: bool = true

## ──────────────────────────────────────────────
## CHILD MODULE REFERENCES
## ──────────────────────────────────────────────
var hack_controller: HackController = null
var capture_zone: CoreCaptureZone = null
var status_display: CoreStatusDisplay = null

## Optional: visual mesh for the Core itself (placeholder)
var _core_mesh: MeshInstance3D = null

## Runtime state tracking for state_changed / presence_changed emission.
var _last_state: HackController.CoreState = HackController.CoreState.IDLE
var _last_presence: bool = false

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	_build_hack_controller()
	_build_capture_zone()
	_build_core_visual()
	_build_status_display()
	_wire_signals()
	add_to_group("ai_core")
	print("[AICore] Fully initialized. Hack speed: %.1f%%/s. Degradation: -%.1f%% / %.0fs." % [
		hack_speed_percent_per_second, degradation_percent_per_tick, degradation_interval_seconds
	])

func _process(_delta: float) -> void:
	## Bridge IDLE state to display (HackController does not emit a signal for IDLE)
	if hack_controller != null and status_display != null:
		if hack_controller.get_current_state() == HackController.CoreState.IDLE:
			status_display.on_state_idle()
	## Emit state/presence transitions for TerminalManager + HUD
	if hack_controller != null:
		var state: HackController.CoreState = hack_controller.get_current_state()
		if state != _last_state:
			_last_state = state
			state_changed.emit(state)
		var present: bool = hack_controller.get_present_teams().size() > 0
		if present != _last_presence:
			_last_presence = present
			presence_changed.emit(present)
## ──────────────────────────────────────────────
## MODULE CONSTRUCTION
## ──────────────────────────────────────────────

func _build_hack_controller() -> void:
	hack_controller = HackController.new()
	hack_controller.name = "HackController"
	hack_controller.hack_speed_percent_per_second = hack_speed_percent_per_second
	hack_controller.degradation_percent_per_tick = degradation_percent_per_tick
	hack_controller.degradation_interval_seconds = degradation_interval_seconds
	hack_controller.capture_threshold_percent = capture_threshold_percent
	add_child(hack_controller)
	hack_controller.add_to_group("hack_controller")

func _build_capture_zone() -> void:
	capture_zone = CoreCaptureZone.new()
	capture_zone.name = "CoreCaptureZone"

	## Collision shape for the perimeter area
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = perimeter_size
	col.shape = box
	capture_zone.add_child(col)

	add_child(capture_zone)

	## Manually inject HackController reference (avoids group-discovery timing issues)
	capture_zone.set_hack_controller(hack_controller)

func _build_core_visual() -> void:
	if not build_core_visual:
		return
	## Placeholder visual: glowing box representing the Core terminal
	_core_mesh = MeshInstance3D.new()
	_core_mesh.name = "CoreMesh"

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 2.0, 2.0)
	_core_mesh.mesh = mesh
	_core_mesh.position = Vector3(0.0, 1.5, 0.0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.6, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.3, 0.6)
	mat.emission_energy_multiplier = 1.5
	_core_mesh.material_override = mat

	add_child(_core_mesh)

func _build_status_display() -> void:
	if not build_status_display:
		return
	status_display = CoreStatusDisplay.new()
	status_display.name = "CoreStatusDisplay"
	status_display.hack_controller = hack_controller
	## Display is added to the scene root's CanvasLayer equivalent (SquadHUD handles this)
	## For modularity, we add it as child here and it self-positions via anchors
	add_child(status_display)

## ──────────────────────────────────────────────
## SIGNAL WIRING
## ──────────────────────────────────────────────

func _wire_signals() -> void:
	if hack_controller == null:
		return

	## Re-emit from HackController to AICore (external listeners)
	hack_controller.hack_started.connect(func(tid: int) -> void:
		hack_started.emit(tid)
		if status_display != null:
			status_display.on_hack_started(tid)
	)
	hack_controller.hack_progress_changed.connect(func(prog: float, tid: int) -> void:
		hack_progress_changed.emit(prog, tid)
		if status_display != null:
			status_display.on_hack_progress_changed(prog, tid)
	)
	hack_controller.hack_contested.connect(func() -> void:
		hack_contested.emit()
		if status_display != null:
			status_display.on_hack_contested()
	)
	hack_controller.hack_degrading.connect(func(prog: float) -> void:
		hack_degrading.emit(prog)
		if status_display != null:
			status_display.on_hack_degrading(prog)
	)
	hack_controller.hack_completed.connect(func(tid: int) -> void:
		hack_completed.emit(tid)
		if status_display != null:
			status_display.on_hack_completed(tid)
	)
	hack_controller.ownership_changed.connect(func(new_owner: int) -> void:
		ownership_changed.emit(new_owner)
		_update_core_visual_captured()
	)

## ──────────────────────────────────────────────
## VISUAL FEEDBACK — CORE STATE
## ──────────────────────────────────────────────

## Updates Core mesh emission color on state transitions
func _update_core_visual_captured() -> void:
	if _core_mesh == null:
		return
	var mat: StandardMaterial3D = _core_mesh.material_override as StandardMaterial3D
	if mat == null:
		## Bound external mesh: create an override so capture feedback tints it.
		mat = StandardMaterial3D.new()
		mat.emission_enabled = true
		_core_mesh.material_override = mat
	mat.albedo_color = Color(0.2, 0.95, 0.5)
	mat.emission = Color(0.1, 0.6, 0.3)
	mat.emission_energy_multiplier = 3.0

## ──────────────────────────────────────────────
## PUBLIC API (facade over HackController)
## ──────────────────────────────────────────────

func get_progress() -> float:
	return hack_controller.get_progress() if hack_controller != null else 0.0

func get_current_state() -> HackController.CoreState:
	return hack_controller.get_current_state() if hack_controller != null else HackController.CoreState.IDLE

func get_hacking_team() -> int:
	return hack_controller.get_hacking_team() if hack_controller != null else -1

func get_owning_team() -> int:
	return hack_controller.get_owning_team() if hack_controller != null else -1

## Binds an external core mesh (e.g. the terminal's own emissive core) so the
## capture color feedback is applied to the host terminal instead of a local box.
func bind_core_visual(mesh: MeshInstance3D) -> void:
	_core_mesh = mesh
