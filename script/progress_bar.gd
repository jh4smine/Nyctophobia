class_name BatteryBarUI
extends ProgressBar

@export var battery_component: ProgressBar

func _ready() -> void:
	if battery_component:
		battery_component.battery_changed.connect(_on_battery_changed)
		max_value = battery_component.max_battery
		value = battery_component.current_battery

func _on_battery_changed(current: float, _max: float) -> void:
	value = current
