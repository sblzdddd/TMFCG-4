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

float RoundedMask(vec3 uvr, float radius, float size) {
	vec2 uv = uvr.xy;
	float ratio = uvr.z;
	vec2 t_uv = uv * vec2(ratio, 1) + vec2((1. - ratio) / 2., 0);
	vec2 r_size = vec2(ratio - (1.-size), size);
	return Rounded(t_uv, r_size, radius);
}

struct RatioUVResult {
	vec2 uv;
	vec2 grad_uv;
	float mask;
};

// flags: x = soft edges, y = reflect, z = infinite repeat, w = rotation angle (radians)
RatioUVResult RatioCorrectUV(vec3 uvr, vec3 transform, ivec2 texSize, ivec4 crop, vec4 flags) {
	vec2 uv = uvr.xy;
	float ratio = uvr.z;
	bool soft = flags.x > 0.5;
	bool reflect = flags.y > 0.5;
	bool repeat = flags.z > 0.5;
	float angle = flags.w;
	vec2 tex_size = vec2(texSize);
	bool use_full_tex = crop.z == 0 && crop.w == 0;
	vec2 crop_origin = use_full_tex ? vec2(0.0) : vec2(crop.xy);
	vec2 crop_size = use_full_tex ? tex_size : vec2(crop.zw);
	vec2 display_size = reflect ? vec2(crop_size.x * 2.0, crop_size.y) : crop_size;
	float tex_ratio = display_size.x / display_size.y;
	vec2 scale;
	if (tex_ratio > ratio) {
		scale = vec2(1, tex_ratio / ratio);
	} else {
		scale = vec2(ratio / tex_ratio, 1);
	}
	vec2 scaled = uv - (0.5 + transform.xy);
	if (angle != 0.0) {
		float s = sin(angle);
		float c = cos(angle);
		scaled.x *= ratio;
		scaled = vec2(scaled.x * c - scaled.y * s, scaled.x * s + scaled.y * c);
		scaled.x /= ratio;
	}
	scaled *= 2. / transform.z;
	scaled *= 0.5 * scale;
	scaled += 0.5;
	float aa = soft ? max(length(fwidth(scaled)), 0.0005) : 0.0;
	vec2 edge = smoothstep(vec2(0.0), vec2(aa), scaled)
			* smoothstep(vec2(1.0), vec2(1.0 - aa), scaled);
	float r = repeat ? 1.0 : edge.x * edge.y;
	vec2 grad_uv = crop_origin / tex_size + scaled * (crop_size / tex_size);
	if (repeat) {
		scaled = fract(scaled);
	}
	if (reflect) {
		scaled.x = abs(scaled.x * 2.0 - 1.0);
	}
	vec2 sample_uv = crop_origin / tex_size + scaled * (crop_size / tex_size);
	return RatioUVResult(sample_uv, grad_uv, r);
}

vec2 TransformUV(vec3 uvr, vec3 transform, ivec2 texSize) {
	vec2 uv = uvr.xy;
	float ratio = uvr.z;
	vec2 scaled = uv - (0.5 + transform.xy);
	float tex_ratio = float(texSize.x) / float(texSize.y);
	vec2 aspect = tex_ratio > ratio
		? vec2(1.0, tex_ratio / ratio)
		: vec2(ratio / tex_ratio, 1.0);
	scaled *= aspect / max(transform.z, 0.0001);
	return scaled + 0.5;
}

vec4 sampleSuitTex(sampler2D tex, RatioUVResult uvm) {
	vec4 col = textureGrad(tex, uvm.uv, dFdx(uvm.grad_uv), dFdy(uvm.grad_uv));
	return col * uvm.mask;
}

float SimpleOutline(vec2 uv, sampler2D tex, float width) {
	vec2 size = normalize(vec2(textureSize(tex, 0)));
	float sx = width * size.y;
	float sy = width * size.x;
	return max(
		max(texture(tex, vec2(uv.x + sx, uv.y)).a, texture(tex, vec2(uv.x - sx, uv.y)).a),
		max(texture(tex, vec2(uv.x, uv.y + sy)).a, texture(tex, vec2(uv.x, uv.y - sy)).a)
	);
}

vec3 color_burn(vec3 base, vec3 blend) {
    return vec3(
        blend.r == 0.0 ? 0.0 : max(1.0 - (1.0 - base.r) / blend.r, 0.0),
        blend.g == 0.0 ? 0.0 : max(1.0 - (1.0 - base.g) / blend.g, 0.0),
        blend.b == 0.0 ? 0.0 : max(1.0 - (1.0 - base.b) / blend.b, 0.0)
    );
}

// Fake 3D Y-axis rotation through the card center (UV 0.5).
// Card lies in XY facing +Z; camera looks along -Z.
// Returns card-space UV in [0,1]. Call after checking facing > 0 and valid.
struct PerspectiveYResult {
	vec2 uv;
	float facing;
	bool valid;
};

PerspectiveYResult PerspectiveYRotate(vec2 screen_uv, float angle, float perspective) {
	float c = cos(angle);
	float s = sin(angle);
	PerspectiveYResult r;
	r.facing = c;
	r.uv = screen_uv;
	r.valid = false;

	// Backface: normal.z = cos(angle); cull when facing away from camera.
	if (c <= 0.0) {
		return r;
	}

	vec2 p = screen_uv * 2.0 - 1.0;
	float denom = c - p.x * s * perspective;
	if (abs(denom) < 1e-5) {
		return r;
	}

	// Inverse of: (u,v,0) --Ry--> (u*c, v, -u*s) --persp--> xy/(1 - z*perspective)
	float u = p.x / denom;
	float v = p.y * (1.0 + u * s * perspective);
	if (abs(u) > 1.0 || abs(v) > 1.0) {
		return r;
	}

	r.uv = vec2(u, v) * 0.5 + 0.5;
	r.valid = true;
	return r;
}
