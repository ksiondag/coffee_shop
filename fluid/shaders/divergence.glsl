#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D velocity_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D divergence_image;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(divergence_image) - ivec2(1, 1);

	if (pixel.x > size.x || pixel.y > size.y) {
		return;
	}

	vec2 center_v = imageLoad(velocity_image, pixel).xy;

	// When hitting edge, pretend it is a wall, so it bounces/reflects
	float left_v = pixel.x > 0
		? imageLoad(velocity_image, pixel - ivec2(1, 0)).x
		: -center_v.x;
	float right_v = pixel.x < size.x
		? imageLoad(velocity_image, pixel + ivec2(1, 0)).x
		: -center_v.x;
	float up_v = pixel.y < size.y
		? imageLoad(velocity_image, pixel + ivec2(0, 1)).y
		: -center_v.y;
	float down_v = pixel.y > 0
		? imageLoad(velocity_image, pixel - ivec2(0, 1)).y
		: -center_v.y;

	float divergence = 0.5 * (right_v - left_v + up_v - down_v);
	imageStore(divergence_image, pixel, vec4(divergence, 0.0, 0.0, 1.0));
}
