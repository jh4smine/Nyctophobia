
extends CharacterBody3D

var speed: float

const WALK_SPEED = 2.0
const SPRINT_SPEED = 3.8
const CONTROLLER_SENSITIVITY = 5.0
const SENSITIVITY = 0.003

# Camera rotation
var mouse_pitch: float = 0.0

# Look behind
var is_looking_behind: bool = false
const LOOK_BEHIND_SPEED = 15.0
var target_look_angle: float = 0.0
var current_look_angle: float = 0.0

# Camera bobbing
const BOB_FREQ = 6.00
const BOB_AMP = 0.08
var t_bob = 0.0
var camera_start_position: Vector3

@onready var head = $Head
@onready var camera = $Head/Camera
@onready var STAIR_RAY = $Leg/stair_ray
@onready var STAIR_MAX = $Leg/stair_max


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_start_position = camera.position


func _unhandled_input(event: InputEvent) -> void:

	# Mouse camera - disabled while looking behind
	if event is InputEventMouseMotion and not is_looking_behind:

		rotate_y(-event.relative.x * SENSITIVITY)

		mouse_pitch -= event.relative.y * SENSITIVITY

		mouse_pitch = clamp(
			mouse_pitch,
			deg_to_rad(-85),
			deg_to_rad(85)
		)

		head.rotation.x = mouse_pitch

	# Release mouse
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Movement input
	var input_dir := Input.get_vector("left", "right", "up", "down")

	# Stairs climbing
	if (
		is_on_floor()
		and STAIR_RAY.is_colliding()
		and input_dir != Vector2.ZERO
		and not STAIR_MAX.is_colliding()
	):
		velocity.y = 2.0

	# Movement direction
	var direction := Vector3.ZERO

	direction = global_transform.basis.z * input_dir.y
	direction += global_transform.basis.x * input_dir.x

	direction.y = 0.0
	direction = direction.normalized()

	# Apply movement
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

		velocity.z = move_toward(
			velocity.z,
			0.0,
			WALK_SPEED * delta * 5.0
		)

	# Controller camera
	var look_x := Input.get_axis("look_left", "look_right")
	var look_y := Input.get_axis("look_up", "look_down")

	rotate_y(-look_x * CONTROLLER_SENSITIVITY * delta)

	mouse_pitch -= look_y * CONTROLLER_SENSITIVITY * delta

	mouse_pitch = clamp(
		mouse_pitch,
		deg_to_rad(-85),
		deg_to_rad(85)
	)

	head.rotation.x = mouse_pitch

	# Look behind input
	is_looking_behind = Input.is_action_pressed("look_behind")

	if is_looking_behind:
		target_look_angle = PI
	else:
		target_look_angle = 0.0

	# Smooth look behind - left rotation
	current_look_angle = move_toward(
		current_look_angle,
		target_look_angle,
		LOOK_BEHIND_SPEED * delta
	)

	head.rotation.y = current_look_angle

	# Keep mouse captured and hidden
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Head bob
	t_bob += (
		delta
		* Vector2(velocity.x, velocity.z).length()
		* float(is_on_floor())
	)

	camera.position = camera_start_position + _headbob(t_bob)

	# Movement physics
	move_and_slide()


func _headbob(time: float) -> Vector3:

	var pos := Vector3.ZERO

	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP

	return pos
