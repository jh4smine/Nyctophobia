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
var _candidate_last_visible_positions: Array[Vector3] = []
var _visible_targets: Array[Node3D] = []
var _last_visibility_failure_reason: String = ""


func _ready() -> void:
	var sphere_shape := _range_shape.shape as SphereShape3D
	if sphere_shape == null:
		push_error("Enemy perception requires a SphereShape3D range shape.")
		set_physics_process(false)
		return

	sphere_shape.radius = sight_range
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	# The explicit range and ray checks below also decide when a visible target is lost.
	# Keeping candidates lets those checks handle an Area3D exit cleanly.
	for index: int in range(_candidate_targets.size() - 1, -1, -1):
		var target: Node3D = _candidate_targets[index]
		if not is_instance_valid(target):
			_candidate_targets.remove_at(index)
			_candidate_last_visible_positions.remove_at(index)
			_visible_targets.erase(target)
			continue

		var can_see_target: bool = _is_target_visible(target)
		var was_visible: bool = _visible_targets.has(target)
		if can_see_target:
			# Cache positions only while vision confirms the player is visible.
			_candidate_last_visible_positions[index] = get_target_aim_point(target)
			if not was_visible:
				_visible_targets.append(target)
				target_detected.emit(target)
		elif was_visible:
			_visible_targets.erase(target)
			print("Perception lost visibility: %s." % _last_visibility_failure_reason)
			target_lost.emit(target)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(target_group) and not _candidate_targets.has(body):
		_candidate_targets.append(body)
		_candidate_last_visible_positions.append(get_target_aim_point(body))


## Returns the most recent position vision confirmed for this target.
## The value stays frozen after target_lost is emitted.
func get_last_visible_position(target: Node3D) -> Vector3:
	var index: int = _candidate_targets.find(target)
	if index < 0:
		return Vector3.ZERO
	return _candidate_last_visible_positions[index]


## Returns the point vision aims at: the center of the target's collision shape.
## Player rigs differ (origin at the feet vs. at the head), so aiming at the body
## itself is more reliable than origin + target_point_height, which is only the fallback.
func get_target_aim_point(target: Node3D) -> Vector3:
	for child: Node in target.get_children():
		var shape := child as CollisionShape3D
		if shape != null and not shape.disabled:
			return shape.global_position
	return target.global_position + Vector3.UP * target_point_height


func is_target_visible(target: Node3D) -> bool:
	return _visible_targets.has(target)


func _is_target_visible(target: Node3D) -> bool:
	_last_visibility_failure_reason = ""
	var eye_position: Vector3 = global_position + Vector3.UP * eye_height
	var target_position: Vector3 = get_target_aim_point(target)
	var offset: Vector3 = target_position - eye_position
	var distance_squared: float = offset.length_squared()
	if distance_squared <= 0.0001 or distance_squared > sight_range * sight_range:
		_last_visibility_failure_reason = "outside sight range"
		return false

	var horizontal_offset := Vector3(offset.x, 0.0, offset.z)
	var forward_direction := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z).normalized()
	var minimum_dot: float = cos(deg_to_rad(field_of_view_degrees * 0.5))
	var horizontal_distance_squared: float = horizontal_offset.length_squared()
	var close_range_distance: float = 1.5
	if horizontal_distance_squared > close_range_distance * close_range_distance and forward_direction.dot(horizontal_offset.normalized()) < minimum_dot:
		_last_visibility_failure_reason = "outside the field of view"
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

	if result.get("collider") == target:
		return true

	var blocking_node: Object = result.get("collider")
	_last_visibility_failure_reason = "line of sight blocked by %s" % (blocking_node.name if blocking_node != null else "an unknown object")
	return false
