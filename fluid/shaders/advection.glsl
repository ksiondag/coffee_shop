#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D main_image;
layout(rgba16f, set = 0, binding = 1) uniform restrict readonly image2D velocity_image;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D output_image;

// PushConstant
// TODO: why std430? What does that mean?
layout(push_constant, std430) uniform Params {
	float delta_time;
	float dissipation;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);

	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 coord = pixel.xy - params.delta_time * imageLoad(velocity_image, pixel) * size.xy;
	vec4 result = imageLoad(main_image, coord);
	float decay = 1.0 + params.dissipation * params.delta_time;
	imageStore(output_image, pixel, result/decay);
}
