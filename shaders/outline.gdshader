shader_type spatial;
// Cartoon outline ("inverted hull"): drawn as a next pass behind a model, back faces only,
// pushed out along the normal by a fixed number of *game* pixels so the line stays a crisp
// 1 px at 320x240 whatever the distance. Snaps like the PS1 shaders so it doesn't swim.
render_mode unshaded, cull_front, specular_disabled, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.10, 0.06, 0.12, 1.0);
uniform float width_px = 1.0;
uniform vec2 snap_resolution = vec2(320.0, 240.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	dir = length(dir) > 1e-5 ? normalize(dir) : vec2(0.0);
	if (clip.w > 0.0) {
		vec2 grid = snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
		clip.xy += dir * width_px / grid * clip.w;   // one game pixel = 1 / grid in NDC
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
