# test_operator_badge.gd
# Technical Rationale: Headless validation of the high-contrast overhead badge
# (Feature: "player names above operators"). The OverheadBadge is a two-layer
# Label3D: a light-gray fill label ("BadgePanel") with a thin subtle-green
# outline is drawn behind the main label, whose near-black text stays readable
# over both the dark terrain and the bright fog overlay. State overrides
# (dead/spawn/invulnerable/drone lost/separated/down) keep their distinct text
# colors. Purely presentation: slot identity colors and detection logic are
# untouched.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).
#
# Run: godot --headless --path game --script res://tests/test_operator_badge.gd

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

## Builds a bare OperatorBase off-tree with the badge set up manually, so the
## test does not depend on match/input/spawn plumbing.
func _make_operator(player: int, team: int) -> OperatorBase:
	var op: OperatorBase = OperatorBase.new()
	op.player_id = player
	op.team_id = team
	op._setup_overhead_badge()
	op._update_overhead_badge()
	return op

func run_test() -> void:
	print("== OPERATOR OVERHEAD BADGE TEST ==")

	var op: OperatorBase = _make_operator(1, OperatorBase.TEAM_ATTACKERS)
	op.has_drone_active = true
	op._update_overhead_badge()
	var label: Label3D = op._overhead_label
	_check(label != null, "overhead badge label exists after setup")
	_check(label != null and label.name == "OverheadBadge", "label is named OverheadBadge")
	_check(label != null and label.no_depth_test, "badge renders through the fog plane (no depth test)")
	_check(label != null and label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		"badge always faces the camera (billboard)")

	# Two-layer badge: the text label carries a thin near-black edge and sits over
	# a light-gray fill panel with a thin subtle-green border.
	_check(label != null and label.outline_size >= 2, "badge text keeps a thin dark edge")
	_check(label != null and label.outline_modulate.is_equal_approx(Color(0.02, 0.02, 0.02, 1.0)),
		"badge text edge is near-black")
	var panel: Label3D = op._badge_panel
	_check(panel != null, "badge has a background fill panel (BadgePanel)")
	_check(panel != null and panel.modulate.is_equal_approx(Color(0.95, 0.95, 0.95, 1.0)),
		"fill panel is light gray/white (readable over green terrain)")
	_check(panel != null and panel.outline_modulate.is_equal_approx(Color(0.08, 0.3, 0.16, 1.0)),
		"fill panel border is a subtle dark green")
	_check(panel != null and panel.text == label.text,
		"fill panel mirrors the badge text")

	# Normal state: near-black text on the light panel — high contrast over both
	# the green terrain and the bright fog overlay.
	_check(label != null and label.modulate.is_equal_approx(Color(0.04, 0.04, 0.04, 1.0)),
		"normal badge text is near-black on the light fill")
	_check(label != null and label.text.contains("P1 RECON"),
		"badge text shows player role")

	# State overrides keep their distinct presentation colors.
	var dead: OperatorBase = _make_operator(2, OperatorBase.TEAM_DEFENDERS)
	dead.is_incapacitated = true
	dead.current_state = OperatorBase.OperatorState.DEAD
	dead._update_overhead_badge()
	_check(dead._overhead_label.modulate.is_equal_approx(Color(0.5, 0.5, 0.5)),
		"dead badge uses the gray override")
	_check(dead._overhead_label.text.contains("DEAD"),
		"dead badge text shows the DEAD marker")

	var drone_lost: OperatorBase = _make_operator(3, OperatorBase.TEAM_ATTACKERS)
	drone_lost.has_drone_active = false
	drone_lost._update_overhead_badge()
	_check(drone_lost._overhead_label.modulate.is_equal_approx(Color(0.9, 0.2, 0.2)),
		"drone-lost badge uses the red override")
	_check(drone_lost._overhead_label.text.contains("DRONE LOST"),
		"drone-lost badge text shows the marker")

	op.free()
	dead.free()
	drone_lost.free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)