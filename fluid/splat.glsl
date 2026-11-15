#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
// TODO: understand the format options, set, and binding
layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D output_image;

// PushConstant
// TODO: why std430? What does that mean?
layout(push_constant, std430) uniform Params {
	vec4 color;
	vec2 cursor;
	float radius;
	float _padding; // TODO: Necessary here?
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);
	

	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	float distance_x = pixel.x - params.cursor.x;
	float distance_y = pixel.y - params.cursor.y;
	
	float distance_squared = distance_x * distance_x + distance_y * distance_y;

	if (distance_squared <= params.radius * params.radius) {
		imageStore(output_image, pixel, params.color);
	}
}
