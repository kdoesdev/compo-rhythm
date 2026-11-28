
shader_type spatial;

uniform float strength : hint_range(0, 100) = 1.0;

uniform vec4 inner_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);

uniform float alphas[8];
uniform int ring_count = 3;

uniform float ring_width : hint_range(0.001, 0.5) = 0.05;
uniform float ring_offset = 0.0;

void vertex() {

}

void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5));

	// Radial gradient
	float gradient = clamp(dist / 0.15, 0.0, 1.0);
	vec3 radial_color = mix(inner_color.rgb, outer_color.rgb, gradient);
	float ring_mask =  0.0;

	for (int i = 0; i < ring_count; i++) {
	    float radius =  clamp((1.f - alphas[i]), 0.001, 1.0) * 0.5 + ring_width;

	    if (radius > 0.0) {
	        float ring_distance = dist - radius;

	        if (dist > radius - ring_width && dist < radius + ring_width) {
	            ring_mask = 1.0;
	            break;
	        }
	    }
	}
	
	if (dist >= 0.5)
	{
		ring_mask = 0.0;
	}

	ALPHA *= ring_mask;

    ALBEDO = vec3(0.0);
    EMISSION = normalize(radial_color.rgb) * strength;
}