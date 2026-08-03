# sandbox_test_scene.gd
# Technical Rationale: Entry script for SANDBOX-01.
# Integrates PlayerManager, SquadHUD, InputManager, CameraController, SquadVisionRegistry,
# Synthesis Points, and AICore (Etapa 6 — AI Core system).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SandboxTestScene
extends Node3D

@onready var input_manager: InputManager = $InputManager if has_node("InputManager") else null
@onready var player_manager: PlayerManager = $PlayerManager if has_node("PlayerManager") else null
@onready var camera_controller: CameraController = $CameraController if has_node("CameraController") else null
@onready var squad_hud: SquadHUD = $SquadHUD if has_node("SquadHUD") else null
@onready var squad_vision_registry: SquadVisionRegistry = $SquadVisionRegistry if has_node("SquadVisionRegistry") else null

## References to synthesis zones
var _synthesis_zones: Array[Area3D] = []

## AICore module reference (Etapa 6)
var ai_core: AICore = null

func _ready() -> void:
	_initialize_etapa_4_sandbox()
	_initialize_ai_core()

func _physics_process(_delta: float) -> void:
	if player_manager != null:
		var centroid: Vector3 = player_manager.get_squad_centroid()
		var ops: Array[OperatorBase] = player_manager.get_all_operators()
		for op: OperatorBase in ops:
			op.update_squad_separation(centroid)
			
		# Dynamic camera target updates for Pilot Mode
		_update_camera_targets()
		_process_synthesis_zones()

## Initializes Etapa 4 Managers, Vision Registry, HUD, and camera binding
func _initialize_etapa_4_sandbox() -> void:
	if input_manager == null:
		input_manager = InputManager.new()
		input_manager.name = "InputManager"
		add_child(input_manager)

	if squad_vision_registry == null:
		squad_vision_registry = SquadVisionRegistry.new()
		squad_vision_registry.name = "SquadVisionRegistry"
		add_child(squad_vision_registry)

	if player_manager == null:
		player_manager = PlayerManager.new()
		player_manager.name = "PlayerManager"
		add_child(player_manager)

	player_manager.setup_squad(input_manager, 4)
	player_manager.squad_updated.connect(_on_squad_updated)
	player_manager.player_spawned.connect(_on_player_spawned)

	if squad_hud != null:
		squad_hud.setup_hud(player_manager, input_manager, squad_vision_registry)

	# Locate and bind any Area3D nodes in "synthesis_points" group
	_synthesis_zones.clear()
	var zones: Array[Node] = get_tree().get_nodes_in_group("synthesis_points")
	for node: Node in zones:
		if node is Area3D:
			_synthesis_zones.append(node as Area3D)

	_on_squad_updated(4)
	print("[SandboxTestScene] SANDBOX-01 base initialized. Drone Gen 1, Escort, Stationary, Pilot Modes active.")

## Callback when a new player operator spawns
func _on_player_spawned(_p_id: int, op: OperatorBase) -> void:
	if op != null:
		if op.vision_cone != null and squad_vision_registry != null:
			squad_vision_registry.register_provider(op.vision_cone)
		op.damage_dealt.connect(_on_operator_damage_dealt)
		op.drone_status_changed.connect(_on_drone_status_changed)

## Callback when drone status changes (registered to shared squad vision)
func _on_drone_status_changed(p_id: int, has_drone: bool, mode: String) -> void:
	print("[SQUAD STATUS] Player P%d Drone status updated: Active = %s, Mode = %s" % [p_id, str(has_drone), mode])
	if squad_vision_registry != null:
		var op: OperatorBase = player_manager.get_operator(p_id)
		if op != null:
			if has_drone and op.drone != null and op.drone.vision_cone != null:
				squad_vision_registry.register_provider(op.drone.vision_cone)
			elif not has_drone and op.drone == null:
				# Re-evaluate vision registry
				squad_vision_registry._recalculate_squad_vision()

## Callback when damage is dealt with cover mitigation
func _on_operator_damage_dealt(target: OperatorBase, damage: float, mitigated_by_cover: bool) -> void:
	var msg: String = "[COMBAT] Operator P%d hit for %.1f damage" % [target.player_id, damage]
	if mitigated_by_cover:
		msg += " [MITIGATED BY COVER -50%]"
	print(msg)

## Callback when squad player count changes
func _on_squad_updated(_active_count: int) -> void:
	_update_camera_targets()

