shader_type canvas_item;
render_mode unshaded;
uniform sampler2D cardTex : hint_default_black;
uniform sampler2D cardMasks : hint_default_black;
uniform sampler2D partsTex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D characterTex : hint_default_transparent, filter_nearest, repeat_disable;
uniform vec3 characterTransform = vec3(0, 0, 1);
uniform float charOutlineWidth : hint_range(0, 1.5) = 0.8;
uniform vec4 charOutlineColor : source_color = vec4(vec3(.9),1);

uniform float cardRadius : hint_range(0.0, 0.2) = 0.08;
uniform float outlineWidth : hint_range(0.0, 0.02) = 0.015;
uniform vec4 outlineColor : source_color = vec4(1., 0.694, 0.045, 1.);

const ivec2 PARTS_SIZE = ivec2(1024);
const float CARD_RATIO = 3./4.;
const vec3 TOP_POS = vec3(0, -0.404, 0.5);
const vec3 BOTTOM_POS = vec3(0, 0.34, 0.76);
const ivec4 TOP_CROP = ivec4(0, 0, 375, 183);
const ivec4 BOTTOM_CROP = ivec4(1, 366, 560, 377);

uniform vec3 tint1 : source_color = vec3(0.5921569, 0.2705882, 0.2);
uniform vec3 tint2 : source_color = vec3(0.7176471, 0.345098, 0.2196078);
uniform vec3 tint3 : source_color = vec3(1, 1, 1);
	
float Rounded(vec2 uv, vec2 Size, float Radius)
{
    float R = min(abs(Radius), min(Size.x, Size.y));
    vec2 P = abs(uv - 0.5) * 2.0;
    vec2 q = abs(P) - Size + R;
    float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - R;
    float px = length(vec2(dFdx(dist), dFdy(dist)));
	dist -= 0.5 * px;
    return smoothstep(px, -px, dist);
}

float RoundedMask(vec2 uv, float radius, float size) {
	vec2 t_uv = uv * vec2(CARD_RATIO, 1) + vec2((1. - CARD_RATIO) / 2., 0);
	vec2 r_size = vec2(CARD_RATIO - (1.-size), size);
	return Rounded(t_uv, r_size, radius);
}

vec3 RatioCorrectUV(vec2 uv, vec3 transform, ivec2 texSize, ivec4 crop, bool soft, bool reflect) {
	vec2 tex_size = vec2(texSize);
	bool use_full_tex = crop.z == 0 && crop.w == 0;
	vec2 crop_origin = use_full_tex ? vec2(0.0) : vec2(crop.xy);
	vec2 crop_size = use_full_tex ? tex_size : vec2(crop.zw);
	vec2 display_size = reflect ? vec2(crop_size.x * 2.0, crop_size.y) : crop_size;
	float tex_ratio = display_size.x / display_size.y;
	vec2 scale;
	if (tex_ratio > CARD_RATIO) {
		scale = vec2(1, tex_ratio / CARD_RATIO);
	} else {
		scale = vec2(CARD_RATIO / tex_ratio, 1);
	}
	vec2 scaled = uv - (0.5 + transform.xy);
	scaled *= 2. / transform.z;
	scaled *= 0.5 * scale;
	scaled += 0.5;
	float aa = soft ? max(length(fwidth(scaled)), 0.0005) : 0.0;
	vec2 edge = smoothstep(vec2(0.0), vec2(aa), scaled)
			* smoothstep(vec2(1.0), vec2(1.0 - aa), scaled);
	float r = edge.x * edge.y;
	if (reflect) {
		scaled.x = abs(scaled.x * 2.0 - 1.0);
	}
	scaled = crop_origin / tex_size + scaled * (crop_size / tex_size);
	return vec3(scaled, r);
}

vec4 sampleSuitTex(sampler2D tex, vec3 uvm) {
	vec2 uv = uvm.xy;
	vec4 col = textureGrad(tex, uv, dFdx(uv), dFdy(uv));
	return col * uvm.z;
}

float SimpleOutline(vec2 uv, sampler2D tex, float width) {
	return max(
		max(texture(tex, vec2(uv.x + width, uv.y)).a, texture(tex, vec2(uv.x - width, uv.y)).a),
		max(texture(tex, vec2(uv.x, uv.y + width)).a, texture(tex, vec2(uv.x, uv.y - width)).a)
	);
}

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

	vec3 charTransform = vec3(characterTransform.x, characterTransform.y + 0.1, characterTransform.z * 0.85);
	vec2 charUV = RatioCorrectUV(UV, charTransform, textureSize(characterTex, 0), ivec4(0), false, false).xy;
	vec4 characterCol = texture(characterTex, charUV);
	float charOutlineMask = SimpleOutline(charUV, characterTex, charOutlineWidth * 0.01);
	charOutlineMask = clamp(charOutlineMask - characterCol.a, 0.0, 1.0) * charOutlineColor.a;
	albedo = mix(albedo, characterCol.rgb, characterCol.a * masks.r);
	albedo = mix(albedo, charOutlineColor.rgb, charOutlineMask * masks.r);

	vec3 topUVM = RatioCorrectUV(UV, TOP_POS, PARTS_SIZE, TOP_CROP, true, true);
	vec4 top = sampleSuitTex(partsTex, topUVM);
	vec3 topUVA = RatioCorrectUV(UV, TOP_POS, PARTS_SIZE, TOP_CROP + ivec4(0, TOP_CROP.w, 0, 0), true, true);
	vec4 topA = sampleSuitTex(partsTex, topUVA);

	vec3 bottomUVM = RatioCorrectUV(UV, BOTTOM_POS, PARTS_SIZE, BOTTOM_CROP, true, true);
	vec4 bottom = sampleSuitTex(partsTex, bottomUVM);
	vec3 bottomUVA = RatioCorrectUV(UV, BOTTOM_POS, PARTS_SIZE, BOTTOM_CROP + ivec4(0, BOTTOM_CROP.w, 0, 0), true, true);
	vec4 bottomA = sampleSuitTex(partsTex, bottomUVA);

	vec3 iconUV = RatioCorrectUV(UV, vec3(-0.364, -0.366, 0.045), PARTS_SIZE, ivec4(960,960,64,64), true, false);
	vec4 icon = sampleSuitTex(partsTex, iconUV);
	
	vec3 iconUV2 = RatioCorrectUV(UV, vec3(0.364, 0.366, -0.045), PARTS_SIZE, ivec4(960,960,64,64), true, false);
	icon += sampleSuitTex(partsTex, iconUV2);
	
	vec4 combinedSuit = SuitTint(max(max(top, bottom), icon - vec4(0.6)).r);
	albedo = mix(albedo, combinedSuit.rgb, combinedSuit.a);

    COLOR.a = RoundedMask(UV, cardRadius, 1.);
	COLOR.xyz = albedo.xyz;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
