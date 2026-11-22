#[compute]
#version 450

// Invocation
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Texture
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D velocity_image;
layout(rgba16f, set = 1, binding = 0) uniform restrict readonly image2D source_read_image;
layout(rgba16f, set = 2, binding = 0) uniform restrict writeonly image2D source_write_image;

// PushConstant
layout(push_constant, std430) uniform Params {
	float delta;
	float dissipation;
} params;

// Manual bilinear filtering for full control versus using builtin sampling
// uv is in 0-1 texture space; texels past the edge repeat the edge (clamp-to-edge)
// One helper per image, because images are awkward to pass as function arguments
// Shifting by half a texel makes integer st land exactly on texel centers
vec4 bilerp_velocity(vec2 uv) {
	ivec2 last = imageSize(velocity_image) - ivec2(1, 1);
	vec2 st = uv * vec2(imageSize(velocity_image)) - 0.5;
	ivec2 base = ivec2(floor(st));
	vec2 f = fract(st);
	vec4 a = imageLoad(velocity_image, clamp(base, ivec2(0), last));
	vec4 b = imageLoad(velocity_image, clamp(base + ivec2(1, 0), ivec2(0), last));
	vec4 c = imageLoad(velocity_image, clamp(base + ivec2(0, 1), ivec2(0), last));
	vec4 d = imageLoad(velocity_image, clamp(base + ivec2(1, 1), ivec2(0), last));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 bilerp_source(vec2 uv) {
	ivec2 last = imageSize(source_read_image) - ivec2(1, 1);
	vec2 st = uv * vec2(imageSize(source_read_image)) - 0.5;
	ivec2 base = ivec2(floor(st));
	vec2 f = fract(st);
	vec4 a = imageLoad(source_read_image, clamp(base, ivec2(0), last));
	vec4 b = imageLoad(source_read_image, clamp(base + ivec2(1, 0), ivec2(0), last));
	vec4 c = imageLoad(source_read_image, clamp(base + ivec2(0, 1), ivec2(0), last));
	vec4 d = imageLoad(source_read_image, clamp(base + ivec2(1, 1), ivec2(0), last));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(source_write_image);

	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	// Work in 0-1 texture space so velocity and source can differ in resolution
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec2 velocity_texel = 1.0 / vec2(imageSize(velocity_image));
	vec2 coord = uv - params.delta * bilerp_velocity(uv).xy * velocity_texel;

	vec4 result = bilerp_source(coord);
	float decay = 1.0 + params.dissipation * params.delta;
	imageStore(source_write_image, pixel, vec4(result.rgb / decay, result.a));
}
