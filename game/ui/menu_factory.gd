# menu_factory.gd
# Technical Rationale: Reusable UI building blocks for every menu screen. Centralises
# typography, colors, button sizing and row composition so all screens look and feel
# consistent and can be re-themed later without touching screen logic.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name MenuFactory
extends RefCounted

const COLOR_BG: Color = Color(0.06, 0.07, 0.1, 1.0)
const COLOR_TEXT: Color = Color(0.9, 0.92, 0.95, 1.0)
const COLOR_MUTED: Color = Color(0.7, 0.73, 0.8, 1.0)
const COLOR_WARN: Color = Color(1.0, 0.45, 0.35, 1.0)

static func make_background() -> ColorRect:
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg

static func make_label(text: String, font_size: int = 16, color: Color = COLOR_TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.modulate = color
	return l

static func make_title(text: String) -> Label:
	return make_label(text, 34, COLOR_TEXT)

static func make_hint(text: String) -> Label:
	var l: Label = make_label(text, 14, COLOR_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	return l

static func make_button(text: String, callback: Callable, min_width: int = 320, min_height: int = 44) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, min_height)
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

static func make_section(text: String) -> Label:
	return make_label(text, 20, COLOR_TEXT)

## Capitalizes only the first character of a string (e.g. "xbox" -> "Xbox").
static func capitalize_first(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)

static func make_option_row(label_text: String, option: OptionButton) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl: Label = make_label(label_text, 16)
	lbl.custom_minimum_size = Vector2(240, 0)
	row.add_child(lbl)
	row.add_child(option)
	return row

## Converts a bound InputEvent to a short human label (e.g. "W", "Click Izq.", "A (Xbox)").
static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var kev: InputEventKey = ev as InputEventKey
		if kev.physical_keycode != KEY_NONE:
			return OS.get_keycode_string(kev.physical_keycode)
		if kev.keycode != KEY_NONE:
			return OS.get_keycode_string(kev.keycode)
		return "?"
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Click Izq."
			MOUSE_BUTTON_RIGHT:
				return "Click Der."
			MOUSE_BUTTON_MIDDLE:
				return "Click Medio."
			_:
				return "Mouse %d" % int((ev as InputEventMouseButton).button_index)
	if ev is InputEventJoypadButton:
		return "B%d" % int((ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = ev as InputEventJoypadMotion
		var side: String = "-" if m.axis_value < 0.0 else "+"
		return "Eje%d%s" % [int(m.axis), side]
	return "?"