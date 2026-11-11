class_name FlashlightBattery
extends Node

signal battery_changed(current: float, max_value: float)
signal battery_depleted

@export var max_battery: float = 100.0
@export var drain_rate: float = 10.0 # Per second

var current_battery: float

func _ready() -> void:
	current_battery = max_battery

func drain(delta: float) -> void:
	if current_battery <= 0:
		return

	current_battery = max(current_battery - (drain_rate * delta), 0.0)
	battery_changed.emit(current_battery, max_battery)

	if current_battery <= 0:
		battery_depleted.emit()

func reload(amount: float = 100.0) -> void:
	current_battery = min(current_battery + amount, max_battery)
	battery_changed.emit(current_battery, max_battery)

func has_power() -> bool:
	return current_battery > 0.0

func get_ratio() -> float:
	return current_battery / max_battery
