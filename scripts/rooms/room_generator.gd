class_name RoomGenerator
## Procedural side-view rooms for exploration.
##
## Rooms are designed on a grid of 64px "blocks"; each block is painted as 4x4
## cells of the 16px tileset (the grass/dirt textures are 64x64 images).
## A room is built left -> right from "features" (steps, pits, platform fields,
## ledge climbs, wall-jump shafts, tunnels). Every feature stays inside Iris's
## movement limits, so the exit is always reachable:
##   - rise per jump  <= 2 blocks (jump height is 2.5 blocks)
##   - headroom       >= 2 blocks wherever she has to walk (she is ~1.1 blocks tall)
##   - wall-jump shafts are 1 block wide and 4 blocks tall

const BLOCK := 64
const CELLS := 4 ## Cells per block side (64 / 16).
const MIN_TOP := 4 ## Highest allowed ground row; rows above it are headroom.
const END_PAD := 7 ## Flat columns before the right wall (exit lives here).

enum Kind { GRASS, DIRT, STONE, PLATFORM } ## Also used as TileSet source ids.

const GRASS_TEX := preload("res://resources/tiles/terrain_grass_block_top.png")
const DIRT_TEX := preload("res://resources/tiles/terrain_grass_block_center.png")

## Feature weights for the random walk. Tweak to change how rooms feel.
const FEATURE_WEIGHTS := {
	"flat": 3, "step": 4, "drop": 1, "pit": 2,
	"platforms": 2, "ledges": 2, "shaft": 1, "tunnel": 1,
}

class Layout:
	var width := 0
	var height := 0
	var blocks := {} ## Vector2i -> Kind
	var surface := PackedInt32Array() ## Ground top row for each column.
	var flat_spots: Array[int] = [] ## Columns with flat ground and open headroom.
	var spawn_x := 2
	var exit_x := -1 ## -1 = no exit (boss arena).
	var content_x := -1 ## Where the monster / campfire / chest goes.

	## World position on top of the ground at a column (center of the block).
	func ground_point(x: int) -> Vector2:
		return Vector2((x + 0.5) * RoomGenerator.BLOCK, surface[x] * RoomGenerator.BLOCK)

	func pixel_size() -> Vector2:
		return Vector2(width * RoomGenerator.BLOCK, height * RoomGenerator.BLOCK)

# ---------------------------------------------------------------- Generation

static func generate(rng: RandomNumberGenerator, room_type: int) -> Layout:
	var types = RunManager.RoomType
	var layout := Layout.new()
	if room_type == types.BOSS:
		layout.width = 26
		layout.height = 12
	elif room_type == types.FIGHT:
		layout.width = rng.randi_range(44, 60)
		layout.height = rng.randi_range(13, 17)
	else: # Rest / treasure: shorter breather rooms.
		layout.width = rng.randi_range(28, 36)
		layout.height = rng.randi_range(12, 14)
	layout.surface.resize(layout.width)

	var max_top := layout.height - 2
	var cur := rng.randi_range(max_top - 3, max_top) # Start low so there's room to climb.
	var x := _flat(layout, 1, 4, cur, false) # Spawn pad.

	if room_type == types.BOSS:
		_flat(layout, x, layout.width - 1 - x, cur, false)
		_platform(layout, 6, 3, cur - 2)
		_platform(layout, 14, 3, cur - 2)
		layout.content_x = layout.width - 5
		_finalize(layout)
		return layout

	while x < layout.width - 1 - END_PAD:
		var remaining := layout.width - 1 - END_PAD - x
		var result := Vector2i(x, cur)
		for attempt in 6: # Re-roll features that don't fit at this height.
			result = _try_feature(layout, rng, _pick_feature(rng), x, cur, remaining)
			if result.x != x:
				break
		if result.x == x: # Nothing fit; lay a short flat instead.
			result = Vector2i(_flat(layout, x, mini(2, remaining), cur, false), cur)
		x = result.x
		cur = result.y

	_flat(layout, x, layout.width - 1 - x, cur, true) # End pad.
	layout.exit_x = layout.width - 3
	layout.content_x = _pick_content_column(layout, rng)
	_finalize(layout)
	return layout

