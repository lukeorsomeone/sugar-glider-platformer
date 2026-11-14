extends RefCounted
## Registers the game's input actions at runtime (keyboard + gamepad),
## so project.godot doesn't need a hand-written input map.
##
## Keyboard: A/D or arrows move, Space/Z/W/Up jump (hold in the air to glide), R restart.
## Gamepad:  left stick / D-pad move, A jump (hold to glide), Y restart.


static func setup() -> void:
	_add("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]], 0.25)
	_add("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]], 0.25)
	_add("jump", [KEY_SPACE, KEY_Z, KEY_W, KEY_UP], [JOY_BUTTON_A])
	_add("restart", [KEY_R], [JOY_BUTTON_Y])


## axes: list of [axis, direction] pairs, e.g. [[JOY_AXIS_LEFT_X, -1.0]].
static func _add(action: String, keys: Array, buttons: Array, axes: Array = [], deadzone: float = 0.25) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, deadzone)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(action, jm)
