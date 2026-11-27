shader_type spatial;
uniform float alpha : hint_range(0, 1) = 0;
uniform float strength : hint_range(0, 100) = 1.f;
uniform vec4 color : source_color;

void vertex() {
	// Called for every vertex the material is visible on.
	VERTEX *= 1.2;
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO *= 0.f;
	ALPHA = alpha;
	EMISSION = color.rgb + (color.rgb * alpha * strength);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
