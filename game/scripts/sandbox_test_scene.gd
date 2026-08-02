# sandbox_test_scene.gd
# Technical Rationale: Entry script for the Etapa 1 Sandbox Test Scene.
# Spawns and configures 4 local operators, links InputManager, and sets up CameraController targets.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SandboxTestScene
extends Node3D

@onready var input_manager: InputManager = $InputManager if has_node("InputManager") else null
@onready var camera_controller: CameraController = $CameraController if has_node("CameraController") else null
@onready var operators_container: Node3D = $Operators if has_node("Operators") else null

func _ready() -> void:
	_initialize_sandbox()

## Initializes input assignments, operator slots, and camera targets
func _initialize_sandbox() -> void:
	if input_manager == null:
		input_manager = InputManager.new()
		input_manager.name = "InputManager"
		add_child(input_manager)
		
	var active_operators: Array[Node3D] = []
	
	if operators_container != null:
		for child: Node in operators_container.get_children():
			if child is OperatorBase:
				var op: OperatorBase = child as OperatorBase
				op.set_input_manager(input_manager)
				active_operators.append(op)
	
	if camera_controller != null:
		camera_controller.targets = active_operators
		print("[SandboxTestScene] ETAPA 1 Initialized successfully. %d active operators linked to CameraController." % active_operators.size())

func _unhandled_input(event: InputEvent) -> void:
	# Quick reset shortcut for testing (R key)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
