shader_type canvas_item;

uniform float blue = 1.0;
uniform vec2 mouse_cursor = vec2(0, 0);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	COLOR = vec4(0, 0, 0, 1.0);
	if (UV.x - mouse_cursor.x > - 0.1 && UV.x - mouse_cursor.x < 0.1) {
		COLOR.r = 1.0;
	}
	if (UV.y - mouse_cursor.y > - 0.1 && UV.y - mouse_cursor.y < 0.1) {
		COLOR.g = 1.0;
	}
	COLOR.b = blue;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
