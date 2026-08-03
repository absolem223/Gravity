# core_capture_zone.gd
# Technical Rationale: Physical Area3D perimeter for the AI Core.
# Detects operator entry/exit and reports team presence to HackController.
# Map-independent: operators only need to be in group "players" and expose team_id and player_id.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name CoreCaptureZone
extends Area3D

## Reference to the HackController (auto-discovered via group "hack_controller")
var hack_controller: HackController = null

## Team assignment for this perimeter (0 = attackers, 1 = defenders, etc.)
## For the Vertical Slice, all operators are team 0 (attackers).
## Defenders will be assigned team 1 in Etapa 9.
@export_range(0, 8, 1) var attacker_team_id: int = 0

## Visual indicator node (optional — used for contested state feedback)
@onready var _zone_mesh: MeshInstance3D = $ZoneMesh if has_node("ZoneMesh") else null

func _ready() -> void:
	## Connect body enter/exit signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	## Auto-discover HackController via group
	_find_hack_controller()

	add_to_group("core_capture_zone")
	print("[CoreCaptureZone] Initialized at position %s. Attacker team: %d" % [str(global_position), attacker_team_id])

## Attempts to locate HackController from scene tree via group
func _find_hack_controller() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("hack_controller")
	if not nodes.is_empty():
		hack_controller = nodes[0] as HackController
		if hack_controller != null:
			print("[CoreCaptureZone] HackController found and connected.")
	else:
		## Deferred retry — scene may not be fully initialized
		call_deferred("_find_hack_controller_deferred")

func _find_hack_controller_deferred() -> void:
	_find_hack_controller()
	if hack_controller == null:
		push_warning("[CoreCaptureZone] HackController not found in group 'hack_controller'. Hack logic disabled.")

## ──────────────────────────────────────────────
## BODY ENTER / EXIT CALLBACKS
## ──────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if hack_controller == null:
		return

	if body is OperatorBase:
		var op: OperatorBase = body as OperatorBase
		var team: int = _resolve_team(op)
		hack_controller.register_entry(team, op.player_id)
		print("[CoreCaptureZone] Operator P%d (team %d) entered perimeter." % [op.player_id, team])

func _on_body_exited(body: Node3D) -> void:
	if hack_controller == null:
		return

	if body is OperatorBase:
		var op: OperatorBase = body as OperatorBase
		var team: int = _resolve_team(op)
		hack_controller.register_exit(team, op.player_id)
		print("[CoreCaptureZone] Operator P%d (team %d) exited perimeter." % [op.player_id, team])

## ──────────────────────────────────────────────
## TEAM RESOLUTION
## ──────────────────────────────────────────────

## Resolves an operator's team_id.
## In the Vertical Slice all operators are attackers (team 0).
## Etapa 9 will assign enemy operators to team 1 via a team_id property on OperatorBase.
func _resolve_team(op: OperatorBase) -> int:
	## Check for explicit team_id property (Etapa 9+)
	if op.get("team_id") != null:
		return int(op.get("team_id"))
	## Vertical Slice default: all operators are attackers (team 0)
	return 0

## ──────────────────────────────────────────────
## PUBLIC API
## ──────────────────────────────────────────────

## Manually assign hack controller (for programmatic scene assembly)
func set_hack_controller(hc: HackController) -> void:
	hack_controller = hc
