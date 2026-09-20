extends CharacterBody3D

# The enemy has exactly two behaviors.
enum State { PATROL, CHASE }

const PATROL_SPEED = 1.0
const CHASE_SPEED = 2.5
const DETECTION_DISTANCE = 6.0
const LOSE_DISTANCE = 6.0
const ARRIVAL_DISTANCE = 0.3
const STOP_DISTANCE = 1.2

@export var player: CharacterBody3D
@export var patrol_points: Array[Marker3D] = []

var state: State = State.PATROL
var patrol_index = 0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Both characters have their origins at their feet.
	var player_distance = global_position.distance_to(player.global_position)
	if state == State.PATROL and player_distance <= DETECTION_DISTANCE:
		state = State.CHASE
		print("Enemy: CHASE")
	elif state == State.CHASE and player_distance > LOSE_DISTANCE:
		state = State.PATROL
		print("Enemy: PATROL")

	var target_position: Vector3
	var speed: float
	var stopping_distance: float

	if state == State.PATROL:
		target_position = patrol_points[patrol_index].global_position
		if global_position.distance_to(target_position) <= ARRIVAL_DISTANCE:
			patrol_index = (patrol_index + 1) % patrol_points.size()
			target_position = patrol_points[patrol_index].global_position
		speed = PATROL_SPEED
		stopping_distance = ARRIVAL_DISTANCE
	else:
		target_position = player.global_position
		speed = CHASE_SPEED
		stopping_distance = STOP_DISTANCE

	# Move across the floor; gravity controls vertical movement.
	var direction = target_position - global_position
	direction.y = 0
	velocity.x = 0
	velocity.z = 0
	if direction.length() > stopping_distance:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

	move_and_slide()
