# spawn_zone.gd
# Technical Rationale: Defines a protected spawn room volume for one team.
# Uses a pure geometry check (no Area3D timing): an operator is "in spawn"
# while inside its own team's zone. Grants invulnerability, firing lockout and
# ability lockout while inside; protection ends the moment the boundary is
# crossed. Robust in headless tests (no body_entered frame timing).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SpawnZone
extends Node3D

## World group so Match/PlayerManager/tests can discover every spawn zone.
const GROUP: String = "spawn_zones"

## Team that owns (and is protected inside) this room.
@export var team_id: int = OperatorBase.TEAM_ATTACKERS

## Horizontal protection radius (matches the hexagonal room circumradius).
@export var protection_radius: float = 5.0

## Protection height (the room walls are 3.0 m high).
const PROTECTION_HEIGHT: float = 4.0

func _ready() -> void:
	add_to_group(GROUP)
	_build_visual()

## True while a world position is inside this room volume.
func is_position_inside(world_pos: Vector3) -> bool:
	var flat: Vector3 = world_pos - global_position
	flat.y = 0.0
	if flat.length() > protection_radius:
		return false
	return world_pos.y >= 0.0 and world_pos.y <= PROTECTION_HEIGHT

## True when the operator is inside the spawn room of its own team.
## Inside = protected; outside = vulnerable. No timers.
static func is_protected(op: OperatorBase) -> bool:
	if op == null or not op.is_inside_tree():
		return false
	var tree: SceneTree = op.get_tree()
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(GROUP):
		var zone: SpawnZone = node as SpawnZone
		if zone != null and zone.team_id == op.team_id and zone.is_position_inside(op.global_position):
			return true
	return false

## Subtle floor ring so the protected area reads clearly in the world.
func _build_visual() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "ProtectionRing"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = protection_radius
	mesh.bottom_radius = protection_radius
	mesh.height = 0.08
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.9, 1.0, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.4
	mesh.material = mat
	ring.mesh = mesh
	ring.position = Vector3(0.0, 0.04, 0.0)
	add_child(ring)
