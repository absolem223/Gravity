# test_bindings_screen.gd
# Technical Rationale: Validates the gamepad binding editor's testable components:
# PadDiagram highlight mapping (config-agnostic, testable via -s), and InputProfile
# joystick defaults (all 14 actions, correct JoyButton/JoyAxis bindings).
# BindingsScreen integration is covered by boot smoke + manual verification
# because -s cannot resolve the GameConfig autoload global.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

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

func run_test() -> void:
    print("== GAMEPAD BINDINGS TEST ==")
    var root: Window = get_root()

    # === Part 1: PadDiagram highlight mapping ===
    var diag: PadDiagram = PadDiagram.new()
    root.add_child(diag)
    diag.set_family("xbox")
    await physics_frame

    _check(diag.get_highlighted_event() == null, "diagram has no highlight initially")

    var ev_a: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_a.button_index = JOY_BUTTON_A
    diag.set_highlight_event(ev_a)
    await physics_frame
    _check(diag.get_highlighted_event() == ev_a, "highlights South button after A press")

    var ev_b: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_b.button_index = JOY_BUTTON_B
    diag.set_highlight_event(ev_b)
    await physics_frame
    _check(diag.get_highlighted_event() == ev_b, "highlights East button after B press")

    var ev_rs: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_rs.button_index = JOY_BUTTON_RIGHT_SHOULDER
    diag.set_highlight_event(ev_rs)
    await physics_frame
    _check(diag.get_highlighted_event() == ev_rs, "highlights right shoulder")

    var ev_axis: InputEventJoypadMotion = InputEventJoypadMotion.new()
    ev_axis.axis = JOY_AXIS_LEFT_Y
    ev_axis.axis_value = -1.0
    diag.set_highlight_event(ev_axis)
    await physics_frame
    _check(diag.get_highlighted_event() == ev_axis, "highlights left stick axis event")

    diag.clear_highlight()
    await physics_frame
    _check(diag.get_highlighted_event() == null, "clear_highlight removes highlight")

    diag.set_family("playstation")
    diag.set_highlight_event(ev_a)
    await physics_frame
    _check(diag.get_highlighted_event() == ev_a, "family change preserves highlight")

    diag.queue_free()
    await physics_frame

    # === Part 2: InputProfile joystick defaults ===
    var prof: InputProfile = InputProfile.new()
    prof.player_id = 1
    prof.set_device(InputProfile.DeviceKind.JOYSTICK, 1)
    prof.reset_defaults()
    _check(not prof.is_keyboard(), "profile is joystick after set_device + reset_defaults")

    var missing: Array[String] = []
    for action: String in InputProfile.ACTION_NAMES:
        if action == "aim_cone":
            continue  # gamepad cone is right-stick driven, not a bindable action
        if not prof.has_binding(action):
            missing.append(action)
    _check(missing.is_empty(), "all %d actions have joystick defaults (missing: %s)" % [InputProfile.ACTION_NAMES.size(), ", ".join(missing)])
    _check(not prof.has_binding("aim_cone"), "aim_cone has NO joystick default (right-stick drives the cone)")

    # Dash → JOY_BUTTON_A (South)
    var dash_ev: InputEventJoypadButton = prof.get_events("dash")[0] as InputEventJoypadButton
    _check(dash_ev.button_index == JOY_BUTTON_A, "dash defaults to JOY_BUTTON_A")

    # Fire → R2 (JOY_AXIS_TRIGGER_RIGHT, positive trigger axis)
    var fire_ev: InputEventJoypadMotion = prof.get_events("fire")[0] as InputEventJoypadMotion
    _check(fire_ev is InputEventJoypadMotion, "fire uses a joy axis (R2 trigger)")
    _check(fire_ev.axis == JOY_AXIS_TRIGGER_RIGHT, "fire defaults to R2 trigger axis")
    _check(fire_ev.axis_value > 0.0, "fire R2 axis is positive (pull-to-fire)")
    _check(not (prof.get_events("fire")[0] is InputEventJoypadButton), "fire is NOT a shoulder button anymore")

    # Ability → JOY_BUTTON_LEFT_SHOULDER
    var ab_ev: InputEventJoypadButton = prof.get_events("ability")[0] as InputEventJoypadButton
    _check(ab_ev.button_index == JOY_BUTTON_LEFT_SHOULDER, "ability defaults to LEFT_SHOULDER")

    # Interact → JOY_BUTTON_X (West)
    var int_ev: InputEventJoypadButton = prof.get_events("interact")[0] as InputEventJoypadButton
    _check(int_ev.button_index == JOY_BUTTON_X, "interact defaults to JOY_BUTTON_X")

    # Drone → JOY_BUTTON_B (East)
    var dr_ev: InputEventJoypadButton = prof.get_events("drone_mode")[0] as InputEventJoypadButton
    _check(dr_ev.button_index == JOY_BUTTON_B, "drone_mode defaults to JOY_BUTTON_B")

    # Back → JOY_BUTTON_BACK
    var bk_ev: InputEventJoypadButton = prof.get_events("back_operator")[0] as InputEventJoypadButton
    _check(bk_ev.button_index == JOY_BUTTON_BACK, "back_operator defaults to JOY_BUTTON_BACK")

    # Drone action → JOY_BUTTON_Y (North)
    var da_ev: InputEventJoypadButton = prof.get_events("drone_action")[0] as InputEventJoypadButton
    _check(da_ev.button_index == JOY_BUTTON_Y, "drone_action defaults to JOY_BUTTON_Y")

    # Menu → JOY_BUTTON_START
    var menu_ev: InputEventJoypadButton = prof.get_events("menu")[0] as InputEventJoypadButton
    _check(menu_ev.button_index == JOY_BUTTON_START, "menu defaults to JOY_BUTTON_START")

    # Crouch → JOY_BUTTON_LEFT_STICK
    var cr_ev: InputEventJoypadButton = prof.get_events("crouch")[0] as InputEventJoypadButton
    _check(cr_ev.button_index == JOY_BUTTON_LEFT_STICK, "crouch defaults to LEFT_STICK")

    # Autoaim → JOY_BUTTON_RIGHT_STICK
    var aa_ev: InputEventJoypadButton = prof.get_events("autoaim")[0] as InputEventJoypadButton
    _check(aa_ev.button_index == JOY_BUTTON_RIGHT_STICK, "autoaim defaults to RIGHT_STICK")

    # Movement → analog axes
    _check(prof.get_events("move_up")[0] is InputEventJoypadMotion, "move_up uses joy axis")
    var mu: InputEventJoypadMotion = prof.get_events("move_up")[0] as InputEventJoypadMotion
    _check(mu.axis == JOY_AXIS_LEFT_Y, "move_up uses left stick Y axis")
    _check(mu.axis_value < 0.0, "move_up uses negative Y (up)")

    # Aim → right-stick analog axes (deflecting the right stick must NEVER feed
    # the movement vector; aim uses its own isolated action set).
    var ar: InputEventJoypadMotion = prof.get_events("aim_right")[0] as InputEventJoypadMotion
    _check(ar is InputEventJoypadMotion and ar.axis == JOY_AXIS_RIGHT_X and ar.axis_value > 0.0,
        "aim_right uses right stick +X")
    var al: InputEventJoypadMotion = prof.get_events("aim_left")[0] as InputEventJoypadMotion
    _check(al is InputEventJoypadMotion and al.axis == JOY_AXIS_RIGHT_X and al.axis_value < 0.0,
        "aim_left uses right stick -X")
    var au: InputEventJoypadMotion = prof.get_events("aim_up")[0] as InputEventJoypadMotion
    _check(au is InputEventJoypadMotion and au.axis == JOY_AXIS_RIGHT_Y and au.axis_value < 0.0,
        "aim_up uses right stick -Y")
    var ad: InputEventJoypadMotion = prof.get_events("aim_down")[0] as InputEventJoypadMotion
    _check(ad is InputEventJoypadMotion and ad.axis == JOY_AXIS_RIGHT_Y and ad.axis_value > 0.0,
        "aim_down uses right stick +Y")

    # Movement stays bound to the LEFT stick only (right stick is aim isolation).
    var mv: InputEventJoypadMotion = prof.get_events("move_right")[0] as InputEventJoypadMotion
    _check(mv is InputEventJoypadMotion and mv.axis == JOY_AXIS_LEFT_X, "move_right uses left stick +X")

    # === Part 3: Rebind replaces the old binding ===
    var new_ev: InputEventJoypadButton = InputEventJoypadButton.new()
    new_ev.button_index = JOY_BUTTON_X
    prof.bind_action("dash", new_ev)
    var dash_after: InputEventJoypadButton = prof.get_events("dash")[0] as InputEventJoypadButton
    _check(dash_after.button_index == JOY_BUTTON_X, "bind_action replaces dash from A to X")
    _check(prof.get_events("dash").size() == 1, "dash still has exactly 1 binding after rebind")

    # === Part 4: D-pad directions can be assigned ===
    var dpad_ok: bool = true
    for btn: int in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
        var ev: InputEventJoypadButton = InputEventJoypadButton.new()
        ev.button_index = btn as JoyButton
        prof.bind_action("dash", ev)
        var got: InputEventJoypadButton = prof.get_events("dash")[0] as InputEventJoypadButton
        if got.button_index != btn:
            dpad_ok = false
    _check(dpad_ok, "D-pad directions can be assigned as bindings")

    # === Part 5: Family-aware binding labels (data-driven editor text) ===
    var ev_a5: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_a5.button_index = JOY_BUTTON_A
    _check(InputProfiles.binding_label(ev_a5, "xbox") == "A", "xbox label for A is 'A'")
    _check(InputProfiles.binding_label(ev_a5, "playstation") == "Cruz", "playstation label for A is 'Cruz'")
    _check(InputProfiles.binding_label(ev_a5, "nintendo") == "B", "nintendo label for A is 'B'")
    _check(InputProfiles.binding_label(ev_a5, "generic") == "A", "generic label for A is 'A'")
    var ev_bs: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_bs.button_index = JOY_BUTTON_B
    _check(InputProfiles.binding_label(ev_bs, "xbox") == "B", "xbox label for B is 'B'")
    var ev_lb: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_lb.button_index = JOY_BUTTON_LEFT_SHOULDER
    _check(InputProfiles.binding_label(ev_lb, "xbox") == "LB", "xbox label for L1 is 'LB'")
    var ev_ls: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_ls.button_index = JOY_BUTTON_LEFT_STICK
    _check(InputProfiles.binding_label(ev_ls, "xbox") == "LS", "xbox label for LS is 'LS'")
    var ev_mk: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_mk.button_index = JOY_BUTTON_START
    _check(InputProfiles.binding_label(ev_mk, "generic") == "Menú", "generic label for START is 'Menú'")
    var ev_up: InputEventJoypadButton = InputEventJoypadButton.new()
    ev_up.button_index = JOY_BUTTON_DPAD_UP
    _check(InputProfiles.binding_label(ev_up, "generic") == "D-Pad ↑", "generic label for d-pad up")
    var ev_axis5: InputEventJoypadMotion = InputEventJoypadMotion.new()
    ev_axis5.axis = JOY_AXIS_TRIGGER_RIGHT
    _check(InputProfiles.binding_label(ev_axis5, "xbox") == "R2", "label for right trigger axis")
    var ev_key: InputEventKey = InputEventKey.new()
    ev_key.keycode = KEY_W
    _check(InputProfiles.binding_label(ev_key, "") == "W", "keyboard label for W is 'W'")

    # === Part 6: KeyCaptureOverlay keyboard capture + Escape cancel ===
    var ov: KeyCaptureOverlay = KeyCaptureOverlay.new()
    root.add_child(ov)
    await physics_frame
    ov.start(InputProfile.DeviceKind.KEYBOARD, "Dash")
    _check(ov.is_listening(), "overlay listening after start()")
    _check(ov.visible, "overlay visible during capture")

    # Lambdas capture locals BY VALUE, so accumulate into arrays (reference types).
    var captured: Array[InputEvent] = []
    var captured_counts: Array[int] = [0]
    ov.captured.connect(func(ev: InputEvent) -> void:
        captured.append(ev)
        captured_counts[0] += 1)
    var kk: InputEventKey = InputEventKey.new()
    kk.keycode = KEY_K
    kk.physical_keycode = KEY_K
    kk.pressed = true
    ov._input(kk)
    await process_frame
    _check(captured_counts[0] == 1, "overlay captures a key press")
    _check(not ov.is_listening(), "overlay stops after capture")
    _check(captured.size() == 1 and (captured[0] as InputEventKey).keycode == KEY_K, "captured event is the pressed key")

    # Escape cancels without emitting captured.
    ov._device_kind = InputProfile.DeviceKind.KEYBOARD
    ov.start(InputProfile.DeviceKind.KEYBOARD, "Dash")
    var caps_before_restart: int = captured_counts[0]
    var cancelled_counts: Array[int] = [0]
    ov.cancelled.connect(func() -> void: cancelled_counts[0] += 1)
    ov._input(kk)
    await process_frame
    _check(cancelled_counts[0] == 0 and captured_counts[0] == caps_before_restart + 1, "no cancel signal but capture works after restart")
    ov.start(InputProfile.DeviceKind.KEYBOARD, "Dash")
    var esc: InputEventKey = InputEventKey.new()
    esc.keycode = KEY_ESCAPE
    esc.pressed = true
    ov._input(esc)
    await process_frame
    _check(cancelled_counts[0] == 1, "Escape cancels capture")
    _check(not ov.is_listening(), "overlay stops after Escape")

    # Gamepad capture via a JoypadButton event.
    ov.start(InputProfile.DeviceKind.JOYSTICK, "Dash")
    _check(ov.is_listening(), "gamepad overlay listening")
    var gcaptured_counts: Array[int] = [0]
    var g_btns: Array[int] = []
    ov.captured.connect(func(ev: InputEvent) -> void:
        gcaptured_counts[0] += 1
        g_btns.append(int((ev as InputEventJoypadButton).button_index)))
    var gb: InputEventJoypadButton = InputEventJoypadButton.new()
    gb.button_index = JOY_BUTTON_X
    gb.pressed = true
    ov._input(gb)
    await process_frame
    _check(gcaptured_counts[0] == 1 and g_btns.size() == 1 and g_btns[0] == int(JOY_BUTTON_X), "gamepad button captured for joypad kind")
    _check(not ov.is_listening(), "gamepad overlay stops after capture")
    ov.queue_free()
    await process_frame

    print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
    quit(1 if _fail_count > 0 else 0)
