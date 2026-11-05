extends RayCast3D

func _process(delta):
	if is_colliding() and Input.is_action_just_pressed("interact"):
		var hitObj = get_collider()

		if hitObj.has_method("interact"):
			hitObj.interact()
