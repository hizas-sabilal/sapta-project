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
##   - spikes on flat ground are 1 block wide (a running jump clears ~2.3 blocks
##     of air, but a 2-block strip plus Iris's width needs ~2.4: too tight).
##     Spike pits may be 2 wide: jumping ledge to ledge needs much less.
##     Spikes always have 2 safe blocks on each side, and JUMP_CLEARANCE open
##     blocks above them: a full jump needs ~3.6 blocks over the ground (Iris
##     1.1 + jump 2.5), and bonking the ceiling cuts the jump short.
##
## Rooms get harder deeper into the run (`difficulty` 0..1): wider, with more
## climbing features and more spikes.

const BLOCK := 64
const CELLS := 4 ## Cells per block side (64 / 16).
const MIN_TOP := 4 ## Highest allowed ground row; rows above it are headroom.
const END_PAD := 7 ## Flat columns before the right wall (exit lives here).
const JUMP_CLEARANCE := 4 ## Open blocks above ground that spike features need.

enum Kind { GRASS, DIRT, STONE, PLATFORM } ## Also used as TileSet source ids.

const GRASS_TEX := preload("res://resources/tiles/terrain_grass_block_top.png")
const DIRT_TEX := preload("res://resources/tiles/terrain_grass_block_center.png")

## Feature weights for the random walk, for the first room (EASY) and the last
## rooms before the boss (HARD); rooms in between blend the two.
const FEATURE_WEIGHTS_EASY := {
	"flat": 4, "step": 4, "drop": 1, "pit": 2,
	"platforms": 2, "ledges": 1, "shaft": 1, "tunnel": 1,
	"spikes": 1.5, "spike_pit": 0,
}
const FEATURE_WEIGHTS_HARD := {
	"flat": 2.5, "step": 3, "drop": 1, "pit": 2,
	"platforms": 3, "ledges": 3, "shaft": 2, "tunnel": 1,
	"spikes": 4, "spike_pit": 2.5,
}
## Extra blocks of width fight rooms get at full difficulty.
const HARD_EXTRA_WIDTH := 12

class Layout:
	var width := 0
	var height := 0
	var blocks := {} ## Vector2i -> Kind
	var surface := PackedInt32Array() ## Ground top row for each column.
	var flat_spots: Array[int] = [] ## Columns with flat ground and open headroom.
	var spawn_x := 2
	var exit_x := -1 ## -1 = no exit (boss arena).
	var content_x := -1 ## Where the monster / campfire / chest goes.
	var difficulty := 0.0 ## 0 = first room, 1 = hardest.
	## Spike strips: {"x": first column, "w": width in blocks, "top": ground row}.
	var spikes: Array[Dictionary] = []

	func is_spiked(col: int) -> bool:
		for strip in spikes:
			if col >= strip.x and col < strip.x + strip.w:
				return true
		return false

	## World position on top of the ground at a column (center of the block).
	func ground_point(x: int) -> Vector2:
		return Vector2((x + 0.5) * RoomGenerator.BLOCK, surface[x] * RoomGenerator.BLOCK)

	func pixel_size() -> Vector2:
		return Vector2(width * RoomGenerator.BLOCK, height * RoomGenerator.BLOCK)

# ---------------------------------------------------------------- Generation

static func generate(rng: RandomNumberGenerator, room_type: int, difficulty := 0.0) -> Layout:
	var types = RunManager.RoomType
	var layout := Layout.new()
	layout.difficulty = clampf(difficulty, 0.0, 1.0)
	if room_type == types.BOSS:
		layout.width = 26
		layout.height = 12
	elif room_type == types.FIGHT:
		layout.width = rng.randi_range(44, 60) + roundi(HARD_EXTRA_WIDTH * layout.difficulty)
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
			result = _try_feature(layout, rng, _pick_feature(rng, layout.difficulty), x, cur, remaining)
			if result.x != x:
				break
		if result.x == x: # Nothing fit; lay a short flat instead.
			result = Vector2i(_flat(layout, x, mini(2, remaining), cur, false), cur)
		x = result.x
		cur = result.y

	_flat(layout, x, layout.width - 1 - x, cur, true) # End pad.
	layout.exit_x = layout.width - 3
	_keep_flat_spots_off_spikes(layout)
	layout.content_x = _pick_content_column(layout, rng)
	_finalize(layout)
	return layout

