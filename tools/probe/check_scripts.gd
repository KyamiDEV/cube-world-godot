extends SceneTree
## Parses every project GDScript file in one engine launch (backlog brick 007).
##
## Usage:
##   godot --headless --script res://tools/probe/check_scripts.gd
##
## A file fails when it does not compile, which — with the warning levels set in
## project.godot — includes warnings promoted to errors. Exit code 0 = all clean.

const SKIPPED_DIRS: PackedStringArray = ["addons", "reference", ".godot", ".git"]


func _initialize() -> void:
	# Reloading the currently executing script would swap the resource out from
	# under the running instance, so it is excluded. It is validated implicitly:
	# a broken version of this file could not have started.
	var self_path := (get_script() as Script).resource_path

	var scripts := _collect("res://")
	scripts.sort()

	var failed: PackedStringArray = []
	var checked := 0
	for path in scripts:
		if path == self_path:
			continue
		checked += 1
		if _parse_fails(path):
			failed.append(path)

	print("checked=%d failed=%d" % [checked, failed.size()])
	if failed.is_empty():
		print("RESULT=OK")
		quit(0)
		return
	for path in failed:
		printerr("FAIL: ", path)
	print("RESULT=FAIL")
	quit(1)


## Compiles a file in isolation. Parsing a detached GDScript object avoids
## reloading a script that already has live instances (autoloads), which fails for
## reasons unrelated to the file being valid.
func _parse_fails(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		printerr("unreadable: ", path)
		return true
	var probe := GDScript.new()
	probe.source_code = _suffix_class_name(text)
	return probe.reload(false) != OK


## The real file is already registered as a global class, so a detached copy
## declaring the same `class_name` is rejected with "hides a global script class".
## Renaming only the declaration sidesteps that: references to the original name
## inside the file still resolve, through the global class list, to the real script.
func _suffix_class_name(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?m)^class_name[ \t]+([A-Za-z_][A-Za-z0-9_]*)")
	return regex.sub(text, "class_name $1__selfcheck")


func _collect(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				if not SKIPPED_DIRS.has(entry):
					found.append_array(_collect(full))
			elif entry.ends_with(".gd"):
				found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
