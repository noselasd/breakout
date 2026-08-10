package main

import rl "vendor:raylib"
tiles: [TILE_ROWS * TILE_COLS]Tile
Level :: struct {
	Level_number:    u8,
	total_tiles:     u8,
	remaining_tiles: u8,
	tiles:           []Tile,
}
init_level :: proc(level_number: u8) -> Level {
	if level_number == 0 || level_number == 1 {
		return level_1()
	} else if level_number == 2 {
		return level_2()
	} else if level_number == 3 {
		return level_3()
	} else {
		return level_n(level_number)
	}
}

level_1 :: proc() -> Level {
	num_tiles: u8 = 0
	for row in 0 ..< TILE_ROWS {
		for col in 0 ..< TILE_COLS {
			tile := &tiles[col * TILE_ROWS + row]
			if row == 2 || row == 9 {
				tile.alive = true
				tile.color = rl.RED if row == 2 else rl.GREEN
				tile.position.x = GRID_X_START + f32(col) * (TILE_WIDTH + TILE_SPACING)
				tile.position.y = WALL_WIDTH + 2.0 * TILE_HEIGHT + f32(row) * (TILE_HEIGHT + TILE_SPACING)
				num_tiles += 1
			} else {
				tile.alive = false
			}
		}
	}
	return Level{Level_number = 1, total_tiles = num_tiles, remaining_tiles = num_tiles, tiles = tiles[:]}
}

level_2 :: proc() -> Level {
	num_tiles: u8 = 0
	for row in 0 ..< TILE_ROWS {
		for col in 0 ..< TILE_COLS {
			tile := &tiles[col * TILE_ROWS + row]
			if (row == 2 || row == 3 || row == 8 || row == 9) && col != 4 && col != 5 {
				tile.alive = true
				tile.color = rl.RED if col < 5 else rl.GREEN
				tile.position.x = GRID_X_START + f32(col) * (TILE_WIDTH + TILE_SPACING)
				tile.position.y = WALL_WIDTH + 2.0 * TILE_HEIGHT + f32(row) * (TILE_HEIGHT + TILE_SPACING)
				num_tiles += 1
			} else {
				tile.alive = false
			}
		}
	}

	return Level{Level_number = 2, total_tiles = num_tiles, remaining_tiles = num_tiles, tiles = tiles[:]}

}

level_3 :: proc() -> Level {
	num_tiles: u8 = 0
	for row in 0 ..< TILE_ROWS {
		for col in 0 ..< TILE_COLS {
			tile := &tiles[col * TILE_ROWS + row]
			if (row != 3 && row != 4 &&  row != 5 && row != 9) {
				tile.alive = true
				tile.color = rl.BLUE if row < 5 else rl.ORANGE
				tile.position.x = GRID_X_START + f32(col) * (TILE_WIDTH + TILE_SPACING)
				tile.position.y = WALL_WIDTH + 2.0 * TILE_HEIGHT + f32(row) * (TILE_HEIGHT + TILE_SPACING)
				num_tiles += 1
			} else {
				tile.alive = false
			}
		}
	}
	return Level{Level_number = 3, total_tiles = num_tiles, remaining_tiles = num_tiles, tiles = tiles[:]}

}

level_n :: proc(level_number: u8) -> Level {
	for row in 0 ..< TILE_ROWS {
		factor := u8(((row * 255) + TILE_ROWS) / TILE_ROWS)
		colrA := rl.ColorAlphaBlend(rl.RED, rl.GREEN, rl.Color{255, 255, 255, factor})
		colrB := rl.ColorAlphaBlend(rl.GREEN, rl.BLUE, rl.Color{255, 255, 255, factor})
		for col in 0 ..< TILE_COLS {
			tile := &tiles[col * TILE_ROWS + row]
			tile.alive = true
			tile.color = colrA if factor < 128 else colrB
			tile.position.x = GRID_X_START + f32(col) * (TILE_WIDTH + TILE_SPACING)
			tile.position.y = WALL_WIDTH + 2.0 * TILE_HEIGHT + f32(row) * (TILE_HEIGHT + TILE_SPACING)
			if level_number >= 5 && row == 5 {
				tile.unbreakable = true
				tile.color = rl.GRAY
			}
		}
	}
	total_tiles: u8 = TILE_COLS * TILE_ROWS
	return Level {
		Level_number = level_number,
		total_tiles = total_tiles,
		remaining_tiles = total_tiles,
		tiles = tiles[:],
	}

}
