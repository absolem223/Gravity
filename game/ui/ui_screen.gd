# ui_screen.gd
# Technical Rationale: Base class for every menu screen. All screens share full-rect
# sizing, a back gesture (Esc), and a reference to the routing stack that rendered
# them. Screens only talk to the config/input layers; they never know gameplay.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name UIScreen
extends Control

## Human title shown by the router header (when rendered there).
var screen_title: String = ""

## Control to restore focus to when this screen becomes active again.
var _saved_focus: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func focus_first() -> void:
	var c: Control = _first_focusable()
	if c != null:
		_saved_focus = c
		c.grab_focus()

## Remembers the currently focused control (used by the router before hiding us).
func save_focus() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var c: Control = vp.gui_get_focus_owner()
	if c != null and is_ancestor_of(c):
		_saved_focus = c

## Restores the saved focus, falling back to the first focusable control.
func restore_focus() -> void:
	if _saved_focus != null and is_instance_valid(_saved_focus) and is_ancestor_of(_saved_focus) \
			and _saved_focus.is_visible_in_tree():
		_saved_focus.grab_focus()
	else:
		focus_first()

## Breadth-first search for the first focusable Button (normal UI chrome only).
func _first_focusable() -> Control:
	var queue: Array[Node] = [self]
	var index: int = 0
	while index < queue.size():
		var n: Node = queue[index]
		index += 1
		if n is Button:
			var b: Button = n as Button
			if b.is_visible_in_tree() and not b.disabled:
				return b
		if n is Control:
			for child: Node in (n as Control).get_children():
				queue.append(child)
	return null

## Navigation helpers (delegate to the enclosing UIScreenStack).
func get_router() -> UIScreenStack:
	var parent: Node = get_parent()
	while parent != null:
		if parent is UIScreenStack:
			return parent as UIScreenStack
		parent = parent.get_parent()
	return null

func push(screen: UIScreen) -> void:
	var router: UIScreenStack = get_router()
	if router != null:
		router.push(screen)

func pop() -> void:
	var router: UIScreenStack = get_router()
	if router != null:
		router.pop()

## Global back gesture: Esc pops the router when the screen is not at its root.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		var router: UIScreenStack = get_router()
		if router != null and router.back_enabled():
			get_viewport().set_input_as_handled()
			router.pop()