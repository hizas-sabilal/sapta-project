class_name RoomBuilder
## Turns the level_001 layout into a specific room (fight / treasure / rest / boss)
## by adjusting its monster and adding props. With one hand-made layout this gives
## every room the same ground; later you can add more layout scenes and pick one at random.

const CAMPFIRE := preload("res://scripts/room_props/campfire.gd")
const CHEST := preload("res://scripts/room_props/treasure_chest.gd")
const EXIT := preload("res://scripts/room_props/room_exit.gd")
const HUD := preload("res://scenes/ui/exploration_hud.gd")

## World-space measurements of level_001 (ground top from its TileMapLayer,
## edges from its Camera2D view: x -591 .. 689).
const GROUND_Y := 172.0
const LEFT_EDGE := -591.0
const RIGHT_EDGE := 689.0
const CENTER_X := 66.0
const EXIT_X := 630.0

const BOSS_SCALE := 1.5
const BOSS_TINT := Color(1.0, 0.55, 0.55)

static func build(level: Node, room: Dictionary) -> void:
	var world: Node2D = level.get_node("Level001")
	var monster: Node2D = world.get_node("Monsta")
	var types = RunManager.RoomType
	var type: int = room.type
	var is_boss: bool = type == types.BOSS

	_add_side_walls(world)

	if type == types.FIGHT or is_boss:
		monster.set_meta("Enemies", room.enemy)
		monster.add_to_group("room_guard") # Locks the exit until defeated.
		if is_boss:
			monster.scale = Vector2.ONE * BOSS_SCALE
			monster.modulate = BOSS_TINT
	else:
		world.remove_child(monster)
		monster.queue_free()

	if type == types.REST:
		_place(world, CAMPFIRE.new(), CENTER_X)
	elif type == types.TREASURE:
		_place(world, CHEST.new(), CENTER_X)

	if not is_boss: # Beating the boss ends the run.
		var exit = EXIT.new()
		exit.trigger_size = Vector2(56, 110)
		_place(world, exit, EXIT_X)

	level.add_child(HUD.new())

static func _place(world: Node2D, prop: Node2D, x: float) -> void:
	prop.position = Vector2(x, GROUND_Y)
	world.add_child(prop)

## Invisible walls at the screen edges so Iris can't walk out of the room.
static func _add_side_walls(world: Node2D) -> void:
	for side in [[Vector2.RIGHT, LEFT_EDGE], [Vector2.LEFT, -RIGHT_EDGE]]:
		var boundary := WorldBoundaryShape2D.new()
		boundary.normal = side[0]
		boundary.distance = side[1]
		var collision := CollisionShape2D.new()
		collision.shape = boundary
		var wall := StaticBody2D.new()
		wall.add_child(collision)
		world.add_child(wall)
