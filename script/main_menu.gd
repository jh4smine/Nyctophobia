extends Control

func _on_new_game_pressed() -> void:
	# Triggers the animated transition to the main house scene
	TransitionScene.change_scene("res://levels/main_house.tscn")
	get_tree().change_scene_to_file("res://levels/main_house.tscn")

func _on_load_game_pressed() -> void:
	# Triggers the animated transition to the main house scene
	TransitionScene.change_scene("res://levels/main_house.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/setting.tscn")

func _on_quit_game_pressed() -> void:
	get_tree().quit()
