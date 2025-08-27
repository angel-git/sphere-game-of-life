package main

import "core:c"
import "core:strings"
import rl "vendor:raylib"

@(private = "file")
Asset :: struct {
	data: []u8,
}

ShaderName :: enum {
	Blur,
	Threshold,
}

@(private = "file")
all_shaders := [ShaderName]Asset {
	.Blur = {data = #load("../assets/blur.glsl")},
	.Threshold = {data = #load("../assets/threshold.glsl")},
}

shaders := [ShaderName]rl.Shader{}
blur_shader_location: c.int

init_assets :: proc() {
	for t, k in all_shaders {
		load_shader_from_memory(k, t.data)
	}
	blur_shader_location = rl.GetShaderLocation(shaders[ShaderName.Blur], "direction")
}


@(private = "file")
load_shader_from_memory :: proc(name: ShaderName, data: []u8) {
	d := strings.string_from_ptr(&data[0], len(data))
	shader := rl.LoadShaderFromMemory(nil, strings.clone_to_cstring(d, context.temp_allocator))
	shaders[name] = shader
	free_all(context.temp_allocator)
}


shutdown_assets :: proc() {
	for t, _ in shaders {
		rl.UnloadShader(t)
	}
}