static func _pick_feature(rng: RandomNumberGenerator) -> String:
	var total := 0
	for w in FEATURE_WEIGHTS.values():
		total += w
	var roll := rng.randi_range(1, total)
	for feature in FEATURE_WEIGHTS:
		roll -= FEATURE_WEIGHTS[feature]
		if roll <= 0:
			return feature
	return "flat"

## Builds one feature starting at column x with ground at row cur.
## Returns Vector2i(next_x, ground_row_at_end); next_x == x means "didn't fit".
## Every feature ends with ground at the returned row, so the next one can start there.
static func _try_feature(layout: Layout, rng: RandomNumberGenerator, feature: String,
		x: int, cur: int, remaining: int) -> Vector2i:
	var max_top := layout.height - 2
	var fail := Vector2i(x, cur)
	match feature:
		"flat":
			var n := mini(rng.randi_range(3, 5), remaining)
			return Vector2i(_flat(layout, x, n, cur, true), cur)

		"step": # Up or down by 1-2 blocks, drifting back toward mid-height.
			var middle := (MIN_TOP + max_top) / 2.0
			var toward_middle := -1 if cur > middle else 1
			var dir := toward_middle if rng.randf() < 0.7 else -toward_middle
			var next := clampi(cur + dir * rng.randi_range(1, 2), MIN_TOP, max_top)
			if next == cur:
				return fail
			var n := mini(rng.randi_range(2, 4), remaining)
			return Vector2i(_flat(layout, x, n, next, true), next)

		"drop": # Bigger one-way drop.
			if cur + 2 > max_top or remaining < 3:
				return fail
			var next := mini(cur + rng.randi_range(2, 4), max_top)
			var n := mini(rng.randi_range(3, 5), remaining)
			return Vector2i(_flat(layout, x, n, next, true), next)

		"pit": # 1-2 wide, 2 deep: jump over it, or climb out.
			if cur + 2 > max_top or remaining < 5:
				return fail
			var w := rng.randi_range(1, 2)
			var nx := _flat(layout, x, 1, cur, false)
			nx = _flat(layout, nx, w, cur + 2, false)
			return Vector2i(_flat(layout, nx, 2, cur, false), cur)

		"platforms": # Sunken area with one-way platforms to hop across.
			var k := rng.randi_range(2, 3)
			var n := 3 * k + 1
			if cur + 4 > max_top or remaining < n + 3:
				return fail
			var nx := _flat(layout, x, n - 1, cur + 4, false) # Pit floor (2 blocks headroom under platforms).
			nx = _flat(layout, nx, 1, cur + 2, false) # Step to climb out if you fall in.
			for i in k:
				_platform(layout, x + 1 + 3 * i, 2, cur + 1)
			return Vector2i(_flat(layout, nx, 2, cur, false), cur)

		"ledges": # Climb 4 blocks up via two one-way ledges.
			var target := cur - 4
			if target < MIN_TOP or remaining < 7:
				return fail
			var nx := _flat(layout, x, 5, cur, false)
			_platform(layout, x + 1, 2, cur - 2)
			_platform(layout, x + 3, 2, target)
			return Vector2i(_flat(layout, nx, 2, target, false), target)

		"shaft": # Wall-jump between a hanging wall and a 4-block cliff.
			var target := cur - 4
			if target < MIN_TOP or remaining < 5:
				return fail
			var nx := _flat(layout, x, 2, cur, false) # Column x: under the hanging wall; x+1: the shaft.
			_stone_column(layout, x, 1, cur - 3) # Leaves 2 blocks to walk under.
			return Vector2i(_flat(layout, nx, 3, target, false), target)

		"tunnel": # Low ceiling; ends with open headroom so the next step is jumpable.
			if remaining < 6:
				return fail
			var n := mini(rng.randi_range(4, 7), remaining - 2)
			var nx := _flat(layout, x, n, cur, false)
			for i in n:
				_stone_column(layout, x + i, 1, cur - 3)
			return Vector2i(_flat(layout, nx, 2, cur, false), cur)
	return fail

