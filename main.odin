package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1200
SCREEN_HEIGHT :: 800

WALL_WIDTH: f32 = 7.0

TILE_WIDTH :: 70.0
TILE_HEIGHT :: 25.0
TILE_COLS :: 10
TILE_ROWS :: 10
TILE_SPACING :: 15.0

BAR_SPEED :: 800.0

PROJ_RADIUS :: 8
PROJ_SPEED :: 512
PROJ_COLOR :: rl.Color{192, 192, 192, 255}

PAD_WIDTH :: 128.0
PAD_Y_POS :: SCREEN_HEIGHT - 50.0

PARTICLES_MAX :: 256
PARTICLE_SPEED :: 150

SCORE_X_OFFSET :: 24
SCORE_FONT_SIZE :: 18
SCORE_Y_OFFSET :: SCORE_FONT_SIZE * 2

// center points
LIVES_X_OFFSET :: SCORE_X_OFFSET + PROJ_RADIUS
LIVES_Y_OFFSET :: SCORE_Y_OFFSET + SCORE_FONT_SIZE + PROJ_RADIUS
LIVES_SPACING :: 5

BIG_PAD_TEX_MAP :: rl.Rectangle{0, 280, 128, 24}
BALL_TEX_MAP :: rl.Rectangle{160, 200, 16, 16}

GRID_WIDTH :: TILE_WIDTH * TILE_COLS + (TILE_COLS - 1) * TILE_SPACING
GRID_X_START :: (SCREEN_WIDTH - GRID_WIDTH) / 2

ParticleType :: enum {
	Square,
	Circle,
}

Particle :: struct {
	position: rl.Vector2,
	velocity: rl.Vector2,
	color:    rl.Color,
	life:     f32,
	lifetime: f32,
	size:     f32, // Side for Square, radius circle
	type:     ParticleType,
}

Tile :: struct {
	position:    rl.Vector2,
	velocity:    rl.Vector2,
	color:       rl.Color,
	alive:       bool,
	unbreakable: bool,
}

ScreenTextSection :: enum {
	Top,
	Middle,
	Bottom,
}
ScreenText :: struct {
	text:    cstring,
	active:  bool,
	section: ScreenTextSection,
}

