# sandbox_test_scene.gd
# Technical Rationale: Entry script for Etapa 4 Sandbox Test Scene.
# Integrates PlayerManager, SquadHUD, InputManager, CameraController, SquadVisionRegistry, and Synthesis Points.
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

func _ready() -> void:
	_initialize_etapa_4_sandbox()

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
	print("[SandboxTestScene] ETAPA 4 Initialized. Permanent Drone Gen 1, Escort, Stationary, and Pilot Modes active.")

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
