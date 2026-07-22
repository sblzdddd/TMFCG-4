class_name CardAnim
extends RefCounted
## Shared tween timings and easing for card motion and interaction.
## Set [member duration_modifier] to scale all card animation speed globally
## (>1 slower, <1 faster).


## Multiplier applied by every duration accessor below.
static var duration_modifier: float = 1.0

const FLIP_DURATION := 0.35
const SELECT_DURATION := 0.2
const MOVE_DURATION := 0.55
const STAGGER_DELAY := 0.05
const FADE_OUT_DURATION := 0.45

const TRANS := Tween.TRANS_QUART
const EASE := Tween.EASE_OUT
const FADE_OUT_TRANS := Tween.TRANS_QUAD
const FADE_OUT_EASE := Tween.EASE_IN


static func flip_duration() -> float:
	return FLIP_DURATION * duration_modifier


static func select_duration() -> float:
	return SELECT_DURATION * duration_modifier


static func move_duration() -> float:
	return MOVE_DURATION * duration_modifier


static func stagger_delay() -> float:
	return STAGGER_DELAY * duration_modifier


static func fade_out_duration() -> float:
	return FADE_OUT_DURATION * duration_modifier


static func init_tween(node: Node, tween: Tween = null) -> Tween:
	return TweenUtils.init_tween(node, tween, TRANS, EASE)


static func init_fade_out_tween(node: Node, tween: Tween = null) -> Tween:
	return TweenUtils.init_tween(node, tween, FADE_OUT_TRANS, FADE_OUT_EASE)
