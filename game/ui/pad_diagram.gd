# pad_diagram.gd
# Technical Rationale: Large, modern gamepad schematic for the binding editor.
# Draws a recognizable controller with family-aware button labels and highlights
# the button/axis bound to the currently-selected action. All positions are keyed
# by the REAL Godot 4 JoyButton ids (Face 0..3, Back=4, Start=6, LS=7, RS=8,
# L1=9, R1=10, D-pad 11..14) and JoyAxis ids (Trig L=4, Trig R=5) so the highlight
# always matches the InputProfile's bound InputEvent. Pure rendering widget.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name PadDiagram
extends Control

const W: int = 560
const H: int = 440

# Colors — dark tech aesthetic
const _BG_BODY: Color = Color(0.07, 0.08, 0.12)
const _BG_INNER: Color = Color(0.13, 0.14, 0.19)
const _OUTLINE: Color = Color(0.38, 0.40, 0.44)
const _BTN_NORMAL: Color = Color(0.20, 0.21, 0.26)
const _BTN_HL: Color = Color(0.92, 0.58, 0.20, 0.85)
const _BTN_SEL: Color = Color(0.30, 0.72, 0.95, 0.85)
const _STICK_BG: Color = Color(0.22, 0.23, 0.27)
const _STICK_HL: Color = Color(0.92, 0.58, 0.20, 0.40)
const _TEXT: Color = Color(0.92, 0.94, 0.96)
const _TEXT_MUTED: Color = Color(0.58, 0.61, 0.67)
const _DPAD_BG: Color = Color(0.18, 0.18, 0.22)

# Face button radius
const FACE_R: float = 30.0
const SHOULDER_W: float = 84.0
const SHOULDER_H: float = 36.0
const STICK_R: float = 46.0
const CENTER_W: float = 64.0
const CENTER_H: float = 34.0
const DPAD_R: float = 22.0
const TRIGGER_H: float = 26.0
const TRIGGER_W: float = 104.0

## Family-key → face-button labels [South(0), East(1), West(2), North(3)]
const FACE_LABELS: Dictionary = {
	"xbox":       ["A", "B", "X", "Y"],
	"playstation": ["✕", "○", "□", "△"],
	"nintendo":   ["B", "A", "Y", "X"],
	"generic":    ["A", "B", "X", "Y"],
}

const FAMILY_LABELS: Dictionary = {
	"xbox":       {"9": "LB", "10": "RB", "trig_l": "L2", "trig_r": "R2", "4": "Ver", "6": "Menú", "7": "LS", "8": "RS"},
	"playstation": {"9": "L1", "10": "R1", "trig_l": "L2", "trig_r": "R2", "4": "Opciones", "6": "Touch", "7": "L3", "8": "R3"},
	"nintendo":   {"9": "L", "10": "R", "trig_l": "ZL", "trig_r": "ZR", "4": "Select", "6": "Start", "7": "L3", "8": "R3"},
	"generic":    {"9": "L1", "10": "R1", "trig_l": "L2", "trig_r": "R2", "4": "Ver", "6": "Menú", "7": "LS", "8": "RS"},
}

## Button positions keyed by REAL Godot 4 JoyButton ids.
## Face: 0=S,1=E,2=W,3=N  Back=4  Start=6  LS=7  RS=8  L1=9  R1=10
## D-pad: 11=Up,12=Down,13=Left,14=Right
const _POS: Dictionary = {
	0:  Vector2(420, 286),
	1:  Vector2(476, 234),
	2:  Vector2(364, 234),
	3:  Vector2(420, 182),
	9:  Vector2(70, 70),
	10: Vector2(490, 70),
	7:  Vector2(170, 360),
	8:  Vector2(410, 360),
	4:  Vector2(270, 386),
	6:  Vector2(330, 386),
	11: Vector2(98, 182),
	12: Vector2(98, 226),
	13: Vector2(76, 204),
	14: Vector2(120, 204),
}

