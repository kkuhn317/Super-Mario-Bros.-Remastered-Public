class_name ROMVerifier
extends Node

const VALID_HASH := "c9b34443c0414f3b91ef496d8cfee9fdd72405d673985afa11fb56732c96152b"

@onready var file_dialog := FileDialog.new()

func _ready() -> void:
	Global.get_node("GameHUD").hide()
	get_window().files_dropped.connect(on_file_dropped)
	await get_tree().physics_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	
	# Configure file dialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.use_native_dialog = true
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.nes ; NES ROMs"]) # adjust for your rom type
	file_dialog.connect("file_selected", Callable(self, "_on_file_selected"))
	add_child(file_dialog)
	
	# Request the MANAGE_EXTERNAL_STORAGE permission
	# which for some reason is the only way I can have it read the file you select
	# https://github.com/godotengine/godot/issues/100493
	OS.request_permissions()	
	
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		file_dialog.popup_centered_ratio(0.8)
		
func _on_file_selected(path: String):
	print("file selected!!: " + path)
	if (handle_file(path)):
		return
	error()

func on_file_dropped(files: PackedStringArray) -> void:
	for i in files:
		if(handle_file(i)):
			return
	error()
	
func handle_file(path: String) -> bool:
	if path.contains(".zip"):
		zip_error()
		return true
	elif is_valid_rom(path):
		Global.rom_path = path
		verified()
		copy_rom(path)
		return true
	return false

func copy_rom(file_path := "") -> void:
	DirAccess.copy_absolute(file_path, Global.ROM_PATH)

static func get_hash(file_path := "") -> String:
	var file_bytes = FileAccess.open(file_path, FileAccess.READ).get_buffer(40976)
	var data = file_bytes.slice(16)
	return Marshalls.raw_to_base64(data).sha256_text()

static func is_valid_rom(rom_path := "") -> bool:
	return get_hash(rom_path) == VALID_HASH

func error() -> void:
	%Error.show()
	$ErrorSFX.play()

func zip_error() -> void:
	$ErrorSFX.play()
	%ZipError.show()

func verified() -> void:
	$BGM.queue_free()
	%DefaultText.queue_free()
	%SuccessMSG.show()
	$SuccessSFX.play()
	await get_tree().create_timer(3, false).timeout
	if not Global.rom_assets_exist:
		Global.transition_to_scene("res://Scenes/Levels/RomResourceGenerator.tscn")
	else:
		Global.transition_to_scene("res://Scenes/Levels/TitleScreen.tscn")

func _exit_tree() -> void:
	Global.get_node("GameHUD").show()

func create_file_pointer(file_path := "") -> void:
	var pointer = FileAccess.open(Global.ROM_POINTER_PATH, FileAccess.WRITE)
	pointer.store_string(file_path)
	pointer.close()
