extends Node3D

const TEST_PLAYER_SPEED: float = 3.0

@onready var enemy: CharacterBody3D = get_node_or_null("Enemy") as CharacterBody3D
@onready var perception: Node = get_node_or_null("Enemy/Perception")
@onready var chase_brain: Node = get_node_or_null("Enemy/ChaseBrain")
@onready var test_player: CharacterBody3D = get_node_or_null("TestPlayer") as CharacterBody3D

var _player_start_transform: Transform3D


func _ready() -> void:
	if not _validate_scene_setup():
		return

	_player_start_transform = test_player.global_transform
	perception.connect(&"target_detected", Callable(self, "_on_target_detected"))
	perception.connect(&"target_lost", Callable(self, "_on_target_lost"))

	print("Enemy AI test ready. Enemy patrols until it sees the brown player.")
	print("WASD: move the brown player | R: move player behind obstacle")
	print("V: place player in front of enemy | F: place player beside enemy | O: hide player behind obstacle")


func _physics_process(delta: float) -> void:
	if test_player == null:
		return

	var input_direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	var move_direction := Vector3(input_direction.x, 0.0, input_direction.y)
	test_player.velocity.x = move_direction.x * TEST_PLAYER_SPEED
	test_player.velocity.z = move_direction.z * TEST_PLAYER_SPEED
	if not test_player.is_on_floor():
		test_player.velocity += test_player.get_gravity() * delta
	test_player.move_and_slide()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_R:
			_hide_player_behind_obstacle()
		KEY_V:
			_place_player_relative_to_enemy(-enemy.global_transform.basis.z, "in front")
		KEY_F:
			_place_player_relative_to_enemy(enemy.global_transform.basis.x, "beside the enemy")
		KEY_O:
			_hide_player_behind_obstacle()


func _validate_scene_setup() -> bool:
	if enemy == null or perception == null or chase_brain == null or test_player == null:
		push_error("Enemy test scene is missing its Enemy, Perception, ChaseBrain, or TestPlayer node.")
		return false

	if not perception.has_signal(&"target_detected") or not perception.has_signal(&"target_lost"):
		push_error("Enemy Perception must expose target_detected and target_lost signals.")
		return false

	if not test_player.is_in_group(&"player"):
		push_error("TestPlayer must be in the 'player' group so the enemy can detect it.")
		return false

	return true


func _on_target_detected(target: Node3D) -> void:
	print("Test: enemy sees %s." % target.name)


func _on_target_lost(target: Node3D) -> void:
	print("Test: enemy lost sight of %s." % target.name)


func _place_player_relative_to_enemy(direction: Vector3, placement: String) -> void:
	direction.y = 0.0
	direction = direction.normalized()
	test_player.global_position = enemy.global_position + direction * 4.0
	test_player.velocity = Vector3.ZERO
	print("Placed TestPlayer %s." % placement)


func _hide_player_behind_obstacle() -> void:
	var enemy_horizontal_position := Vector2(enemy.global_position.x, enemy.global_position.z)
	var hidden_position: Vector2 = Vector2(3.5, 0.0)
	if enemy_horizontal_position.length_squared() > 0.01:
		hidden_position = -enemy_horizontal_position.normalized() * 3.5
	test_player.global_position = Vector3(hidden_position.x, _player_start_transform.origin.y, hidden_position.y)
	test_player.velocity = Vector3.ZERO
	print("Placed TestPlayer behind the obstacle. The enemy should investigate if it had seen you.")
