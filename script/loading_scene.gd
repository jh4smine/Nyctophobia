extends Node2D

@onready var progress_bar: ProgressBar = $ProgressBar
@export var next_scene_path: String = "res://scenes/main_menu.tscn"

var progress: Array[float] = []
var target_progress: float = 0.0
var is_loading_finished: bool = false

func _ready() -> void:
	progress_bar.value = 0.0
	ResourceLoader.load_threaded_request(next_scene_path)

func _process(delta: float) -> void:
	if is_loading_finished:
		return

	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				target_progress = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			target_progress = 100.0

	# Smoothly fill the bar toward target_progress regardless of actual load speed
	progress_bar.value = move_toward(progress_bar.value, target_progress, 100.0 * delta)

	# Transition only when both the background load and the visual animation hit 100%
	if status == ResourceLoader.THREAD_LOAD_LOADED and progress_bar.value >= 100.0:
		is_loading_finished = true
		await get_tree().create_timer(0.5).timeout
		var loaded_scene = ResourceLoader.load_threaded_get(next_scene_path)
		get_tree().change_scene_to_packed(loaded_scene)