const FACE_BTNS: Array[int] = [0, 1, 2, 3]
const SHOULDER_BTNS: Array[int] = [9, 10]
const STICK_BTNS: Array[int] = [7, 8]
const CENTER_BTNS: Array[int] = [4, 6]
const DPAD_BTNS: Array[int] = [11, 12, 13, 14]
const TRIGGER_AXES: Array[int] = [4, 5]
const STICK_AXES: Array[int] = [0, 1, 2, 3]

const _TRIGGER_L: Rect2 = Rect2(30, 26, TRIGGER_W, TRIGGER_H)
const _TRIGGER_R: Rect2 = Rect2(400, 26, TRIGGER_W, TRIGGER_H)

var family: String = "generic"
var _highlight_event: InputEvent = null
var _font: Font = ThemeDB.fallback_font

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)

func set_family(f: String) -> void:
	if f != family:
		family = f
		queue_redraw()

func set_highlight_event(ev: InputEvent) -> void:
	_highlight_event = ev
	queue_redraw()

func clear_highlight() -> void:
	_highlight_event = null
	queue_redraw()

func get_highlighted_event() -> InputEvent:
	return _highlight_event

func _btn_label(btn: int) -> String:
	if btn >= 0 and btn <= 3:
		var face: Array = FACE_LABELS.get(family, FACE_LABELS["generic"]) as Array
		return face[btn] as String
	return ""

func _fam_label(key: String) -> String:
	var fl: Dictionary = FAMILY_LABELS.get(family, FAMILY_LABELS["generic"]) as Dictionary
	return fl.get(key, "?") as String

func _axis_label(axis: int, sign: float) -> String:
	match axis:
		0: return "Stick Izq" + ("→" if sign >= 0.0 else "←")
		1: return "Stick Izq" + ("↓" if sign >= 0.0 else "↑")
		2: return "Stick Der" + ("→" if sign >= 0.0 else "←")
		3: return "Stick Der" + ("↓" if sign >= 0.0 else "↑")
		_: return ""

func _btn_hl(btn: int) -> bool:
	return _highlight_event is InputEventJoypadButton \
		and int((_highlight_event as InputEventJoypadButton).button_index) == btn

func _axis_hl(axis: int) -> bool:
	return _highlight_event is InputEventJoypadMotion \
		and int((_highlight_event as InputEventJoypadMotion).axis) == axis

func _axis_dir(axis: int) -> String:
	if not _highlight_event is InputEventJoypadMotion:
		return ""
	return "+" if (_highlight_event as InputEventJoypadMotion).axis_value >= 0.0 else "-"

func _cap(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)

