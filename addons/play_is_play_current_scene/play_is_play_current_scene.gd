@tool
extends EditorPlugin

const TOOL_MENU_NAME: String = "Play Is Play Current Scene"
const CONFIG_SECTION: String = ""
const TOGGLE_ON_OFF: String = "Toggle On / Off"

var tool_popup_menu: PopupMenu
var previous_index: int

class Settings:
	const SETTING_PREFIX = "s_"

	var s_enabled: bool

	static func read_from_file(file_path: String):
		var config = ConfigFile.new()
		var error = config.load(file_path)

		if error != OK:
			return null

		var settings = Settings.new()
		for section in config.get_sections():
			for key in config.get_section_keys(section):
				settings.set(key, config.get_value(section, key))

		return settings

	func save_settings(file_path: String) -> void:
		var config = ConfigFile.new()

		for property_dictionary in self.get_property_list():
			var property_name: String = property_dictionary['name']

			if property_name.begins_with(SETTING_PREFIX):
				config.set_value(CONFIG_SECTION, property_name, self.get(property_name))

		return config.save(file_path)

func get_settings_file_path() -> String:
	return ProjectSettings.globalize_path('user://').path_join('play_is_play_current_scene_editor_settings.ini')

func recursive_iterate(node: Node, include_parent: bool = false) -> Array[Node]:
	var return_nodes: Array[Node] = []
	if include_parent:
		return_nodes.append(node)

	var recursive_iterate_func := func _recursive_iterate(parent_node: Node, function: Callable):
		return_nodes.append(parent_node)
		for child_node in parent_node.get_children():
			function.call(child_node, function)

	for child_node in node.get_children():
		recursive_iterate_func.call(child_node, recursive_iterate_func)

	return return_nodes

func _cleanup():
	if tool_popup_menu != null:
		if tool_popup_menu.id_pressed.is_connected(_popup_item_selected):
			tool_popup_menu.id_pressed.disconnect(_popup_item_selected)
		tool_popup_menu.queue_free()
	tool_popup_menu = null

func _handle_swap():
	# TODO: Store previous if first so we can swap back on disable.
	var play_main_button_node: BaseButton = null
	var play_current_button_node: BaseButton = null
	for node in recursive_iterate(EditorInterface.get_base_control()):
		if node is BaseButton and node.theme_type_variation == "RunBarButton":
			var pressed_connection_list = node.get_signal_connection_list("pressed")
			for connection_dict in pressed_connection_list:
				var callable_string = str(connection_dict.get("callable", null))
				if callable_string.contains("play_main"):
					play_main_button_node = node
					break
				elif callable_string.contains("play_current"):
					play_current_button_node = node
					break

	if play_main_button_node != null and play_current_button_node != null:
		previous_index = play_main_button_node.get_index()

		play_main_button_node.get_parent().move_child(play_main_button_node, play_current_button_node.get_index())
		play_current_button_node.get_parent().move_child(play_current_button_node, previous_index)
	else:
		push_warning("Failed to find either play_main_button_node (" + str(play_main_button_node) + " or play_current_button_node (" + str(play_current_button_node) + ").")

func _popup_item_selected(id: int) -> void:
	var item_index = tool_popup_menu.get_item_index(id)
	var item_text = tool_popup_menu.get_item_text(item_index)

	match item_text:
		TOGGLE_ON_OFF:
			var settings = Settings.read_from_file(get_settings_file_path())
			if settings == null:
				settings = Settings.new()
				settings.s_enabled = false;
			else:
				settings.s_enabled = !settings.s_enabled

			settings.save_settings(get_settings_file_path())

			_handle_swap()
		_:
			push_error("Unrecognized item text '" + str(item_text) + "'.")

func _enter_tree() -> void:
	tool_popup_menu = PopupMenu.new()
	tool_popup_menu.name = TOOL_MENU_NAME
	tool_popup_menu.add_item(TOGGLE_ON_OFF)

	tool_popup_menu.id_pressed.connect(_popup_item_selected)

	add_tool_submenu_item(TOOL_MENU_NAME, tool_popup_menu)

	var settings = Settings.read_from_file(get_settings_file_path())
	if settings == null:
		settings = Settings.new()
		settings.s_enabled = false;

	if settings.s_enabled:
		_handle_swap()

func _exit_tree() -> void:
	_cleanup()