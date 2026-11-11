extends RayCast3D

func _ready() -> void:
	enabled = true
	exclude_parent = true
	var player_body := get_parent().get_parent() as CollisionObject3D
	if player_body != null:
		add_exception(player_body)


func _physics_process(_delta: float) -> void:
	force_raycast_update()
