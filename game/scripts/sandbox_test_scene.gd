# sandbox_test_scene.gd
# Technical Rationale: Entry script for Etapa 3 Sandbox Test Scene.
# Integrates PlayerManager, SquadHUD, InputManager, CameraController, SquadVisionRegistry, and Target Dummies.
# Validates hitscan combat, cover mitigation (50% low cover / 100% full cover), VisionCone3D, and LoS checks.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SandboxTestScene
extends Node3D

@onready var input_manager: InputManager = $InputManager if has_node("InputManager") else null
@onready var player_manager: PlayerManager = $PlayerManager if has_node("PlayerManager") else null
@onready var camera_controller: CameraController = $CameraController if has_node("CameraController") else null
@onready var squad_hud: SquadHUD = $SquadHUD if has_node("SquadHUD") else null
@onready var squad_vision_registry: SquadVisionRegistry = $SquadVisionRegistry if has_node("SquadVisionRegistry") else null

func _ready() -> void:
	_initialize_etapa_3_sandbox()

func _physics_process(_delta: float) -> void:
	if player_manager != null:
		var centroid: Vector3 = player_manager.get_squad_centroid()
		var ops: Array[OperatorBase] = player_manager.get_all_operators()
		for op: OperatorBase in ops:
			op.update_squad_separation(centroid)

## Initializes Etapa 3 Managers, Vision Registry, HUD, and camera binding
func _initialize_etapa_3_sandbox() -> void:
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

	_on_squad_updated(4)
	print("[SandboxTestScene] ETAPA 3 Initialized. Hitscan, Cover & VisionCone active. Keys: [2],[3],[4] for squad count, [R] reload.")

## Callback when a new player operator spawns
func _on_player_spawned(_p_id: int, op: OperatorBase) -> void:
	if op != null and squad_vision_registry != null:
		if op.vision_cone != null:
			squad_vision_registry.register_provider(op.vision_cone)
		op.damage_dealt.connect(_on_operator_damage_dealt)

## Callback when damage is dealt with cover mitigation
func _on_operator_damage_dealt(target: OperatorBase, damage: float, mitigated_by_cover: bool) -> void:
	var msg: String = "[COMBAT] Operator P%d hit for %.1f damage" % [target.player_id, damage]
	if mitigated_by_cover:
		msg += " [MITIGATED BY COVER -50%]"
	print(msg)

## Callback when squad player count changes
func _on_squad_updated(_active_count: int) -> void:
	if camera_controller != null and player_manager != null:
		var ops: Array[OperatorBase] = player_manager.get_all_operators()
		var node3d_targets: Array[Node3D] = []
		for op: OperatorBase in ops:
			node3d_targets.append(op as Node3D)
			# Re-register vision cones
			if op.vision_cone != null and squad_vision_registry != null:
				squad_vision_registry.register_provider(op.vision_cone)
		camera_controller.targets = node3d_targets

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
