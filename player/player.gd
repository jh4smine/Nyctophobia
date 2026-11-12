
extends CharacterBody3D

var speed: float = 0.0

const WALK_SPEED: float = 2.6
const SPRINT_SPEED: float = 3.8
const CONTROLLER_SENSITIVITY: float = 5.0
const SENSITIVITY: float = 0.003
const LOOK_BEHIND_SMOOTHING: float = 7.0
const BOB_FREQ: float = 6.0
const BOB_AMP: float = 0.08
const SPRINT_PANT_THRESHOLD: float = 3.0
const WALK_NOISE_STRENGTH: float = 0.75
const SPRINT_NOISE_STRENGTH: float = 1.55
const WALK_NOISE_STEP_INTERVAL: float = 0.55
const SPRINT_NOISE_STEP_INTERVAL: float = 0.36

# Sprint panting settings
const PANT_SPEED_REDUCTION: float = 0.8
const STAMINA_RECOVERY_TIME: float = 3.0

# Peek settings
const PEEK_ANGLE: float = 20.0
const PEEK_OFFSET: float = 0.45
const PEEK_SMOOTHING: float = 16.0

var mouse_pitch: float = 0.0
var is_looking_behind: bool = false
var target_look_angle: float = 0.0
var current_look_angle: float = 0.0
var current_peek_angle: float = 0.0
var target_peek_angle: float = 0.0
var current_peek_offset: float = 0.0
var t_bob: float = 0.0
var camera_start_position: Vector3
var prev_bob_y: float = 0.0
var step_triggered: bool = false
var sprint_timer: float = 0.0
var _noise_footstep_timer: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var stair_ray: RayCast3D = get_node_or_null("Leg/stair_ray") as RayCast3D
@onready var stair_max: RayCast3D = get_node_or_null("Leg/stair_max") as RayCast3D
@onready var footstep_sound: AudioStreamPlayer3D = get_node_or_null("FootstepSound") as AudioStreamPlayer3D
@onready var breathing_sound: AudioStreamPlayer3D = get_node_or_null("BreathingSound") as AudioStreamPlayer3D


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_start_position = camera.position
	prev_bob_y = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_looking_behind and Input.get_axis("peek_left", "peek_right") == 0.0:
		rotate_y(-event.relative.x * SENSITIVITY)
		mouse_pitch = clampf(mouse_pitch - event.relative.y * SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = mouse_pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir: Vector2 = Input.get_vector("left", "right", "down", "up")
	var is_moving: bool = input_dir.length_squared() > 0.0
	var is_peeking: bool = Input.is_action_pressed("peek_left") or Input.is_action_pressed("peek_right")
	var is_sprinting: bool = Input.is_action_pressed("sprint") and is_moving and is_on_floor()

	# Sprint panting and stamina recovery
	if is_sprinting:
		sprint_timer += delta

		if sprint_timer >= SPRINT_PANT_THRESHOLD:
			# Start panting after 3 seconds
			if breathing_sound != null and not breathing_sound.playing:
				breathing_sound.play()

			# Slightly reduce sprint speed
			speed = SPRINT_SPEED - PANT_SPEED_REDUCTION
		else:
			speed = SPRINT_SPEED

	else:
		# Recover stamina while walking OR standing still
		sprint_timer = move_toward(
			sprint_timer,
			0.0,
			(SPRINT_PANT_THRESHOLD / STAMINA_RECOVERY_TIME) * delta
		)

		speed = WALK_SPEED

		# Stop panting when not sprinting
		if breathing_sound != null and breathing_sound.playing:
			breathing_sound.stop()

		if breathing_sound != null and breathing_sound.playing:
			breathing_sound.stop()

	var has_stair_sensors: bool = stair_ray != null and stair_max != null
	var is_stair_step_edge: bool = has_stair_sensors and input_dir.y > 0.1 and stair_ray.is_colliding() and not stair_max.is_colliding()
	if is_stair_step_edge and not is_peeking:
		# Keep a small upward assist active while the lower ray sees a riser that
		# the upper ray clears. This lets the body climb consecutive steps instead
		# of getting only one lift at the first riser.
		velocity.y = maxf(velocity.y, 2.0)

	var direction: Vector3 = -global_transform.basis.z * input_dir.y
	direction += global_transform.basis.x * input_dir.x
	direction.y = 0.0
	direction = direction.normalized()

	# Stop player movement while peeking
	if is_peeking:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 10.0)
	else:
		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 5.0)

	var look_x: float = Input.get_axis("look_left", "look_right")
	var look_y: float = Input.get_axis("look_up", "look_down")
	if not is_peeking:
		rotate_y(-look_x * CONTROLLER_SENSITIVITY * delta)
		mouse_pitch = clampf(mouse_pitch - look_y * CONTROLLER_SENSITIVITY * delta, deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = mouse_pitch

	is_looking_behind = Input.is_action_pressed("look_behind")
	target_look_angle = -PI if is_looking_behind else 0.0
	var look_blend: float = 1.0 - exp(-LOOK_BEHIND_SMOOTHING * delta)
	current_look_angle = lerp_angle(current_look_angle, target_look_angle, look_blend)
	head.rotation.y = current_look_angle

	# Peek left and right
	# Q = Peek left
	# E = Peek right
	# Peek only works when standing still and not looking behind
	# Player movement and mouse movement are locked while peeking

	var peek_input: float = 0.0

	if not is_moving and not is_sprinting and not is_looking_behind:
		peek_input = Input.get_axis("peek_left", "peek_right")

	target_peek_angle = deg_to_rad(PEEK_ANGLE) * peek_input

	var peek_blend: float = 1.0 - exp(-PEEK_SMOOTHING * delta)

	current_peek_angle = lerp(
		current_peek_angle,
		target_peek_angle,
		peek_blend
	)

	current_peek_offset = lerp(
		current_peek_offset,
		PEEK_OFFSET * peek_input,
		peek_blend
	)

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()

	if horizontal_speed > 0.1:
		t_bob += delta * horizontal_speed
		var on_stairs: bool = is_stair_step_edge or (has_stair_sensors and (stair_ray.is_colliding() or stair_max.is_colliding()))
		var camera_target: Vector3 = camera_start_position + _headbob(t_bob, on_stairs)
		camera_target.x += current_peek_offset
		var camera_follow_speed: float = 25.0 if on_stairs else 12.0
		camera.position = camera.position.lerp(camera_target, minf(delta * camera_follow_speed, 1.0))
		if is_on_floor():
			_handle_footsteps(is_sprinting)
	else:
		t_bob = 0.0
		var idle_camera_target: Vector3 = camera_start_position
		idle_camera_target.x += current_peek_offset
		camera.position = camera.position.lerp(idle_camera_target, minf(delta * 12.0, 1.0))
		step_triggered = false
		prev_bob_y = 0.0

	camera.rotation.z = lerp_angle(camera.rotation.z, -current_peek_angle, peek_blend)

	move_and_slide()
	_update_footstep_noise(delta, is_sprinting)


func _headbob(time: float, on_stairs: bool = false) -> Vector3:
	if on_stairs:
		# Stairs use a visible vertical step rhythm with no sideways sway.
		return Vector3(0.0, sin(time * BOB_FREQ * 0.85) * BOB_AMP * 0.8, 0.0)
	return Vector3(cos(time * BOB_FREQ / 2.0) * BOB_AMP, sin(time * BOB_FREQ) * BOB_AMP, 0.0)


func _handle_footsteps(is_sprinting: bool) -> void:
	var bob_y: float = camera.position.y - camera_start_position.y
	if bob_y < prev_bob_y and not step_triggered and bob_y < -BOB_AMP * 0.4:
		_play_footstep_sound(is_sprinting)
		step_triggered = true
	elif bob_y > prev_bob_y:
		step_triggered = false
	prev_bob_y = bob_y


func _play_footstep_sound(is_sprinting: bool) -> void:
	if footstep_sound != null and footstep_sound.stream != null:
		var base_pitch: float = 1.15 if is_sprinting else 0.95
		footstep_sound.pitch_scale = randf_range(base_pitch - 0.05, base_pitch + 0.05)
		footstep_sound.play()


func _update_footstep_noise(delta: float, is_sprinting: bool) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horizontal_speed <= 0.1:
		_noise_footstep_timer = 0.0
		return

	_noise_footstep_timer -= delta
	if _noise_footstep_timer > 0.0:
		return

	var noise_strength: float = SPRINT_NOISE_STRENGTH if is_sprinting else WALK_NOISE_STRENGTH
	get_tree().call_group(&"enemy_listeners", &"hear_noise", global_position + Vector3.UP * 0.7, noise_strength, self)
	_noise_footstep_timer = SPRINT_NOISE_STEP_INTERVAL if is_sprinting else WALK_NOISE_STEP_INTERVAL
