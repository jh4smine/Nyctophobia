
extends CanvasLayer

@onready var animation_player: AnimationPlayer = $ColorRect/Fade_to_black

var is_transitioning: bool = false


func change_scene(target_scene_path: String) -> void:

	if is_transitioning:
		return

	if not is_instance_valid(animation_player):
		push_error("AnimationPlayer not found! Check the node path.")
		return

	if not ResourceLoader.exists(target_scene_path):
		push_error("Scene does not exist: " + "res://levels/main_house.tscn")
		return

	is_transitioning = true

	# Close eyes
	animation_player.play("blink_close")
	await animation_player.animation_finished

	# Change scene
	var error = get_tree().change_scene_to_file("res://levels/main_house.tscn")

	if error != OK:
		push_error("Failed to change scene: " + "res://levels/main_house.tscn")
		is_transitioning = false
		return

	# Wait for the new scene
	await get_tree().scene_changed

	# Open eyes
	animation_player.play("blink_open")
	await animation_player.animation_finished

	is_transitioning = false
