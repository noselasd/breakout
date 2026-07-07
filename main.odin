package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH: f32 = 1200.0
SCREEN_HEIGHT: f32 = 800.0

WALL_WIDTH: f32 = 7.0

TILE_WIDTH: f32 = 70.0
TILE_HEIGHT: f32 = 25.0
TILE_COLS :: 10
TILE_ROWS :: 10
TILE_SPACING: f32 = 15.0

BAR_SPEED: f32 = 800.0

PROJ_RADIUS :: 8
PROJ_SPEED :: 512

PAD_Y_POS := SCREEN_HEIGHT - 50.0
PAD_WIDTH := TILE_WIDTH * 2.0

PARTICLES_MAX :: 256
PARTICLE_LIFETIME :: 2
PARTICLE_SPEED :: 150

SCORE_X_OFFSET :: 24
SCORE_FONT_SIZE :: 18
SCORE_Y_OFFSET :: SCORE_FONT_SIZE * 2

// center points
LIVES_X_OFFSET :: SCORE_X_OFFSET + PROJ_RADIUS
LIVES_Y_OFFSET :: SCORE_Y_OFFSET + SCORE_FONT_SIZE + PROJ_RADIUS
LIVES_SPACING :: 5

Particle :: struct {
	position: rl.Vector2,
	velocity: rl.Vector2,
	color:    rl.Color,
	life:     f32,
	size:     f32,
}

Tile :: struct {
	position: rl.Vector2,
	velocity: rl.Vector2,
	color:    rl.Color,
	alive:    bool,
}
ScreenText :: struct {
	text:   cstring,
	active: bool,
}

Event :: enum {
	Killed,
	TileDestroyed,
	WallBounced,
}
ProjectileEvent :: bit_set[Event]

timer_expired :: proc(dt: f32, timer: ^f32, timeout: f32) -> bool {
	time := timer^
	time += dt / timeout
	if time > 1 {
		time = 1
	}
	timer^ = time
	return time == 1
}

spawn_particle :: proc(pos: rl.Vector2, color: rl.Color) {
	part: ^Particle
	for &p in particles {
		if p.life <= 0 {
			part = &p
			break
		}
	}
	if part == nil {
		return
	}
	part.life = PARTICLE_LIFETIME
	part.color = color
	part.size = rand.float32() * 7 + 1
	part.position = pos
	vx := rand.float32() * 2 - 1
	vy := rand.float32() * 2 - 1
	part.velocity.x = f32(vx) * PARTICLE_SPEED
	part.velocity.y = vy * PARTICLE_SPEED
}

particles_update :: proc(dt: f32) {
	for &part in particles {

		if part.life <= 0 {
			continue
		}
		part.life = max(part.life - dt, 0)
		normalized_life := part.life / PARTICLE_LIFETIME
		part.color.a = u8(math.round(255 * normalized_life))
		part.position += dt * part.velocity
		part.velocity.y += dt * PARTICLE_SPEED

		for &tile in tiles {
			if !tile.alive {
				continue
			}
			coll := circle_rect_collide(
				part.position,
				part.size,
				rl.Rectangle{tile.position.x, tile.position.y, TILE_WIDTH, TILE_HEIGHT},
			)
			if coll.side != .None {
				part.position += coll.normal * coll.overlap // push back projectile
				part.velocity = linalg.reflect(part.velocity, coll.normal)
				part.velocity *= .5
				if rl.Vector2LengthSqr(part.velocity) <= 1 { 	// kill jitter
					part.velocity = {0, 0}
				}
			}
		}
	}
}

particle_erupt :: proc(area: rl.Rectangle, color: rl.Color, particle_count: u8) {
	for _ in 0 ..< particle_count {
		x := rand.float32() * (area.x + area.width - area.x) + area.x
		y := rand.float32() * (area.y + area.height - area.y) + area.y
		spawn_particle({x, y}, color)
	}
}
draw_particles :: proc() {
	for &part in particles {
		if part.life > 0 {
			rl.DrawRectangleV(
				{part.position.x - part.size, part.position.y - part.size},
				{part.size * 2, part.size * 2},
				part.color,
			)
			//	rl.DrawCircleV(part.position, part.size, part.color)
		}
	}
}

