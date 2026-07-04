@tool
extends FileDialog
class_name ImagePickerDialog

signal image_selected(path: String)

const WEB_IMAGE_ACCEPT := ".png,.jpg,.jpeg,.webp"

var _pending_callback: Callable = Callable()
var _pending_upload_dir: String = ""
var _js_input: JavaScriptObject
var _js_change_callback: JavaScriptObject
var _web_reader: JavaScriptObject
var _web_reader_callback: JavaScriptObject


func _ready() -> void:
	visible = false
	use_native_dialog = false
	file_mode = FileDialog.FILE_MODE_OPEN_FILE
	filters = ResourceFsUtils.IMAGE_FILTERS
	file_selected.connect(_on_file_selected)
	canceled.connect(_on_canceled)
	if OS.has_feature("web"):
		_setup_native_uploader()


func _setup_native_uploader() -> void:
	var document := JavaScriptBridge.get_interface("document")
	_js_input = document.createElement("input")
	_js_input.type = "file"
	_js_input.accept = WEB_IMAGE_ACCEPT
	_js_input.style.display = "none"
	document.body.appendChild(_js_input)
	_js_change_callback = JavaScriptBridge.create_callback(_on_web_file_selected)
	_js_input.addEventListener("change", _js_change_callback)


func pick(kind: ResConst.ImageKind, mode: ResConst.ImagePickMode, builtin: bool, callback: Callable) -> void:
	_pending_callback = callback
	match mode:
		ResConst.ImagePickMode.UPLOAD:
			if OS.has_feature("web") and _js_input:
				_pending_upload_dir = ResConst.textures_dir(kind, false)
				_js_input.value = ""
				_js_input.click()
				return
			title = ResConst.upload_title(kind)
			access = FileDialog.ACCESS_FILESYSTEM
			use_native_dialog = true
		ResConst.ImagePickMode.CHOOSE:
			title = ResConst.choose_title(kind)
			access = FileDialog.ACCESS_RESOURCES if builtin else FileDialog.ACCESS_FILESYSTEM
			root_subfolder = ResConst.textures_dir(kind, builtin)
			use_native_dialog = false
	popup_centered_ratio(0.6)


func _on_web_file_selected(_args: Array) -> void:
	var files = _js_input.files
	if files.length == 0:
		return

	var file = files.item(0)
	var file_name: String = file.name
	_web_reader = JavaScriptBridge.create_object("FileReader")
	_web_reader_callback = JavaScriptBridge.create_callback(func(_reader_args: Array):
		_on_web_file_read(_web_reader.result, file_name)
	)
	_web_reader.addEventListener("load", _web_reader_callback)
	_web_reader.readAsArrayBuffer(file)


func _on_web_file_read(array_buffer: JavaScriptObject, file_name: String) -> void:
	if not JavaScriptBridge.is_js_buffer(array_buffer):
		push_error("Uploaded image data is not a binary buffer.")
		return

	var bytes := JavaScriptBridge.js_buffer_to_packed_byte_array(array_buffer)
	if bytes.is_empty():
		push_error("Uploaded image is empty.")
		return

	ResourceFsUtils.ensure_directories()
	var base_name := ResourceFsUtils.sanitize_filename(file_name.get_basename())
	var ext := file_name.get_extension().to_lower()
	if ext.is_empty():
		ext = "png"
	var dest_path := ResourceFsUtils.make_unique_path(_pending_upload_dir, base_name, ext)

	var file := FileAccess.open(dest_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save uploaded image to %s" % dest_path)
		return
	file.store_buffer(bytes)
	file.close()
	_finish_pick(dest_path)


func _on_file_selected(path: String) -> void:
	_finish_pick(path)


func _finish_pick(path: String) -> void:
	if _pending_callback.is_valid():
		_pending_callback.call(path)
	image_selected.emit(path)
	_pending_callback = Callable()


func _on_canceled() -> void:
	_pending_callback = Callable()
