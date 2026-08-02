# sandbox_test_scene.gd
# Technical Rationale: Entry script for Etapa 2 Sandbox Test Scene.
# Integrates PlayerManager, SquadHUD, InputManager, CameraController, and live 2-4 player testing controls.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SandboxTestScene
extends Node3D

@onready var input_manager: InputManager = $InputManager if has_node("InputManager") else null
@onready var player_manager: PlayerManager = $PlayerManager if has_node("PlayerManager") else null
@onready var camera_controller: CameraController = $CameraController if has_node("CameraController") else null
@onready var squad_hud: SquadHUD = $SquadHUD if has_node("SquadHUD") else null

func _ready() -> void:
	_initialize_etapa_2_sandbox()

func _physics_process(_delta: float) -> void:
	if player_manager != null:
		var centroid: Vector3 = player_manager.get_squad_centroid()
		var ops: Array[OperatorBase] = player_manager.get_all_operators()
		for op: OperatorBase in ops:
			op.update_squad_separation(centroid)

## Initializes Etapa 2 Managers, HUD, and camera target binding
func _initialize_etapa_2_sandbox() -> void:
	if input_manager == null:
		input_manager = InputManager.new()
		input_manager.name = "InputManager"
		add_child(input_manager)

	if player_manager == null:
		player_manager = PlayerManager.new()
		player_manager.name = "PlayerManager"
		add_child(player_manager)

	player_manager.setup_squad(input_manager, 4)
	player_manager.squad_updated.connect(_on_squad_updated)

	if squad_hud != null:
		squad_hud.setup_hud(player_manager, input_manager)

	_on_squad_updated(4)
	print("[SandboxTestScene] ETAPA 2 Initialized. Press keys [2], [3], [4] to test dynamic player counts. [R] to reload.")

## Callback when squad player count changes
func _on_squad_updated(_active_count: int) -> void:
	if camera_controller != null and player_manager != null:
		var ops: Array[OperatorBase] = player_manager.get_all_operators()
		var node3d_targets: Array[Node3D] = []
		for op: OperatorBase in ops:
			node3d_targets.append(op as Node3D)
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
