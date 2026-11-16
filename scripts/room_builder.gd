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
## Coins in a room that has them (see Progress.coin_room_chance()).
const COINS_MIN := 1
const COINS_MAX := 3
const COIN_GROUND_HEIGHT := 40.0 ## Walking through picks it up.
## Over spikes: a jump that clears a 1-block strip is near its peak there,
## with Iris's body ~162-195px up for every clean takeoff, so a full jump
## over the spikes always grabs it (a short hop doesn't).
const COIN_SPIKE_HEIGHT := 175.0
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

	if not is_boss:
		_place_coins(world, layout, rng, _place_ammo(world, layout, rng))

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

## Some rooms (Progress.coin_room_chance()) have a few coins: floating over
## open ground, and over spike traps so jumping them pays off.
## Some rooms (WeaponLibrary.AMMO_ROOM_CHANCE) have an ammo box on open ground,
## while a gun is equipped. Returns the column it took (-1 if none), so coins
## don't land on it.
static func _place_ammo(world: Node2D, layout: RoomGenerator.Layout,
		rng: RandomNumberGenerator) -> int:
	if not RunManager.weapon.uses_ammo() or rng.randf() >= WeaponLibrary.AMMO_ROOM_CHANCE:
		return -1
	# Same rules as coins: clear of the chest / campfire and before the exit door.
	var columns := Array(layout.flat_spots).filter(func(col):
		return absi(col - layout.content_x) > 1 and col < layout.exit_x - 1)
	if columns.is_empty():
		return -1
	var col: int = columns[rng.randi_range(0, columns.size() - 1)]
	var box := AmmoBox.new()
	_place(world, box, layout.ground_point(col))
	return col

static func _place_coins(world: Node2D, layout: RoomGenerator.Layout,
		rng: RandomNumberGenerator, ammo_column := -1) -> void:
	if rng.randf() >= Progress.coin_room_chance():
		return
	var spots: Array[Vector2] = []
	for strip in layout.spikes:
		var center_x: float = (strip.x + strip.w / 2.0) * RoomGenerator.BLOCK
		var is_pit: bool = layout.surface[strip.x - 1] < strip.top
		var ledge_y: float = (strip.top - (2 if is_pit else 0)) * RoomGenerator.BLOCK
		spots.append(Vector2(center_x, ledge_y - (50.0 if is_pit else COIN_SPIKE_HEIGHT)))
	for col in layout.flat_spots:
		# Leave the chest / campfire spot alone, and nothing at or past the exit
		# door: touching the door leaves the room, so those could never be reached.
		if absi(col - layout.content_x) > 1 and col < layout.exit_x - 1 and col != ammo_column:
			spots.append(layout.ground_point(col) - Vector2(0, COIN_GROUND_HEIGHT))
	# Shuffle with the room's rng so a run seed always gives the same coins.
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var count := mini(rng.randi_range(COINS_MIN, COINS_MAX), spots.size())
	for i in count:
		var coin := Coin.new()
		coin.position = spots[i]
		world.add_child(coin)

static func _place_spikes(world: Node2D, layout: RoomGenerator.Layout) -> void:
	var damage := SPIKE_DAMAGE + roundi(SPIKE_EXTRA_DAMAGE * layout.difficulty)
	damage = maxi(damage - Progress.bonus("thick_soles"), 1) # Skill tree.
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
