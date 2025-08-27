package main

import "core:math"
import rl "vendor:raylib"


DEFAULT_CAMERA_XYZ :: 5

SPHERE_RADIUS :: 4.0
RINGS :: 64 // latitude divisions
SLICES :: 64 // longitude divisions

DEFAULT_CHANCE_ALIVE :: 20 // initial chance a cell is alive
UPDATE_INTERVAL_MS :: 0.4
DYING_INITIAL_INTENSITY :: 0.5 // 1.0 full red

Game :: struct {
	alive:    [RINGS][SLICES]bool,
	previous: [RINGS][SLICES]bool,
}

run_game :: proc() {
	game := init_game()
	camera := init_camera()
	game_texture := rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
	temp1_texture := rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
	temp2_texture := rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
    rl.SetTextureWrap(temp1_texture.texture, rl.TextureWrap.CLAMP)
    rl.SetTextureWrap(temp2_texture.texture, rl.TextureWrap.CLAMP)
	end_texture := rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())

	last_update := rl.GetTime()
	fade_timer: f32 = 0.0

	for !rl.WindowShouldClose() {
		fade_timer += rl.GetFrameTime()
		current_time := rl.GetTime()
		if current_time - last_update >= UPDATE_INTERVAL_MS {
			update_game_state(&game)
			last_update = current_time
			fade_timer = 0
		}


		if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
			rl.UpdateCamera(&camera, rl.CameraMode.FREE)
		}

		draw_game_in_texture(&game, camera, game_texture, fade_timer)
		apply_threshold_shader(game_texture, temp1_texture)
		apply_blur_shader(temp1_texture, temp2_texture)
		apply_bloom_shader(temp2_texture, game_texture, end_texture)
		draw_in_screen(end_texture)

		free_all(context.temp_allocator)
	}
}

@(private = "file")
apply_bloom_shader :: proc(
	blur_texture: rl.RenderTexture2D,
	input_texture: rl.RenderTexture2D,
	output_texture: rl.RenderTexture2D,
) {
	// merge all textures into bloom_texture
	rl.BeginTextureMode(output_texture)
	{
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(
			input_texture.texture,
			{0, 0, f32(input_texture.texture.width), f32(-input_texture.texture.height)},
			{0, 0, f32(output_texture.texture.width), f32(output_texture.texture.height)},
			{0, 0},
			0,
			rl.WHITE,
		)
		rl.BeginBlendMode(rl.BlendMode.ADDITIVE)
		rl.DrawTexturePro(
			blur_texture.texture,
			{0, 0, f32(blur_texture.texture.width), f32(-blur_texture.texture.height)},
			{0, 0, f32(output_texture.texture.width), f32(output_texture.texture.height)},
			{0, 0},
			0,
			rl.WHITE,
		)
		rl.EndBlendMode()
	}
	rl.EndTextureMode()
}

@(private = "file")
apply_blur_shader :: proc(input_texture: rl.RenderTexture2D, output_texture: rl.RenderTexture2D) {
	for _ in 0 ..< 10 {

		rl.BeginTextureMode(output_texture)
		rl.ClearBackground(rl.BLACK)
		rl.BeginShaderMode(shaders[ShaderName.Blur])
		rl.SetShaderValue(
			shaders[ShaderName.Blur],
			blur_shader_location,
			&(rl.Vector2{1.0 / f32(input_texture.texture.width), 0.0}),
			.VEC2,
		)
		rl.DrawTexturePro(
			input_texture.texture,
			{0, 0, f32(input_texture.texture.width), f32(-input_texture.texture.height)},
			{0, 0, f32(output_texture.texture.width), f32(output_texture.texture.height)},
			{0, 0},
			0.0,
			rl.WHITE,
		)
		rl.EndShaderMode()
		rl.EndTextureMode()

		rl.BeginTextureMode(input_texture)
		rl.ClearBackground(rl.BLACK)
		rl.BeginShaderMode(shaders[ShaderName.Blur])
		rl.SetShaderValue(
			shaders[ShaderName.Blur],
			blur_shader_location,
			&(rl.Vector2{0.0, 1.0 / f32(output_texture.texture.height)}),
			.VEC2,
		)
		rl.DrawTexturePro(
			output_texture.texture,
			{0, 0, f32(output_texture.texture.width), f32(-output_texture.texture.height)},
			{0, 0, f32(input_texture.texture.width), f32(input_texture.texture.height)},
			{0, 0},
			0.0,
			rl.WHITE,
		)
		rl.EndShaderMode()
		rl.EndTextureMode()

	}
}


@(private = "file")
apply_threshold_shader :: proc(
	input_texture: rl.RenderTexture2D,
	output_texture: rl.RenderTexture2D,
) {
	rl.BeginTextureMode(output_texture)
	rl.ClearBackground(rl.BLACK)
	rl.BeginShaderMode(shaders[ShaderName.Threshold])
	rl.DrawTexturePro(
		input_texture.texture,
		{0, 0, f32(input_texture.texture.width), f32(-input_texture.texture.height)},
		{0, 0, f32(output_texture.texture.width), f32(output_texture.texture.height)},
		{0, 0},
		0.0,
		rl.WHITE,
	)
	rl.EndShaderMode()
	rl.EndTextureMode()
}

@(private = "file")
draw_in_screen :: proc(texture_to_draw: rl.RenderTexture2D) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.DrawTexturePro(
		texture_to_draw.texture,
		{0, 0, f32(texture_to_draw.texture.width), f32(-texture_to_draw.texture.height)},
		{0, 0, f32(texture_to_draw.texture.width), f32(texture_to_draw.texture.height)},
		{0, 0},
		0.0,
		rl.WHITE,
	)
	rl.DrawFPS(10, 10)
	rl.EndDrawing()
}

@(private = "file")
draw_game_in_texture :: proc(
	game: ^Game,
	camera: rl.Camera3D,
	game_texture: rl.RenderTexture2D,
	fade_timer: f32,
) {
	rl.BeginTextureMode(game_texture)
	rl.ClearBackground(rl.Color{10, 10, 15, 255})
	rl.BeginMode3D(camera)

	alive_color := rl.Color{255, 0, 0, 255}
	dying_color := rl.Color {
		u8(255 * math.max(0.0, DYING_INITIAL_INTENSITY - fade_timer / UPDATE_INTERVAL_MS)),
		0,
		0,
		255,
	}
	dead_color := rl.Color{0, 0, 0, 255}

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
				rl.DrawTriangle3D(corner1, corner2, corner3, alive_color)
				rl.DrawTriangle3D(corner3, corner2, corner4, alive_color)
			} else if game.previous[i][j] {
				rl.DrawTriangle3D(corner1, corner2, corner3, dying_color)
				rl.DrawTriangle3D(corner3, corner2, corner4, dying_color)
			} else {
				rl.DrawTriangle3D(corner1, corner2, corner3, dead_color)
				rl.DrawTriangle3D(corner3, corner2, corner4, dead_color)
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
	rl.EndTextureMode()
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
			game.previous[i][j] = false
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
			game.previous[i][j] = game.alive[i][j]
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
