package main

import "core:container/queue"
import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: WINDOW_WIDTH

COLS :: WINDOW_WIDTH / 29
ROWS :: COLS

CELL_SIZE :: f32(WINDOW_WIDTH) / f32(COLS)
Grid :: [ROWS * COLS]Cell

// MINE_COUNT :: COLS * ROWS / 6
MINE_COUNT :: 10
MINE_VALUE :: 9

Textures :: map[string]rl.Texture2D

Coord :: struct {
	col: int,
	row: int,
}

Cell_State :: enum {
	CLOSED,
	FLAGGED,
	OPEN,
}

Cell :: struct {
	id:          int,
	using coord: Coord,
	state:       Cell_State,
	value:       int,
}

Game_State :: enum {
	INIT,
	RUNNING,
	GAME_OVER,
	WIN,
}

Game :: struct {
	state:    Game_State,
	cells:    Grid,
	textures: Textures,
	quit:     bool,
}

set_game_win :: proc(game: ^Game) {
	game.state = .WIN
}


set_game_over :: proc(game: ^Game) {
	game.state = .GAME_OVER
}

set_game_running :: proc(game: ^Game) {
	game.state = .RUNNING
}

game_init :: proc(game: ^Game) {
	game.state = .INIT
	game.cells = Grid{}

	for i in 0 ..< ROWS * COLS {
		game.cells[i].row = i / COLS
		game.cells[i].col = i % COLS
	}

	place_mines(&game.cells)
	init_values(&game.cells)
}


place_mines :: proc(cells: ^Grid) {
	placed := 0
	for placed < MINE_COUNT {
		i := rand.int32_range(0, ROWS * COLS)
		cell := &cells[i]

		if cell.value == MINE_VALUE do continue

		cell.value = MINE_VALUE
		placed += 1
	}
}

init_values :: proc(cells: ^Grid) {
	for &c, i in cells {
		if c.value == MINE_VALUE do continue
		v := 0

		neighbours := get_neighbour_indices(i)
		for n in neighbours {
			other_cell := cells[n]
			if other_cell.value == MINE_VALUE do v += 1
		}

		c.value = v
	}
}

load_textures :: proc(game: ^Game) {
	game.textures = map[string]rl.Texture2D{}

	game.textures["base_closed"] = rl.LoadTexture("assets/base_closed.png")
	game.textures["base_open"] = rl.LoadTexture("assets/base_open.png")
	game.textures["flag"] = rl.LoadTexture("assets/flag.png")

	game.textures["mine"] = rl.LoadTexture("assets/mine.png")
	game.textures["mine_explode"] = rl.LoadTexture("assets/mine_explode.png")
	game.textures["mine_wrong"] = rl.LoadTexture("assets/mine_wrong.png")

	game.textures["one"] = rl.LoadTexture("assets/one.png")
	game.textures["two"] = rl.LoadTexture("assets/two.png")
	game.textures["three"] = rl.LoadTexture("assets/three.png")
	game.textures["four"] = rl.LoadTexture("assets/four.png")
	game.textures["five"] = rl.LoadTexture("assets/five.png")
	game.textures["six"] = rl.LoadTexture("assets/six.png")
	game.textures["seven"] = rl.LoadTexture("assets/seven.png")
	game.textures["eight"] = rl.LoadTexture("assets/eight.png")
}

get_cell_texture :: proc(game: ^Game, c: Cell) -> ^rl.Texture2D {
	if game.state == .GAME_OVER {
		if c.value == MINE_VALUE && c.state == .OPEN do return &game.textures["mine_explode"]
		if c.value == MINE_VALUE && c.state == .CLOSED do return &game.textures["mine"]
		if c.value != MINE_VALUE && c.state == .FLAGGED do return &game.textures["mine_wrong"]
	}

	if c.state == .CLOSED do return &game.textures["base_closed"]
	if c.state == .FLAGGED do return &game.textures["flag"]

	switch c.value {
	case 0:
		return &game.textures["base_open"]
	case 1:
		return &game.textures["one"]
	case 2:
		return &game.textures["two"]
	case 3:
		return &game.textures["three"]
	case 4:
		return &game.textures["four"]
	case 5:
		return &game.textures["five"]
	case 6:
		return &game.textures["six"]
	case 7:
		return &game.textures["seven"]
	case 8:
		return &game.textures["eight"]
	case MINE_VALUE:
		return &game.textures["mine"]
	}

	return &game.textures["base_open"]
}

update :: proc(game: ^Game) {
	if rl.IsKeyPressed(.Q) {
		game.quit = true
		return
	}

	if rl.IsKeyPressed(.R) do game_init(game)

	if game.state == .GAME_OVER || game.state == .WIN do return

	if rl.IsMouseButtonPressed(.LEFT) {
		if game.state == .INIT do set_game_running(game)

		coords := get_mouse_coords()
		idx := get_coord_index(coords)
		open_cell(game, idx)

		if is_game_won(game) {
			set_game_win(game)
			return
		}
	}

	if rl.IsMouseButtonPressed(.RIGHT) {
		if game.state == .INIT do set_game_running(game)

		coords := get_mouse_coords()
		idx := get_coord_index(coords)
		flag_cell(game, idx)
	}
}

