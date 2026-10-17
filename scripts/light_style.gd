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

static var _shaders := {}     ## variant key -> Shader
static var _converted := {}   ## StandardMaterial3D -> ShaderMaterial

const TEMPLATE := """
shader_type spatial;
render_mode {modes};
#include "res://shaders/light3d.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest, {repeat};
uniform bool has_tex = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vcol = false;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform bool emission_from_tex = false;
uniform float alpha_cut = 0.5;

void fragment() {
	vec4 c = albedo_color;
	if (has_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (use_vcol) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	{alpha}
	vec3 em = emission_color * emission_energy;
	if (emission_from_tex && has_tex) {
		em *= texture(albedo_tex, UV).rgb;
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
	out.render_priority = sm.render_priority
	_converted[sm] = out
	return out
