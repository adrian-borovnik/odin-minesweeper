package main

import "core:container/queue"
import "core:fmt"
import "core:math/rand"
import "vendor:darwin/MetalKit"
import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: WINDOW_WIDTH

COLS :: WINDOW_WIDTH / 40
ROWS :: COLS

CELL_SIZE :: WINDOW_WIDTH / COLS

MINE_COUNT :: COLS * ROWS / 5
MINE_VALUE :: 9

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
}

Game :: struct {
	state: Game_State,
	cells: [ROWS * COLS]Cell,
}

game_init :: proc(game: ^Game) {
	game.state = Game_State.INIT
	game.cells = [ROWS * COLS]Cell{}

	for i in 0 ..< ROWS * COLS {
		game.cells[i].row = i / COLS
		game.cells[i].col = i % COLS
	}

	place_mines(&game.cells)
	init_values(&game.cells)
}


place_mines :: proc(cells: ^[ROWS * COLS]Cell) {
	placed := 0
	for placed < MINE_COUNT {
		i := rand.int32_range(0, ROWS * COLS)
		cell := &cells[i]

		if cell.value == MINE_VALUE do continue

		cell.value = 9
		placed += 1
	}
}

init_values :: proc(cells: ^[ROWS * COLS]Cell) {
	for &c, i in cells {
		if c.value == MINE_VALUE do continue
		v := 0

		neighbours := get_neighbour_indices(i)
		for n in neighbours {
			other_cell := cells[n]
			if other_cell.value == 9 do v += 1
		}

		c.value = v
	}
}

update :: proc(game: ^Game) {

	if rl.IsKeyPressed(.R) do game_init(game)

	if game.state == Game_State.GAME_OVER do return

	if rl.IsMouseButtonPressed(.LEFT) {
		coords := get_mouse_coords()
		idx := get_coord_index(coords)
		open_cell(game, idx)
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		coords := get_mouse_coords()
		idx := get_coord_index(coords)
		flag_cell(game, idx)
	}

}

open_cell :: proc(game: ^Game, idx: int) {
	q: queue.Queue(int)
	queue.push_back(&q, idx)

	for q.len > 0 {
		i := queue.pop_front(&q)
		c := &game.cells[i]

		if c.state == Cell_State.FLAGGED do continue

		#partial switch c.state {
		case Cell_State.CLOSED:
			c.state = Cell_State.OPEN

			if c.value == MINE_VALUE {
				set_game_over(game)
				return
			}

			if c.value != 0 do continue

			neighbours := get_neighbour_indices(i)
			for n in neighbours {
				neighbour := &game.cells[n]
				if neighbour.state == Cell_State.OPEN do continue

				queue.push_back(&q, n)
			}

		case Cell_State.OPEN:
			neighbours := get_neighbour_indices(i)
			flag_count := 0
			closed_neighbours: [dynamic]int

			for n in neighbours {
				neighbour := &game.cells[n]
				if neighbour.state == Cell_State.FLAGGED do flag_count += 1
				else if neighbour.state == Cell_State.CLOSED do append(&closed_neighbours, n)
			}

			if flag_count != c.value do continue

			for n in closed_neighbours do queue.push_back(&q, n)
		}
	}
}

flag_cell :: proc(game: ^Game, idx: int) {
	c := &game.cells[idx]
	#partial switch c.state {
	case Cell_State.CLOSED:
		c.state = Cell_State.FLAGGED
	case Cell_State.FLAGGED:
		c.state = Cell_State.CLOSED
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

set_game_over :: proc(game: ^Game) {
	game.state = Game_State.GAME_OVER
}

draw :: proc(game: Game) {
	rl.ClearBackground(rl.RAYWHITE)

	draw_cells(game.cells)

	if game.state == Game_State.GAME_OVER {
		draw_game_over()
	}
}

draw_game_over :: proc() {
	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.ColorAlpha(rl.BLACK, 0.7))
	font_size := 64
	rl.DrawText(
		"Game Over",
		i32(WINDOW_WIDTH / 2 - 5 * font_size),
		i32(WINDOW_HEIGHT / 2 - font_size / 2),
		i32(font_size),
		rl.WHITE,
	)
}

draw_cells :: proc(cells: [ROWS * COLS]Cell) {
	for c in cells {
		x := c.col * CELL_SIZE
		y := c.row * CELL_SIZE

		switch c.state {
		case Cell_State.CLOSED:
			rl.DrawRectangle(i32(x), i32(y), CELL_SIZE, CELL_SIZE, rl.DARKGREEN)

		case Cell_State.FLAGGED:
			rl.DrawRectangle(i32(x), i32(y), CELL_SIZE, CELL_SIZE, rl.DARKGREEN)
			cx := x + CELL_SIZE / 2
			cy := y + CELL_SIZE / 2
			rl.DrawCircle(i32(cx), i32(cy), CELL_SIZE / 4, rl.RED)

		case Cell_State.OPEN:
			rl.DrawRectangle(
				i32(x),
				i32(y),
				CELL_SIZE,
				CELL_SIZE,
				c.value == 9 ? rl.RED : rl.WHITE,
			)

			font_size := CELL_SIZE / 2
			text: string
			if c.value == 9 {
				rl.DrawText(
					"*",
					i32(x + CELL_SIZE / 2 - font_size / 2),
					i32(y + CELL_SIZE / 2 - font_size / 2),
					i32(font_size),
					rl.BLACK,
				)
			} else {
				rl.DrawText(
					fmt.ctprintf("%d", c.value),
					i32(x + CELL_SIZE / 2 - font_size / 2),
					i32(y + CELL_SIZE / 2 - font_size / 2),
					i32(font_size),
					rl.BLACK,
				)
			}
		}
	}

}

print_grid :: proc(cells: [ROWS * COLS]Cell) {
	for c, i in cells {
		fmt.print(fmt.ctprintf("%d ", c.value))
		if i % COLS == COLS - 1 {
			fmt.println()
		}
	}
	fmt.println()
}

main :: proc() {
	game := Game{}
	game_init(&game)

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Minesweeper")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		update(&game)

		rl.BeginDrawing()
		draw(game)
		rl.EndDrawing()
	}
}