Event :: enum {
	Killed,
	TileDestroyed,
	Bounced,
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

spawn_particle :: proc(pos: rl.Vector2, color: rl.Color, min_size, max_size: f32, type: ParticleType, lifetime: f32) {
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
	part.life = lifetime
	part.lifetime = lifetime
	part.type = type
	part.color = color
	part.size = rand.float32() * (max_size - min_size) + min_size
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
		normalized_life := part.life / part.lifetime
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

particle_erupt :: proc(
	area: rl.Rectangle,
	color: rl.Color,
	particle_count: u8,
	min_size, max_size: f32,
	type: ParticleType,
	lifetime: f32,
) {
	for _ in 0 ..< particle_count {
		x := rand.float32() * (area.x + area.width - area.x) + area.x
		y := rand.float32() * (area.y + area.height - area.y) + area.y
		spawn_particle({x, y}, color, min_size, max_size, type, lifetime)
	}
}
draw_particles :: proc() {
	for &part in particles {
		if part.life > 0 {
			switch part.type {
			case .Square:
				rl.DrawRectangleV(
					{part.position.x - part.size, part.position.y - part.size},
					{part.size * 2, part.size * 2},
					part.color,
				)
			case .Circle:
				rl.DrawCircleV(part.position, part.size, part.color)
			}
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

draw_tile :: proc(tile: ^Tile) {
	rl.DrawRectangleV(tile.position, {TILE_WIDTH, TILE_HEIGHT}, tile.color)
	if tile.unbreakable {
		rl.DrawRectangleLines(i32(tile.position.x), i32(tile.position.y), TILE_WIDTH, TILE_HEIGHT, rl.BLACK)
	}
}


attach_projectile_to_pad :: proc() {
	proj_pos = rl.Vector2{pad_x + PAD_WIDTH / 2.0, SCREEN_HEIGHT - 50 - PROJ_RADIUS}
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
	//rl.DrawRectangleV({x, PAD_Y_POS}, {PAD_WIDTH, TILE_HEIGHT}, rl.BEIGE)
	rl.DrawTextureRec(texture_map, BIG_PAD_TEX_MAP, {x, PAD_Y_POS}, rl.WHITE)

}

draw_projectile :: proc(pos: rl.Vector2) {
	adjusted_pos := rl.Vector2{pos.x - PROJ_RADIUS, pos.y - PROJ_RADIUS}
	rl.DrawTextureRec(texture_map, BALL_TEX_MAP, adjusted_pos, rl.WHITE)
}

draw_tiles :: proc() {
	for &tile in tiles {
		if tile.alive {
			draw_tile(&tile)

		}
	}
}

draw_screen_text :: proc(text: ScreenText) {
	if (!text.active) {
		return
	}

	font_size: i32 = 64
	text_width := rl.MeasureText(screen_text.text, font_size)
	section: i32 = ---
	switch text.section {
	case .Top:
		section = SCREEN_HEIGHT / 3
	case .Middle:
		section = SCREEN_HEIGHT / 2
	case .Bottom:
		section = (SCREEN_HEIGHT / 3) * 2
	}
	text_x := i32(SCREEN_WIDTH) / 2 - text_width / 2
	text_y := section - font_size / 2
	rl.DrawText(screen_text.text, text_x, text_y, font_size, rl.BLACK)
}

draw_score :: proc() {
	text := fmt.ctprintf("Level %02d : %03d/%03d", current_level, total_tiles - remaining_tiles, total_tiles)
	rl.DrawText(text, SCORE_X_OFFSET, SCORE_Y_OFFSET, SCORE_FONT_SIZE, rl.BLACK)
}

draw_lives :: proc() {
	for life in 0 ..< lives - 1 { 	// 1 ball is on the pad
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
		return {.Bounced}
	}
	// right wal
	if pos.x + PROJ_RADIUS >= SCREEN_WIDTH - WALL_WIDTH {
		velocity.x = -velocity.x
		pos.x = SCREEN_WIDTH - WALL_WIDTH - PROJ_RADIUS
		return {.Bounced}
	}

	// top
	if pos.y - PROJ_RADIUS <= WALL_WIDTH {
		velocity.y = -velocity.y
		pos.y = WALL_WIDTH + PROJ_RADIUS
		return {.Bounced}
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
			pos^ += coll.normal * coll.overlap // push back projectile
			// Note, collision detection is cooked - we can get tunneling
			if !tile.unbreakable {
				tile.alive = false
				area := rl.Rectangle{tile.position.x, tile.position.y, TILE_WIDTH, TILE_HEIGHT}
				particle_erupt(area, tile.color, 12, 1, 6, .Square, .6)
				return {.TileDestroyed}
			} else {
				return {.Bounced}
			}
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
		// Circle center is inside the rect. Use axis-minimum (SAT) to find the
		// nearest face and push the circle out that way, rather than returning
		// an arbitrary normal.
		dx_left := circle_pos.x - rect.x
		dx_right := (rect.x + rect.width) - circle_pos.x
		dy_top := circle_pos.y - rect.y
		dy_bottom := (rect.y + rect.height) - circle_pos.y

		min_d := min(dx_left, dx_right, dy_top, dy_bottom)
		if min_d == dx_left {
			result.normal = {1, 0}
			result.overlap = -(dx_left + circle_radius)
			result.side = .Left
		} else if min_d == dx_right {
			result.normal = {-1, 0}
			result.overlap = -(dx_right + circle_radius)
			result.side = .Right
		} else if min_d == dy_top {
			result.normal = {0, 1}
			result.overlap = -(dy_top + circle_radius)
			result.side = .Top
		} else {
			result.normal = {0, -1}
			result.overlap = -(dy_bottom + circle_radius)
			result.side = .Bottom
		}
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
remaining_tiles: u8
total_tiles: u8
particles: [PARTICLES_MAX]Particle
lives: i8
state: State
celebrate_timer: f32
celebrate_cooldown: f32 = .33
texture_map: rl.Texture2D
current_level: u8 = 1

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
			rl.SetSoundPitch(sound_destroy, rand.float32() * (1.2 - 0.8) + 0.8)
			rl.PlaySound(sound_destroy)

		}
		collided := pad_collide(&proj_pos, &proj_velocity, pad_x)
		if collided || .Bounced in event {
			rl.SetSoundPitch(sound_bounce, rand.float32() * (1.2 - 0.8) + 0.8)
			rl.PlaySound(sound_bounce)
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
	texture_map = rl.LoadTexture("sprites.png")

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
	@(static) colors := [?]rl.Color{PROJ_COLOR, rl.RED, rl.GREEN, rl.WHITE, rl.BLUE}
	x := rand.float32() * (SCREEN_WIDTH - WALL_WIDTH * 4) + WALL_WIDTH * 2
	y := rand.float32() * (SCREEN_WIDTH - WALL_WIDTH * 4) + WALL_WIDTH * 2
	particle_erupt(rl.Rectangle{x, y, TILE_WIDTH, TILE_HEIGHT}, rand.choice(colors[:]), 12, 1, 8, .Circle, 2.)
}

toggle_pause :: proc() {
	paused = !paused
	screen_text.active = paused
	screen_text.section = .Bottom
	if paused {
		screen_text.text = "PAUSED"
	}
}

handle_killed :: proc() {
	particle_erupt(proj_area(), PROJ_COLOR, 10, 2, PROJ_RADIUS / 2, .Circle, 2)
	proj_velocity = {0, 0}

	lives -= 1
	rl.PlaySound(sound_died)
	if lives == 0 {
		switch_to_gameover()
	} else {
		proj_pos = {LIVES_X_OFFSET * f32(lives), LIVES_Y_OFFSET}
		state = .Dead
	}
}

switch_to_starting :: proc() {
	if current_level == 0 {
		current_level = 1
	}
	total_tiles = init_level(current_level)
	remaining_tiles = total_tiles
	center_pad()
	particles_reset()

	paused = false
	screen_text.active = true
	screen_text.section = .Bottom
	screen_text.text = "Press (space) to start"
	lives = 5

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
	screen_text.section = .Bottom
	screen_text.text = "Game Over"
	proj_pos.y = SCREEN_HEIGHT + PROJ_RADIUS // hide
	proj_velocity = {0, 0}
	state = .GameOver
	current_level = 0
}

switch_to_victory :: proc() {
	screen_text.active = true
	screen_text.section = .Middle
	screen_text.text = "Victory !"
	proj_pos.y = SCREEN_HEIGHT + PROJ_RADIUS // hide
	proj_velocity = {0, 0}
	state = .Victory
	celebrate_timer = celebrate_cooldown
	current_level += 1
}