particles_reset :: proc() {
	for &part in particles {
		part.life = 0
	}
}

draw_walls :: proc() {
	rl.DrawRectangleV({0, 0}, {WALL_WIDTH, SCREEN_HEIGHT}, rl.BLUE)
	rl.DrawRectangleV({SCREEN_WIDTH - WALL_WIDTH, 0}, {WALL_WIDTH, SCREEN_HEIGHT}, rl.BLUE)
	rl.DrawRectangleV({0, 0}, {SCREEN_WIDTH, WALL_WIDTH}, rl.BLUE)
}

draw_tile :: proc(x: f32, y: f32, color: rl.Color) {
	rl.DrawRectangleV({x, y}, {TILE_WIDTH, TILE_HEIGHT}, color)
}

init_tiles :: proc(grid_x: f32) {
	for row in 0 ..< TILE_ROWS {
		factor := u8(((row * 255) + TILE_ROWS) / TILE_ROWS)
		colrA := rl.ColorAlphaBlend(rl.RED, rl.GREEN, rl.Color{255, 255, 255, factor})
		colrB := rl.ColorAlphaBlend(rl.GREEN, rl.BLUE, rl.Color{255, 255, 255, factor})
		for col in 0 ..< TILE_COLS {
			tile := &tiles[col * TILE_ROWS + row]
			tile.alive = true
			tile.color = colrA if factor < 128 else colrB
			tile.position.x = grid_x + f32(col) * (TILE_WIDTH + TILE_SPACING)
			tile.position.y = WALL_WIDTH + 2.0 * TILE_HEIGHT + f32(row) * (TILE_HEIGHT + TILE_SPACING)

		}
	}
	remaining_tiles = TILE_COLS * TILE_ROWS
}

attach_projectile_to_pad :: proc() {
	proj_pos = rl.Vector2{pad_x + PAD_WIDTH / 2, SCREEN_HEIGHT - 50 - PROJ_RADIUS}
	proj_velocity = 0
}

move_pad :: proc(dt: f32, pad_x: f32) -> f32 {
	direction: f32 = 0.0
	if rl.IsKeyDown(.LEFT) {
		direction -= 1.0
	}
	if rl.IsKeyDown(.RIGHT) {
		direction += 1.0
	}

	new_pos := pad_x + direction * dt * BAR_SPEED
	new_pos = math.clamp(new_pos, WALL_WIDTH, SCREEN_WIDTH - PAD_WIDTH - WALL_WIDTH)

	return new_pos
}

draw_pad :: proc(x: f32) {
	rl.DrawRectangleV({x, PAD_Y_POS}, {PAD_WIDTH, TILE_HEIGHT}, rl.BEIGE)
}

draw_projectile :: proc(pos: rl.Vector2) {
	rl.DrawCircleV(pos, PROJ_RADIUS, rl.GOLD)
}

draw_tiles :: proc() {
	for &tile in tiles {
		if tile.alive {
			draw_tile(tile.position.x, tile.position.y, tile.color)
		}
	}
}

draw_screen_text :: proc(text: ScreenText) {
	if (!text.active) {
		return
	}

	font_size: i32 = 64
	text_width := rl.MeasureText(screen_text.text, font_size)

	text_x := i32(SCREEN_WIDTH) / 2 - text_width / 2
	text_y := i32(SCREEN_HEIGHT) / 3 * 2 - font_size / 2
	rl.DrawText(screen_text.text, text_x, text_y, font_size, rl.BLACK)
}

draw_score :: proc() {
	total_tiles: i32 = TILE_COLS * TILE_ROWS
	text := fmt.ctprintf("%03d/%03d", total_tiles - remaining_tiles, total_tiles)
	rl.DrawText(text, SCORE_X_OFFSET, SCORE_Y_OFFSET, SCORE_FONT_SIZE, rl.BLACK)
}

