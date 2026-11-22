#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D pressure_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict readonly image2D velocity_read_image;
layout(rgba16f, set = 2, binding = 0) uniform restrict writeonly image2D velocity_write_image;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 zero = ivec2(0, 0);
	ivec2 size = imageSize(velocity_write_image) - ivec2(1, 1);

	if (pixel.x > size.x || pixel.y > size.y) {
		return;
	}

	// Clamped neighbours match the pressure solve and Pavel's clamp-to-edge sampling.
	float left_p = imageLoad(pressure_image, clamp(pixel - ivec2(1, 0), zero, size)).x;
	float right_p = imageLoad(pressure_image, clamp(pixel + ivec2(1, 0), zero, size)).x;
	float up_p = imageLoad(pressure_image, clamp(pixel + ivec2(0, 1), zero, size)).x;
	float down_p = imageLoad(pressure_image, clamp(pixel - ivec2(0, 1), zero, size)).x;

	// Matches Pavel: no 0.5 on the pressure gradient, unlike the divergence pass.
	vec2 velocity = imageLoad(velocity_read_image, pixel).xy;
	velocity -= vec2(right_p - left_p, up_p - down_p);
	imageStore(velocity_write_image, pixel, vec4(velocity, 0.0, 1.0));
}
