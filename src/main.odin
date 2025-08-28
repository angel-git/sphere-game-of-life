package main

import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.BORDERLESS_WINDOWED_MODE})
	rl.InitWindow(1024, 768, "game of life")
	rl.SetTargetFPS(60)

	init_assets()
	run_game()
	shutdown_assets()

	rl.CloseWindow()
}