draw_lives :: proc() {
	for life in 0 ..< lives {
		x: f32 = LIVES_X_OFFSET + f32(life) * (PROJ_RADIUS * 2 + LIVES_SPACING)
		y: f32 = LIVES_Y_OFFSET
		draw_projectile(rl.Vector2{x, y})
	}
}

center_pad :: proc() {
	pad_x = (SCREEN_WIDTH - PAD_WIDTH) / 2.0
}

proj_area :: proc() -> rl.Rectangle {
	return rl.Rectangle{proj_pos.x - PROJ_RADIUS, proj_pos.y - PROJ_RADIUS, PROJ_RADIUS * 2, PROJ_RADIUS * 2}
}

pad_collide :: proc(pos: ^rl.Vector2, velocity: ^rl.Vector2, pad_pos_x: f32) -> bool {
	// Note - our collision is a bit more complicated than it should be, and it doesn't properly handle
	// if the projectile ends up inside the pad...
	collided := false
	coll := circle_rect_collide(pos^, PROJ_RADIUS, rl.Rectangle{pad_pos_x, PAD_Y_POS, PAD_WIDTH, TILE_HEIGHT})
	if coll.side != .None {
		old_pos := pos^
		pos^ += coll.normal * coll.overlap // push back projectile
		if coll.side == .Left || coll.side == .Right {
			velocity.x = -velocity.x
		} else if coll.side == .Top {

			// left/right side reflects projectile to the corresponding side
			// middle area reflects straight up
			pad_center := pad_pos_x + (PAD_WIDTH / 2)

			hit_pos := clamp((pos.x - pad_center) / (PAD_WIDTH / 2), -1, 1)
			angle: f32 = --- // relative to Y axis.
			if abs(hit_pos) < PROJ_RADIUS / (PAD_WIDTH / 2.0) {
				angle = 0
			} else {
				angle = hit_pos * (60 * rl.DEG2RAD)
			}
			velocity.x = PROJ_SPEED * math.sin(angle)
			velocity.y = PROJ_SPEED * -math.cos(abs(angle))


		}
		collided = true
		// alternative, reflect the vector. Though we may get pure horizontal or vertical movement
		// velocity^ = linalg.reflect(velocity^, coll.normal)
	}
	return collided
}

projectile_collide :: proc(pos: ^rl.Vector2, velocity: ^rl.Vector2) -> ProjectileEvent {

	// left wall
	if pos.x - PROJ_RADIUS <= WALL_WIDTH {
		pos.x = WALL_WIDTH + PROJ_RADIUS
		velocity.x = -velocity.x
		return {.WallBounced}
	}
	// right wal
	if pos.x + PROJ_RADIUS >= SCREEN_WIDTH - WALL_WIDTH {
		velocity.x = -velocity.x
		pos.x = SCREEN_WIDTH - WALL_WIDTH - PROJ_RADIUS
		return {.WallBounced}
	}

	// top
	if pos.y - PROJ_RADIUS <= WALL_WIDTH {
		velocity.y = -velocity.y
		pos.y = WALL_WIDTH + PROJ_RADIUS
		return {.WallBounced}
	}

	//bottom
	if pos.y + PROJ_RADIUS >= SCREEN_HEIGHT {
		velocity.y = -velocity.y
		pos.y = SCREEN_HEIGHT
		return {.Killed}
	}

	rect := rl.Rectangle{0, 0, TILE_WIDTH, TILE_HEIGHT}
	for &tile in tiles {
		if !tile.alive {
			continue
		}
		rect.x = tile.position.x
		rect.y = tile.position.y
		coll := circle_rect_collide(pos^, PROJ_RADIUS, rect)
		if coll.side != .None {
			// Not reflecting this, we don't want to end up with pure
			// horizontal or vertical movement
			if coll.side == .Left || coll.side == .Right {
				velocity.x = -velocity.x
			} else {
				velocity.y = -velocity.y
			}

			tile.alive = false
			area := rl.Rectangle{tile.position.x, tile.position.y, TILE_WIDTH, TILE_HEIGHT}
			particle_erupt(area, tile.color, 12)
			return {.TileDestroyed}
		}
	}
	return {}
}