## Sets ground at row `top` for n columns. Records interior columns as flat spots.
static func _flat(layout: Layout, x: int, n: int, top: int, record: bool) -> int:
	for i in n:
		layout.surface[x + i] = top
		if record and n >= 3 and i > 0 and i < n - 1:
			layout.flat_spots.append(x + i)
	return x + n

static func _platform(layout: Layout, x: int, w: int, top: int) -> void:
	for i in w:
		layout.blocks[Vector2i(x + i, top)] = Kind.PLATFORM

static func _stone_column(layout: Layout, x: int, from_row: int, to_row: int) -> void:
	for row in range(from_row, to_row + 1):
		layout.blocks[Vector2i(x, row)] = Kind.STONE

## The room's monster/prop goes on flat ground in the back half, away from the exit.
static func _pick_content_column(layout: Layout, rng: RandomNumberGenerator) -> int:
	var lo := int(layout.width * 0.45)
	var hi := layout.exit_x - 4
	var candidates := layout.flat_spots.filter(func(c): return c >= lo and c <= hi)
	if candidates.is_empty():
		return layout.width - 6 # Inside the end pad.
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## Fills ground below the surface and adds the stone border.
static func _finalize(layout: Layout) -> void:
	for col in layout.width:
		if col == 0 or col == layout.width - 1:
			for row in layout.height:
				layout.blocks[Vector2i(col, row)] = Kind.STONE
			continue
		layout.blocks[Vector2i(col, 0)] = Kind.STONE # Ceiling.
		var top := layout.surface[col]
		for row in range(top, layout.height):
			var kind := Kind.GRASS
			if row > top + 2:
				kind = Kind.STONE
			elif row > top:
				kind = Kind.DIRT
			layout.blocks[Vector2i(col, row)] = kind

# ---------------------------------------------------------------- Painting

static var _tile_set: TileSet

static func paint(layout: Layout, layer: TileMapLayer) -> void:
	layer.clear()
	layer.tile_set = get_tile_set()
	layer.position = Vector2.ZERO
	for block: Vector2i in layout.blocks:
		var kind: int = layout.blocks[block]
		var rows := 1 if kind == Kind.PLATFORM else CELLS # Platforms are a thin grass slab.
		for cy in rows:
			for cx in CELLS:
				layer.set_cell(block * CELLS + Vector2i(cx, cy), kind, Vector2i(cx, cy))

## Built once in code: grass, dirt, placeholder stone, and one-way platform sources.
static func get_tile_set() -> TileSet:
	if _tile_set:
		return _tile_set
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	_add_block_source(ts, Kind.GRASS, GRASS_TEX, false)
	_add_block_source(ts, Kind.DIRT, DIRT_TEX, false)
	_add_block_source(ts, Kind.STONE, _make_stone_texture(), false)
	_add_block_source(ts, Kind.PLATFORM, GRASS_TEX, true)
	_tile_set = ts
	return ts

static func _add_block_source(ts: TileSet, id: int, texture: Texture2D, one_way: bool) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	ts.add_source(source, id)
	var square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for cy in CELLS:
		for cx in CELLS:
			var coords := Vector2i(cx, cy)
			source.create_tile(coords)
			if one_way and cy > 0:
				continue # Platforms only collide on their top row.
			var data := source.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
			if one_way:
				data.set_collision_polygon_one_way(0, 0, true)

## Placeholder wall art: grey bricks, generated so no asset is needed.
static func _make_stone_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var base := Color(0.30, 0.31, 0.36)
	var mortar := Color(0.17, 0.17, 0.21)
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	for y in 64:
		var row_offset := 16 if (y / 16) % 2 == 1 else 0
		for x in 64:
			if y % 16 == 0 or (x + row_offset) % 32 == 0:
				img.set_pixel(x, y, mortar)
			else:
				var f := noise.randf_range(0.9, 1.1)
				img.set_pixel(x, y, Color(base.r * f, base.g * f, base.b * f))
	return ImageTexture.create_from_image(img)
