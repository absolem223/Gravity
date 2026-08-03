# wreck_site.gd
# Technical Rationale: Represents a persistent wreckage site left behind when a Drone is destroyed.
# Serves as the future anchor for resource economy/maintenance harvesting.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name WreckSite
extends StaticBody3D

## Signals
signal dissipated()

## Time before the wreckage dissipates (seconds)
@export var lifetime: float = 90.0

## Visual indicator for the wreckage
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

var _timer: float = 0.0

func _ready() -> void:
	add_to_group("wreck_sites")
	_setup_visuals()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		dissipated.emit()
		queue_free()
	else:
		# Visual pulsing indicator to show decay status
		if _mesh_instance != null:
			var pulse: float = 0.5 + 0.5 * sin(_timer * 6.0)
			var opacity: float = 1.0 - (_timer / lifetime)
			var mat: StandardMaterial3D = _mesh_instance.material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color = Color(1.0, 0.4 * pulse, 0.0, opacity)

func _setup_visuals() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.8, 0.3, 0.8)
		_mesh_instance.mesh = box
		add_child(_mesh_instance)
		
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.4, 0.0, 1.0)
	_mesh_instance.material_override = material
