// fog_of_war.gdshader
// Technical Rationale: Ground-plane fog overlay (Phase 2 of the Fog of War
// system). Samples a 2D texture where R = explored, G = visible. The texture is
// rebuilt by FogOfWarDisplay from the UNION of the active players' fog state.
// gl_compatibility-safe: plain spatial shader, single texture sample, no
// compute/depth-texture tricks, fully camera-independent (it only maps UV).
//
// Brightness per state:
//   VISIBLE               -> visible_brightness (lighter grey, reads as "live")
//   EXPLORED_NOT_VISIBLE  -> explored_brightness (dimmed, AoE look)
//   NEVER_EXPLORED        -> 0.0          (black)
// The visible tier is intentionally a mid-light grey rather than pure white so
// the live reveal circles read as a subtle light-grey-on-grey contrast, not a
// stark spotlight disc.
// Adheres to ADR-0001 (GDScript 2.x Strict Typing) for the script that uses it.

shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D fog_map : source_color, repeat_disable;
uniform float explored_brightness : hint_range(0.0, 1.0) = 0.35;
uniform float visible_brightness : hint_range(0.0, 1.0) = 0.62;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// Linear filtering on the grid texture already interpolates between cells,
	// so the sampled values are 0..1 across edges. edge_softness widens/tightens
	// that transition band via a smoothstep around the state threshold (0.5).
	float band = clamp(edge_softness, 0.02, 0.98);
	float explored = smoothstep(0.5 - band, 0.5 + band, texture(fog_map, UV).r);
	float visible = smoothstep(0.5 - band, 0.5 + band, texture(fog_map, UV).g);

	// NEVER_EXPLORED -> black (0.0). EXPLORED_NOT_VISIBLE -> explored_brightness.
	// VISIBLE -> visible_brightness (lighter grey, never pure white).
	float brightness = mix(0.0, explored_brightness, explored);
	brightness = mix(brightness, visible_brightness, visible);

	ALBEDO = vec3(brightness);
	ALPHA = 1.0;
}