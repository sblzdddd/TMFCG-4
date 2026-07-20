shader_type canvas_item;
render_mode unshaded;
uniform sampler2D cardTex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D cardMasks : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D bgTileTex : hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform sampler2D laserTex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D suitLayerTex : hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D characterTex : hint_default_transparent, filter_nearest, repeat_disable;
uniform vec3 characterTransform = vec3(0, 0, 1);
uniform float charOutlineWidth : hint_range(0, 1.5) = 0.8;
uniform vec4 charOutlineColor : source_color = vec4(vec3(.9), 1);

uniform float cardRadius : hint_range(0.0, 0.2) = 0.08;

const float CARD_RATIO = 3./4.;
const float BG_TILE_ANGLE = 3.1415926 / 6.;

uniform vec4 laserParams = vec4(0, 0, 1, 0);
// xy = scroll speed; z = scale (z <= 0 disables bg tile).
uniform vec3 bgTileParams = vec3(0.5, 0.5, 0.0);

#include "res://src/shaders/card_utils.gdshaderinc"

void fragment() {
	vec3 albedo = texture(cardTex, UV).xyz;
	vec3 masks = texture(cardMasks, UV).rgb;
	vec3 uvr = vec3(UV, CARD_RATIO);
	vec2 cuv = abs(UV - vec2(0.5));

	vec4 suitLayer = texture(suitLayerTex, UV);
	albedo = mix(albedo, suitLayer.rgb, suitLayer.a);

	if (laserParams.w > 0.0) {
		vec4 laser = texture(laserTex, TransformUV(uvr, laserParams.xyz, textureSize(laserTex, 0)));
		float laserMask = masks.g + step(0.1, suitLayer.a);
		albedo = mix(albedo, albedo + color_burn(albedo, laser.rgb) * 0.75, clamp(laserMask, 0.0, 1.0) * laserParams.w);
	}

	vec3 charTransform = characterTransform * vec3(.2, .2, .86) + vec3(0, .12, 0);
	vec2 charUV = TransformUV(uvr, charTransform, textureSize(characterTex, 0));
	vec4 characterCol = texture(characterTex, charUV);
	float charOutlineMask = SimpleOutline(charUV, characterTex, charOutlineWidth * 0.02);
	charOutlineMask = clamp(charOutlineMask - characterCol.a, 0.0, 1.0) * charOutlineColor.a;
	float charMask = min(masks.r, clamp(smoothstep(0.649, 0.639, UV.y) + step(cuv.x, 0.3125), 0., 1.));
	albedo = mix(albedo, characterCol.rgb, characterCol.a * charMask);
	albedo = mix(albedo, charOutlineColor.rgb, charOutlineMask * charMask);

	COLOR.a = RoundedMask(uvr, cardRadius, 1.);
	COLOR.xyz = vec3(albedo);
}
