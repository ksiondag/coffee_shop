#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D velocity_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D curl_image;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 zero = ivec2(0, 0);
	ivec2 size = imageSize(curl_image) - ivec2(1, 1);

	if (pixel.x > size.x || pixel.y > size.y) {
		return;
	}

	float left_v = imageLoad(velocity_image, clamp(pixel - ivec2(1, 0), zero, size)).y;
	float right_v = imageLoad(velocity_image, clamp(pixel + ivec2(1, 0), zero, size)).y;
	float up_v = imageLoad(velocity_image, clamp(pixel + ivec2(0, 1), zero, size)).x;
	float down_v = imageLoad(velocity_image, clamp(pixel - ivec2(0, 1), zero, size)).x;
	float vorticity = right_v - left_v - up_v + down_v;
	imageStore(curl_image, pixel, vec4(0.5 * vorticity, 0.0, 0.0, 1.0));
}
