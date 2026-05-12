extends Node

# ── Level Definitions ────────────────────────────────────────────────────────
# To add a level: append a new dictionary entry.
# col  — 0-indexed horizontal slot in the graph (drives X position)
# row  — vertical track within a chapter (0 = center, ±1 = branch above/below)
# prerequisites — array of level IDs that must ALL be completed to unlock this one
#                 (empty = always unlocked / chapter start)
const LEVELS: Array = [
	# ── Chapter 1: Light ──────────────────────────────────────────────────────
	{
		"id": "ch1_l1", "name": "The Awakening",
		"scene": "res://levels/chapter_1/level1.tscn",
		"chapter": 1, "col": 0, "row": 0, "prerequisites": []
	},
	{
		"id": "ch1_l2", "name": "First Shadows",
		"scene": "res://levels/chapter_1/level2.tscn",
		"chapter": 1, "col": 1, "row": 0, "prerequisites": ["ch1_l1"]
	},
	{
		"id": "ch1_l3", "name": "Mirror Garden",
		"scene": "res://levels/chapter_1/level3.tscn",
		"chapter": 1, "col": 2, "row": 0, "prerequisites": ["ch1_l2"]
	},
	{
		"id": "ch1_l4", "name": "Prism Falls",
		"scene": "res://levels/chapter_1/level4.tscn",
		"chapter": 1, "col": 3, "row": 0, "prerequisites": ["ch1_l3"]
	},
	{
		"id": "ch1_l5", "name": "Eclipse Chamber",
		"scene": "res://levels/chapter_1/level5.tscn",
		"chapter": 1, "col": 4, "row": 0, "prerequisites": ["ch1_l4"]
	},
	{
		"id": "ch1_l6", "name": "Radiant Depths",
		"scene": "res://levels/chapter_1/level6.tscn",
		"chapter": 1, "col": 5, "row": 0, "prerequisites": ["ch1_l5"]
	},
	{
		"id": "ch1_l7", "name": "The Lighthouse",
		"scene": "res://levels/chapter_1/level7.tscn",
		"chapter": 1, "col": 5, "row": 1, "prerequisites": ["ch1_l6"]
	},
	# ── Chapter 2: Flow — add levels here as you build them ──────────────────
	# Example:
	# {
	# 	"id": "ch2_l1", "name": "First Step",
	# 	"scene": "res://levels/chapter_2/level1.tscn",
	# 	"chapter": 2, "col": 0, "row": 0, "prerequisites": []
	# },
	# ── Chapter 3: Convergence — needs last Ch1 + last Ch2 completed ─────────
	# Example (set prerequisites to the final levels of both previous chapters):
	# {
	# 	"id": "ch3_l1", "name": "Merge Point",
	# 	"scene": "res://levels/chapter_3/level1.tscn",
	# 	"chapter": 3, "col": 0, "row": 0,
	# 	"prerequisites": ["ch1_l7", "ch2_lX"]  # last of each chapter
	# },
	{
		"id": "ch1_l8", "name": "Level 8",
		"scene": "res://levels/chapter_1/level8.tscn",
		"chapter": 1, "col": 4, "row": 1, "prerequisites": ["ch1_l7"]
	},
	{
		"id": "ch1_l9", "name": "Level 9",
		"scene": "res://levels/chapter_1/level9.tscn",
		"chapter": 1, "col": 3, "row": 1, "prerequisites": ["ch1_l8"]
	},
	{
		"id": "ch1_l10", "name": "Level 10",
		"scene": "res://levels/chapter_1/level10.tscn",
		"chapter": 1, "col": 2, "row": 1, "prerequisites": ["ch1_l9"]
	},
	{
		"id": "ch1_l11", "name": "Level 11",
		"scene": "res://levels/chapter_1/level11.tscn",
		"chapter": 1, "col": 1, "row": 1, "prerequisites": ["ch1_l10"]
	},
]

const CHAPTER_NAMES: Dictionary = {
	1: "Chapter I — Light",
	2: "Chapter II — Flow",
	3: "Chapter III — Convergence",
}

const SAVE_PATH: String = "user://save.json"

# Persisted settings (0.0–1.0 linear scale)
var music_volume: float = 0.80
var sfx_volume:   float = 0.80

var _all_locked: bool = false
var _completed: Array[String] = []
var _unlocked:  Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


# ── Public API ───────────────────────────────────────────────────────────────

func mark_completed(level_id: String) -> void:
	if level_id == "" or level_id in _completed:
		return
	_all_locked = false
	_completed.append(level_id)
	_recompute_unlocked()
	_save()


func is_completed(level_id: String) -> bool:
	return level_id in _completed


func is_unlocked(level_id: String) -> bool:
	return level_id in _unlocked


func get_level(level_id: String) -> Dictionary:
	for level in LEVELS:
		if level["id"] == level_id:
			return level
	return {}


func get_chapters() -> Array:
	var chapters: Array = []
	for level in LEVELS:
		var ch: int = level["chapter"]
		if ch not in chapters:
			chapters.append(ch)
	chapters.sort()
	return chapters


func get_levels_for_chapter(chapter: int) -> Array:
	var result: Array = []
	for level in LEVELS:
		if level["chapter"] == chapter:
			result.append(level)
	return result


func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.2)
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		var db := linear_to_db(music_volume) if music_volume > 0.0 else -80.0
		AudioServer.set_bus_volume_db(idx, db)
	_save()


func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.2)
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		var db := linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0
		AudioServer.set_bus_volume_db(idx, db)
	_save()


func reset_progress(lock_all: bool = false) -> void:
	_completed.clear()
	_all_locked = lock_all
	_recompute_unlocked()
	_save()


# ── Internal ─────────────────────────────────────────────────────────────────

func _recompute_unlocked() -> void:
	_unlocked.clear()
	if _all_locked:
		return
	for level in LEVELS:
		if _prereqs_met(level):
			_unlocked.append(level["id"])


func _prereqs_met(level: Dictionary) -> bool:
	for req in level["prerequisites"]:
		if req not in _completed:
			return false
	return true


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"completed":     _completed,
		"all_locked":    _all_locked,
		"music_volume":  music_volume,
		"sfx_volume":    sfx_volume,
	}))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_recompute_unlocked()
		_apply_volumes()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_recompute_unlocked()
		_apply_volumes()
		return
	var text   := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		_recompute_unlocked()
		_apply_volumes()
		return

	var raw: Array = data.get("completed", [])
	_completed.clear()
	for s in raw:
		_completed.append(str(s))

	_all_locked = bool(data.get("all_locked", false))
	music_volume = clampf(float(data.get("music_volume", 0.80)), 0.0, 1.2)
	sfx_volume   = clampf(float(data.get("sfx_volume",   0.80)), 0.0, 1.2)

	# Migrate the temporary "everything locked" selector reset back to a fresh-save state.
	if _all_locked and _completed.is_empty():
		_all_locked = false

	_recompute_unlocked()
	_apply_volumes()


func _apply_volumes() -> void:
	# Re-apply without saving to avoid write on first boot
	var mi := AudioServer.get_bus_index("Music")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, linear_to_db(music_volume) if music_volume > 0.0 else -80.0)
	var si := AudioServer.get_bus_index("SFX")
	if si >= 0:
		AudioServer.set_bus_volume_db(si, linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0)
