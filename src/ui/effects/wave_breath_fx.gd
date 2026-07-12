@tool
class_name WaveBreathFx
extends RichTextEffect

## BBCode: [wave_breath]text[/wave_breath]
## Optional params: freq, phase, color1, color2
## Example: [wave_breath freq=0.8 phase=0.35 color1=#ffffff70 color2=#ffbccc]
var bbcode := "wave_breath"

@export var default_color1: Color = Color(1, 1, 1, 0.2)
@export var default_color2: Color = Color(1, 1, 1, 0.7)
@export var default_freq: float = 0.85
@export var default_phase: float = 0.1


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var env := char_fx.env
	var freq: float = float(env.get("freq", default_freq))
	var phase: float = float(env.get("phase", default_phase))
	var color1 := _resolve_color(env, "color1", default_color1)
	var color2 := _resolve_color(env, "color2", default_color2)

	var wave := sin((char_fx.elapsed_time * freq - char_fx.relative_index * phase) * TAU)
	var t := (wave + 1.0) * 0.5
	char_fx.color = color1.lerp(color2, t)
	return true


func _resolve_color(env: Dictionary, key: String, fallback: Color) -> Color:
	if not env.has(key):
		return fallback
	var value: Variant = env[key]
	if value is Color:
		return value
	if value is String:
		return Color(value)
	return fallback
