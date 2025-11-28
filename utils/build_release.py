#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys
import zipfile

from downgrade_to_godot_3 import downgrade_file

def relativize_path(path : Path):
	return path.relative_to(Path("../").expanduser().resolve())

def main():
	parent_folder_path = Path("../").resolve()
	parent_folder_name = parent_folder_path.name

	license_file_path = Path(parent_folder_path, "LICENSE")
	readme_file_path = Path(parent_folder_path, "README.md")

	input_file_path = Path(parent_folder_path, "addons", "play_is_play_current_scene", "play_is_play_current_scene.gd").resolve()
	output_folder_path = Path(parent_folder_path, "output")
	downgraded_folder_path = Path(output_folder_path, "downgraded")

	downgraded_file_path = Path(downgrade_file(input_file_path, downgraded_folder_path))

	# Copy the license and README files into the addon folder for the repository.
	for file_path in [readme_file_path, license_file_path]:
		shutil.copy2(file_path, Path(input_file_path.parent, file_path.name))

	for (zip_output_file_path, plugin_gdscript_file_path) in [
		(Path(output_folder_path, "play_is_play_current_scene_godot_3.zip"), downgraded_file_path),
		(Path(output_folder_path, "play_is_play_current_scene_godot_4.zip"), input_file_path),
	]:
		with zipfile.ZipFile(zip_output_file_path, 'w', zipfile.ZIP_DEFLATED) as zip_file:
			# Write all the files in the input file path folder as long as it is not the input file itself.
			for file_path in input_file_path.parent.rglob('*'):
				if file_path != input_file_path:
					zip_file.write(file_path, Path(parent_folder_name, relativize_path(file_path)))

			# Write either the downgraded file or the original into the zip at the relative location of the input file path.
			zip_file.write(plugin_gdscript_file_path, Path(parent_folder_name, relativize_path(input_file_path)))

	return 0

if __name__ == '__main__':
	sys.exit(main())