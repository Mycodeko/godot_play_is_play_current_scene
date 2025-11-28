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

	func save_settings(file_path: String) -> Error:
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

	for child_node in node.get_children():
		return_nodes.append_array(recursive_iterate(child_node, true))

	return return_nodes

func handle_swap():
	var play_main_button_node: BaseButton = null
	var play_current_button_node: BaseButton = null

	var current_engine_version = Engine.get_version_info()

	var editor_control_nodes: Array[Node] = recursive_iterate(self.get_editor_interface().get_base_control())

	if current_engine_version["major"] == 4 and current_engine_version["minor"] >= 5:
		for node in editor_control_nodes:
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
	else:
		# TODO: Only works for English language. Could check icon, control index (which would need to factor in Mono support), keybind.
		for node in editor_control_nodes:
			if node is BaseButton:
				var node_tooltip_text_lower = node.tooltip_text.to_lower()

				if "play the project" in node_tooltip_text_lower:
					play_main_button_node = node
				elif "play the edited scene" in node_tooltip_text_lower:
					play_current_button_node = node

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
				settings.s_enabled = false
			else:
				settings.s_enabled = !settings.s_enabled

			settings.save_settings(get_settings_file_path())

			handle_swap()
		_:
			push_error("Unrecognized item text '" + str(item_text) + "'.")

func _cleanup():
	var settings = Settings.read_from_file(get_settings_file_path())
	if settings == null:
		settings = Settings.new()
		settings.s_enabled = false

	if settings.s_enabled:
		handle_swap()

	if tool_popup_menu != null:
		if tool_popup_menu.id_pressed.is_connected(_popup_item_selected):
			tool_popup_menu.id_pressed.disconnect(_popup_item_selected)

		# Will free the node automatically.
		remove_tool_menu_item(TOOL_MENU_NAME)

	tool_popup_menu = null

func _enter_tree() -> void:
	tool_popup_menu = PopupMenu.new()
	tool_popup_menu.name = TOOL_MENU_NAME
	tool_popup_menu.add_item(TOGGLE_ON_OFF)

	tool_popup_menu.id_pressed.connect(_popup_item_selected)

	add_tool_submenu_item(TOOL_MENU_NAME, tool_popup_menu)

	var settings = Settings.read_from_file(get_settings_file_path())
	if settings == null:
		settings = Settings.new()
		settings.s_enabled = false

	if settings.s_enabled:
		handle_swap()

func _exit_tree() -> void:
	_cleanup()