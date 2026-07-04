class_name SystemUtils
extends RefCounted


static func is_editor(node: Node) -> bool:
    return node != null and node.get_tree().edited_scene_root != null and node.get_tree().edited_scene_root in [node, node.owner]

