# ui_screen_stack.gd
# Technical Rationale: Definitvie menu router. Holds a stack of UIScreen children and
# only ever shows the top one, preserving the state of the screens below so returning
# back keeps the user's selections. Adding a new screen is just push(UIScreenClass.new()).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name UIScreenStack
extends Control

var _screens: Array[UIScreen] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

## Shows `screen` as the new active screen (previous ones stay alive, hidden).
func push(screen: UIScreen) -> void:
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not _screens.is_empty():
		_screens.back().save_focus()
		_screens.back().visible = false
	_screens.append(screen)
	add_child(screen)
	screen.visible = true
	screen.restore_focus()

## Replaces the top screen (used for modal dialogs that never return).
func replace(screen: UIScreen) -> void:
	if not _screens.is_empty():
		var old: UIScreen = _screens.pop_back()
		remove_child(old)
		old.queue_free()
	push(screen)

## Pops the top screen and reveals the previous one, restoring its focus.
func pop() -> void:
	if _screens.is_empty():
		return
	var top: UIScreen = _screens.pop_back()
	remove_child(top)
	top.queue_free()
	if not _screens.is_empty():
		_screens.back().visible = true
		_screens.back().restore_focus()

func back_enabled() -> bool:
	return _screens.size() > 1

func top() -> UIScreen:
	if _screens.is_empty():
		return null
	return _screens.back()