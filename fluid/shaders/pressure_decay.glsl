#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D pressure_read_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D pressure_write_image;

// PushConstant
layout(push_constant, std430) uniform Params {
	float value;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(pressure_write_image) - ivec2(1, 1);

	if (pixel.x > size.x || pixel.y > size.y) {
		return;
	}

	// Keep a fraction of last frame's pressure as the starting guess for the
	// Jacobi solve
	float pressure = imageLoad(pressure_read_image, pixel).x;
	imageStore(pressure_write_image, pixel, vec4(params.value * pressure, 0.0, 0.0, 1.0));
}
