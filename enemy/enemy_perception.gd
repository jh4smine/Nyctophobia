extends Area3D

signal target_detected(target: Node3D)
signal target_lost(target: Node3D)

@export_range(0.1, 100.0, 0.1) var sight_range: float = 12.0
@export_range(0.0, 360.0, 1.0) var field_of_view_degrees: float = 90.0
@export_range(0.0, 3.0, 0.05) var eye_height: float = 1.5
@export_range(0.0, 2.0, 0.05) var target_point_height: float = 1.0
@export var target_group: StringName = &"player"
@export_flags_3d_physics var obstruction_collision_mask: int = 1

@onready var _range_shape: CollisionShape3D = $CollisionShape3D

var _candidate_targets: Array[Node3D] = []
var _visible_targets: Array[Node3D] = []


func _ready() -> void:
	var sphere_shape := _range_shape.shape as SphereShape3D
	if sphere_shape == null:
		push_error("Enemy perception requires a SphereShape3D range shape.")
		set_physics_process(false)
		return

	sphere_shape.radius = sight_range
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	for index: int in range(_candidate_targets.size() - 1, -1, -1):
		var target: Node3D = _candidate_targets[index]
		if not is_instance_valid(target):
			_candidate_targets.remove_at(index)
			_visible_targets.erase(target)
			continue

		var can_see_target: bool = _is_target_visible(target)
		var was_visible: bool = _visible_targets.has(target)
		if can_see_target and not was_visible:
			_visible_targets.append(target)
			target_detected.emit(target)
		elif was_visible and not can_see_target:
			_visible_targets.erase(target)
			target_lost.emit(target)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(target_group) and not _candidate_targets.has(body):
		_candidate_targets.append(body)


func _on_body_exited(body: Node3D) -> void:
	_candidate_targets.erase(body)
	if _visible_targets.has(body):
		_visible_targets.erase(body)
		target_lost.emit(body)


func _is_target_visible(target: Node3D) -> bool:
	var eye_position: Vector3 = global_position + Vector3.UP * eye_height
	var target_position: Vector3 = target.global_position + Vector3.UP * target_point_height
	var offset: Vector3 = target_position - eye_position
	var distance_squared: float = offset.length_squared()
	if distance_squared <= 0.0001 or distance_squared > sight_range * sight_range:
		return false

	var direction_to_target: Vector3 = offset / sqrt(distance_squared)
	var forward_direction: Vector3 = -global_transform.basis.z.normalized()
	var minimum_dot: float = cos(deg_to_rad(field_of_view_degrees * 0.5))
	if forward_direction.dot(direction_to_target) < minimum_dot:
		return false

	return _has_clear_line_of_sight(target, eye_position, target_position)


func _has_clear_line_of_sight(target: Node3D, from_position: Vector3, to_position: Vector3) -> bool:
	var excluded_rids: Array[RID] = []
	var enemy_body := get_parent() as CollisionObject3D
	if enemy_body != null:
		excluded_rids.append(enemy_body.get_rid())

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_position,
		to_position,
		obstruction_collision_mask,
		excluded_rids
	)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true

	return result.get("collider") == target
