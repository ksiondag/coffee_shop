#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D output_image;

// PushConstant
layout(push_constant, std430) uniform Params {
	vec2 cursor;
	float blue;
	float _pad;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);

	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);

	vec4 result = vec4(0, 0, 0, 1.0);
	if (abs(uv.x - params.cursor.x) < 0.1) {
		result.r = 1.0;
	}
	if (abs(uv.y - params.cursor.y) < 0.1) {
		result.g = 1.0;
	}
	result.b = params.blue;

	imageStore(output_image, pixel, result);
}
