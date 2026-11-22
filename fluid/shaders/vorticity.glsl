#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D curl_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict readonly image2D velocity_read_image;
layout(rgba16f, set = 2, binding = 0) uniform restrict writeonly image2D velocity_write_image;

// PushConstant
layout(push_constant, std430) uniform Params {
	float curl;
	float delta;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 zero = ivec2(0, 0);
	ivec2 size = imageSize(curl_image) - ivec2(1, 1);

	if (pixel.x > size.x || pixel.y > size.y) {
		return;
	}

	float center_c = imageLoad(curl_image, clamp(pixel, zero, size)).x;
	float left_c = imageLoad(curl_image, clamp(pixel - ivec2(1, 0), zero, size)).x;
	float right_c = imageLoad(curl_image, clamp(pixel + ivec2(1, 0), zero, size)).x;
	float up_c = imageLoad(curl_image, clamp(pixel + ivec2(0, 1), zero, size)).x;
	float down_c = imageLoad(curl_image, clamp(pixel - ivec2(0, 1), zero, size)).x;

	vec2 force = 0.5 * vec2(abs(up_c) - abs(down_c), abs(right_c) - abs(left_c));
	force /= (length(force) + 0.0001);
	force *= params.curl * center_c;
	force.y *= -1.0;

	vec2 velocity = imageLoad(velocity_read_image, clamp(pixel, zero, size)).xy;
	velocity += force * params.delta;
	velocity = clamp(velocity, -1000.0, 1000.0);
	imageStore(velocity_write_image, pixel, vec4(velocity, 0.0, 1.0));
}