static func _pick_feature(rng: RandomNumberGenerator, difficulty: float) -> String:
	var weights := {}
	var total := 0.0
	for feature in FEATURE_WEIGHTS_EASY:
		var w := lerpf(FEATURE_WEIGHTS_EASY[feature], FEATURE_WEIGHTS_HARD[feature], difficulty)
		weights[feature] = w
		total += w
	var roll := rng.randf() * total
	for feature in weights:
		roll -= weights[feature]
		if roll <= 0.0:
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

		"pit": # 1-2 wide (3 when hard), 2 deep: jump over it, or climb out.
			if cur + 2 > max_top or remaining < 6:
				return fail
			var w := rng.randi_range(1, 3 if layout.difficulty >= 0.5 else 2)
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

		"spikes": # 1-block spike strips on open ground with 2 safe blocks around
			# each: one strip, or (more often when hard) two in a row to hop.
			var count := 2 if rng.randf() < 0.25 + 0.5 * layout.difficulty else 1
			var n := 2 + 3 * count # 2 safe, then (spike + 2 safe) per strip.
			if remaining < n or cur - JUMP_CLEARANCE < 1: # Row 0 is the ceiling.
				return fail
			var nx := _flat(layout, x, n, cur, false)
			for i in count:
				_spikes(layout, x + 2 + 3 * i, 1, cur)
			return Vector2i(nx, cur)

		"spike_pit": # Pit with a spiked floor. Jump it; falling in hurts but you can climb out.
			if cur + 2 > max_top or remaining < 5 or cur - JUMP_CLEARANCE < 1:
				return fail
			var w := 2 if rng.randf() < 0.5 * layout.difficulty else 1
			var nx := _flat(layout, x, 1, cur, false)
			_flat(layout, nx, w, cur + 2, false)
			_spikes(layout, nx, w, cur + 2)
			return Vector2i(_flat(layout, nx + w, 2, cur, false), cur)
	return fail

## Sets ground at row `top` for n columns. Records interior columns as flat spots.
static func _flat(layout: Layout, x: int, n: int, top: int, record: bool) -> int:
	for i in n:
		layout.surface[x + i] = top
		if record and n >= 3 and i > 0 and i < n - 1:
			layout.flat_spots.append(x + i)
	return x + n

## Spikes standing on the ground at row `top`. Features only place these on
## columns with nothing above them, so a jump over them is never blocked.
static func _spikes(layout: Layout, x: int, w: int, top: int) -> void:
	layout.spikes.append({"x": x, "w": w, "top": top})

## Monsters and props stand on flat spots; keep them off and next to spikes.
static func _keep_flat_spots_off_spikes(layout: Layout) -> void:
	var kept: Array[int] = []
	for c in layout.flat_spots:
		if not (layout.is_spiked(c) or layout.is_spiked(c - 1) or layout.is_spiked(c + 1)):
			kept.append(c)
	layout.flat_spots = kept

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

## Up to `count` distinct flat columns for patrolling monsters, spread through the
## room (away from the spawn and the exit) and at least MONSTER_SPACING apart.
## Falls back to content_x so a fight room always has at least one monster.
const MONSTER_SPACING := 7
const MONSTER_SPACING_HARD := 5 ## Packed tighter at full difficulty.

static func pick_monster_columns(layout: Layout, rng: RandomNumberGenerator, count: int) -> Array[int]:
	var lo := layout.spawn_x + 6
	var hi := (layout.exit_x - 3) if layout.exit_x >= 0 else layout.width - 3
	var candidates := layout.flat_spots.filter(func(c): return c >= lo and c <= hi)
	# Shuffle with the room's rng so a run seed always gives the same placement.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var picked: Array[int] = []
	for c in candidates:
		if picked.size() >= count:
			break
		var spacing := roundi(lerpf(MONSTER_SPACING, MONSTER_SPACING_HARD, layout.difficulty))
		if picked.all(func(p): return absi(p - c) >= spacing):
			picked.append(c)
	if picked.is_empty():
		picked.append(layout.content_x)
	picked.sort()
	return picked

## How far a monster at column x can patrol: the run of columns at the same ground
## height with nothing in the 2 blocks above it, capped at `max_reach` each side
## and kept clear of the spawn and the exit. Returns Vector2i(first_col, last_col).
static func patrol_span(layout: Layout, x: int, max_reach: int) -> Vector2i:
	var lo_limit := layout.spawn_x + 3
	var hi_limit := (layout.exit_x - 2) if layout.exit_x >= 0 else layout.width - 2
	var first := x
	while first - 1 >= lo_limit and x - (first - 1) <= max_reach and _walkable(layout, first - 1, layout.surface[x]):
		first -= 1
	var last := x
	while last + 1 <= hi_limit and (last + 1) - x <= max_reach and _walkable(layout, last + 1, layout.surface[x]):
		last += 1
	return Vector2i(first, last)

static func _walkable(layout: Layout, col: int, top: int) -> bool:
	if col <= 0 or col >= layout.width - 1 or layout.surface[col] != top or layout.is_spiked(col):
		return false
	return not layout.blocks.has(Vector2i(col, top - 1)) and not layout.blocks.has(Vector2i(col, top - 2))

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