is_game_won :: proc(game: ^Game) -> bool {
	for c in game.cells {
		if c.value != MINE_VALUE && c.state == .CLOSED do return false
	}

	return true
}

open_cell :: proc(game: ^Game, idx: int) {
	q: queue.Queue(int)
	queue.push_back(&q, idx)

	for q.len > 0 {
		i := queue.pop_front(&q)
		c := &game.cells[i]

		if c.state == .FLAGGED do continue

		#partial switch c.state {
		case .CLOSED:
			c.state = .OPEN

			if c.value == MINE_VALUE {
				set_game_over(game)
				return
			}

			if c.value != 0 do continue

			neighbours := get_neighbour_indices(i)
			for n in neighbours {
				neighbour := &game.cells[n]
				if neighbour.state == .OPEN do continue

				queue.push_back(&q, n)
			}

		case .OPEN:
			neighbours := get_neighbour_indices(i)
			flag_count := 0
			closed_neighbours: [dynamic]int

			for n in neighbours {
				neighbour := &game.cells[n]
				if neighbour.state == .FLAGGED do flag_count += 1
				else if neighbour.state == .CLOSED do append(&closed_neighbours, n)
			}

			if flag_count != c.value do continue

			for n in closed_neighbours do queue.push_back(&q, n)
		}
	}
}

flag_cell :: proc(game: ^Game, idx: int) {
	c := &game.cells[idx]
	#partial switch c.state {
	case .CLOSED:
		c.state = .FLAGGED
	case .FLAGGED:
		c.state = .CLOSED
	}
}

get_neighbour_indices :: proc(i: int) -> [dynamic; 8]int {
	neighbours: [dynamic; 8]int

	for n in 0 ..< 9 {
		top_left_idx := i - int(COLS) - 1
		col_offset := n / 3
		row_offset := n % 3
		j := top_left_idx + col_offset * int(COLS) + row_offset

		if j == i do continue

		// top & bottom edge
		if j < 0 || j >= int(ROWS * COLS) do continue

		// left & right edge
		if i % COLS == 0 && j % COLS == COLS - 1 do continue
		if i % COLS == COLS - 1 && j % COLS == 0 do continue

		append(&neighbours, j)
	}

	return neighbours
}

get_mouse_coords :: proc() -> Coord {
	mx := rl.GetMouseX()
	my := rl.GetMouseY()

	c := mx * COLS / WINDOW_WIDTH
	r := my * ROWS / WINDOW_HEIGHT

	return Coord{int(c), int(r)}
}

get_coord_index :: proc(coords: Coord) -> int {
	return coords.row * COLS + coords.col
}

draw :: proc(game: ^Game) {
	rl.ClearBackground(rl.RAYWHITE)

	draw_cells(game)

	if game.state == .GAME_OVER do draw_game_over()
	if game.state == .WIN do draw_win()
}

draw_game_over :: proc() {
	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.ColorAlpha(rl.BLACK, 0.5))
	font_size := 64
	rl.DrawText(
		"Game Over",
		i32(WINDOW_WIDTH / 2 - 5 * font_size),
		i32(WINDOW_HEIGHT / 2 - font_size / 2),
		i32(font_size),
		rl.WHITE,
	)
}

draw_win :: proc() {
	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.ColorAlpha(rl.BLACK, 0.5))
	font_size := 64
	rl.DrawText(
		"You Won!!!",
		i32(WINDOW_WIDTH / 2 - 5 * font_size),
		i32(WINDOW_HEIGHT / 2 - font_size / 2),
		i32(font_size),
		rl.WHITE,
	)
}

draw_cells :: proc(game: ^Game) {
	for c in game.cells {
		x := f32(c.col) * CELL_SIZE
		y := f32(c.row) * CELL_SIZE

		texture := get_cell_texture(game, c)
		pos := rl.Vector2{f32(x), f32(y)}
		scale := f32(CELL_SIZE) / f32(texture.width)
		rl.DrawTextureEx(texture^, pos, 0, scale, rl.WHITE)
	}
}

print_grid :: proc(cells: Grid) {
	for c, i in cells {
		fmt.print(fmt.ctprintf("%d ", c.value))
		if i % COLS == COLS - 1 do fmt.println()
	}
	fmt.println()
}

quit :: proc() {

}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Minesweeper")

	game := Game{}
	load_textures(&game)
	game_init(&game)

	defer rl.CloseWindow()

	for !rl.WindowShouldClose() && !game.quit {
		update(&game)

		rl.BeginDrawing()
		draw(&game)
		rl.EndDrawing()
	}

	quit()
}
