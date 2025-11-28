#!/usr/bin/env python3
import os
from pathlib import Path
import sys
from typing import List

def remove_array_types(line : str):
	if 'Array' not in line:
		return line

	return_string_parts : List[str] = []

	for part in line.split(' '):
		output_part = part
		if part.startswith('Array['):
			output_part = ""

			in_brackets = False
			for character in part:
				if in_brackets:
					if character == ']':
						in_brackets = False
						continue
				else:
					if character == '[':
						in_brackets = True
						continue

				if not in_brackets:
					output_part += character

		return_string_parts.append(output_part)

	return ' '.join(return_string_parts)

def fix_signals(line : str):
	if '.connect(' in line and '.connect("' not in line:
		line_dot_split = line.split('.', 2)
		node_signal = line_dot_split[0]
		signal_name = line_dot_split[1]
		function_name = line_dot_split[2].removeprefix('connect(').removesuffix(')')

		return f'{node_signal}.connect("{signal_name}", self, "{function_name}")'

	if '.is_connected(' in line and '.is_connected("' not in line:
		line_dot_split = line.split('.', 2)
		node_signal = line_dot_split[0]
		signal_name = line_dot_split[1]
		function_name = line_dot_split[2].removeprefix('is_connected(')

		suffix_char = ''
		if function_name.endswith(':'):
			function_name = function_name.removesuffix(':')
			suffix_char = ':'

		function_name = function_name.removesuffix(')')

		return f'{node_signal}.is_connected("{signal_name}", self, "{function_name}"){suffix_char}'

	if '.disconnect(' in line and '.disconnect("' not in line:
		line_dot_split = line.split('.', 2)
		node_signal = line_dot_split[0]
		signal_name = line_dot_split[1]
		function_name = line_dot_split[2].removeprefix('disconnect(').removesuffix(')')

		return f'{node_signal}.disconnect("{signal_name}", self, "{function_name}")'

	return line

def replace_functions(line : str):
	output_line = line

	if '.path_join(' in line:
		path_parts : List[str] = []

		line_split = line.split('.path_join(', 1)
		path_parts.append(line_split[0])

		function_parameter_list_split = line_split[1].split(',')
		for function_parameter in function_parameter_list_split:
			path_parts.append(function_parameter.strip())

		output_line = " + '/' + ".join(path_parts).removesuffix(')')

	output_line = output_line.replace('-> Error', '-> int')

	return output_line

def replace_fields(line : str):
	return line.replace('.tooltip_text', '.hint_tooltip')

def downgrade_file(script_file_path : str | os.PathLike, output_folder_path : str | os.PathLike) -> str | os.PathLike:
	script_file_path = Path(script_file_path).expanduser().resolve()
	output_folder_path = Path(output_folder_path).expanduser().resolve()

	output_folder_path.mkdir(parents=True, exist_ok=True)

	output_file_path = Path(output_folder_path, script_file_path.stem + "_godot_3" + ''.join(script_file_path.suffixes))

	with open(script_file_path, 'r', encoding='utf-8') as script_file:
		with open(output_file_path, 'w', encoding='utf-8') as output_file:
			for line in script_file.readlines():
				output_line : str | None = line.removesuffix('\n')

				if output_line.startswith("@tool"):
					output_line = output_line.removeprefix('@')

				output_line = remove_array_types(output_line)
				output_line = fix_signals(output_line)
				output_line = replace_functions(output_line)
				output_line = replace_fields(output_line)

				if output_line != None:
					output_file.write(output_line + '\n')

	return str(output_file_path)

def main():
	downgrade_file(Path("../", "addons", "play_is_play_current_scene", "play_is_play_current_scene.gd"), Path("../", "output", "downgraded"))

	return 0

if __name__ == '__main__':
	sys.exit(main())