extends Area3D

@export var ambience_player: AudioStreamPlayer3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" and ambience_player != null:
		ambience_player.stop()
