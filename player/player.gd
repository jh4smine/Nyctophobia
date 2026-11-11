
extends CharacterBody3D

var speed: float

const WALK_SPEED = 2.0
const SPRINT_SPEED = 3.8
const CONTROLLER_SENSITIVITY = 5.0
const SENSITIVITY = 0.003


# Camera rotation
var mouse_pitch: float = 0.0

# Camera bobbing
const BOB_FREQ = 6.00
const BOB_AMP = 0.08
var t_bob = 0.0


@onready var head = $Head
@onready var camera = $Head/Camera
@onready var STAIR_RAY = $Leg/stair_ray
@onready var STAIR_MAX = $Leg/stair_max


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):

	# Mouse camera
	if event is InputEventMouseMotion:

		rotate_y(-event.relative.x * SENSITIVITY)

		mouse_pitch -= event.relative.y * SENSITIVITY

		mouse_pitch = clamp(
			mouse_pitch,
			deg_to_rad(-85),
			deg_to_rad(85)
		)

		head.rotation.x = mouse_pitch


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
	var input_dir := Input.get_vector("left", "right", "down", "up")

	# Stairs climbing
	if is_on_floor() and STAIR_RAY.is_colliding() and input_dir != Vector2.ZERO and !STAIR_MAX.is_colliding():
		velocity.y += 2

	# Movement direction
	var direction := Vector3.ZERO

	direction = -head.global_transform.basis.z * input_dir.y
	direction += head.global_transform.basis.x * input_dir.x

	direction.y = 0
	direction = direction.normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

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

	# Head bob
	t_bob += delta * Vector2(velocity.x, velocity.z).length() * float(is_on_floor())

	camera.position = _headbob(t_bob)

	# Movement physics
	move_and_slide()


func _headbob(time) -> Vector3:

	var pos = Vector3.ZERO

	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP

	return pos