RectSide :: enum {
	None,
	Top,
	Bottom,
	Left,
	Right,
}

CollisionResult :: struct {
	normal:  rl.Vector2,
	overlap: f32,
	side:    RectSide,
}

circle_rect_collide :: proc(circle_pos: rl.Vector2, circle_radius: f32, rect: rl.Rectangle) -> CollisionResult {
	result: CollisionResult

	closest_point: rl.Vector2 = ---
	closest_point.x = math.clamp(circle_pos.x, rect.x, rect.x + rect.width)
	closest_point.y = math.clamp(circle_pos.y, rect.y, rect.y + rect.height)

	collision: rl.Vector2 = closest_point - circle_pos
	dist_squared := collision.x * collision.x + collision.y * collision.y
	if dist_squared >= circle_radius * circle_radius {
		// no overlap
		return result
	}

	distance := rl.Vector2Length(collision)
	result.overlap = distance - circle_radius
	if dist_squared == 0.0 {
		result.normal = {0, 1} // somewhat arbitrary case..
		result.side = .Top
		return result
	}
	normal := collision * (1 / distance)

	side_x: RectSide = .Right if normal.x < 0.0 else .Left
	side_y: RectSide = .Bottom if normal.y < 0.0 else .Top

	result.side = side_x if abs(normal.x) > abs(normal.y) else side_y
	result.normal = normal

	return result
}

pad_x: f32
proj_pos: rl.Vector2
proj_velocity: rl.Vector2
screen_text: ScreenText
paused := false
remaining_tiles: i32
grid_width: f32 = TILE_WIDTH * f32(TILE_COLS) + f32(TILE_COLS - 1) * TILE_SPACING
grid_x := (SCREEN_WIDTH - grid_width) / 2
tiles: [TILE_ROWS * TILE_COLS]Tile
particles: [PARTICLES_MAX]Particle
lives: i8
state: State
celebrate_timer: f32
celebrate_cooldown: f32 = .33

game_update :: proc(dt: f32, state: State) -> bool {
	killed: bool
	pad_x = move_pad(dt, pad_x)
	proj_pos = proj_pos + proj_velocity * dt
	if state == .Playing {
		event := projectile_collide(&proj_pos, &proj_velocity)
		killed = .Killed in event
		tile_destoyed := .TileDestroyed in event
		if tile_destoyed {
			remaining_tiles -= 1
			rl.SetSoundPitch(destroy_sound, rand.float32() * (1.2 - 0.8) + 0.8)
			rl.PlaySound(destroy_sound)

		}
		collided := pad_collide(&proj_pos, &proj_velocity, pad_x)
		if collided || .WallBounced in event {
			rl.SetSoundPitch(bounce_sound, rand.float32() * (1.2 - 0.8) + 0.8)
			rl.PlaySound(bounce_sound)
		}

	}
	particles_update(dt)
	return killed
}

game_draw :: proc() {

	rl.BeginDrawing()

	rl.ClearBackground(rl.WHITE)

	draw_walls()
	draw_tiles()
	draw_projectile(proj_pos)
	draw_particles()
	draw_pad(pad_x)
	draw_screen_text(screen_text)
	draw_score()
	draw_lives()
	rl.EndDrawing()
}

State :: enum {
	Starting,
	Playing,
	Dead,
	GameOver,
	Victory,
}

