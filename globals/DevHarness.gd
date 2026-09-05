extends Node

const CAPTURE_FPS := 12.0
const LABEL_FONT_SIZE := 28

var _capture_enabled := false
var _label := ""
var _capture_dir := ""
var _frame_index := 0
var _capture_accumulator := 0.0
var _capture_tasks: Array[int] = []

func _ready() -> void:
	var args := OS.get_cmdline_args()
	_capture_enabled = args.has("--capture")
	if not _capture_enabled:
		return

	var label_index := args.find("--label")
	if label_index != -1 and label_index + 1 < args.size():
		_label = args[label_index + 1]
	_capture_dir = OS.get_environment("GOMSTALLE_CAPTURE_DIR")

	if _capture_enabled and not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		if not _label.is_empty():
			_add_label_overlay()

func _process(delta: float) -> void:
	if not _capture_enabled:
		return
	if _capture_enabled and not _capture_dir.is_empty():
		_capture_accumulator += delta
		if _capture_accumulator >= 1.0 / CAPTURE_FPS:
			_capture_accumulator = 0.0
			_capture_frame()

func _capture_frame() -> void:
	for index in range(_capture_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_capture_tasks[index]):
			WorkerThreadPool.wait_for_task_completion(_capture_tasks[index])
			_capture_tasks.remove_at(index)
	if _capture_tasks.size() >= 2:
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var path := _capture_dir.path_join("frame_%06d.jpg" % _frame_index)
	_capture_tasks.append(WorkerThreadPool.add_task(_write_frame.bind(image, path)))
	_frame_index += 1

static func _write_frame(image: Image, path: String) -> void:
	image.save_jpg(path, 0.92)

func _exit_tree() -> void:
	for task_id in _capture_tasks:
		WorkerThreadPool.wait_for_task_completion(task_id)

func _add_label_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(140, 44)
	var label := Label.new()
	label.text = _label
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	layer.add_child(panel)
	layer.add_child(label)
	add_child(layer)
