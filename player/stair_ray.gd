extends RayCast3D

func _ready() -> void:
	enabled = true
	exclude_parent = true
	add_exception(get_parent())


func _physics_process(_delta: float) -> void:
	force_raycast_update()

	if is_colliding():
		print("HIT: ", get_collider().name)
		print("NORMAL: ", get_collision_normal())
	else:
		print("NO HIT")
