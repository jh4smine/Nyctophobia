extends StaticBody3D

var toggle = false
var interactable = true

const OPEN_DOOR_SOUND_TRANSMISSION: float = 1.0
const OPEN_DOOR_INTERACTION_LAYER: int = 1 << 1

@export_range(0.05, 1.0, 0.05) var closed_door_sound_transmission: float = 0.55

@export var animation_player: AnimationPlayer
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _closed_collision_layer: int
var _closed_collision_mask: int


func _ready() -> void:
	_closed_collision_layer = collision_layer
	_closed_collision_mask = collision_mask


func get_sound_transmission() -> float:
	return OPEN_DOOR_SOUND_TRANSMISSION if toggle else closed_door_sound_transmission


func open_for_enemy() -> void:
	if not toggle and interactable:
		interact()


func interact():
	if not interactable:
		return

	interactable = false
	toggle = !toggle

	if toggle:
		animation_player.play("open")
	else:
		animation_player.play("close")
	# Keep the moving leaf from trapping either the enemy or player mid-animation.
	_collision_shape.set_deferred(&"disabled", true)

	await animation_player.animation_finished
	if toggle:
		# Leave the open door visible to the player's interaction ray, but remove
		# it from body collisions so it cannot block the doorway.
		collision_layer = OPEN_DOOR_INTERACTION_LAYER
		collision_mask = 0
	else:
		collision_layer = _closed_collision_layer
		collision_mask = _closed_collision_mask
	_collision_shape.set_deferred(&"disabled", false)
	interactable = true
