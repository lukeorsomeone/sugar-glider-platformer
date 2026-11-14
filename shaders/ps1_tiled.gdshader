shader_type spatial;
// PS1-style tiling texture for level geometry: nearest-filtered, repeating pixel art
// (nearest within a mip level so pixels stay sharp up close, mipmaps so it does not
// sparkle in the distance), multiplied
// by the vertex colour for cheap shading, with per-vertex lighting and vertex snapping.
render_mode vertex_lighting, cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 snap_resolution = vec2(320.0, 240.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (clip.w > 0.0) {
		vec2 grid = snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	ALBEDO = texture(tex, UV * uv_scale).rgb * to_linear(COLOR.rgb) * tint.rgb;
	ROUGHNESS = 1.0;
}
