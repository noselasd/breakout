package main

import rl "vendor:raylib"
tiles: [TILE_ROWS * TILE_COLS]Tile
Level :: struct {
	Level_number:    u8,
	total_tiles:     u8,
	remaining_tiles: u8,
	tiles:           []Tile,
}
TileKind :: enum {
	Normal,
	Unbreakable,
	Blank,
}

TileType :: struct {
	color: rl.Color,
	lives: u8,
	kind:  TileKind,
}
COL_WHITE :: rl.Color{252, 252, 252, 255}
COL_ORANGE :: rl.Color{252, 116, 96, 255}
COL_LIGHTBLUE :: rl.Color{60, 188, 252, 255}
COL_GREEN :: rl.Color{128, 208, 16, 255}
COL_RED :: rl.Color{216, 40, 0, 255}
COL_BLUE :: rl.Color{0, 112, 236, 255}
COL_PINK :: rl.Color{252, 116, 180, 255}
COL_YELLOW :: rl.Color{252, 152, 56, 255}
COL_SILVER :: rl.Color{188, 188, 188, 255}
COL_GOLD :: rl.Color{240, 188, 60, 255}

// odinfmt: disable
WT :: TileType{COL_WHITE ,       1, .Normal      } // 50 points
OT :: TileType{COL_ORANGE,       1, .Normal      } // 60 points
LB :: TileType{COL_LIGHTBLUE,    1, .Normal      } // 70 points
GT :: TileType{COL_GREEN,        1, .Normal      } // 80 points
RT :: TileType{COL_RED,          1, .Normal      } // 90 points
BT :: TileType{COL_BLUE,         1, .Normal      } //100  points
PT :: TileType{COL_PINK,         1, .Normal      } //110  points
YT :: TileType{COL_YELLOW,       1, .Normal      } //120  points
S2 :: TileType{COL_SILVER,       2, .Normal      } // silver: 50 * level
S3 :: TileType{COL_SILVER,       3, .Normal      }
S4 :: TileType{COL_SILVER,       4, .Normal      }
S5 :: TileType{COL_SILVER,       5, .Normal      }
XX :: TileType{COL_GOLD,         1, .Unbreakable }
__ :: TileType{rl.BLANK,         0, .Blank       }

// 0 indexed. The displayed level is +1
levels :[][TILE_ROWS * TILE_COLS]TileType= {
	{ // 0
		__,__,__,__,__,__,__,__,__,__,__,
		RT,RT,RT,RT,RT,RT,RT,RT,RT,RT,RT,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		GT,GT,GT,GT,GT,GT,GT,GT,GT,GT,GT,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
	},
	{ // 1
		OT,__,__,__,__,__,__,__,__,__,__,
		OT,LB,__,__,__,__,__,__,__,__,__,
		OT,LB,GT,__,__,__,__,__,__,__,__,
		OT,LB,GT,BT,__,__,__,__,__,__,__,
		OT,LB,GT,BT,RT,__,__,__,__,__,__,
		OT,LB,GT,BT,RT,OT,__,__,__,__,__,
		OT,LB,GT,BT,RT,OT,LB,__,__,__,__,
		OT,LB,GT,BT,RT,OT,LB,LB,__,__,__,
		OT,LB,GT,BT,RT,OT,LB,LB,GT,__,__,
		OT,LB,GT,BT,RT,OT,LB,LB,GT,RT,__,
		S2,S2,S2,S2,S2,S2,S2,S2,S2,S2,OT,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
	},
	{ // 2
		__,__,__,OT,__,__,__,OT,__,__,__,
		__,__,__,__,OT,__,OT,__,__,__,__,
		__,__,__,__,OT,__,OT,__,__,__,__,
		__,__,__,S2,S2,S2,S2,S2,__,__,__,
		__,__,__,S2,S2,S2,S2,S2,__,__,__,
		__,__,S2,S2,RT,S2,RT,S2,S2,__,__,
		__,__,S2,S2,RT,S2,RT,S2,S2,__,__,
		__,S2,S2,S2,S2,S2,S2,S2,S2,S2,__,
		__,S2,S2,S2,S2,S2,S2,S2,S2,S2,__,
		__,S2,__,S2,S2,S2,S2,S2,__,S2,__,
		__,S2,__,S2,__,__,__,S2,__,S2,__,
		__,S2,__,S2,__,__,__,S2,__,S2,__,
		__,__,__,__,S2,__,S2,__,__,__,__,
		__,__,__,__,S2,__,S2,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
	},

		 { // 3
		XX,XX,__,__,__,__,__,__,__,__,__,
		__,__,__,__,__,__,__,__,__,__,__,
		__,XX,__,__,__,__,__,__,__,__,__,
		__,XX,__,__,__,__,__,__,__,__,__,
		__,XX,__,__,__,__,__,__,__,__,__,
		__,XX,__,__,__,__,BT,__,__,__,__,
		__,XX,__,__,__,BT,LB,BT,__,__,__,
		__,XX,__,__,BT,LB,BT,LB,BT,__,__,
		__,XX,__,BT,LB,BT,S2,BT,LB,BT,__,
		__,XX,__,__,BT,LB,BT,LB,BT,__,__,
		__,XX,__,__,__,BT,LB,BT,__,__,__,
		__,XX,__,__,__,__,BT,__,__,__,__,
		__,XX,__,__,__,__,__,__,__,__,__,
		__,XX,__,__,__,__,__,__,__,__,__,
		__,XX,XX,XX,XX,XX,XX,XX,XX,XX,XX
	},
}
// odinfmt: enable


init_level :: proc(level_number: u8) -> Level {
	num_tiles: u8 = 0
	level := &levels[level_number]
	for row in 0 ..< TILE_ROWS {
		for col in 0 ..< TILE_COLS {
			tile_def := level[row * TILE_COLS + col]
			tile := &tiles[row * TILE_COLS + col]
			if tile_def.kind != .Blank {
				tile.lives = tile_def.lives
				tile.color = tile_def.color
				tile.unbreakable = tile_def.kind == .Unbreakable
				tile.position.x = GRID_X_START + f32(col) * (TILE_WIDTH + TILE_SPACING)
				tile.position.y = WALL_WIDTH + 2.0 * TILE_HEIGHT + f32(row) * (TILE_HEIGHT + TILE_SPACING)
			}
			if tile_def.kind == .Normal {
				num_tiles += 1
			}

		}
	}
	return Level{Level_number = level_number, total_tiles = num_tiles, remaining_tiles = num_tiles, tiles = tiles[:]}
}
