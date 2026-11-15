extends Node
## Player settings that survive between sessions. For now: rebindable keys.
## Defaults come from the Input Map in project.godot; overrides are saved to
## user://settings.cfg and applied on startup.

signal bindings_changed

const SAVE_PATH := "user://settings.cfg"
const MAX_KEYS_PER_ACTION := 2

## Actions shown on the Options screen, in display order.
const REBINDABLE := [
	{"group": "Movement", "action": "Move left", "label": "Move left"},
	{"group": "Movement", "action": "Move right", "label": "Move right"},
	{"group": "Movement", "action": "Move up", "label": "Jump"},
	{"group": "Movement", "action": "Dash", "label": "Dash"},
	{"group": "Cards", "action": "card_prev", "label": "Previous card"},
	{"group": "Cards", "action": "card_next", "label": "Next card"},
	{"group": "Cards", "action": "card_select", "label": "Select / deselect card"},
	{"group": "Cards", "action": "card_execute", "label": "Action! (play selected)"},
	{"group": "Cards", "action": "card_1", "label": "Card 1"},
	{"group": "Cards", "action": "card_2", "label": "Card 2"},
	{"group": "Cards", "action": "card_3", "label": "Card 3"},
]

## Keys that can't be bound because something else always owns them.
const RESERVED_KEYS := [KEY_ESCAPE, KEY_F11]

var _defaults := {} ## action -> Array[int] of physical keycodes from project.godot

func _ready() -> void:
	for entry in REBINDABLE:
		_defaults[entry.action] = get_keys(entry.action)
	_load()

## Physical keycodes bound to an action, in order.
func get_keys(action: String) -> Array[int]:
	var keys: Array[int] = []
	if not InputMap.has_action(action):
		return keys
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code != 0 and not keys.has(code):
				keys.append(code)
	return keys

## Binds `key` to slot `slot` of `action`. Within the same group, the key is
## taken away from any other action so one press never means two things;
## that action gets the replaced key instead (a swap), so it never ends up
## with no keys. Returns the label of the action it was taken from ("" if none).
func set_key(action: String, slot: int, key: int) -> String:
	var keys := get_keys(action)
	var replaced: int = keys[slot] if slot < keys.size() else KEY_NONE
	var stolen_from := ""
	var group := _group_of(action)
	for entry in REBINDABLE:
		if entry.action != action and entry.group == group:
			var other := get_keys(entry.action)
			var at := other.find(key)
			if at >= 0:
				if replaced != KEY_NONE and not other.has(replaced):
					other[at] = replaced
				else:
					other.remove_at(at)
				_apply(entry.action, other)
				stolen_from = entry.label

	keys.erase(key)
	if slot < keys.size():
		keys[slot] = key
	else:
		keys.append(key)
	_apply(action, keys.slice(0, MAX_KEYS_PER_ACTION))
	_save()
	return stolen_from

## Removes the key in `slot`. The last key of an action can't be removed.
func clear_key(action: String, slot: int) -> bool:
	var keys := get_keys(action)
	if keys.size() <= 1 or slot >= keys.size():
		return false
	keys.remove_at(slot)
	_apply(action, keys)
	_save()
	return true

func reset_to_defaults() -> void:
	for action in _defaults:
		_apply(action, _defaults[action])
	_save()

func is_reserved(key: int) -> bool:
	return RESERVED_KEYS.has(key)

## Human-readable name for a physical key, using the current keyboard layout.
func key_name(physical: int) -> String:
	var mapped := KEY_NONE
	if DisplayServer.get_name() != "headless": # Headless has no keyboard layout.
		mapped = DisplayServer.keyboard_get_keycode_from_physical(physical)
	return OS.get_keycode_string(mapped if mapped != KEY_NONE else physical)

## "A / Left" style text for hints and tutorials.
func describe(action: String) -> String:
	var names: PackedStringArray = []
	for key in get_keys(action):
		names.append(key_name(key))
	return " / ".join(names) if not names.is_empty() else "(unbound)"

func _group_of(action: String) -> String:
	for entry in REBINDABLE:
		if entry.action == action:
			return entry.group
	return ""

## Replaces the action's keyboard events, keeping any non-key events.
func _apply(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.device = -1 # Any keyboard.
		InputMap.action_add_event(action, event)
	bindings_changed.emit()

func _save() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH) # Keep any other sections; a missing file is fine.
	for entry in REBINDABLE:
		config.set_value("input", entry.action, get_keys(entry.action))
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for entry in REBINDABLE:
		var saved = config.get_value("input", entry.action, null)
		if saved is Array and not saved.is_empty():
			_apply(entry.action, saved)
