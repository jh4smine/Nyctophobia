extends TextureProgressBar

@export var high_color: Color = Color("38d96c")   # Green
@export var mid_color: Color = Color("f5c542")    # Yellow
@export var low_color: Color = Color("e63946")    # Red

func _ready() -> void:
	# Initialize color based on starting value
	update_visuals(value)

# Call this function from your player or game manager to update the HUD
func set_battery_level(new_percentage: float) -> void:
	# Smoothly tween the visual bar over 0.2 seconds
	var tween := create_tween()
	tween.tween_property(self, "value", clamp(new_percentage, min_value, max_value), 0.2)
	update_visuals(new_percentage)

func update_visuals(current_val: float) -> void:
	# Tint the progress texture based on percentage thresholds
	if current_val > 50.0:
		tint_progress = high_color
	elif current_val > 20.0:
		tint_progress = mid_color
	else:
		tint_progress = low_color
