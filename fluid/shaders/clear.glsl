#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D output_image;

// PushConstant
layout(push_constant, std430) uniform Params {
	vec4 color;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);

	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	imageStore(output_image, pixel, params.color);
}
