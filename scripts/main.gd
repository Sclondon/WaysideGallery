extends Node3D
## Wayside Gallery: walk through the rooms, aim at a picture and press E (or click / tap)
## to step up to it and read its wall text. Browse from there with the arrow keys.

enum State { INTRO, WALK, VIEW, MOVING }

const AIM_RANGE := 6.0
const VIEW_FOV := 40.0
const STAND_BACK := 2.4        ## where you're left standing after viewing a piece
const TOUCH_TAP_TIME := 0.3
const TOUCH_TAP_SLOP := 14.0
const TOUCH_LOOK := 0.005
const SWIPE := 70.0

var state := State.INTRO
var pieces: Array[ArtPiece] = []
var gallery := Gallery.new()
var player := Player.new()
var hud := Hud.new()
var view_cam := Camera3D.new()
var viewing := -1
var aimed := -1
var touch_mode := false

var _touches := {}  ## finger index -> {start, pos, time, kind}
var _tween: Tween


func _ready() -> void:
	_setup_input()
	_setup_environment()
	pieces = ArtCatalog.load_pieces()
	add_child(gallery)
	gallery.build(pieces)
	add_child(player)
	player.place(gallery.spawn_position, Vector3.FORWARD)
	view_cam.near = 0.05
	add_child(view_cam)
	add_child(hud)
	hud.prev_pressed.connect(func() -> void: browse(-1))
	hud.next_pressed.connect(func() -> void: browse(1))
	hud.back_pressed.connect(leave_view)
	get_window().size_changed.connect(_fit_window)
	_fit_window()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			_autotest(arg.trim_prefix("--autotest="))


