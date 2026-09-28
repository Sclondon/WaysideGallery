class_name Player
extends CharacterBody3D
## First-person visitor: walk with keys / stick / touch joystick, look with mouse / stick / drag.

const WALK_SPEED := 2.4
const RUN_SPEED := 4.4
const ACCEL := 9.0
const EYE_HEIGHT := 1.62
const MOUSE_LOOK := 0.0022   ## radians per screen pixel
const KEY_TURN := 1.9        ## radians per second
const STICK_LOOK := 2.6
const GRAVITY := 9.8

var active := false
var touch_move := Vector2.ZERO  ## set by the on-screen joystick, -1..1 each way
var camera: Camera3D
var yaw := 0.0
var pitch := 0.0

var _bob := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)

	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = 70.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true


func look(delta: Vector2) -> void:
	yaw = wrapf(yaw - delta.x, -PI, PI)
	pitch = clampf(pitch - delta.y, -1.35, 1.35)
	rotation.y = yaw
	camera.rotation.x = pitch


## Stand at `feet` looking along `forward` (level).
func place(feet: Vector3, forward: Vector3) -> void:
	global_position = feet
	velocity = Vector3.ZERO
	yaw = atan2(-forward.x, -forward.z)
	pitch = 0.0
	look(Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.screen_relative * MOUSE_LOOK)


func _physics_process(delta: float) -> void:
	var move := Vector2.ZERO
	if active:
		move = (Input.get_vector("move_left", "move_right", "move_forward", "move_back") + touch_move).limit_length(1.0)
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		var turn := Input.get_axis("turn_left", "turn_right")
		look((stick * STICK_LOOK + Vector2(turn * KEY_TURN, 0.0)) * delta)

	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	var target := global_basis * Vector3(move.x, 0.0, move.y) * speed
	var blend := 1.0 - exp(-ACCEL * delta)
	velocity.x = lerpf(velocity.x, target.x, blend)
	velocity.z = lerpf(velocity.z, target.z, blend)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	# gentle head bob while walking
	var pace := Vector2(velocity.x, velocity.z).length()
	_bob += delta * pace * 3.2
	var sway := clampf(pace / WALK_SPEED, 0.0, 1.0)
	camera.position.y = lerpf(camera.position.y, EYE_HEIGHT + sin(_bob) * 0.018 * sway, 0.3)
