class_name TweenUtils
extends RefCounted

static func init_tween(node: Node, tween: Tween, trans: int = Tween.TRANS_EXPO, easing: int = Tween.EASE_OUT) -> Tween:
	if tween != null:
		tween.kill()
	return node.create_tween().set_trans(trans).set_ease(easing)