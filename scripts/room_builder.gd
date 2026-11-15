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
## Fight rooms spawn this many patrolling monsters (fewer if the room is too
## cramped). Deeper rooms raise both ends by one (see _monster_count).
const MIN_MONSTERS := 2
const MAX_MONSTERS := 3
## Spike damage: base, plus up to this much more at full difficulty.
const SPIKE_DAMAGE := 3
const SPIKE_EXTRA_DAMAGE := 3
## Max blocks a monster walks either side of where it spawned.
const PATROL_REACH := 3

static func build(level: Node, room: Dictionary) -> void:
	var world: Node2D = level.get_node("Level001")
	var types = RunManager.RoomType
	var type: int = room.type
	var is_boss: bool = type == types.BOSS

	var rng := RandomNumberGenerator.new()
	rng.seed = RunManager.room_seed()
	var layout := RoomGenerator.generate(rng, type, RunManager.difficulty())
	RoomGenerator.paint(layout, world.get_node("TileMapLayer"))
	_place_spikes(world, layout)

	# The template's fixed camera and floor boundary don't fit generated rooms.
	for old in ["Camera2D", "LevelBounds"]:
		var node := world.get_node_or_null(old)
		if node:
			world.remove_child(node)
			node.queue_free()

	_place_player(world, layout)
	_setup_background(world)

	var monster: Node2D = world.get_node("Monsta")
	if is_boss:
		_setup_monster(monster, room.enemy, layout, layout.content_x, BOSS_SCALE)
		monster.modulate = BOSS_TINT # The boss stands its ground: no patrol.
	elif type == types.FIGHT:
		var count := _monster_count(rng, layout.difficulty)
		var columns := RoomGenerator.pick_monster_columns(layout, rng, count)
		# Copy the template before any patrol is attached, so copies don't inherit one.
		var monsters: Array[Node2D] = [monster]
		for i in range(1, columns.size()):
			var copy := monster.duplicate() as Node2D
			copy.name = "Monsta%d" % (i + 1)
			world.add_child(copy)
			monsters.append(copy)
		for i in columns.size():
			var m := monsters[i]
			_setup_monster(m, room.enemy, layout, columns[i], 1.0)
			_add_patrol(m, layout, columns[i], rng)
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

## 2-3 monsters early in the run, up to 3-4 near the boss.
static func _monster_count(rng: RandomNumberGenerator, difficulty: float) -> int:
	var lo := MIN_MONSTERS + (1 if difficulty >= 0.6 else 0)
	var hi := MAX_MONSTERS + (1 if difficulty >= 0.3 else 0)
	return rng.randi_range(lo, hi)

static func _place_spikes(world: Node2D, layout: RoomGenerator.Layout) -> void:
	var damage := SPIKE_DAMAGE + roundi(SPIKE_EXTRA_DAMAGE * layout.difficulty)
	for strip in layout.spikes:
		var spikes := Spikes.new()
		spikes.width = strip.w * RoomGenerator.BLOCK
		spikes.damage = damage
		spikes.position = Vector2(strip.x * RoomGenerator.BLOCK, strip.top * RoomGenerator.BLOCK)
		spikes.z_index = -1 # Iris and monsters draw over them.
		world.add_child(spikes)

static func _setup_monster(monster: Node2D, enemy: String, layout: RoomGenerator.Layout,
		column: int, monster_scale: float) -> void:
	monster.set_meta("Enemies", enemy)
	monster.add_to_group("room_guard") # Locks the exit until every guard is defeated.
	monster.scale = Vector2.ONE * monster_scale
	# Feet on the ground (this also fixes the boss sinking into the floor).
	monster.position = layout.ground_point(column) \
		- Vector2(0, MONSTER_HALF_HEIGHT * monster_scale + 1)

static func _add_patrol(monster: Node2D, layout: RoomGenerator.Layout, column: int,
		rng: RandomNumberGenerator) -> void:
	var span := RoomGenerator.patrol_span(layout, column, PATROL_REACH)
	var patrol := MonsterPatrol.new()
	patrol.speed = rng.randf_range(35.0, 60.0)
	# Walk between the centers of the first and last flat columns, so the monster
	# never hangs over a ledge or clips into a step.
	patrol.setup(layout.ground_point(span.x).x, layout.ground_point(span.y).x,
		-1.0 if rng.randf() < 0.5 else 1.0)
	monster.add_child(patrol)

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
