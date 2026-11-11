extends CharacterBody3D

var speed: float

const WALK_SPEED = 2.6
const SPRINT_SPEED = 3.8
const CONTROLLER_SENSITIVITY = 5.0
const SENSITIVITY = 0.003

# Camera rotation
var mouse_pitch: float = 0.0

# Camera bobbing
const BOB_FREQ = 6.00
const BOB_AMP = 0.08
var t_bob = 0.0

# Track head bob cycle to trigger footsteps accurately
var prev_bob_y: float = 0.0
var step_triggered: bool = false

# Sprinting timer for panting sound (Changed threshold from 5.0 to 3.0)
const SPRINT_PANT_THRESHOLD = 3.0
var sprint_timer: float = 0.0

@onready var head = $Head
@onready var camera = $Head/Camera
@onready var STAIR_RAY = $Leg/stair_ray
@onready var STAIR_MAX = $Leg/stair_max
@onready var footstep_sound = $FootstepSound
@onready var breathing_sound = $BreathingSound


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

	# Movement input
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

	# Head bob & Footsteps (plays when moving on floor)
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	if is_moving and is_on_floor() and horizontal_velocity > 0.1:
		t_bob += delta * speed * BOB_FREQ
		camera.position = _headbob(t_bob)
		_handle_footsteps(is_sprinting)
	else:
		t_bob = 0.0
		camera.position = camera.position.move_toward(Vector3.ZERO, delta * 2.0)

	# Movement physics
	move_and_slide()


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time) * BOB_AMP
	pos.x = cos(time / 2.0) * BOB_AMP
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
