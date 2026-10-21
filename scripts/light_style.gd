class_name LightStyle
extends RefCounted
## Gives everything in the 3D view the same light model
## (shaders/light3d.gdshaderinc): banded, dithered pools of light whose colour
## runs from a hot heart to a deep, saturated edge.
##
## The models are built with ordinary StandardMaterial3Ds (world_mesh.gd,
## objects3d.gd, village3d.gd...). Once they're built, convert() walks the
## 3D scene and swaps each lit StandardMaterial3D for a ShaderMaterial that
## shows the same texture / colour / glow but is lit by our light model.
## Unshaded ones (sprites, gas, darts) are left alone.

## how far (in texels) the painted look reaches: 0 keeps the pixels
const PAINT := 1.0

static var _shaders := {}     ## variant key -> Shader
static var _converted := {}   ## StandardMaterial3D -> ShaderMaterial

const TEMPLATE := """
shader_type spatial;
render_mode {modes};
#include "res://shaders/light3d.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, {repeat};
uniform bool has_tex = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vcol = false;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform bool emission_from_tex = false;
uniform float alpha_cut = 0.5;
uniform float paint = 0.0;     // > 0: painted, not pixel-sharp (see paint_tex)

// Pixel art on a 3D surface without the shimmer: each texel stays a crisp
// square, but where its edge falls between two screen pixels the two are
// blended for that one pixel. With plain nearest sampling the perspective
// doubles some rows of texels and drops others, and which ones flips as
// you walk -- brick and cobble patterns crawl.
vec2 sharp_uv(vec2 uv, vec2 size) {
	vec2 p = uv * size;
	vec2 seam = floor(p + 0.5);
	vec2 w = max(fwidth(p), vec2(1e-4));
	p = seam + clamp((p - seam) / w, -0.5, 0.5);
	return p / size;
}

// The painted look (like the blocks in concept art, crisp, not blurred): each
// texel is cleaned up by a Kuwahara filter -- of the four 2x2 windows that
// hold it, the one whose colours agree best gives its average -- so speckle
// and noise even out into flat areas of colour while real shapes (a brick's
// edge, a path's border) stay. The taps fall on texel centres (sharp_uv), so
// every texel keeps a crisp square edge at any size on screen.
vec4 paint_tex(sampler2D t, vec2 uv, float r) {
	vec2 size = vec2(textureSize(t, 0));
	vec2 suv = sharp_uv(uv, size);
	vec2 tx = 1.0 / size;
	vec4 best = texture(t, suv);
	float bv = 1e9;
	for (int q = 0; q < 4; q++) {
		vec2 s = vec2(q % 2 == 0 ? -1.0 : 1.0, q < 2 ? -1.0 : 1.0);
		vec4 m = vec4(0.0);
		vec3 m2 = vec3(0.0);
		for (int i = 0; i < 2; i++) {
			for (int j = 0; j < 2; j++) {
				vec4 c = texture(t, suv + s * vec2(float(i), float(j)) * tx);
				m += c;
				m2 += c.rgb * c.rgb;
			}
		}
		m *= 0.25;
		m2 *= 0.25;
		vec3 v3 = m2 - m.rgb * m.rgb;
		float v = v3.r + v3.g + v3.b;
		if (v < bv) {
			bv = v;
			best = m;
		}
	}
	return mix(texture(t, suv), best, clamp(r, 0.0, 1.0) * 0.85);
}

void fragment() {
	vec4 c = albedo_color;
	vec2 uv = UV;
	if (has_tex) {
		if (paint > 0.0) {
			vec4 pc = paint_tex(albedo_tex, UV, 1.0);
			// above 1: calmer still -- the joints and speckle turned down toward
			// the surface's soft overall colour
			if (paint > 1.0) {
				vec2 sz = vec2(textureSize(albedo_tex, 0));
				vec2 suv = sharp_uv(UV, sz);
				vec4 soft = vec4(0.0);
				for (int k = 0; k < 8; k++) {
					float a = float(k) * 0.785398;
					soft += texture(albedo_tex, suv + round(vec2(cos(a), sin(a)) * 2.0) / sz);
				}
				pc = mix(pc, soft * 0.125, clamp(paint - 1.0, 0.0, 1.0));
			}
			c *= pc;
		} else {
			uv = sharp_uv(UV, vec2(textureSize(albedo_tex, 0)));
			c *= texture(albedo_tex, uv);
		}
	}
	if (use_vcol) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	{alpha}
	vec3 em = emission_color * emission_energy;
	if (emission_from_tex && has_tex) {
		em *= texture(albedo_tex, uv).rgb;
	}
	EMISSION = em;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""


## Swaps the materials of every model under `root` (call once it's built).
static func convert(root: Node) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		_convert_node(n)


static func _convert_node(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var lit := _lit(mi.material_override)
		if lit != null:
			mi.material_override = lit
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := _lit(mi.get_active_material(i) if mi.material_override == null else null)
				if m != null:
					mi.set_surface_override_material(i, m)
	elif n is MultiMeshInstance3D:
		var mm := n as MultiMeshInstance3D
		var lit := _lit(mm.material_override)
		if lit != null:
			mm.material_override = lit


## The lit version of a material, or null to leave it as it is.
static func _lit(m: Material) -> ShaderMaterial:
	var sm := m as StandardMaterial3D
	if sm == null or sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return null
	if _converted.has(sm):
		return _converted[sm]
	var cull := "cull_back"
	match sm.cull_mode:
		BaseMaterial3D.CULL_DISABLED: cull = "cull_disabled"
		BaseMaterial3D.CULL_FRONT: cull = "cull_front"
	var alpha := ""
	var blend := ""
	match sm.transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			alpha = "if (c.a < alpha_cut) { discard; }"
		BaseMaterial3D.TRANSPARENCY_ALPHA:
			alpha = "ALPHA = c.a;"
			blend = ", blend_mix, depth_draw_opaque"
	var repeat := "repeat_enable" if sm.texture_repeat else "repeat_disable"
	var key := "%s|%s|%s|%s" % [cull, alpha, blend, repeat]
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = TEMPLATE.replace("{modes}", cull + ", specular_disabled" + blend) \
			.replace("{repeat}", repeat).replace("{alpha}", alpha)
		_shaders[key] = sh
	var out := ShaderMaterial.new()
	out.shader = _shaders[key]
	out.set_shader_parameter("has_tex", sm.albedo_texture != null)
	if sm.albedo_texture != null:
		out.set_shader_parameter("albedo_tex", sm.albedo_texture)
	out.set_shader_parameter("albedo_color", sm.albedo_color)
	out.set_shader_parameter("use_vcol", sm.vertex_color_use_as_albedo)
	if sm.emission_enabled:
		out.set_shader_parameter("emission_color", sm.emission)
		out.set_shader_parameter("emission_energy", sm.emission_energy_multiplier)
		out.set_shader_parameter("emission_from_tex", sm.emission_texture != null)
	out.set_shader_parameter("alpha_cut", sm.alpha_scissor_threshold)
	# solid textured surfaces are painted (paint_tex); cut-outs keep their pixels
	if sm.albedo_texture != null and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		out.set_shader_parameter("paint", float(sm.get_meta("paint", PAINT)))
	out.render_priority = sm.render_priority
	_converted[sm] = out
	return out
