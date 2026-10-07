package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 788
SCREEN_HEIGHT :: 1024

WALL_WIDTH :: 7.0

// Orig arkanoid:
// 11 columns, 28 rows , but bottow rows always empty, often max 11 rows
// 121 tiles for biggest level
// tiles 16 x 8 pixels

TILE_WIDTH :: 64
TILE_HEIGHT :: 32
TILE_COLS :: 11
TILE_ROWS :: 15
TILE_SPACING :: 6

BAR_SPEED :: 800.0

BALL_RADIUS :: 8
BALL_SPEED :: 512
BALL_COLOR :: rl.Color{192, 192, 192, 255}

PAD_WIDTH :: 128.0
PAD_HEIGHT :: 24
PAD_Y_POS :: SCREEN_HEIGHT - 50.0

PARTICLES_MAX :: 256
PARTICLE_SPEED :: 150

SCORE_FONT_SIZE :: 18
SCORE_X_OFFSET :: WALL_WIDTH + 3
SCORE_Y_OFFSET :: WALL_WIDTH + 3

// center points
LIVES_X_OFFSET :: SCORE_X_OFFSET + BALL_RADIUS
LIVES_Y_OFFSET :: SCORE_Y_OFFSET + SCORE_FONT_SIZE + BALL_RADIUS
LIVES_SPACING :: 5

BIG_PAD_TEX_MAP :: rl.Rectangle{0, 280, PAD_WIDTH, PAD_HEIGHT}
BALL_TEX_MAP :: rl.Rectangle{160, 200, BALL_RADIUS * 2, BALL_RADIUS * 2}

GRID_WIDTH :: TILE_WIDTH * TILE_COLS + (TILE_COLS - 1) * TILE_SPACING
GRID_X_START :: (SCREEN_WIDTH - GRID_WIDTH) / 2
// 0 indexed. The displayed level is +1
START_LEVEL :: 3
FONT_SIZE :: 64

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
	size:     f32, // Side/2 for Square, radius for circle
	type:     ParticleType,
}

Tile :: struct {
	position:    rl.Vector2,
	velocity:    rl.Vector2,
	color:       rl.Color,
	lives:       u8,
	unbreakable: bool,
}

ScreenTextSection :: enum {
	Top,
	Middle,
	Bottom,
}
ScreenText :: struct {
	text:       cstring,
	font_size:  i32,
	text_width: i32,
	active:     bool,
	section:    ScreenTextSection,
}

Event :: enum {
	Killed,
	TileDestroyed,
	Bounced,
}

Movable :: struct {
	position:      rl.Vector2,
	velocity:      rl.Vector2,
	prev_position: rl.Vector2,
}

