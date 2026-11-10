extends Node

## Chooses patrol/chase/investigate/search behavior. EnemyMovement owns motion,
## NavigationAgent3D owns pathfinding, and Perception owns vision.
enum BehaviorState { PATROL, CHASE, INVESTIGATE, SEARCH }
enum SearchPhase { TURN_LEFT, PAUSE_LEFT, TURN_RIGHT, PAUSE_RIGHT }

@export var patrol_enabled: bool = true
@export var chase_enabled: bool = true
@export_range(0.1, 2.0, 0.1) var chase_repath_distance: float = 0.6
@export_range(0.0, 10.0, 0.1) var patrol_wait_time: float = 1.5
@export_range(0.5, 10.0, 0.1) var search_duration: float = 3.0
@export_range(10.0, 180.0, 1.0) var search_scan_angle_degrees: float = 50.0
@export_range(20.0, 360.0, 1.0) var search_turn_speed_degrees: float = 90.0
@export_range(0.1, 3.0, 0.05) var search_pause_duration: float = 0.4

const PATROL_POINTS_PATH: NodePath = ^"../../PatrolPoints"

@onready var _enemy: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _perception: Node = _enemy.get_node_or_null("Perception")

var _patrol_points: Array[Node3D] = []
var _patrol_index: int = 0
var _current_target: Node3D
var _state: BehaviorState = BehaviorState.PATROL
var _last_known_position: Vector3 = Vector3.ZERO
var _has_last_known_position: bool = false
var _last_chase_destination: Vector3 = Vector3.ZERO
var _has_chase_destination: bool = false
var _patrol_destination_active: bool = false
var _investigation_active: bool = false
var _patrol_wait_timer: float = 0.0
var _search_elapsed: float = 0.0
var _search_phase: SearchPhase = SearchPhase.TURN_LEFT
var _search_pause_elapsed: float = 0.0
var _search_scan_progress: float = 0.0
var _navigation_ready: bool = false


func _ready() -> void:
	if _enemy == null:
		push_error("Enemy chase brain must be a child of a CharacterBody3D.")
		set_physics_process(false)
		return

	if _perception == null:
		push_error("Enemy chase brain needs a sibling Perception node on the enemy.")
		set_physics_process(false)
		return

	_perception.connect(&"target_detected", Callable(self, "_on_target_detected"))
	_perception.connect(&"target_lost", Callable(self, "_on_target_lost"))
	_collect_patrol_points()
	_wait_until_navigation_is_ready()


func _physics_process(delta: float) -> void:
	if not _navigation_ready:
		return

	match _state:
		BehaviorState.PATROL:
			_tick_patrol(delta)
		BehaviorState.CHASE:
			_tick_chase()
		BehaviorState.INVESTIGATE:
			_tick_investigate()
		BehaviorState.SEARCH:
			_tick_search(delta)


func get_state_name() -> String:
	return BehaviorState.keys()[_state]


func _tick_patrol(delta: float) -> void:
	if not patrol_enabled or _patrol_points.is_empty():
		return

	if _patrol_wait_timer > 0.0:
		_patrol_wait_timer = maxf(0.0, _patrol_wait_timer - delta)
		if _patrol_wait_timer == 0.0:
			_set_patrol_destination()
		return

	if not _patrol_destination_active:
		_set_patrol_destination()
	elif bool(_enemy.call(&"has_reached_destination")):
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_patrol_destination_active = false
		_patrol_wait_timer = patrol_wait_time
		print("Enemy reached patrol point; pausing before the next point.")
	elif bool(_enemy.call(&"has_failed_destination")):
		push_warning("Enemy could not reach patrol point %d; moving to the next point." % (_patrol_index + 1))
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_patrol_destination_active = false


func _tick_chase() -> void:
	if not is_instance_valid(_current_target):
		_current_target = null
		_begin_investigation()
		return

	# Only use the live position while Perception confirms current line of sight.
	if not bool(_perception.call(&"is_target_visible", _current_target)):
		return

	var target_position: Vector3 = _current_target.global_position
	_last_known_position = target_position
	_has_last_known_position = true
	if not _has_chase_destination or _horizontal_distance(target_position, _last_chase_destination) >= chase_repath_distance:
		_enemy.call(&"move_to", target_position)
		_last_chase_destination = target_position
		_has_chase_destination = true


func _tick_investigate() -> void:
	if not _investigation_active:
		return
	if bool(_enemy.call(&"has_reached_destination")) or bool(_enemy.call(&"has_failed_destination")):
		_begin_search()


