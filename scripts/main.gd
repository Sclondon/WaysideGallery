extends Node3D
## Wayside Gallery: walk the rooms and read the labels on the walls. There's deliberately
## no on-screen UI; everything a visitor needs is written somewhere in the building.

const TOUCH_LOOK := 0.005
const STICK_RADIUS := 70.0   ## drag this far from where the thumb landed for full walking speed

var pieces: Array[ArtPiece] = []
var gallery := Gallery.new()
var player := Player.new()

var _touches := {}  ## finger index -> {start, kind}


func _ready() -> void:
	_setup_input()
	_setup_environment()
	pieces = ArtCatalog.load_pieces()
	add_child(gallery)
	gallery.build(pieces)
	add_child(player)
	player.place(gallery.spawn_position, Vector3.FORWARD)
	player.active = true

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			_autotest(arg.trim_prefix("--autotest="))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch(event)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("free_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Left side of the screen is an invisible joystick, anywhere else drags the view.
func _touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var walking := _touches.values().any(func(t: Dictionary) -> bool: return t.kind == "move")
			var left: bool = event.position.x < get_viewport().get_visible_rect().size.x * 0.4
			_touches[event.index] = {"start": event.position, "kind": "move" if left and not walking else "look"}
		elif _touches.has(event.index):
			if _touches[event.index].kind == "move":
				player.touch_move = Vector2.ZERO
			_touches.erase(event.index)
	elif _touches.has(event.index):
		var t: Dictionary = _touches[event.index]
		if t.kind == "move":
			player.touch_move = (event.position - t.start).limit_length(STICK_RADIUS) / STICK_RADIUS
		else:
			player.look(event.screen_relative * TOUCH_LOOK)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.88)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.2
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"turn_left": [KEY_LEFT], "turn_right": [KEY_RIGHT],
		"run": [KEY_SHIFT], "free_mouse": [KEY_ESCAPE],
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	var buttons := {"run": [JOY_BUTTON_LEFT_STICK]}
	for action in ["move_forward", "move_back", "move_left", "move_right", "turn_left", "turn_right",
			"look_left", "look_right", "look_up", "look_down", "run", "free_mouse"]:
		InputMap.add_action(action, 0.2)
		for key: Key in keys.get(action, []):
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
		if axes.has(action):
			var e := InputEventJoypadMotion.new()
			e.axis = axes[action][0]
			e.axis_value = axes[action][1]
			InputMap.action_add_event(action, e)
		for b: JoyButton in buttons.get(action, []):
			var e := InputEventJoypadButton.new()
			e.button_index = b
			InputMap.action_add_event(action, e)


# --- automated smoke test: godot --path . -- --autotest=<folder> ----------------------

func _autotest(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var shoot := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder.path_join(name + ".png"))
		print("autotest: saved ", name)
	var wait := func(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout

	print("autotest: %d pieces" % pieces.size())
	await wait.call(1.0)
	await shoot.call("01_entrance")

	# the welcome sign, up close
	player.place(Vector3(1.2, 0.0, -2.4), Vector3(0.7, 0.0, -1.0).normalized())
	await wait.call(0.4)
	await shoot.call("02_welcome_sign")

	# standing back from the first piece, then reading its label
	var first := pieces[0]
	var right := (-first.normal).cross(Vector3.UP)
	var feet := Vector3(first.center.x, 0.0, first.center.z)
	player.place(feet + first.normal * 2.6 + right * 0.6, -first.normal)
	await wait.call(0.4)
	await shoot.call("03_piece")
	var label_at := feet + right * (first.outer_size.x * 0.5 + Gallery.LABEL_GAP + Gallery.LABEL_W * 0.5)
	player.place(label_at + first.normal * 0.9, -first.normal)
	player.look(Vector2(0.0, 0.12))
	await wait.call(0.4)
	await shoot.call("04_label")

	var last := pieces[-1]
	player.place(Vector3(last.center.x, 0.0, last.center.z) + last.normal * 5.0, -last.normal)
	await wait.call(0.4)
	await shoot.call("05_feature")
	print("autotest: done")
	get_tree().quit()
