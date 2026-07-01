shader_type canvas_item;
render_mode unshaded;
uniform sampler2D cardTex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D cardMasks : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D partsTex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D characterTex : hint_default_transparent, filter_nearest, repeat_disable;
uniform sampler2D JQKTex : hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform vec3 characterTransform = vec3(0, 0, 1);
uniform float charOutlineWidth : hint_range(0, 1.5) = 0.8;
uniform vec4 charOutlineColor : source_color = vec4(vec3(.9),1);
uniform int suit: hint_enum("Club", "Diamond", "Heart", "Spade") = 0;
uniform int value: hint_enum("-", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K") = 1;

uniform float cardRadius : hint_range(0.0, 0.2) = 0.08;
uniform float outlineWidth : hint_range(0.0, 0.02) = 0.015;
uniform vec4 outlineColor : source_color = vec4(1., 0.694, 0.045, 1.);

const ivec2 PARTS_SIZE = ivec2(1024);
const float CARD_RATIO = 3./4.;
const vec3 TOP_POS = vec3(0, -0.404, 0.5);
const vec3 BOTTOM_POS = vec3(0, 0.335, 0.75);
const ivec4 TOP_CROP = ivec4(0, 0, 375, 183);
const ivec4 BOTTOM_CROP = ivec4(1, 366, 560, 377);
const ivec4 TOP_CROPA = ivec4(0, 183, 375, 183);
const ivec4 BOTTOM_CROPA = ivec4(1, 366+377, 560, 377);
const ivec4 ICON_CROP = ivec4(992, 992, 32, 32);
const vec3 ICON_POS = vec3(-0.364, -0.366, 0.045);
const ivec4 BG_TILE_CROP = ivec4(1024-71*2-35, 0, 142, 311);
const ivec4 LASER_CROP = ivec4(1024-379, 512-189, 380, 378);

uniform vec3 tint1 : source_color = vec3(0.5921569, 0.2705882, 0.2);
uniform vec3 tint2 : source_color = vec3(0.7176471, 0.345098, 0.2196078);
uniform vec3 tint3 : source_color = vec3(1, 1, 1);
uniform vec4 laserParams = vec4(0, 0, 1, 0);
uniform vec3 bgTileParams = vec3(0.5, 0.5, 0.3);

#include "res://src/shaders/card_utils.gdshaderinc"

vec4 SuitTint(float matCol) {
	float aa = max(fwidth(matCol), 0.002);
	return vec4(
		mix(
			mix(tint1, tint2, smoothstep(0.2 - aa, 0.62 + aa, matCol)),
			tint3, smoothstep(0.625 - aa, 1.0 + aa, matCol)
		),
		smoothstep(-aa, 0.1 + aa, matCol)
	);
}

void fragment() {
	vec3 albedo = texture(cardTex, UV).xyz;
	vec3 masks = texture(cardMasks, UV).rgb;
	vec3 uvr = vec3(UV, CARD_RATIO);
	
	RatioUVResult bgTileUV = RatioCorrectUV(uvr, bgTileParams * vec3(vec2(TIME*.1),1), PARTS_SIZE, BG_TILE_CROP, vec4(1, 0, 1, 3.1415926/6.));
	vec4 bgTile = sampleSuitTex(partsTex, bgTileUV);
	albedo = mix(albedo, bgTile.rgb, bgTile.a * masks.b);

	RatioUVResult topUVM = RatioCorrectUV(uvr, TOP_POS, PARTS_SIZE, TOP_CROP, vec4(1, 1, 0, 0));
	vec4 top = sampleSuitTex(partsTex, topUVM);
	RatioUVResult topUVA = RatioCorrectUV(uvr, TOP_POS, PARTS_SIZE, TOP_CROPA, vec4(1, 1, 0, 0));
	vec4 topA = sampleSuitTex(partsTex, topUVA);

	RatioUVResult bottomUVM = RatioCorrectUV(uvr, BOTTOM_POS, PARTS_SIZE, BOTTOM_CROP, vec4(1, 1, 0, 0));
	vec4 bottom = sampleSuitTex(partsTex, bottomUVM);
	RatioUVResult bottomUVA = RatioCorrectUV(uvr, BOTTOM_POS, PARTS_SIZE, BOTTOM_CROPA, vec4(1, 1, 0, 0));
	vec4 bottomA = sampleSuitTex(partsTex, bottomUVA);

	RatioUVResult iconUV = RatioCorrectUV(uvr, ICON_POS, PARTS_SIZE, ICON_CROP, vec4(1, 0, 0, 0));
	vec4 icon = sampleSuitTex(partsTex, iconUV);
	
	RatioUVResult iconUV2 = RatioCorrectUV(uvr, ICON_POS * vec3(-1), PARTS_SIZE, ICON_CROP, vec4(1, 0, 0, 0));
	icon += sampleSuitTex(partsTex, iconUV2);

	vec4 suits = bottom;
	if (value == 1) {
		suits += top;
	} else if (value != 0) {
		vec2 cuv = abs(UV - vec2(0.5));
		if (value > 4) {
			float bx011 = step(cuv.x, 0.11);
			if (value <= 7) {
				suits = mix(bottom, bottomA, step(cuv.x, 0.275) - bx011);
			} else if (value <= 10) {
				suits = bx011 * bottom + bottomA;
			} else {
				suits = bx011 * bottom;
			}
		}
		if (value >= 2 && value <= 10) {
			float tx005 = step(cuv.x, 0.05);
			float tx165 = step(cuv.x, 0.165);
			float topMix = 1.0;
			if (value == 2) {
				topMix = tx005;
			} else if (value == 3 || value == 5) {
				topMix = tx165 - tx005;
			} else if (value == 4 || value == 6 || value == 8) {
				topMix = tx165;
			} else if (value == 7 || value == 9) {
				topMix = 1.0 - tx005;
			}
			suits += mix(top, topA, topMix);
		}
	}
	
	vec4 combinedSuit = mix(SuitTint(suits[suit]), icon[suit] * vec4(tint1, 1.), icon[suit]);
	albedo = mix(albedo, combinedSuit.rgb, combinedSuit.a);
	
	int JQKIndex = clamp(value-11, -1, 2);
	RatioUVResult JQKUV = RatioCorrectUV(uvr, vec3(0,-0.04,0.91), textureSize(JQKTex, 0), ivec4(JQKIndex*561,0,561,907), vec4(1,0,0,0));
	vec4 JQK = sampleSuitTex(JQKTex, JQKUV);
	albedo = mix(albedo, JQK.rgb, JQK.a * step(0.0, float(JQKIndex)));
	
	RatioUVResult laserUV = RatioCorrectUV(uvr, laserParams.xyz, PARTS_SIZE, LASER_CROP, vec4(1, 0, 1, 0));
	vec4 laser = sampleSuitTex(partsTex, laserUV);
	float laserMask = masks.g + step(0.1, suits[suit]) - bgTile.a * masks.b;

	albedo = mix(albedo, albedo + color_burn(albedo, laser.rgb) * 0.75, clamp(laserMask, 0.0, 1.0) * laserParams.w);
	
	vec3 charTransform = characterTransform * vec3(.2,.2,.86) + vec3(0, .12, 0);
	vec2 charUV = RatioCorrectUV(uvr, charTransform, textureSize(characterTex, 0), ivec4(0), vec4(0)).uv;
	vec4 characterCol = texture(characterTex, charUV);
	float charOutlineMask = SimpleOutline(charUV, characterTex, charOutlineWidth * 0.02);
	charOutlineMask = clamp(charOutlineMask - characterCol.a, 0.0, 1.0) * charOutlineColor.a;
	albedo = mix(albedo, characterCol.rgb, characterCol.a * masks.r);
	albedo = mix(albedo, charOutlineColor.rgb, charOutlineMask * masks.r);

    COLOR.a = RoundedMask(uvr, cardRadius, 1.);
	COLOR.xyz = albedo.xyz;
}