func _tick_search(delta: float) -> void:
	_search_elapsed += delta
	if _search_elapsed >= search_duration:
		_enemy.call(&"stop_moving")
		_investigation_active = false
		_has_last_known_position = false
		_state = BehaviorState.PATROL
		print("Enemy search failed; returning to patrol.")
		return

	var scan_angle: float = deg_to_rad(search_scan_angle_degrees)
	var max_turn_step: float = deg_to_rad(search_turn_speed_degrees) * delta
	match _search_phase:
		SearchPhase.TURN_LEFT:
			var left_step: float = minf(max_turn_step, scan_angle - _search_scan_progress)
			_enemy.rotate_y(left_step)
			_search_scan_progress += left_step
			if _search_scan_progress >= scan_angle:
				_search_phase = SearchPhase.PAUSE_LEFT
				_search_pause_elapsed = 0.0
		SearchPhase.PAUSE_LEFT:
			_search_pause_elapsed += delta
			if _search_pause_elapsed >= search_pause_duration:
				_search_phase = SearchPhase.TURN_RIGHT
		SearchPhase.TURN_RIGHT:
			var right_step: float = minf(max_turn_step, _search_scan_progress + scan_angle)
			_enemy.rotate_y(-right_step)
			_search_scan_progress -= right_step
			if _search_scan_progress <= -scan_angle:
				_search_phase = SearchPhase.PAUSE_RIGHT
				_search_pause_elapsed = 0.0
		SearchPhase.PAUSE_RIGHT:
			_search_pause_elapsed += delta
			if _search_pause_elapsed >= search_pause_duration:
				_search_phase = SearchPhase.TURN_LEFT


func _collect_patrol_points() -> void:
	var points_parent: Node = get_node_or_null(PATROL_POINTS_PATH)
	if points_parent == null:
		return

	for child: Node in points_parent.get_children():
		if child is Node3D:
			_patrol_points.append(child as Node3D)


func _wait_until_navigation_is_ready() -> void:
	await get_tree().physics_frame
	var navigation_agent := _enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if navigation_agent == null:
		push_error("Enemy chase brain needs a NavigationAgent3D child.")
		return

	var navigation_map: RID = navigation_agent.get_navigation_map()
	for _frame: int in range(120):
		if not is_inside_tree() or not navigation_map.is_valid() or NavigationServer3D.map_get_iteration_id(navigation_map) > 0:
			break
		await get_tree().physics_frame

	if not is_inside_tree() or not navigation_map.is_valid() or NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		push_error("Enemy chase brain could not find a ready navigation map.")
		return

	_navigation_ready = true
	if patrol_enabled and _patrol_points.is_empty():
		push_warning("Patrol is enabled, but no Marker3D points were found under PatrolPoints.")


func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _set_patrol_destination() -> void:
	if not patrol_enabled or _patrol_points.is_empty() or _state != BehaviorState.PATROL:
		return

	var point: Node3D = _patrol_points[_patrol_index]
	_enemy.call(&"move_to", point.global_position)
	_patrol_destination_active = true
	print("Enemy patrolling to %s." % point.name)


func _begin_investigation() -> void:
	_has_chase_destination = false
	_patrol_destination_active = false
	if not _has_last_known_position:
		_state = BehaviorState.PATROL
		return

	_state = BehaviorState.INVESTIGATE
	_investigation_active = true
	_enemy.call(&"move_to", _last_known_position)
	print("Enemy investigating last known position %s." % _last_known_position)


func _begin_search() -> void:
	_enemy.call(&"stop_moving")
	_investigation_active = false
	_state = BehaviorState.SEARCH
	_search_elapsed = 0.0
	_search_phase = SearchPhase.TURN_LEFT
	_search_pause_elapsed = 0.0
	_search_scan_progress = 0.0
	print("Enemy searching the last known area.")


func _on_target_detected(target: Node3D) -> void:
	if not chase_enabled or target == null:
		return
	if is_instance_valid(_current_target) and _current_target != target:
		return

	_current_target = target
	_state = BehaviorState.CHASE
	_enemy.call(&"stop_moving")
	_investigation_active = false
	_has_chase_destination = false
	_patrol_destination_active = false
	_patrol_wait_timer = 0.0
	_last_known_position = _perception.call(&"get_last_visible_position", target)
	_has_last_known_position = true
	print("Enemy saw %s and is starting a chase." % target.name)


func _on_target_lost(target: Node3D) -> void:
	if _current_target != target:
		return

	# Perception freezes this cached position at the last frame with clear vision.
	_last_known_position = _perception.call(&"get_last_visible_position", target)
	_has_last_known_position = true
	_current_target = null
	print("Enemy lost sight of %s." % target.name)
	_begin_investigation()
