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
	SkyBox,
}

ImageName :: enum {
	Space,
}

@(private = "file")
all_shaders := [ShaderName][2]Asset {
	.Blur      = {{data = nil}, {data = #load("../assets/blur.glsl")}},
	.Threshold = {{data = nil}, {data = #load("../assets/threshold.glsl")}},
	.SkyBox    = {{data = #load("../assets/skybox.vs")}, {data = #load("../assets/skybox.fs")}},
}

@(private = "file")
all_images := [ImageName]Asset {
	.Space = {data = #load("../assets/StandardCubeMap.png")},
}

shaders := [ShaderName]rl.Shader{}
images := [ImageName]rl.Image{}
blur_shader_location: c.int

init_assets :: proc() {
	for t, k in all_shaders {
		load_shader_from_memory(k, t[0].data, t[1].data)
	}
	blur_shader_location = rl.GetShaderLocation(shaders[ShaderName.Blur], "direction")

	for t, k in all_images {
		load_image_from_memory(k, t.data)
	}
}

@(private = "file")
load_image_from_memory :: proc(name: ImageName, data: []u8) {
	img := rl.LoadImageFromMemory(".png", &data[0], i32(len(data)))
	images[name] = img
}

@(private = "file")
load_shader_from_memory :: proc(name: ShaderName, vs_data: []u8, fs_data: []u8) {
	fs := strings.string_from_ptr(&fs_data[0], len(fs_data))
	if vs_data != nil {
		vs := strings.string_from_ptr(&vs_data[0], len(vs_data))
		shader := rl.LoadShaderFromMemory(
			strings.clone_to_cstring(vs, context.temp_allocator),
			strings.clone_to_cstring(fs, context.temp_allocator),
		)
		shaders[name] = shader
	} else {
		shader := rl.LoadShaderFromMemory(
			nil,
			strings.clone_to_cstring(fs, context.temp_allocator),
		)
		shaders[name] = shader
	}

	free_all(context.temp_allocator)
}


shutdown_assets :: proc() {
	for t, _ in shaders {
		rl.UnloadShader(t)
	}
	for t, _ in images {
		rl.UnloadImage(t)
	}
}