func _physics_process(_delta: float) -> void:
	if state != State.WALK:
		return
	var centre := get_viewport().get_visible_rect().size * 0.5
	var hit := -1 if touch_mode else _pick(centre)
	if hit != aimed:
		aimed = hit
		hud.show_prompt(pieces[aimed] if aimed >= 0 else null)
	hud.show_mouse_hint(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch(event)
		return
	var emulated: bool = event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not emulated

	match state:
		State.INTRO:
			if click or (event is InputEventKey and event.pressed and not event.echo):
				_enter_gallery()
		State.WALK:
			if click:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				elif aimed >= 0:
					view(aimed)
			elif event.is_action_pressed("view") and aimed >= 0:
				view(aimed)
			elif event.is_action_pressed("back"):
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		State.VIEW:
			if event.is_action_pressed("back") or event.is_action_pressed("view"):
				leave_view()
			elif event.is_action_pressed("prev"):
				browse(-1)
			elif event.is_action_pressed("next"):
				browse(1)


# --- viewing a piece ------------------------------------------------------------

func view(index: int) -> void:
	state = State.MOVING
	player.active = false
	player.touch_move = Vector2.ZERO
	hud.set_stick(false)
	hud.show_mouse_hint(false)
	_touches.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view_cam.global_transform = player.camera.global_transform
	view_cam.fov = player.camera.fov
	view_cam.current = true
	_go_to(index)


func browse(step: int) -> void:
	if state != State.VIEW or pieces.is_empty():
		return
	state = State.MOVING
	_go_to(posmod(viewing + step, pieces.size()))


func leave_view() -> void:
	if state != State.VIEW:
		return
	state = State.MOVING
	hud.hide_card()
	var p := pieces[viewing]
	var feet := p.center + p.normal * minf(STAND_BACK, p.clearance - 0.6)
	feet.y = 0.0
	player.place(feet, -p.normal)
	_move_camera(player.camera.global_transform, player.camera.fov, 0.7)
	_tween.tween_callback(_back_to_walking)


func _back_to_walking() -> void:
	player.camera.current = true
	player.active = true
	state = State.WALK
	aimed = -1
	if not touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _go_to(index: int) -> void:
	var p := pieces[index]
	hud.show_card(p, pieces.size())
	var shot := _framing(p)
	# fly there if the way is clear, otherwise cut through a quick fade
	var path := PhysicsRayQueryParameters3D.create(view_cam.global_position, shot[0].origin, 1)
	var blocked := not get_world_3d().direct_space_state.intersect_ray(path).is_empty()
	viewing = index
	_kill_tween()
	if blocked:
		_tween = hud.fade_through(_set_view_cam.bind(shot[0], shot[1]))
	else:
		_move_camera(shot[0], shot[1], 0.9)
	_tween.tween_callback(func() -> void: state = State.VIEW)


func _set_view_cam(xform: Transform3D, fov: float) -> void:
	view_cam.global_transform = xform
	view_cam.fov = fov


## Camera transform and fov that frame the picture in the space the wall-text card leaves free.
func _framing(p: ArtPiece) -> Array:
	var vp := get_viewport().get_visible_rect().size
	var free := hud.free_space()
	var aspect := vp.x / vp.y
	var want := p.outer_size + Vector2(0.3, 0.3)
	var half := maxf(want.y / (2.0 * free.y * 0.92), want.x / (2.0 * free.x * 0.92 * aspect))
	var fov := VIEW_FOV
	var dist := half / tan(deg_to_rad(fov) * 0.5)
	if dist > p.clearance - 0.5:
		dist = p.clearance - 0.5
		fov = rad_to_deg(2.0 * atan(half / dist))
	var right := (-p.normal).cross(Vector3.UP)
	var pos := p.center + p.normal * dist + right * (1.0 - free.x) * half * aspect - Vector3.UP * (1.0 - free.y) * half
	return [Transform3D(Basis.looking_at(-p.normal), pos), fov]


func _move_camera(to: Transform3D, fov: float, time: float) -> void:
	_kill_tween()
	var from := view_cam.global_transform
	var from_fov := view_cam.fov
	var step := func(t: float) -> void:
		_set_view_cam(from.interpolate_with(to, t), lerpf(from_fov, fov, t))
	_tween = create_tween()
	_tween.tween_method(step, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _pick(screen_pos: Vector2) -> int:
	var cam := get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen_pos) * AIM_RANGE,
		1 | Gallery.ART_LAYER, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_meta("piece"):
		return hit.collider.get_meta("piece")
	return -1


# --- touch ------------------------------------------------------------------------

func _touch(event: InputEvent) -> void:
	if not touch_mode:
		touch_mode = true
		hud.set_touch(true)
		hud.show_prompt(null)
	var now := Time.get_ticks_msec() / 1000.0
	if event is InputEventScreenTouch and event.pressed:
		if state == State.INTRO:
			_enter_gallery()
			return
		var moving := _touches.values().any(func(t: Dictionary) -> bool: return t.kind == "move")
		var kind := "move" if event.position.x < get_viewport().get_visible_rect().size.x * 0.4 and not moving else "look"
		_touches[event.index] = {"start": event.position, "pos": event.position, "time": now, "kind": kind}
		if kind == "move" and state == State.WALK:
			hud.set_stick(true, event.position, event.position)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var t: Dictionary = _touches[event.index]
		t.pos = event.position
		if state == State.WALK:
			if t.kind == "move":
				player.touch_move = (t.pos - t.start).limit_length(Hud.STICK_RADIUS) / Hud.STICK_RADIUS
				hud.set_stick(true, t.start, t.pos)
			else:
				player.look(event.screen_relative * TOUCH_LOOK)
	elif event is InputEventScreenTouch and _touches.has(event.index):
		var t: Dictionary = _touches[event.index]
		_touches.erase(event.index)
		var moved: Vector2 = t.pos - t.start
		if t.kind == "move":
			player.touch_move = Vector2.ZERO
			hud.set_stick(false)
		if state == State.WALK and t.kind == "look" and now - t.time < TOUCH_TAP_TIME and moved.length() < TOUCH_TAP_SLOP:
			var hit := _pick(event.position)
			if hit >= 0:
				view(hit)
		elif state == State.VIEW and absf(moved.x) > SWIPE and absf(moved.x) > absf(moved.y):
			browse(-1 if moved.x > 0.0 else 1)


# --- setup ------------------------------------------------------------------------

func _enter_gallery() -> void:
	state = State.WALK
	player.active = true
	hud.hide_intro()
	if not touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Keep text a readable size in portrait windows (phones) by swapping the base resolution.
func _fit_window() -> void:
	var size := get_window().size
	get_window().content_scale_size = Vector2i(720, 1280) if size.y > size.x else Vector2i(1280, 720)


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
		"run": [KEY_SHIFT], "view": [KEY_E, KEY_ENTER, KEY_SPACE], "back": [KEY_ESCAPE, KEY_BACKSPACE],
		"prev": [KEY_LEFT, KEY_A, KEY_Q], "next": [KEY_RIGHT, KEY_D],
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	var buttons := {
		"view": [JOY_BUTTON_A], "back": [JOY_BUTTON_B], "run": [JOY_BUTTON_LEFT_STICK],
		"prev": [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER], "next": [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action in ["move_forward", "move_back", "move_left", "move_right", "turn_left", "turn_right",
			"look_left", "look_right", "look_up", "look_down", "run", "view", "back", "prev", "next"]:
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
	await wait.call(0.5)
	await shoot.call("00_intro")
	_enter_gallery()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await wait.call(1.0)
	await shoot.call("01_entrance")

	var first := pieces[0]
	player.place(Vector3(first.center.x, 0.0, first.center.z) + first.normal * 3.0, -first.normal)
	await wait.call(0.4)
	print("autotest: aimed at ", aimed)
	await shoot.call("02_aim")

	view(0)
	await wait.call(1.3)
	await shoot.call("03_view")
	for i in 3:
		browse(1)
		await wait.call(1.3)
	await shoot.call("04_view_far_wall")
	browse(-4)
	await wait.call(1.3)
	await shoot.call("05_view_feature")
	leave_view()
	await wait.call(1.0)
	player.place(Vector3(0.0, 0.0, -Gallery.ROOM_D * 1.1), Vector3.FORWARD)
	await wait.call(0.5)
	await shoot.call("06_room2")
	print("autotest: done, state ", State.keys()[state])
	get_tree().quit()
