#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D divergence_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict readonly image2D pressure_read_image;
layout(rgba16f, set = 2, binding = 0) uniform restrict writeonly image2D pressure_write_image;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 zero = ivec2(0, 0);
	ivec2 size = imageSize(pressure_write_image) - ivec2(1, 1);

	if (pixel.x > size.x || pixel.y > size.y) {
		return;
	}

	// Clamped neighbours continue pressure past the wall (zero normal gradient)
	float left_p = imageLoad(pressure_read_image, clamp(pixel - ivec2(1, 0), zero, size)).x;
	float right_p = imageLoad(pressure_read_image, clamp(pixel + ivec2(1, 0), zero, size)).x;
	float up_p = imageLoad(pressure_read_image, clamp(pixel + ivec2(0, 1), zero, size)).x;
	float down_p = imageLoad(pressure_read_image, clamp(pixel - ivec2(0, 1), zero, size)).x;
	float divergence = imageLoad(divergence_image, pixel).x;

	// One Jacobi iteration of the pressure Poisson equation
	float pressure = 0.25 * (left_p + right_p + up_p + down_p - divergence);
	imageStore(pressure_write_image, pixel, vec4(pressure, 0.0, 0.0, 1.0));
}
