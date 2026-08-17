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

## Bodies overlapping the zone during the fragile bootstrap window are ignored briefly.
## This prevents an immediate "entered" transition from a spawn overlap from being counted as gameplay intention.
var _startup_ignored_bodies: Dictionary = {}
var _startup_grace_remaining: float = 0.0
const STARTUP_IGNORE_SECONDS: float = 0.5

func _ready() -> void:
	## Prevent the perimeter from counting spawn-overlap on scene bootstrap.
	## This avoids turning an initial overlap into a false hack start.
	monitoring = true
	_startup_grace_remaining = STARTUP_IGNORE_SECONDS

	## Connect body enter/exit signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	## Auto-discover HackController via group
	_find_hack_controller()
	call_deferred("_arm_monitoring")

	add_to_group("core_capture_zone")
	print("[CoreCaptureZone] Initialized at position %s. Attacker team: %d" % [str(global_position), attacker_team_id])

func _process(delta: float) -> void:
	if _startup_grace_remaining > 0.0:
		_startup_grace_remaining = maxf(0.0, _startup_grace_remaining - delta)

func _arm_monitoring() -> void:
	print("[CoreCaptureZone] Monitoring armed after scene bootstrap.")

## Attempts to locate HackController from scene tree via group
func _find_hack_controller() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("hack_controller")
	var found: bool = false
	for n: Node in nodes:
		if not n.is_queued_for_deletion() and n is HackController:
			hack_controller = n as HackController
			found = true
			print("[CoreCaptureZone] HackController found and connected.")
			break
	if not found:
		## Deferred retry — scene may not be fully initialized or group contained invalid nodes
		call_deferred("_find_hack_controller_deferred")

func _find_hack_controller_deferred() -> void:
	_find_hack_controller()
	if hack_controller == null:
		push_warning("[CoreCaptureZone] HackController not found in group 'hack_controller'. Hack logic disabled.")

## ──────────────────────────────────────────────
## BODY ENTER / EXIT CALLBACKS
## ──────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	print("[CoreCaptureZone DEBUG] _on_body_entered called for body: %s (class: %s, is_operator: %s)" % [body.name, body.get_class(), str(body is OperatorBase)])
	if hack_controller == null:
		print("[CoreCaptureZone DEBUG] hack_controller is NULL!")
		return

	if body is OperatorBase:
		if _startup_grace_remaining > 0.0:
			_startup_ignored_bodies[body] = _startup_grace_remaining
			print("[CoreCaptureZone] Ignoring startup overlap for Operator P%d during grace period." % body.player_id)
			return
		if _startup_ignored_bodies.has(body):
			print("[CoreCaptureZone DEBUG] Operator P%d is in ignore list." % body.player_id)
			return
		var op: OperatorBase = body as OperatorBase
		var team: int = _resolve_team(op)
		hack_controller.register_entry(team, op.player_id)
		print("[CoreCaptureZone] Operator P%d (team %d) entered perimeter." % [op.player_id, team])

func _on_body_exited(body: Node3D) -> void:
	print("[CoreCaptureZone DEBUG] _on_body_exited called for body: %s" % body.name)
	if hack_controller == null:
		return

	if body is OperatorBase:
		if _startup_ignored_bodies.has(body):
			_startup_ignored_bodies.erase(body)
			print("[CoreCaptureZone] Operator P%d exited during startup grace, removed from ignore list." % body.player_id)
			return
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
