extends CharacterBody3D

var speed: float

const WALK_SPEED = 2.6
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
<<<<<<< HEAD
var camera_start_position: Vector3
=======

# Track head bob cycle to trigger footsteps accurately
var prev_bob_y: float = 0.0
var step_triggered: bool = false

# Sprinting timer for panting sound (Changed threshold from 5.0 to 3.0)
const SPRINT_PANT_THRESHOLD = 3.0
var sprint_timer: float = 0.0
>>>>>>> ab3fe449d8605719dc0f5ea369fb10e6030845bd

@onready var head = $Head
@onready var camera = $Head/Camera
@onready var STAIR_RAY = $Leg/stair_ray
@onready var STAIR_MAX = $Leg/stair_max
@onready var footstep_sound = $FootstepSound
@onready var breathing_sound = $BreathingSound


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_start_position = camera.position


<<<<<<< HEAD
func _unhandled_input(event: InputEvent) -> void:

	# Mouse camera - disabled while looking behind
	if event is InputEventMouseMotion and not is_looking_behind:

=======
func _unhandled_input(event):
	# Mouse camera
	if event is InputEventMouseMotion:
>>>>>>> ab3fe449d8605719dc0f5ea369fb10e6030845bd
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

	# Movement input
<<<<<<< HEAD
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
=======
	var input_dir := Input.get_vector("left", "right", "down", "up")
	var is_moving = input_dir != Vector2.ZERO
	var is_sprinting = Input.is_action_pressed("sprint") and is_moving and is_on_floor()

	# Sprint handling & panting timer
	if is_sprinting:
		speed = SPRINT_SPEED
		sprint_timer += delta

		if sprint_timer >= SPRINT_PANT_THRESHOLD:
			if breathing_sound and not breathing_sound.playing:
				breathing_sound.play()
	else:
		speed = WALK_SPEED
		sprint_timer = 0.0
		if breathing_sound and breathing_sound.playing:
			breathing_sound.stop()

	# Stairs climbing
	if is_on_floor() and STAIR_RAY.is_colliding() and is_moving and !STAIR_MAX.is_colliding():
		velocity.y += 2

	# Movement direction
	var direction := Vector3.ZERO
	direction = -head.global_transform.basis.z * input_dir.y
	direction += head.global_transform.basis.x * input_dir.x
>>>>>>> ab3fe449d8605719dc0f5ea369fb10e6030845bd

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

<<<<<<< HEAD
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
=======
	# Head bob & Footsteps (plays when moving on floor)
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	if is_moving and is_on_floor() and horizontal_velocity > 0.1:
		t_bob += delta * speed * BOB_FREQ
		camera.position = _headbob(t_bob)
		_handle_footsteps(is_sprinting)
	else:
		t_bob = 0.0
		camera.position = camera.position.move_toward(Vector3.ZERO, delta * 2.0)
>>>>>>> ab3fe449d8605719dc0f5ea369fb10e6030845bd

	# Movement physics
	move_and_slide()


<<<<<<< HEAD
func _headbob(time: float) -> Vector3:

	var pos := Vector3.ZERO

	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP

=======
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time) * BOB_AMP
	pos.x = cos(time / 2.0) * BOB_AMP
>>>>>>> ab3fe449d8605719dc0f5ea369fb10e6030845bd
	return pos


func _handle_footsteps(is_sprinting: bool) -> void:
	# Triggers when camera dips (foot hitting floor)
	var current_bob_y = camera.position.y

	if current_bob_y < prev_bob_y and not step_triggered:
		if current_bob_y < -BOB_AMP * 0.4:
			_play_footstep_sound(is_sprinting)
			step_triggered = true
	elif current_bob_y > prev_bob_y:
		step_triggered = false

	prev_bob_y = current_bob_y


func _play_footstep_sound(is_sprinting: bool) -> void:
	if footstep_sound and footstep_sound.stream:
		# Slightly higher pitch when sprinting for dynamic feel
		var base_pitch = 1.15 if is_sprinting else 0.95
		footstep_sound.pitch_scale = randf_range(base_pitch - 0.05, base_pitch + 0.05)
		footstep_sound.play()