BallEvent :: bit_set[Event]

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
	part.size = rand.float32_range(min_size, max_size)
	part.position = pos
	vx := rand.float32_range(-1, 1)
	vy := rand.float32_range(-1, 1)
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
		prev_pos := part.position
		part.position += dt * part.velocity
		part.velocity.y += dt * PARTICLE_SPEED

		for &tile in tiles {
			if tile.lives == 0 {
				continue
			}
			tile_rect := rl.Rectangle{tile.position.x, tile.position.y, TILE_WIDTH, TILE_HEIGHT}
			hit, t, normal := circle_rect_collision_time(prev_pos, part.position, part.size, tile_rect)
			if hit {
				if t > 0 { 	// 0 = inside at previous pos...
					part.position = prev_pos + t * (part.position - prev_pos)
					part.velocity = linalg.reflect(part.velocity, normal)
				}
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
		x := rand.float32_range(area.x, area.x + area.width)
		y := rand.float32_range(area.y, area.y + area.height)

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


attach_ball_to_pad :: proc() {
	ball.position = rl.Vector2{pad.position.x + PAD_WIDTH / 2.0, SCREEN_HEIGHT - 50 - BALL_RADIUS}
	ball.prev_position = ball.position
	ball.velocity = 0
}

move_pad :: proc(dt: f32) {
	direction: f32 = 0.0
	if rl.IsKeyDown(.LEFT) {
		direction -= 1.0
	}
	if rl.IsKeyDown(.RIGHT) {
		direction += 1.0
	}

	new_pos_x := pad.position.x + direction * dt * pad.velocity.x
	pad.position.x = math.clamp(new_pos_x, WALL_WIDTH, SCREEN_WIDTH - PAD_WIDTH - WALL_WIDTH)
}

draw_pad :: proc(pos: rl.Vector2) {
	//rl.DrawRectangleV({x, PAD_Y_POS}, {PAD_WIDTH, TILE_HEIGHT}, rl.BEIGE)
	rl.DrawTextureRec(texture_map, BIG_PAD_TEX_MAP, pos, rl.WHITE)

}

draw_ball :: proc(pos: rl.Vector2) {
	adjusted_pos := rl.Vector2{pos.x - BALL_RADIUS, pos.y - BALL_RADIUS}
	rl.DrawTextureRec(texture_map, BALL_TEX_MAP, adjusted_pos, rl.WHITE)
}

draw_tiles :: proc() {
	for &tile in tiles {
		if tile.lives != 0 {
			draw_tile(&tile)
		}
	}
}

set_screen_text :: proc(section: ScreenTextSection, text: cstring) {
	screen_text.active = true
	screen_text.section = section
	screen_text.text = text
	screen_text.text_width = rl.MeasureText(screen_text.text, screen_text.font_size)
}

draw_screen_text :: proc(text: ScreenText) {
	if (!text.active) {
		return
	}

	section: i32 = ---
	switch text.section {
	case .Top:
		section = SCREEN_HEIGHT / 3
	case .Middle:
		section = SCREEN_HEIGHT / 2
	case .Bottom:
		section = (SCREEN_HEIGHT / 3) * 2
	}
	text_x := i32(SCREEN_WIDTH) / 2 - screen_text.text_width / 2
	text_y := section - screen_text.font_size / 2
	rl.DrawText(screen_text.text, text_x, text_y, screen_text.font_size, rl.BLACK)
}

draw_score :: proc() {
	text := fmt.ctprintf(
		"Level %02d : %03d/%03d",
		current_level.Level_number + 1,
		current_level.total_tiles - current_level.remaining_tiles,
		current_level.total_tiles,
	)
	rl.DrawText(text, SCORE_X_OFFSET, SCORE_Y_OFFSET, SCORE_FONT_SIZE, rl.BLACK)
}

draw_lives :: proc() {
	for life in 0 ..< lives - 1 { 	// 1 ball is on the pad
		x: f32 = LIVES_X_OFFSET + f32(life) * (BALL_RADIUS * 2 + LIVES_SPACING)
		y: f32 = LIVES_Y_OFFSET
		draw_ball(rl.Vector2{x, y})
	}
}

center_pad :: proc() {
	pad.position.x = (SCREEN_WIDTH - PAD_WIDTH) / 2.0
	pad.position.y = PAD_Y_POS
	pad.velocity.x = BAR_SPEED
	pad.velocity.y = 0
}

ball_area :: proc() -> rl.Rectangle {
	return rl.Rectangle{ball.position.x - BALL_RADIUS, ball.position.y - BALL_RADIUS, BALL_RADIUS * 2, BALL_RADIUS * 2}
}

pad_collide :: proc(ball: ^Movable, pad: ^Movable) -> bool {
	// Only the top of the pad bounces. The pad moves too, so check in the pad's frame of
	// reference: where the ball was relative to the pad at the previous frame.
	prev := pad.position + (ball.prev_position - pad.prev_position)
	top := pad.position.y - BALL_RADIUS // ball center when touching the top
	if ball.velocity.y <= 0 || prev.y > top || ball.position.y < top {
		return false
	}
	// where the ball crossed the top
	t := (top - prev.y) / (ball.position.y - prev.y)
	x := prev.x + t * (ball.position.x - prev.x)
	if x < pad.position.x - BALL_RADIUS || x > pad.position.x + PAD_WIDTH + BALL_RADIUS {
		return false
	}
	ball.position = {x, top}

	// left/right side reflects ball to the corresponding side
	// middle area reflects straight up
	pad_center := pad.position.x + (PAD_WIDTH / 2)
	hit_pos := clamp((ball.position.x - pad_center) / (PAD_WIDTH / 2), -1, 1)
	angle: f32 = --- // relative to Y axis.
	if abs(hit_pos) < BALL_RADIUS / (PAD_WIDTH / 2.0) {
		angle = 0
	} else {
		angle = hit_pos * (60 * rl.DEG2RAD)
	}
	ball.velocity.x = BALL_SPEED * math.sin(angle)
	ball.velocity.y = BALL_SPEED * -math.cos(abs(angle))
	return true
}

tile_collide :: proc(ball: ^Movable) -> BallEvent {

	// left wall
	if ball.position.x - BALL_RADIUS <= WALL_WIDTH {
		ball.position.x = WALL_WIDTH + BALL_RADIUS
		ball.velocity.x = -ball.velocity.x
		return {.Bounced}
	}
	// right wall
	if ball.position.x + BALL_RADIUS >= SCREEN_WIDTH - WALL_WIDTH {
		ball.velocity.x = -ball.velocity.x
		ball.position.x = SCREEN_WIDTH - WALL_WIDTH - BALL_RADIUS
		return {.Bounced}
	}

	// top
	if ball.position.y - BALL_RADIUS <= WALL_WIDTH {
		ball.velocity.y = -ball.velocity.y
		ball.position.y = WALL_WIDTH + BALL_RADIUS
		return {.Bounced}
	}

	//bottom
	if ball.position.y + BALL_RADIUS >= SCREEN_HEIGHT {
		ball.position.y = SCREEN_HEIGHT + BALL_RADIUS
		return {.Killed}
	}

	// The sweep can pass several tiles in one frame, the first one hit wins.
	first_tile: ^Tile
	first_t: f32 = 2
	first_normal: rl.Vector2
	rect := rl.Rectangle{0, 0, TILE_WIDTH, TILE_HEIGHT}
	for &tile in tiles {
		if tile.lives == 0 {
			continue
		}
		rect.x = tile.position.x
		rect.y = tile.position.y
		hit, t, normal := circle_rect_collision_time(ball.prev_position, ball.position, BALL_RADIUS, rect)
		if hit && t > 0 && t < first_t { 	// 0 = inside at previous pos...
			first_tile = &tile
			first_t = t
			first_normal = normal
		}
	}
	if first_tile == nil {
		return {}
	}

	tile := first_tile
	ball.position = ball.prev_position + first_t * (ball.position - ball.prev_position)
	ball.velocity = linalg.reflect(ball.velocity, first_normal)

	if !tile.unbreakable {
		tile.lives -= 1
		area := rl.Rectangle{tile.position.x, tile.position.y, TILE_WIDTH, TILE_HEIGHT}
		if tile.lives == 0 {
			particle_erupt(area, tile.color, 12, 1, 6, .Square, .6)
			return {.TileDestroyed}
		} else {
			particle_erupt(area, tile.color, 6, 1, 4, .Square, .3)
			return {.Bounced}
		}
	}
	return {.Bounced}
}

RectSide :: enum {
	None,
	Top,
	Bottom,
	Left,
	Right,
}


// Swept circle vs rect. The circle center moving prev -> pos is treated as a ray against
// the rect expanded by the radius. The corners are kept square, so the normal is always
// axis aligned (and the circle bounces off a corner up to ~0.4 radius early).
// Returns time of impact in [0,1] and the outward normal of the side hit.
// hit with t == 0 and a zero normal means the circle already overlapped at prev.
circle_rect_collision_time :: proc(
	prev, pos: rl.Vector2,
	radius: f32,
	rect: rl.Rectangle,
) -> (
	hit: bool,
	t: f32,
	normal: rl.Vector2,
) {
	delta := pos - prev
	min_p := rl.Vector2{rect.x - radius, rect.y - radius}
	max_p := rl.Vector2{rect.x + rect.width + radius, rect.y + rect.height + radius}

	// Slab test: the ray is inside the expanded rect when it is inside both axis ranges.
	// y goes first, so hitting a corner exactly diagonally counts as a top/bottom hit.
	t_enter: f32 = 0
	t_exit: f32 = 1
	for axis in ([2]int{1, 0}) {
		if delta[axis] == 0 {
			if prev[axis] < min_p[axis] || prev[axis] > max_p[axis] {
				return
			}
			continue
		}
		t0 := (min_p[axis] - prev[axis]) / delta[axis]
		t1 := (max_p[axis] - prev[axis]) / delta[axis]
		n: rl.Vector2
		n[axis] = -1
		if t0 > t1 {
			t0, t1 = t1, t0
			n[axis] = 1
		}
		// the axis entered last is the side that was hit
		if t0 > t_enter {
			t_enter = t0
			normal = n
		}
		t_exit = min(t_exit, t1)
		if t_enter > t_exit {
			return
		}
	}
	return true, t_enter, normal
}

rect_closest_point :: proc(p: rl.Vector2, rect: rl.Rectangle) -> rl.Vector2 {
	return {math.clamp(p.x, rect.x, rect.x + rect.width), math.clamp(p.y, rect.y, rect.y + rect.height)}
}

circle_rect_collide2 :: proc(circle_pos: rl.Vector2, circle_radius: f32, rect: rl.Rectangle) -> bool {
	offset := rect_closest_point(circle_pos, rect) - circle_pos // from cicle center to rect

	return offset.x * offset.y + offset.x * offset.y < circle_radius * circle_radius
}

pad: Movable
ball: Movable
screen_text: ScreenText
paused := false
particles: [PARTICLES_MAX]Particle
lives: i8
state: State
celebrate_timer: f32
celebrate_cooldown: f32 = .33
texture_map: rl.Texture2D
current_level: Level

game_update :: proc(dt: f32, state: State) -> bool {
	killed: bool
	pad.prev_position = pad.position
	move_pad(dt)
	ball.prev_position = ball.position
	ball.position = ball.position + ball.velocity * dt
	if state == .Playing {
		event := tile_collide(&ball)
		killed = .Killed in event
		tile_destoyed := .TileDestroyed in event
		if tile_destoyed {
			current_level.remaining_tiles -= 1
			rl.SetSoundPitch(sound_destroy, rand.float32_range(0.8, 1.2))
			rl.PlaySound(sound_destroy)

		}
		collided := pad_collide(&ball, &pad)
		if collided || .Bounced in event {
			rl.SetSoundPitch(sound_bounce, rand.float32_range(0.8, 1.2))
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
	draw_ball(ball.position)
	draw_particles()
	draw_pad(pad.position)
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
	monitorFPS = max(24, monitorFPS)
	rl.SetTargetFPS(monitorFPS)
	fmt.println("Using FPS=", monitorFPS)
	screen_text.font_size = FONT_SIZE
	switch_to_new_game(START_LEVEL)
	// note, we should handle large dt better, we can tunnel through things for large dt
	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		if rl.IsKeyPressed(.R) {
			switch_to_new_game(current_level.Level_number)
		}
		switch state {
		case .Starting:
			attach_ball_to_pad()
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
			if current_level.remaining_tiles == 0 {
				switch_to_victory()
			}
		case .Dead:
			reached_pad := move_towards(
				dt,
				&ball.position,
				&ball.velocity,
				{pad.position.x + PAD_WIDTH / 2, PAD_Y_POS - BALL_RADIUS},
				BALL_SPEED * 1.667,
			)
			game_update(dt, state)
			if reached_pad {
				attach_ball_to_pad()
				if rl.IsKeyPressed(.SPACE) {
					switch_to_playing()
				}
			}
		case .GameOver:
			if rl.IsKeyPressed(.SPACE) {
				switch_to_new_game(START_LEVEL)
			}
			game_update(dt, state)

		case .Victory:
			if timer_expired(dt, &celebrate_timer, celebrate_cooldown) {
				celebrate()
				celebrate()
				celebrate_timer = 0
			}

			if rl.IsKeyPressed(.SPACE) {
				switch_to_starting(current_level.Level_number + 1)
			}
			game_update(dt, state)

		}

		game_draw()
		free_all(context.temp_allocator)

	}
}

celebrate :: proc() {
	@(static) colors := [?]rl.Color{BALL_COLOR, rl.RED, rl.GREEN, rl.WHITE, rl.BLUE}
	x := rand.float32_range(WALL_WIDTH * 4, SCREEN_WIDTH - WALL_WIDTH * 4)
	y := rand.float32_range(WALL_WIDTH * 4, SCREEN_HEIGHT - WALL_WIDTH * 4)
	particle_erupt(rl.Rectangle{x, y, TILE_WIDTH, TILE_HEIGHT}, rand.choice(colors[:]), 12, 1, 8, .Circle, 2.)
}

toggle_pause :: proc() {
	paused = !paused
	if paused {
		set_screen_text(.Bottom, "PAUSED")
	}
	screen_text.active = paused
}

handle_killed :: proc() {
	particle_erupt(ball_area(), BALL_COLOR, 10, 2, BALL_RADIUS / 2, .Circle, 2)
	ball.velocity = {0, 0}

	lives -= 1
	rl.PlaySound(sound_died)
	if lives == 0 {
		switch_to_gameover()
	} else {
		ball.position = {LIVES_X_OFFSET * f32(lives), LIVES_Y_OFFSET}
		state = .Dead
	}
}

switch_to_new_game :: proc(level_number: u8) {
	lives = 5
	switch_to_starting(level_number)
}

switch_to_starting :: proc(level_number: u8) {
	current_level = init_level(level_number)
	center_pad()
	particles_reset()

	paused = false
	set_screen_text(.Bottom, "Press (space) to start")
	state = .Starting
}

switch_to_playing :: proc() {

	attach_ball_to_pad()
	screen_text.active = false
	left_or_right: f32 = -1

	if rl.IsKeyDown(.RIGHT) {
		left_or_right = 1.0
	}
	ball.velocity = {left_or_right * BALL_SPEED / math.SQRT_TWO, -BALL_SPEED / math.SQRT_TWO}

	state = .Playing
}

switch_to_gameover :: proc() {
	set_screen_text(.Middle, "Game Over")

	ball.position.y = SCREEN_HEIGHT + BALL_RADIUS // hide
	ball.velocity = {0, 0}
	state = .GameOver
}

switch_to_victory :: proc() {
	set_screen_text(.Middle, "Victory !")
	ball.position.y = SCREEN_HEIGHT + BALL_RADIUS // hide
	ball.velocity = {0, 0}
	state = .Victory
	celebrate_timer = celebrate_cooldown
}
