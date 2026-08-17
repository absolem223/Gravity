# input_registry.gd
# Technical Rationale: Static input profiling helpers. Provides device resolution
# (menu joystick slot -> OS device id) and controller-family layout detection so
# menus and gameplay never reason about physical keys/devices directly.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name InputProfiles
extends RefCounted

## Number of supported local player slots.
const MAX_PLAYERS: int = 4

## Resolves a menu joystick slot (1..N, N = number of connected pads) to the OS
## device id of the N-th connected controller. Returns -1 when the slot is invalid
## or no controller is physically connected to it. Device ids change on hotplug,
## so we always resolve lazily at query time.
static func resolve_joy_device(joy_slot: int) -> int:
	if joy_slot < 1:
		return -1
	var pads: Array[int] = Input.get_connected_joypads()
	var idx: int = joy_slot - 1
	if idx < pads.size():
		return pads[idx]
	return -1

## All connected controller device ids.
static func get_connected_joypads() -> Array[int]:
	return Input.get_connected_joypads()

## Best-effort controller-family detection for visual layout rendering.
## Returns "xbox" | "playstation" | "nintendo" | "generic".
static func joypad_layout_name(device_id: int) -> String:
	if device_id < 0:
		return "generic"
	var name: String = Input.get_joy_name(device_id).to_lower()
	if name.contains("xbox"):
		return "xbox"
	if name.contains("playstation") or name.contains("dual"):
		return "playstation"
	if name.contains("switch") or name.contains("nintendo") or name.contains("pro controller"):
		return "nintendo"
	return "generic"

## Human-readable device label for a resolved controller slot.
static func joypad_slot_label(joy_slot: int) -> String:
	var pads: Array[int] = get_connected_joypads()
	if joy_slot < 1 or joy_slot > pads.size():
		return "Joystick %d (desconectado)" % joy_slot
	return "Joystick %d" % joy_slot

## ──────────────────────────────────────────────
## BINDING LABELS (data-driven text for the editor)
## ──────────────────────────────────────────────

## Family-key -> face button labels [South(0), East(1), West(2), North(3)].
const FACE_LABELS: Dictionary = {
	"xbox":        ["A", "B", "X", "Y"],
	"playstation": ["Cruz", "Círculo", "Cuadrado", "Triángulo"],
	"nintendo":    ["B", "A", "Y", "X"],
	"generic":     ["A", "B", "X", "Y"],
}

## Family-key -> non-face button labels, by Godot 4 JoyButton integer id:
## 4=Back, 6=Start, 7=LeftStick, 8=RightStick, 9=L1, 10=R1,
## 11..14=D-pad Up/Down/Left/Right.
const BUTTON_LABELS: Dictionary = {
	"xbox": {
		4: "Ver", 6: "Menú", 7: "LS", 8: "RS",
		9: "LB", 10: "RB",
		11: "D-Pad ↑", 12: "D-Pad ↓", 13: "D-Pad ←", 14: "D-Pad →",
	},
	"playstation": {
		4: "Opciones", 6: "Touch", 7: "L3", 8: "R3",
		9: "L1", 10: "R1",
		11: "D-Pad ↑", 12: "D-Pad ↓", 13: "D-Pad ←", 14: "D-Pad →",
	},
	"nintendo": {
		4: "Select", 6: "Start", 7: "L3", 8: "R3",
		9: "L", 10: "R",
		11: "D-Pad ↑", 12: "D-Pad ↓", 13: "D-Pad ←", 14: "D-Pad →",
	},
	"generic": {
		4: "Ver", 6: "Menú", 7: "LS", 8: "RS",
		9: "L1", 10: "R1",
		11: "D-Pad ↑", 12: "D-Pad ↓", 13: "D-Pad ←", 14: "D-Pad →",
	},
}

const AXIS_LABELS: Dictionary = {
	0: "Stick Izq →", 1: "Stick Izq ↓", 2: "Stick Der →", 3: "Stick Der ↓",
	4: "L2", 5: "R2",
}

## Human readable label for a bound InputEvent. `family` is one of the layout
## keys ("xbox"|"playstation"|"nintendo"|"generic"), used for controller buttons.
static func binding_label(event: InputEvent, family: String) -> String:
	if event is InputEventJoypadButton:
		var btn: int = int((event as InputEventJoypadButton).button_index)
		if btn >= 0 and btn <= 3:
			var face: Array = FACE_LABELS.get(family, FACE_LABELS["generic"]) as Array
			return str(face[btn])
		var labels: Dictionary = BUTTON_LABELS.get(family, BUTTON_LABELS["generic"]) as Dictionary
		if labels.has(btn):
			return str(labels[btn])
		return "Botón %d" % btn
	if event is InputEventJoypadMotion:
		return str(AXIS_LABELS.get(int((event as InputEventJoypadMotion).axis), "Eje %d" % int((event as InputEventJoypadMotion).axis)))
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.physical_keycode != KEY_NONE:
			return OS.get_keycode_string(k.physical_keycode)
		if k.keycode != KEY_NONE:
			return OS.get_keycode_string(k.keycode)
		return "?"
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Click Izq."
			MOUSE_BUTTON_RIGHT:
				return "Click Der."
			_:
				return "Mouse %d" % int((event as InputEventMouseButton).button_index)
	return "?"