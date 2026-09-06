class_name RunStorage
extends RefCounted
## Preparation snapshots, completion progress, and atomic versioned JSON helpers.

const VERSION := 1
const SLOT_COUNT := 3
const MAX_FILE_BYTES := 2 * 1024 * 1024
static var storage_root: String = "user://wardens"

static func save_slot(slot: int, data: Dictionary) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return _failure("Choose a save slot from 1 to 3.")
	var error := validate_run(data)
	if not error.is_empty():
		return _failure(error)
	return write_document(_slot_path(slot), "run", data)

static func load_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return _failure("Choose a save slot from 1 to 3.")
	return read_document(_slot_path(slot), "run")

static func list_slots() -> Array:
	var slots: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		var path := _slot_path(slot)
		var result := load_slot(slot)
		var item := {"slot": slot, "exists": FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"), "ok": result.ok, "error": result.get("error", "")}
		if result.ok:
			var data: Dictionary = result.data
			for key in ["map_id", "map_name", "difficulty", "wave"]:
				item[key] = data.get(key, "")
			item.timestamp = result.timestamp
			item.recovered = result.get("recovered", false)
		slots.append(item)
	return slots

static func delete_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return _failure("Choose a save slot from 1 to 3.")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path: String = _slot_path(slot) + suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			return _failure("The save could not be deleted. Check file permissions.")
	return {"ok": true, "error": ""}

static func load_progress() -> Dictionary:
	var result := read_document(storage_root.path_join("progress.json"), "progress")
	return result.data if result.ok else {}

static func record_completion(map_id: String, summary: Dictionary) -> Dictionary:
	if not _stable_id(map_id):
		return _failure("Map completion has an invalid map ID.")
	var entry := summary.duplicate(true)
	for key in ["kills", "integrity", "waves_completed"]:
		if not _integer_in(entry.get(key, 0), 0, 1000000000):
			return _failure("Map completion contains an invalid " + key + ".")
	var progress := load_progress()
	entry["timestamp"] = Time.get_datetime_string_from_system(true)
	entry["wins"] = int(progress.get(map_id, {}).get("wins", 0)) + 1
	progress[map_id] = entry
	return write_document(storage_root.path_join("progress.json"), "progress", progress)

static func validate_run(data: Dictionary) -> String:
	if not _stable_id(data.get("map_id")):
		return "The save has an invalid map ID."
	for key in ["wave", "credits", "kills"]:
		if not _integer_in(data.get(key), 0, 1000000000):
			return "The save has an invalid " + key + "."
	if not _integer_in(data.get("integrity"), 1, 1000000):
		return "Only a surviving core can be saved."
	if typeof(data.get("spent")) != TYPE_BOOL or data.spent:
		return "Save between waves, when the next wave's savings bonus is available."
	if not _integer_in(data.get("speed"), 1, 3):
		return "The save has an unsupported game speed."
	if typeof(data.get("towers")) != TYPE_ARRAY or data.towers.size() > 1000:
		return "The save has an invalid fleet."
	for tower in data.towers:
		if typeof(tower) != TYPE_DICTIONARY or not _stable_id(tower.get("type_id")):
			return "A saved tower has an invalid type ID."
		if typeof(tower.get("position")) != TYPE_ARRAY or tower.position.size() != 3:
			return "A saved tower has an invalid position."
		for coordinate in tower.position:
			if not _number(coordinate) or absf(float(coordinate)) > 10000.0:
				return "A saved tower has an invalid position."
		if not _integer_in(tower.get("tier"), 0, 3) or not _integer_in(tower.get("branch"), -1, 1):
			return "A saved tower has an invalid upgrade."
		if (int(tower.tier) == 0) != (int(tower.branch) == -1):
			return "A saved tower has inconsistent upgrade prerequisites."
	return ""

static func read_document(path: String, kind: String) -> Dictionary:
	var primary := _read_file(path, kind)
	if primary.ok:
		primary["recovered"] = false
		return primary
	var backup := _read_file(path + ".bak", kind)
	if backup.ok:
		backup["recovered"] = true
		backup["warning"] = "Recovered the previous valid copy. " + primary.error
		return backup
	return primary

static func write_document(path: String, kind: String, data: Dictionary) -> Dictionary:
	var validation := _validate_document_data(kind, data)
	if not validation.is_empty():
		return _failure(validation)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return _failure("The save directory could not be created.")
	var envelope := {"version": VERSION, "kind": kind, "timestamp": Time.get_datetime_string_from_system(true), "data": data}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("The save could not be written. Check available disk space and permissions.")
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _read_file(temporary, kind).ok:
		return _failure("The new save could not be verified; the previous copy was preserved.")
	# A corrupt primary must never overwrite a healthy recovery copy.
	if _read_file(path, kind).ok:
		if DirAccess.copy_absolute(path, path + ".bak.tmp") != OK or DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak") != OK:
			return _failure("The recovery copy could not be updated; the previous save was preserved.")
	if DirAccess.rename_absolute(temporary, path) != OK:
		return _failure("The save could not be replaced; the recovery copy was preserved.")
	return {"ok": true, "error": "", "timestamp": envelope.timestamp}

static func _read_file(path: String, kind: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("No save exists in this slot.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("The save could not be opened.")
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return _failure("The save is too large or corrupt.")
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _failure("The save is corrupt and could not be read.")
	var document: Dictionary = json.data
	if not _integer_in(document.get("version"), VERSION, VERSION):
		return _failure("This save version is incompatible with this game.")
	if document.get("kind") != kind or typeof(document.get("timestamp")) != TYPE_STRING or typeof(document.get("data")) != TYPE_DICTIONARY:
		return _failure("The save header is corrupt.")
	var validation := _validate_document_data(kind, document.data)
	if not validation.is_empty():
		return _failure(validation)
	return {"ok": true, "error": "", "data": document.data, "timestamp": document.timestamp}

static func _validate_document_data(kind: String, data: Dictionary) -> String:
	if kind == "run":
		return validate_run(data)
	if kind == "progress":
		for map_id in data:
			if not _stable_id(map_id) or typeof(data[map_id]) != TYPE_DICTIONARY:
				return "Map completion progress is corrupt."
			if not _integer_in(data[map_id].get("wins"), 1, 1000000000):
				return "Map completion progress is corrupt."
	if kind == "settings":
		for key in ["fullscreen", "music_enabled", "sfx_enabled"]:
			if typeof(data.get(key)) != TYPE_BOOL:
				return "Settings contain an invalid toggle."
		for key in ["master_volume", "music_volume", "sfx_volume"]:
			if not _number(data.get(key)) or float(data[key]) < 0.0 or float(data[key]) > 1.0:
				return "Settings contain an invalid volume."
		if typeof(data.get("window_size")) != TYPE_ARRAY or data.window_size.size() != 2:
			return "Settings contain an invalid window size."
		if not _integer_in(data.window_size[0], 960, 7680) or not _integer_in(data.window_size[1], 600, 4320):
			return "Settings contain an unsupported window size."
	return ""

static func _slot_path(slot: int) -> String:
	return storage_root.path_join("slot_%d.json" % slot)

static func _stable_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 80:
		return false
	for character in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			return false
	return true

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func _integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
