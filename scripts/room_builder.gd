class_name RoomBuilder
## Turns the level_001 template into a freshly generated room for the current run:
## procedural terrain (RoomGenerator), the player at the spawn, the room's monster or
## prop, an exit, a follow camera, the background and the HUD.
## level_001 supplies the player, the monster node and the background art; its
## hand-placed tiles, fixed camera and floor boundary are replaced.

const CAMPFIRE := preload("res://scripts/room_props/campfire.gd")
const CHEST := preload("res://scripts/room_props/treasure_chest.gd")
const EXIT := preload("res://scripts/room_props/room_exit.gd")
const HUD := preload("res://scenes/ui/exploration_hud.gd")

## The monster's sprite is 128px tall and centered on its origin.
const MONSTER_HALF_HEIGHT := 64.0
const BOSS_SCALE := 1.5
const BOSS_TINT := Color(1.0, 0.55, 0.55)
const BACKGROUND_SCALE := 0.75

static func build(level: Node, room: Dictionary) -> void:
	var world: Node2D = level.get_node("Level001")
	var types = RunManager.RoomType
	var type: int = room.type
	var is_boss: bool = type == types.BOSS

	var rng := RandomNumberGenerator.new()
	rng.seed = RunManager.room_seed()
	var layout := RoomGenerator.generate(rng, type)
	RoomGenerator.paint(layout, world.get_node("TileMapLayer"))

	# The template's fixed camera and floor boundary don't fit generated rooms.
	for old in ["Camera2D", "LevelBounds"]:
		var node := world.get_node_or_null(old)
		if node:
			world.remove_child(node)
			node.queue_free()

	_place_player(world, layout)
	_setup_background(world)

	var monster: Node2D = world.get_node("Monsta")
	if type == types.FIGHT or is_boss:
		monster.set_meta("Enemies", room.enemy)
		monster.add_to_group("room_guard") # Locks the exit until defeated.
		var monster_scale := BOSS_SCALE if is_boss else 1.0
		monster.scale = Vector2.ONE * monster_scale
		if is_boss:
			monster.modulate = BOSS_TINT
		# Feet on the ground (this also fixes the boss sinking into the floor).
		monster.position = layout.ground_point(layout.content_x) \
			- Vector2(0, MONSTER_HALF_HEIGHT * monster_scale + 1)
	else:
		world.remove_child(monster)
		monster.queue_free()

	if type == types.REST:
		_place(world, CAMPFIRE.new(), layout.ground_point(layout.content_x))
	elif type == types.TREASURE:
		_place(world, CHEST.new(), layout.ground_point(layout.content_x))

	if layout.exit_x >= 0: # The boss arena has no exit; beating the boss ends the run.
		var exit = EXIT.new()
		exit.trigger_size = Vector2(56, 110)
		_place(world, exit, layout.ground_point(layout.exit_x))

	level.add_child(HUD.new())

static func _place_player(world: Node2D, layout: RoomGenerator.Layout) -> void:
	var player: CharacterBody2D = world.get_node("Player 1")
	var shape := player.get_node("CollisionShape2D").shape as RectangleShape2D
	var half_height := shape.size.y / 2.0 if shape else 36.0
	player.position = layout.ground_point(layout.spawn_x) - Vector2(0, half_height + 1)

	# The room is laid out in Level001's local space, but the template places Level001
	# at an offset, and camera limits are global, so shift the bounds by it.
	var camera := RoomCamera.new()
	camera.setup(Rect2(world.global_position, layout.pixel_size()))
	player.add_child(camera)

static func _setup_background(world: Node2D) -> void:
	var layer := world.get_node_or_null("ParallaxBackground/ParallaxLayer") as ParallaxLayer
	if layer == null:
		return
	var bg := layer.get_node("Sprite2D") as Sprite2D
	bg.centered = false
	bg.position = Vector2.ZERO
	bg.scale = Vector2.ONE * BACKGROUND_SCALE
	# Distant background: scrolls slowly and repeats sideways across wide rooms.
	layer.motion_scale = Vector2(0.2, 0.1)
	layer.motion_mirroring = Vector2(bg.texture.get_width() * BACKGROUND_SCALE, 0)

static func _place(world: Node2D, prop: Node2D, ground: Vector2) -> void:
	prop.position = ground
	world.add_child(prop)
