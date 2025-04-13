@tool
extends EditorPlugin

const BIMSpawnEditorDebuggerPlugin = preload("res://addons/bim_launcher/spawning/bim_spawn_editor_debugger_plugin.gd")

const BIMSpawnerName: String = "BIMSpawner"

var _menu_bar := MenuBar.new()
var _selected_spawn_point_index: int = 0
var _spawn_points_texts := [
	"Default",
	"Editor Camera",
]

var _spawnpoint_debugger_plugin := BIMSpawnEditorDebuggerPlugin.new()

var _config: ConfigFile = ConfigFile.new()

## The camera cache containing information about camera transform in all scenes, even these that are not open.
var _editor_camera_3d_cache: Dictionary

func _enter_tree():
	_load_plugin_config()

	_spawnpoint_debugger_plugin.spawn_point_provider = self

	add_autoload_singleton(BIMSpawnerName, "res://addons/bim_launcher/spawning/bim_spawner.gd")
	add_debugger_plugin(_spawnpoint_debugger_plugin)
	print_verbose("[bim_launcher] Registered debugger plugin!")

	var spawn_points := PopupMenu.new()
	for spawn_point_text in _spawn_points_texts:
		spawn_points.add_radio_check_item(spawn_point_text)

	spawn_points.index_pressed.connect(_spawn_point_selected.bind(spawn_points))
	
	_menu_bar.add_child(spawn_points)

	spawn_points.set_item_checked(_selected_spawn_point_index, true)
	_update_spawn_point_title(_selected_spawn_point_index)

	add_control_to_container(CustomControlContainer.CONTAINER_TOOLBAR, _menu_bar)
	pass

func _exit_tree():
	remove_autoload_singleton(BIMSpawnerName)
	remove_debugger_plugin(_spawnpoint_debugger_plugin)
	remove_control_from_container(CustomControlContainer.CONTAINER_TOOLBAR, _menu_bar)
	_menu_bar.queue_free()

func _update_spawn_point_title(index):
	_menu_bar.set_menu_title(0, "Spawn Point: " + _spawn_points_texts[index])

func _load_plugin_config() -> void:
	var result: int = _config.load(get_editor_interface().get_editor_paths().get_project_settings_dir() + "/bim_launcher.cfg")
	if result != OK:
		push_warning("Failed to load BIM Launcher plugin config, using defaults. Result: " + str(result))
		return

	_selected_spawn_point_index = clamp(_config.get_value("editor_spawn_point", "_selected_spawn_point_index", 0), 0, _spawn_points_texts.size())

	var raw_editor_camera_3d_cache = _config.get_value("editor_spawn_point", "_editor_camera_3d_cache", {})
	if raw_editor_camera_3d_cache is Dictionary:
		_editor_camera_3d_cache = raw_editor_camera_3d_cache

func _save_plugin_config() -> void:
	_config.save(get_editor_interface().get_editor_paths().get_project_settings_dir() + "/bim_launcher.cfg")

func _spawn_point_selected(index, spawn_points: PopupMenu):
	spawn_points.set_item_checked(_selected_spawn_point_index, false)
	spawn_points.set_item_checked(index, true)
	_selected_spawn_point_index = index

	_config.set_value("editor_spawn_point", "_selected_spawn_point_index", _selected_spawn_point_index)
	_save_plugin_config()
	_update_spawn_point_title(index)

func get_spawn_point() -> BIMSpawnData:
	if _selected_spawn_point_index == 0:
		return BIMSpawnData.Default

	_update_editor_camera_cache()

	var active_scene_path: String = get_editor_interface().get_playing_scene()
	var transform_or_null: Variant = _editor_camera_3d_cache.get(active_scene_path)
	if transform_or_null == null:
		push_warning("There is no valid camera transform available for 'Spawn Point: Editor Camera' to work. Please open at least once the scene '" + active_scene_path + "' in editor.")
		return BIMSpawnData.Default

	var spawn_data = BIMSpawnData.new()
	spawn_data.transform = transform_or_null as Transform3D
	return spawn_data

func _get_plugin_name() -> String:
	return "BIMLauncher"

func _get_state() -> Dictionary:
	# Hook into get state, this is called when user switches scene tab. We use it to cache camera position
	# so we can teleport to camera of the main scene reliably even if the scene is not open.
	_update_editor_camera_cache()
	return {}

## Stores currently edited scene 3D camera transform into camera cache.
func _update_editor_camera_cache() -> void:
	var edited_scene_root: Node = get_editor_interface().get_edited_scene_root()
	if not edited_scene_root:
		return

	assert(not edited_scene_root.scene_file_path.is_empty(), "Trying to cache editor camera for scene without path, this should not be possible.")

	var scene_resource_uid: int = ResourceLoader.get_resource_uid(edited_scene_root.scene_file_path)
	assert(scene_resource_uid != -1, "Trying to cache editor camera for scene "+edited_scene_root.scene_file_path+" and for some reason it has no resource UID. Godot bug?")

	_editor_camera_3d_cache[ResourceUID.id_to_text(scene_resource_uid)] = get_editor_interface().get_editor_viewport_3d(0).get_camera_3d().global_transform

	_config.set_value("editor_spawn_point", "_editor_camera_3d_cache", _editor_camera_3d_cache)
	_save_plugin_config()
