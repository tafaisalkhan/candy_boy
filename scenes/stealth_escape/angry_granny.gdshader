shader_type spatial;

uniform sampler2D albedo_tex : source_color;
uniform bool use_texture = false;
uniform bool recolor_outfit = false;
uniform vec4 outfit_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 source = vec4(0.72, 0.72, 0.72, 1.0);
	if (use_texture) {
		source = texture(albedo_tex, UV);
	}
	if (source.a < 0.5) {
		discard;
	}
	ALBEDO = source.rgb;
	if (recolor_outfit) {
		// The tracksuit is the blue/cyan area of the source atlas. Mask only that
		// hue so skin, hair, glasses, shoes, and all their texture detail stay intact.
		float blue_mask = smoothstep(0.12, 0.34, source.b - source.r)
			* smoothstep(0.04, 0.20, source.g - source.r);
		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		float tint_luminance = max(0.001, dot(outfit_tint.rgb, vec3(0.299, 0.587, 0.114)));
		vec3 recolored = outfit_tint.rgb * (luminance / tint_luminance);
		ALBEDO = mix(source.rgb, recolored, blue_mask);
	}
	ROUGHNESS = 0.82;
}
