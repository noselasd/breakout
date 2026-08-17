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
COL_SILVER :: rl.Color{192, 192, 192, 255}
COL_LIGHTBLUE :: rl.Color{173, 216, 230, 255}
// odinfmt: disable
WT :: TileType{rl.WHITE ,       1, .Normal      } // 50 points
OT :: TileType{rl.ORANGE,       1, .Normal      } // 60 points
LB :: TileType{COL_LIGHTBLUE,   1, .Normal      } // 70 points
GT :: TileType{rl.GREEN ,       1, .Normal      } // 80 points
RT :: TileType{rl.RED   ,       1, .Normal      } // 90 points
BT :: TileType{rl.BLUE   ,      1, .Normal      } //100  points
PT :: TileType{rl.PINK,         1, .Normal      } //110  points
YT :: TileType{rl.YELLOW,       1, .Normal      } //120  points
S2 :: TileType{COL_SILVER,      2, .Normal      } // silver: 50 * level
S3 :: TileType{COL_SILVER,      3, .Normal      }
S4 :: TileType{COL_SILVER,      4, .Normal      }
S5 :: TileType{COL_SILVER,      5, .Normal      }
XX :: TileType{rl.GOLD  ,       1, .Unbreakable }
__ :: TileType{rl.BLANK ,       0, .Blank       }

// 0 indexed. The displayed level is +1
levels :[][TILE_ROWS * TILE_COLS]TileType= {
	 {
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
	{
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
	{
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



	}
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
				tile.alive = true
				tile.color = tile_def.color
				tile.unbreakable = tile_def.kind == .Unbreakable
				tile.position.x = GRID_X_START + f32(col) * (TILE_WIDTH + TILE_SPACING)
				tile.position.y = WALL_WIDTH + 2.0 * TILE_HEIGHT + f32(row) * (TILE_HEIGHT + TILE_SPACING)
				num_tiles += 1
			} else {
				tile.alive = false
			}
		}
	}
	return Level{Level_number = level_number, total_tiles = num_tiles, remaining_tiles = num_tiles, tiles = tiles[:]}
}
