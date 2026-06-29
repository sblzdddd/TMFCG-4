shader_type canvas_item;

#include "res://src/shaders/card_utils.gdshaderinc"

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform vec2 shadow_offset = vec2(2, 2);
// uniform vec4 outline_color : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	vec2 sprite_size = normalize(vec2(textureSize(TEXTURE, 0)));
	// float outline = SimpleOutline(UV, TEXTURE, 0.01);
	// float alpha = max(sprite.a, outline);
	float alpha = sprite.a;
	// vec3 albedo = mix(sprite.rgb, outline_color.rgb, clamp(outline - sprite.a, 0.0, 1.0));
	vec3 albedo = sprite.rgb;
	vec4 sprite_shadow = texture(TEXTURE, UV + shadow_offset * vec2(-0.01) * sprite_size.yx);
	// float shadow_mask = clamp(sprite_shadow.a - outline, 0.0, 1.0);
	float shadow_mask = clamp(sprite_shadow.a - sprite.a, 0.0, 1.0);
	// float shadow_mask = sprite_shadow.a;
	alpha = max(alpha, sprite_shadow.a * shadow_color.a);
	COLOR = vec4(mix(albedo, shadow_color.rgb, shadow_mask), alpha * opacity);
}
