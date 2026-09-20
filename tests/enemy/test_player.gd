extends CharacterBody3D

const WALK_SPEED = 2.0
const SPRINT_SPEED = 4.0
const MOUSE_SENSITIVITY = 0.003
const CONTROLLER_SENSITIVITY = 5.0

# Camera bobbing, matching the main player.
const BOB_FREQ = 6.0
const BOB_AMP = 0.08
var t_bob = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -1.5, 1.5)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var speed = WALK_SPEED
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED

	# Use the same movement calculation as the main player.
	var input_dir := Input.get_vector("left", "right", "down", "up")
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

	# Controller camera.
	var look_x := Input.get_axis("look_left", "look_right")
	var look_y := Input.get_axis("look_up", "look_down")
	head.rotate_y(-look_x * CONTROLLER_SENSITIVITY * delta)
	camera.rotate_x(-look_y * CONTROLLER_SENSITIVITY * delta)
	camera.rotation.x = clampf(camera.rotation.x, -1.5, 1.5)

	# Apply head bob before moving, just like the main player.
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	move_and_slide()


func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
