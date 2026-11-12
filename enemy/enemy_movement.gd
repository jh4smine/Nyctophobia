extends CharacterBody3D

## Horizontal movement speed while following a navigation path.
@export_range(0.0, 10.0, 0.1) var move_speed: float = 2.0
@export_range(0.1, 1.0, 0.05) var step_up_height: float = 0.35

const TARGET_CHANGE_EPSILON: float = 0.1

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var _has_destination: bool = false
var _destination_reached: bool = false
var _destination_failed: bool = false
var _path_update_frames_remaining: int = 0


func _ready() -> void:
	floor_snap_length = maxf(floor_snap_length, step_up_height + 0.05)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if _has_destination:
		if _path_update_frames_remaining > 0:
			navigation_agent.get_next_path_position()
			_path_update_frames_remaining -= 1
		else:
			_follow_navigation_path()
	else:
		_stop_horizontal_movement()

	var stepped_up: bool = _try_step_up(delta)
	move_and_slide()
	_open_collided_doors()
	if stepped_up:
		apply_floor_snap()


## Starts moving toward a world-space position using the NavigationAgent3D path.
func move_to(target_position: Vector3) -> void:
	if _has_destination and navigation_agent.target_position.distance_to(target_position) < TARGET_CHANGE_EPSILON:
		return

	_has_destination = true
	_destination_reached = false
	_destination_failed = false
	_path_update_frames_remaining = 2
	navigation_agent.target_position = target_position


## Stops horizontal movement while leaving gravity active.
func stop_moving() -> void:
	_has_destination = false
	_destination_reached = false
	_destination_failed = false
	_path_update_frames_remaining = 0
	_stop_horizontal_movement()


## Returns true only after the NavigationAgent3D reports that the target was reached.
func has_reached_destination() -> bool:
	return _destination_reached


## Returns true when the current destination failed instead of being reached.
func has_failed_destination() -> bool:
	return _destination_failed


func _follow_navigation_path() -> void:
	# Ask the agent for its current waypoint before checking completion. This also
	# lets it refresh a newly assigned path before we decide it has no route.
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()

	if navigation_agent.is_navigation_finished():
		_destination_reached = navigation_agent.is_target_reached()
		_destination_failed = not _destination_reached
		_has_destination = false
		_stop_horizontal_movement()
		if not _destination_reached:
			push_warning("Enemy stopped because its navigation target is unreachable.")
		return

	var direction: Vector3 = next_path_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		look_at(global_position + direction, Vector3.UP)
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		_stop_horizontal_movement()


## CharacterBody3D cannot climb stair risers by itself. If the current horizontal
## move hits a low, walkable step, test the same move from just above it and
## place the enemy on the landing surface.
func _try_step_up(delta: float) -> bool:
	if not is_on_floor() or Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		return false

	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	var initial_collision := KinematicCollision3D.new()
	if not test_move(global_transform, horizontal_motion, initial_collision):
		return false
	if initial_collision.get_normal().dot(up_direction) > 0.2:
		return false

	var raised_transform: Transform3D = global_transform.translated(up_direction * step_up_height)
	if test_move(global_transform, up_direction * step_up_height):
		return false
	if test_move(raised_transform, horizontal_motion):
		return false

	var landing_transform: Transform3D = raised_transform.translated(horizontal_motion)
	var landing_collision := KinematicCollision3D.new()
	if not test_move(landing_transform, -up_direction * (step_up_height + floor_snap_length), landing_collision):
		return false
	if landing_collision.get_normal().dot(up_direction) < cos(floor_max_angle):
		return false

	global_position = landing_transform.origin + landing_collision.get_travel()
	velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	return true


func _open_collided_doors() -> void:
	for collision_index: int in range(get_slide_collision_count()):
		var collider: Object = get_slide_collision(collision_index).get_collider()
		if collider != null and collider.has_method(&"open_for_enemy"):
			collider.call_deferred(&"open_for_enemy")


func _stop_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
