shader_type spatial;
// PS1-style terrain: three tiling 64px textures picked per pixel with an ordered dither
// (no smooth blending, like old consoles), per-vertex lighting and vertex snapping.
// Vertex colour carries the surface weights: R = rock, G = groomed track, B = ramp ice.
render_mode vertex_lighting, cull_disabled, specular_disabled;

uniform sampler2D offpiste_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D track_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tile_size = 8.0;          // metres covered by one 64px tile
uniform float rock_tile_size = 11.0;
uniform vec3 ice_tint : source_color = vec3(0.78, 0.9, 1.0);
uniform vec2 snap_resolution = vec2(320.0, 240.0);

varying vec2 world_xz;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (clip.w > 0.0) {
		vec2 grid = snap_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

float dither(vec2 uv) {
	// Threshold from a 4x4 Bayer matrix, locked to the texture's own pixel grid.
	vec2 texel = floor(uv * 64.0);
	int idx = int(mod(texel.x, 4.0)) + int(mod(texel.y, 4.0)) * 4;
	return (BAYER[idx] + 0.5) / 16.0;
}

void fragment() {
	vec2 uv = world_xz / tile_size;
	float t = dither(uv);
	vec3 col = texture(offpiste_tex, uv).rgb;
	if (COLOR.g > t) {
		col = texture(track_tex, uv).rgb;
	}
	if (COLOR.r > t) {
		col = texture(rock_tex, world_xz / rock_tile_size).rgb;
	}
	col = mix(col, col * ice_tint * 1.1, COLOR.b);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
