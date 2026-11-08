extends Node3D

const REQUIRED_ENEMY_METHODS: Array[StringName] = [
	&"move_to",
	&"stop_moving",
	&"has_reached_destination",
	&"has_failed_destination",
]

@onready var enemy: Node3D = get_node_or_null("Enemy") as Node3D
@onready var target: Marker3D = get_node_or_null("Target") as Marker3D
@onready var unreachable_target: Marker3D = get_node_or_null("UnreachableTarget") as Marker3D
@onready var navigation_region: NavigationRegion3D = get_node_or_null("NavigationRegion3D") as NavigationRegion3D
@onready var perception: Node = get_node_or_null("Enemy/Perception")
@onready var test_player: CharacterBody3D = get_node_or_null("TestPlayer") as CharacterBody3D

var _navigation_ready: bool = false
var _watching_destination: bool = false
var _watched_destination_name: String = ""
var _status_report_timer: float = 0.0


func _ready() -> void:
	if not _validate_scene_setup():
		return

	# Keep the isolated movement test manual; the shared enemy scene also has a patrol brain.
	var patrol_brain: Node = enemy.get_node_or_null("ChaseBrain")
	if patrol_brain != null:
		patrol_brain.set("patrol_enabled", false)

	perception.connect(&"target_detected", Callable(self, "_on_target_detected"))
	perception.connect(&"target_lost", Callable(self, "_on_target_lost"))

	var navigation_mesh: NavigationMesh = navigation_region.navigation_mesh
	if navigation_mesh == null:
		push_error("Enemy test arena needs a NavigationMesh resource on NavigationRegion3D.")
		return

	if navigation_mesh.get_polygon_count() == 0:
		push_error("Bake the NavigationMesh in the editor and save enemy_test.tscn before running this test.")
		return

	await get_tree().physics_frame
	var navigation_map: RID = navigation_region.get_navigation_map()
	while navigation_map.is_valid() and NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		await get_tree().physics_frame

	if not navigation_map.is_valid():
		push_error("Enemy test arena does not have a valid navigation map.")
		return

	_navigation_ready = true
	print("Enemy test arena ready. Navigation map synchronized.")
	print("Enemy starts moving toward Target automatically.")
	print("SPACE: move again | S: stop | U: unreachable target")
	print("V: place test player in view | F: outside FOV | O: behind obstacle")
	_move_enemy_to(target, "Target")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var pressed_key: Key = key_event.physical_keycode
	if pressed_key == KEY_NONE:
		pressed_key = key_event.keycode

	match pressed_key:
		KEY_SPACE:
			_move_enemy_to(target, "Target")
		KEY_S:
			_stop_enemy()
		KEY_U:
			_move_enemy_to(unreachable_target, "UnreachableTarget")
		KEY_V:
			_place_test_player_in_view()
		KEY_F:
			_place_test_player_outside_fov()
		KEY_O:
			_place_test_player_behind_obstacle()


func _process(_delta: float) -> void:
	if not _watching_destination:
		return

	_status_report_timer += _delta
	if _status_report_timer >= 1.0:
		_status_report_timer = 0.0
		var agent := enemy.get_node("NavigationAgent3D") as NavigationAgent3D
		print(
			"Enemy position: %s | velocity: %s | next waypoint: %s | path points: %d"
			% [enemy.global_position, (enemy as CharacterBody3D).velocity, agent.get_next_path_position(), agent.get_current_navigation_path().size()]
		)

	if bool(enemy.call(&"has_reached_destination")):
		print("Enemy reached %s." % _watched_destination_name)
		_watching_destination = false
	elif bool(enemy.call(&"has_failed_destination")):
		push_warning("Enemy failed to reach %s. Check the navigation path." % _watched_destination_name)
		_watching_destination = false


func _validate_scene_setup() -> bool:
	if enemy == null or target == null or unreachable_target == null or navigation_region == null or perception == null or test_player == null:
		push_error("Enemy test arena is missing a required enemy, target, region, or test-player node.")
		return false

	for method_name: StringName in REQUIRED_ENEMY_METHODS:
		if not enemy.has_method(method_name):
			push_error("Enemy is missing the required public method: %s" % method_name)
			return false

	if not perception.has_signal(&"target_detected") or not perception.has_signal(&"target_lost"):
		push_error("Enemy Perception must expose target_detected and target_lost signals.")
		return false

	return true


func _on_target_detected(detected_target: Node3D) -> void:
	print("Perception detected: %s" % detected_target.name)


func _on_target_lost(lost_target: Node3D) -> void:
	print("Perception lost: %s" % lost_target.name)


func _place_test_player_in_view() -> void:
	enemy.rotation.y = 0.0
	test_player.global_position = Vector3(enemy.global_position.x, 0.0, enemy.global_position.z - 4.0)
	print("Placed TestPlayer in front of the enemy.")


func _place_test_player_outside_fov() -> void:
	enemy.rotation.y = 0.0
	test_player.global_position = Vector3(enemy.global_position.x + 4.0, 0.0, enemy.global_position.z)
	print("Placed TestPlayer to the side, outside the enemy's FOV.")


func _place_test_player_behind_obstacle() -> void:
	enemy.rotation.y = -PI * 0.5
	test_player.global_position = Vector3(3.5, 0.0, 0.0)
	print("Placed TestPlayer behind the obstacle; run this test before moving the enemy.")


func _move_enemy_to(destination: Marker3D, destination_name: String) -> void:
	if not _navigation_ready:
		push_warning("Navigation is not ready. Check the NavigationMesh bake and Output panel.")
		return

	enemy.call(&"move_to", destination.global_position)
	_watched_destination_name = destination_name
	_watching_destination = true
	_status_report_timer = 0.0
	print("Moving enemy toward %s at %s." % [destination_name, destination.global_position])
	if destination == unreachable_target:
		print("Watch for the enemy movement script's unreachable-target warning in Output.")


func _stop_enemy() -> void:
	if not _navigation_ready:
		push_warning("Navigation is not ready. Check the NavigationMesh bake and Output panel.")
		return

	enemy.call(&"stop_moving")
	_watching_destination = false
	print("Enemy movement stopped.")
