package main

import "core:math"
import rl "vendor:raylib"


DEFAULT_CAMERA_XYZ :: 5

SPHERE_RADIUS :: 4.0
RINGS :: 64 // latitude divisions
SLICES :: 64 // longitude divisions

DEFAULT_CHANCE_ALIVE :: 20 // initial chance a cell is alive
UPDATE_INTERVAL_MS :: 0.5

Game :: struct {
	alive: [RINGS][SLICES]bool,
}

main :: proc() {
	game := init_game()
	camera := init_camera()

	last_update := rl.GetTime()

	rl.SetConfigFlags({.BORDERLESS_WINDOWED_MODE})
	rl.InitWindow(800, 800, "game of life")
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		current_time := rl.GetTime()
		if current_time - last_update >= UPDATE_INTERVAL_MS {
			update_game_state(&game)
			last_update = current_time
		}


		if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
			rl.UpdateCamera(&camera, rl.CameraMode.FREE)
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(camera)

		// Draw all patches
		for i in 0 ..< RINGS {
			theta0 := f32(i) / f32(RINGS) * math.PI
			theta1 := f32(i + 1) / f32(RINGS) * math.PI

			for j in 0 ..< SLICES {
				phi0 := f32(j) / f32(SLICES) * 2 * math.PI
				phi1 := f32(j + 1) / f32(SLICES) * 2 * math.PI

				// Four corners of the patch
				corner1 := rl.Vector3 {
					SPHERE_RADIUS * math.sin(theta0) * math.cos(phi0),
					SPHERE_RADIUS * math.cos(theta0),
					SPHERE_RADIUS * math.sin(theta0) * math.sin(phi0),
				}
				corner2 := rl.Vector3 {
					SPHERE_RADIUS * math.sin(theta0) * math.cos(phi1),
					SPHERE_RADIUS * math.cos(theta0),
					SPHERE_RADIUS * math.sin(theta0) * math.sin(phi1),
				}
				corner3 := rl.Vector3 {
					SPHERE_RADIUS * math.sin(theta1) * math.cos(phi0),
					SPHERE_RADIUS * math.cos(theta1),
					SPHERE_RADIUS * math.sin(theta1) * math.sin(phi0),
				}
				corner4 := rl.Vector3 {
					SPHERE_RADIUS * math.sin(theta1) * math.cos(phi1),
					SPHERE_RADIUS * math.cos(theta1),
					SPHERE_RADIUS * math.sin(theta1) * math.sin(phi1),
				}

				// Color pattern: alternate like a checkerboard
				// color := (i + j) % 2 == 0 ? rl.LIGHTGRAY : rl.DARKGRAY

				if game.alive[i][j] {
					rl.DrawTriangle3D(corner1, corner2, corner3, rl.RED)
					rl.DrawTriangle3D(corner3, corner2, corner4, rl.RED)
				}

				// rl.DrawTriangle3D(corner1, corner2, corner3, color)
				// rl.DrawTriangle3D(corner3, corner2, corner4, color)

				// rl.DrawLine3D(corner1, corner2, rl.BLUE)
				// rl.DrawLine3D(corner2, corner4, rl.BLUE)
				// rl.DrawLine3D(corner4, corner3, rl.BLUE)
				// rl.DrawLine3D(corner3, corner1, rl.BLUE)
			}
		}


		rl.EndMode3D()
		rl.DrawFPS(10, 10)
		rl.EndDrawing()

	}
	rl.CloseWindow()

}

@(private = "file")
init_camera :: proc() -> rl.Camera3D {
	camera := rl.Camera3D {
		position   = rl.Vector3{DEFAULT_CAMERA_XYZ, DEFAULT_CAMERA_XYZ, DEFAULT_CAMERA_XYZ},
		target     = rl.Vector3{0, 0, 0},
		up         = rl.Vector3{0, 1, 0},
		fovy       = 45.0,
		projection = rl.CameraProjection.PERSPECTIVE,
	}
	return camera
}

@(private = "file")
init_game :: proc() -> Game {
	game := Game {
		alive = [RINGS][SLICES]bool{},
	}
	for i in 0 ..< RINGS {
		for j in 0 ..< SLICES {
			game.alive[i][j] = (rl.GetRandomValue(0, 100) <= DEFAULT_CHANCE_ALIVE)
		}
	}
	return game
}

@(private = "file")
update_game_state :: proc(game: ^Game) {
	temp := game.alive

	for i in 0 ..< RINGS {
		for j in 0 ..< SLICES {
			neighbors := count_alive_neighbors(game.alive, i, j)
			if game.alive[i][j] {
				temp[i][j] = (neighbors == 2 || neighbors == 3)
			} else {
				temp[i][j] = (neighbors == 3)
			}
		}
	}
	game.alive = temp
}

@(private = "file")
count_alive_neighbors :: proc(alive: [RINGS][SLICES]bool, i: int, j: int) -> int {
	count := 0

	for di in -1 ..= 1 {
		ni := i + di
		if ni < 0 || ni >= RINGS {
			continue
		}
		for dj in -1 ..= 1 {
			if di == 0 && dj == 0 {
				continue
			}
			nj := (j + dj + SLICES) % SLICES // wrap around longitude
			if alive[ni][nj] {
				count += 1
			}
		}
	}

	return count
}