move_towards :: proc(dt: f32, pos, vel: ^rl.Vector2, target: rl.Vector2, speed: f32) -> bool {
	// target is where pos should end up. arrival_dist is a grace area
	difference := target - pos^
	length := rl.Vector2Length(difference)
	step := speed * dt
	if length < step || length < 0.001 {
		pos^ = target // snap
		vel^ = 0
		return true
	}
	direction_normal := difference / length
	vel^ = direction_normal * speed
	return false
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), "Breakout")
	rl.InitAudioDevice()
	init_sound()
	defer rl.CloseWindow()
	monitorFPS := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
	monitorFPS = max(30, monitorFPS)
	rl.SetTargetFPS(monitorFPS)
	fmt.println("Using FPS=", monitorFPS)

	switch_to_starting()
	// note, we should handle large dt better, we can tunnel through things for large dt

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		if rl.IsKeyPressed(.R) {
			switch_to_starting()
		}
		switch state {
		case .Starting:
			attach_projectile_to_pad()
			game_update(dt, state)
			if rl.IsKeyPressed(.SPACE) {
				switch_to_playing()
			}

		case .Playing:
			if rl.IsKeyPressed(.SPACE) {
				toggle_pause()
			}

			if !paused {
				if game_update(dt, state) {
					handle_killed()
				}
			}
			if remaining_tiles == 0 {
				switch_to_victory()
			}
		case .Dead:
			reached_pad := move_towards(
				dt,
				&proj_pos,
				&proj_velocity,
				{pad_x + PAD_WIDTH / 2, PAD_Y_POS - PROJ_RADIUS},
				PROJ_SPEED * 1.667,
			)
			game_update(dt, state)
			if reached_pad {
				attach_projectile_to_pad()
				if rl.IsKeyPressed(.SPACE) {
					switch_to_playing()
				}
			}
		case .GameOver:
			if rl.IsKeyPressed(.SPACE) {
				switch_to_starting()
			}
			game_update(dt, state)

		case .Victory:
			if timer_expired(dt, &celebrate_timer, celebrate_cooldown) {
				celebrate()
				celebrate()
				celebrate_timer = 0
			}

			if rl.IsKeyPressed(.SPACE) {
				switch_to_starting()
			}
			game_update(dt, state)

		}

		game_draw()
		free_all(context.temp_allocator)

	}
}

celebrate :: proc() {
	@(static) colors := [?]rl.Color{rl.GOLD, rl.RED, rl.GREEN, rl.WHITE, rl.BLUE}
	x := rand.float32() * (SCREEN_WIDTH - WALL_WIDTH * 4) + WALL_WIDTH * 2
	y := rand.float32() * (SCREEN_WIDTH - WALL_WIDTH * 4) + WALL_WIDTH * 2

	particle_erupt(rl.Rectangle{x, y, TILE_WIDTH, TILE_HEIGHT}, rand.choice(colors[:]), 12)
}

toggle_pause :: proc() {
	paused = !paused
	screen_text.active = paused
	if paused {
		screen_text.text = "PAUSED"
	}
}

handle_killed :: proc() {
	particle_erupt(proj_area(), rl.GOLD, 8)
	proj_velocity = {0, 0}

	lives -= 1
	rl.PlaySound(died_sound)
	if lives == 0 {
		switch_to_gameover()
	} else {
		proj_pos = {LIVES_X_OFFSET * f32(lives), LIVES_Y_OFFSET}
		particle_erupt(proj_area(), rl.GOLD, 4)
		state = .Dead
	}
}

switch_to_starting :: proc() {
	init_tiles(grid_x)
	center_pad()
	particles_reset()

	paused = false
	screen_text.active = true
	screen_text.text = "Press (space) to start"
	lives = 4

	state = .Starting
}

switch_to_playing :: proc() {
	attach_projectile_to_pad()
	screen_text.active = false
	left_or_right: f32 = -1

	if rl.IsKeyDown(.RIGHT) {
		left_or_right = 1.0
	}
	proj_velocity = {left_or_right * PROJ_SPEED / math.SQRT_TWO, -PROJ_SPEED / math.SQRT_TWO}

	state = .Playing
}

switch_to_gameover :: proc() {
	screen_text.active = true
	screen_text.text = "Game Over"
	proj_pos.y = SCREEN_HEIGHT + PROJ_RADIUS // hide
	proj_velocity = {0, 0}
	state = .GameOver
}

switch_to_victory :: proc() {
	screen_text.active = true
	screen_text.text = "Victory !"
	proj_pos.y = SCREEN_HEIGHT + PROJ_RADIUS // hide
	proj_velocity = {0, 0}
	state = .Victory
	celebrate_timer = celebrate_cooldown
}