func _draw() -> void:
	# Controller body
	draw_rect(Rect2(6, 6, W - 12, H - 12), _BG_BODY, true)
	draw_rect(Rect2(10, 10, W - 20, H - 20), _OUTLINE, false, 2.0)
	draw_rect(Rect2(14, 14, W - 28, H - 28), _BG_INNER, true)

	# ── Triggers (L2/R2) — axes 4/5 ──
	for axis: int in TRIGGER_AXES:
		var rect: Rect2 = _TRIGGER_L if axis == 4 else _TRIGGER_R
		var col: Color = _BTN_HL if _axis_hl(axis) else _STICK_BG
		draw_rect(rect, col, true)
		draw_rect(rect, _OUTLINE, false, 1.0)
		_fmid(_fam_label("trig_l" if axis == 4 else "trig_r"), rect.position + Vector2(rect.size.x * 0.5, 11), 12)

	# ── Shoulders (L1/R1) — buttons 9/10 ──
	for i: int in range(0, SHOULDER_BTNS.size()):
		var btn: int = SHOULDER_BTNS[i]
		var pos: Vector2 = _POS[btn]
		var col: Color = _BTN_HL if _btn_hl(btn) else _BTN_NORMAL
		var sz: Vector2 = Vector2(SHOULDER_W, SHOULDER_H)
		draw_rect(Rect2(pos - sz * 0.5, sz), col, true)
		draw_rect(Rect2(pos - sz * 0.5, sz), _OUTLINE, false, 1.5)
		_fmid(_fam_label(str(btn)), pos, 14, _TEXT, SHOULDER_W)

	# ── Face buttons (diamond) ──
	for btn: int in FACE_BTNS:
		var pos: Vector2 = _POS[btn]
		var col: Color = _BTN_HL if _btn_hl(btn) else _BTN_NORMAL
		draw_circle(pos, FACE_R, col)
		draw_circle(pos, FACE_R, _OUTLINE, -1, true, 2.0)
		_fmid(_btn_label(btn), pos, 16, _TEXT, FACE_R * 2)

	# ── D-pad (cross + directional buttons) ──
	draw_rect(Rect2(84, 164, 28, 84), _DPAD_BG, true)
	draw_rect(Rect2(84, 164, 28, 84), _OUTLINE, false, 1.5)
	draw_rect(Rect2(66, 186, 64, 28), _DPAD_BG, true)
	draw_rect(Rect2(66, 186, 64, 28), _OUTLINE, false, 1.5)
	for btn: int in DPAD_BTNS:
		var pos: Vector2 = _POS[btn]
		var col: Color = _BTN_HL if _btn_hl(btn) else _DPAD_BG
		draw_circle(pos, DPAD_R, col)
		draw_circle(pos, DPAD_R, _OUTLINE, -1, true, 1.5)

	# ── Sticks ──
	for i: int in range(0, STICK_BTNS.size()):
		var btn: int = STICK_BTNS[i]
		var pos: Vector2 = _POS[btn]
		var ax: int = i * 2
		var ay: int = i * 2 + 1
		var hl: bool = _btn_hl(btn) or _axis_hl(ax) or _axis_hl(ay)
		var col: Color = _BTN_HL if hl else _STICK_BG
		draw_circle(pos, STICK_R, col)
		draw_circle(pos, STICK_R, _OUTLINE, -1, true, 2.0)
		# Inner dot with direction for axis bindings
		var inner: Vector2 = pos
		if _axis_hl(ax):
			inner.x += 16.0 if _axis_dir(ax) == "+" else -16.0
		if _axis_hl(ay):
			inner.y += -16.0 if _axis_dir(ay) == "-" else 16.0
		draw_circle(inner, 10.0, Color(0.92, 0.58, 0.2, 0.9))
		_fmid(_fam_label(str(btn)), pos + Vector2(0, STICK_R + 18), 12)

	# ── Back / Start ──
	for i: int in range(0, CENTER_BTNS.size()):
		var btn: int = CENTER_BTNS[i]
		var pos: Vector2 = _POS[btn]
		var col: Color = _BTN_HL if _btn_hl(btn) else _BTN_NORMAL
		var sz: Vector2 = Vector2(CENTER_W, CENTER_H)
		draw_rect(Rect2(pos - sz * 0.5, sz), col, true)
		draw_rect(Rect2(pos - sz * 0.5, sz), _OUTLINE, false, 1.5)
		_fmid(_fam_label(str(btn)), pos, 13, _TEXT, CENTER_W)

	# Status footer
	var status: String = "Controlador: " + _cap(family)
	if _highlight_event != null:
		status += "  •  " + _event_desc()
	_fmid(status, Vector2(16, H - 16), 12, _TEXT_MUTED, W - 32)

func _fmid(text: String, pos: Vector2, size: int, color: Color = _TEXT, width: float = 0.0) -> void:
	_font.draw_string(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)

func _event_desc() -> String:
	if _highlight_event is InputEventJoypadButton:
		var btn: int = int((_highlight_event as InputEventJoypadButton).button_index)
		var label: String = _btn_label(btn) if btn <= 3 else _fam_label(str(btn))
		if not label.is_empty():
			return label
		return "Botón %d" % btn
	if _highlight_event is InputEventJoypadMotion:
		var axis: int = int((_highlight_event as InputEventJoypadMotion).axis)
		return _axis_label(axis, (_highlight_event as InputEventJoypadMotion).axis_value)
	return "Entrada"