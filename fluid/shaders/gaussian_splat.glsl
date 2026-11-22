#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D source_read_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D source_write_image;

// PushConstant (32 bytes)
layout(push_constant, std430) uniform Params {
	vec4 color;
	vec2 point;
	float radius;
	float aspect_ratio;
} params;

// Port of Unity's Splat.shader (itself Pavel's splatShader): adds a soft
// Gaussian blob to the existing field instead of overwriting it.
void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(source_write_image);

	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	// 0-1 texture space, so the same point/radius works at any resolution
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec2 p = uv - params.point;
	p.x *= params.aspect_ratio;
	vec3 splat = exp(-dot(p, p) / params.radius) * params.color.xyz;
	vec3 base = imageLoad(source_read_image, pixel).xyz;
	imageStore(source_write_image, pixel, vec4(base + splat, 1.0));
}
