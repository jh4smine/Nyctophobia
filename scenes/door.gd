extends StaticBody3D

var toggle = false
var interactable = true

@export var animation_player: AnimationPlayer

func interact():
	if not interactable:
		return

	interactable = false
	toggle = !toggle

	if toggle:
		animation_player.play("open")
	else:
		animation_player.play("close")

	await animation_player.animation_finished
	interactable = true
