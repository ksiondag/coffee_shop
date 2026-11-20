#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D velocity_image;
layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D curl_image;

// PushConstant
layout(push_constant, std430) uniform Params {
	vec4 color;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(curl_image);

	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	// TODO: What do I do with edges? clamp suffices
	float left_v = imageLoad(velocity_image, clamp(uv - ivec2(1, 0), tl, size)).r;
	float right_v = imageLoad(velocity_image, clamp(uv + ivec2(1, 0), tl, size)).r;
	float up_v = imageLoad(velocity_image, clamp(uv - ivec2(0, 1), tl, size)).g;
	float down_v = imageLoad(velocity_image, clamp(uv + ivec2(0, 1), tl, size)).g;
	float vorticity = right_v - left_v - up_v + down_v;
	imageStore(curl_image, pixel, vec4(0.5 * vorticity, 0.0, 0.0, 1.0));
}