## Recalculates CameraController targets based on active Operator/Drone pilot status
func _update_camera_targets() -> void:
	if camera_controller == null or player_manager == null:
		return

	var ops: Array[OperatorBase] = player_manager.get_all_operators()
	var node3d_targets: Array[Node3D] = []
	
	for op: OperatorBase in ops:
		if op.is_piloting_drone and op.drone != null and is_instance_valid(op.drone):
			node3d_targets.append(op.drone as Node3D)
		else:
			node3d_targets.append(op as Node3D)
			
	camera_controller.targets = node3d_targets

## Handles reconstruction logic if operator enters a Synthesis zone lacking a Drone
func _process_synthesis_zones() -> void:
	if player_manager == null:
		return

	var ops: Array[OperatorBase] = player_manager.get_all_operators()
	for op: OperatorBase in ops:
		if op.drone == null or not op.has_drone_active:
			for zone: Area3D in _synthesis_zones:
				if zone.overlaps_body(op):
					op.rebuild_drone()
					print("[SYNTHESIS] Rebuilt Drone Gen 1 for Operator P%d." % op.player_id)
					break

## ──────────────────────────────────────────────
## ETAPA 6 — AI CORE INITIALIZATION
## ──────────────────────────────────────────────

## Instantiates AICore module and places it on the CorePlatform (Z = -20)
func _initialize_ai_core() -> void:
	ai_core = AICore.new()
	ai_core.name = "AICore"
	## CorePlatform is at (0, 0.5, -20) — place Core just above it
	ai_core.position = Vector3(0.0, 1.5, -20.0)
	## Configurable parameters (exposed for future balance tuning)
	ai_core.hack_speed_percent_per_second = 5.0
	ai_core.degradation_percent_per_tick = 10.0
	ai_core.degradation_interval_seconds = 30.0
	ai_core.capture_threshold_percent = 100.0
	ai_core.perimeter_size = Vector3(10.0, 3.0, 10.0)
	add_child(ai_core)

	## Connect AICore signals for console logging and SquadHUD integration
	ai_core.hack_started.connect(_on_core_hack_started)
	ai_core.hack_progress_changed.connect(_on_core_progress_changed)
	ai_core.hack_contested.connect(_on_core_contested)
	ai_core.hack_degrading.connect(_on_core_degrading)
	ai_core.hack_completed.connect(_on_core_completed)
	ai_core.ownership_changed.connect(_on_core_ownership_changed)

	## Notify SquadHUD of the AICore reference
	if squad_hud != null:
		squad_hud.set_ai_core(ai_core)

	print("[SandboxTestScene] AICore initialized at CorePlatform (Z=-20). Perimeter: 10x3x10m.")

func _on_core_hack_started(team_id: int) -> void:
	print("[CORE] *** HACK STARTED — Team %d is hacking the AI Core ***" % team_id)

func _on_core_progress_changed(progress: float, team_id: int) -> void:
	if squad_hud != null:
		squad_hud.update_core_status(progress, ai_core.get_current_state() if ai_core != null else HackController.CoreState.IDLE)
	## Throttle to avoid log spam — only print at each 10% threshold
	var threshold: int = int(progress / 10.0) * 10
	if threshold > 0 and int(progress) % 10 < 2:
		print("[CORE] Progress: %d%% — Team %d" % [int(progress), team_id])

func _on_core_contested() -> void:
	if squad_hud != null:
		squad_hud.update_core_status(ai_core.get_progress() if ai_core != null else 0.0, HackController.CoreState.CONTESTED)

func _on_core_degrading(progress: float) -> void:
	print("[CORE] *** DEGRADATION — Progress dropping to %.1f%% ***" % progress)
	if squad_hud != null:
		squad_hud.update_core_status(progress, HackController.CoreState.DEGRADED)

func _on_core_completed(team_id: int) -> void:
	print("[CORE] *** CORE CAPTURED — Team %d controls the AI Core! ***" % team_id)
	if squad_hud != null:
		squad_hud.update_core_status(100.0, HackController.CoreState.CAPTURED)

func _on_core_ownership_changed(new_owner: int) -> void:
	print("[CORE] Ownership transferred to Team %d" % new_owner)

## ──────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				get_tree().reload_current_scene()
			KEY_2:
				print("[SandboxTestScene] Testing 2-Player Squad")
				if player_manager != null:
					player_manager.set_active_player_count(2)
			KEY_3:
				print("[SandboxTestScene] Testing 3-Player Squad")
				if player_manager != null:
					player_manager.set_active_player_count(3)
			KEY_4:
				print("[SandboxTestScene] Testing 4-Player Squad")
				if player_manager != null:
					player_manager.set_active_player_count(4)
