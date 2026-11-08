extends Node

## Follows visible Marker3D waypoints. Chasing is intentionally disabled for now.
@export var patrol_enabled: bool = true
@export_node_path("Node3D") var patrol_points_path: NodePath = ^"../../PatrolPoints"
## Used only in scenes without a PatrolPoints node.
@export var fallback_patrol_route: Array[Vector3] = [
	Vector3(7.5, 0.476, -5.5),
	Vector3(4.0, 0.476, -6.0),
	Vector3(1.0, 0.476, -4.0),
	Vector3(6.0, 0.476, -2.0),
]
@export_range(0.0, 10.0, 0.1) var patrol_wait_time: float = 1.5

@onready var enemy: CharacterBody3D = get_parent() as CharacterBody3D

var _patrol_points: Array[Marker3D] = []
var _patrol_index: int = 0
var _waiting_at_patrol_point: bool = false
var _wait_remaining: float = 0.0


func _ready() -> void:
	if not patrol_enabled:
		return
	var points_node := get_node_or_null(patrol_points_path)
	if points_node != null:
		for child in points_node.get_children():
			if child is Marker3D:
				_patrol_points.append(child)
	if not await _wait_for_navigation_map():
		return
	_start_patrol()


func _process(delta: float) -> void:
	if not patrol_enabled:
		return
	if _waiting_at_patrol_point:
		_wait_remaining -= delta
		if _wait_remaining <= 0.0:
			_waiting_at_patrol_point = false
			_advance_patrol_index()
			_start_patrol()
		return

	if enemy.has_reached_destination():
		print("Enemy reached patrol point %d." % (_patrol_index + 1))
		_waiting_at_patrol_point = true
		_wait_remaining = patrol_wait_time
	elif enemy.has_failed_destination():
		push_warning("Skipping unreachable patrol point %d." % _patrol_index)
		_advance_patrol_index()
		_start_patrol()


func _start_patrol() -> void:
	var point_count := _get_patrol_point_count()
	if point_count == 0:
		push_warning("Enemy patrol needs Marker3D children under PatrolPoints, or a fallback route.")
		return
	var target_position: Vector3
	if not _patrol_points.is_empty():
		target_position = _patrol_points[_patrol_index].global_position
	else:
		target_position = fallback_patrol_route[_patrol_index]
	enemy.move_to(target_position)
	print("Enemy patrolling to ", target_position)


func _get_patrol_point_count() -> int:
	return _patrol_points.size() if not _patrol_points.is_empty() else fallback_patrol_route.size()


func _advance_patrol_index() -> void:
	_patrol_index = (_patrol_index + 1) % _get_patrol_point_count()


func _wait_for_navigation_map() -> bool:
	var navigation_agent := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if navigation_agent == null:
		push_error("Enemy patrol requires a NavigationAgent3D child.")
		return false

	for _frame in range(120):
		if not patrol_enabled or not is_inside_tree():
			return false
		var navigation_map: RID = navigation_agent.get_navigation_map()
		if navigation_map.is_valid() and NavigationServer3D.map_get_iteration_id(navigation_map) > 0:
			return true
		await get_tree().physics_frame

	push_error("Enemy patrol could not start because its navigation map did not synchronize.")
	return false
