extends CanvasLayer

# Updated node path (or use %Fade_to_black if configured as Unique Name)
@onready var animation_player: AnimationPlayer = $ColorRect/Fade_to_black

func change_scene(target_scene_path: String) -> void:
	# Safety check to prevent crashing if node is missing
	if not animation_player:
		push_error("AnimationPlayer node not found!")
		return

	# 1. Close eyes (0.25s)
	animation_player.play("blink_close")
	await animation_player.animation_finished
	
	# 2. Swap scene using the passed parameter
	get_tree().change_scene_to_file(target_scene_path)
	
	# 3. Open eyes (0.25s)
	animation_player.play("blink_open")
	await animation_player.animation_finished

# Triggers a full blink lasting 0.5s total
func trigger_player_blink() -> void:
	if not animation_player:
		push_error("AnimationPlayer node not found!")
		return

	animation_player.play("blink_close")
	await animation_player.animation_finished # waits 0.25s
	
	animation_player.play("blink_open")
	await animation_player.animation_finished # waits 0.25s
