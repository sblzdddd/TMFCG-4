shader_type canvas_item;
render_mode unshaded;
uniform sampler2D cardTex : hint_default_black, filter_linear_mipmap, repeat_disable;

uniform float cardRadius : hint_range(0.0, 0.2) = 0.08;

const float CARD_RATIO = 3./4.;

#include "res://src/shaders/card_utils.gdshaderinc"

void fragment() {
	vec3 albedo = texture(cardTex, UV).xyz;
	vec3 uvr = vec3(UV, CARD_RATIO);

    COLOR.a = RoundedMask(uvr, cardRadius, 1.);
	COLOR.xyz = vec3(albedo);
}
