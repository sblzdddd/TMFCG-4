#!/usr/bin/env python3
"""Generate SkillNodeDefinition .tres files from node metadata."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEF_ROOT = ROOT / "src/editor/skill/definitions"
SKILL = "src/editor/skill"

SCRIPTS = {
    "definition": f"{SKILL}/registry/skill_node_definition.gd",
    "input_spec": f"{SKILL}/slots/skill_input_spec.gd",
    "output_spec": f"{SKILL}/slots/skill_slot_spec.gd",
}

ANY_ARRAY = -1000
WIDGET_KIND = {"number": 1, "bool": 2, "string": 3}


def port_input(entry: dict, ids: list[str]) -> tuple[str, str]:
    wid = f"input_{len(ids)}"
    ids.append(wid)
    lines = [f"[sub_resource type=\"Resource\" id=\"{wid}\"]", f"script = ExtResource(\"input_spec\")"]
    if entry.get("polymorphic"):
        lines.append(f"type = {ANY_ARRAY}")
        lines.append("type_mode = 1")
        lines.append("polymorphic_group = &\"default\"")
    else:
        lines.append(f"type = {entry.get('type', 0)}")
    if entry.get("label"):
        lines.append(f"label = \"{entry['label']}\"")
    widget = entry.get("widget")
    if widget:
        kind = widget["kind"]
        lines.append(f"inline_widget_kind = {WIDGET_KIND[kind]}")
        if kind == "number":
            lines.append(f"number_min = {widget.get('min', 0.0)}")
            lines.append(f"number_max = {widget.get('max', 100.0)}")
            lines.append(f"number_step = {widget.get('step', 1.0)}")
            lines.append(f"number_value = {widget.get('value', 0.0)}")
            lines.append(f"number_rounded = {'true' if widget.get('rounded') else 'false'}")
        elif kind == "bool":
            lines.append(f"bool_pressed = {'true' if widget.get('pressed') else 'false'}")
        elif kind == "string":
            lines.append(f"string_value = \"{widget.get('value', '')}\"")
            lines.append(f"string_placeholder = \"{widget.get('placeholder', '')}\"")
    return "\n".join(lines), wid


def port_output(entry: dict, ids: list[str]) -> tuple[str, str]:
    wid = f"output_{len(ids)}"
    ids.append(wid)
    lines = [f"[sub_resource type=\"Resource\" id=\"{wid}\"]", f"script = ExtResource(\"output_spec\")"]
    if entry.get("polymorphic"):
        lines.append(f"type = {ANY_ARRAY}")
        lines.append("type_mode = 1")
        lines.append("polymorphic_group = &\"default\"")
    else:
        lines.append(f"type = {entry.get('type', 0)}")
    if entry.get("label"):
        lines.append(f"label = \"{entry['label']}\"")
    return "\n".join(lines), wid


def write_tres(node: dict) -> None:
    rel_dir = Path(node["folder"])
    out_path = DEF_ROOT / rel_dir / f"{node['file']}.tres"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    ids: list[str] = []
    subresources: list[str] = []
    input_refs: list[str] = []
    output_refs: list[str] = []

    for entry in node.get("inputs", []):
        spec, input_id = port_input(entry, ids)
        subresources.append(spec)
        input_refs.append(f"SubResource(\"{input_id}\")")

    for entry in node.get("outputs", []):
        spec, output_id = port_output(entry, ids)
        subresources.append(spec)
        output_refs.append(f"SubResource(\"{output_id}\")")

    ext_resource_count = len(SCRIPTS)
    load_steps = ext_resource_count + len(ids) + 1
    header = [
        f"[gd_resource type=\"Resource\" script_class=\"SkillNodeDefinition\" load_steps={load_steps} format=3]",
        "",
        f"[ext_resource type=\"Script\" path=\"res://{SCRIPTS['definition']}\" id=\"definition\"]",
        f"[ext_resource type=\"Script\" path=\"res://{SCRIPTS['input_spec']}\" id=\"input_spec\"]",
        f"[ext_resource type=\"Script\" path=\"res://{SCRIPTS['output_spec']}\" id=\"output_spec\"]",
        "",
    ]
    body = [
        "[resource]",
        "script = ExtResource(\"definition\")",
        f"node_id = \"{node['id']}\"",
        f"display_name = \"{node['name']}\"",
        f"category = {node['category']}",
        f"node_script_path = \"res://{node['script']}\"",
    ]
    if input_refs:
        body.append(f"input_slot_specs = Array[ExtResource(\"input_spec\")]([{', '.join(input_refs)}])")
    if output_refs:
        body.append(f"output_slot_specs = Array[ExtResource(\"output_spec\")]([{', '.join(output_refs)}])")

    content = "\n".join(header) + "\n\n" + "\n\n".join(subresources) + "\n\n" + "\n".join(body) + "\n"
    out_path.write_text(content, encoding="utf-8")
    print(f"Wrote {out_path.relative_to(ROOT)}")


NUM = lambda **kw: {"kind": "number", **kw}
BOOL = lambda **kw: {"kind": "bool", **kw}


NODES = [
    {
        "id": "boolean.compare",
        "folder": "Boolean",
        "file": "compare_node",
        "name": "比较",
        "category": 5,
        "script": f"{SKILL}/nodes/Boolean/compare_node.gd",
        "inputs": [
            {"polymorphic": True, "label": "A"},
            {"polymorphic": True, "label": "B"},
            {"type": 2, "label": "模式", "widget": NUM(min=0, max=5, step=1, value=0, rounded=True)},
        ],
        "outputs": [{"type": 3, "label": "输出"}],
    },
    {
        "id": "boolean.and",
        "folder": "Boolean",
        "file": "and_node",
        "name": "与",
        "category": 5,
        "script": f"{SKILL}/nodes/Boolean/and_node.gd",
        "inputs": [
            {"type": 3, "label": "A", "widget": BOOL()},
            {"type": 3, "label": "B", "widget": BOOL()},
        ],
        "outputs": [{"type": 3, "label": "输出"}],
    },
    {
        "id": "boolean.or",
        "folder": "Boolean",
        "file": "or_node",
        "name": "或",
        "category": 5,
        "script": f"{SKILL}/nodes/Boolean/or_node.gd",
        "inputs": [
            {"type": 3, "label": "A", "widget": BOOL()},
            {"type": 3, "label": "B", "widget": BOOL()},
        ],
        "outputs": [{"type": 3, "label": "输出"}],
    },
    {
        "id": "boolean.not",
        "folder": "Boolean",
        "file": "not_node",
        "name": "非",
        "category": 5,
        "script": f"{SKILL}/nodes/Boolean/not_node.gd",
        "inputs": [{"type": 3, "label": "输入", "widget": BOOL()}],
        "outputs": [{"type": 3, "label": "输出"}],
    },
    {
        "id": "array.slice",
        "folder": "Array",
        "file": "slice_node",
        "name": "切片",
        "category": 6,
        "script": f"{SKILL}/nodes/Array/slice_node.gd",
        "inputs": [
            {"polymorphic": True, "label": "输入数组"},
            {"type": 0},
            {"type": 2, "label": "起始", "widget": NUM(min=-10, max=10, step=1, value=1, rounded=True)},
            {"type": 2, "label": "延伸", "widget": NUM(min=-10, max=10, step=1, value=1, rounded=True)},
        ],
        "outputs": [
            {"polymorphic": True, "label": "输出数组"},
            {"polymorphic": True, "label": "剩余数组"},
        ],
    },
    {
        "id": "array.join",
        "folder": "Array",
        "file": "join_node",
        "name": "合并",
        "category": 6,
        "script": f"{SKILL}/nodes/Array/join_node.gd",
        "inputs": [
            {"polymorphic": True, "label": "输入数组"},
            {"polymorphic": True, "label": "输入数组"},
        ],
        "outputs": [{"polymorphic": True, "label": "输出数组"}],
    },
    {
        "id": "array.reverse",
        "folder": "Array",
        "file": "reverse_node",
        "name": "反转",
        "category": 6,
        "script": f"{SKILL}/nodes/Array/reverse_node.gd",
        "inputs": [{"polymorphic": True, "label": "输入数组"}],
        "outputs": [{"polymorphic": True, "label": "输出数组"}],
    },
    {
        "id": "array.shuffle",
        "folder": "Array",
        "file": "shuffle_node",
        "name": "打乱",
        "category": 6,
        "script": f"{SKILL}/nodes/Array/shuffle_node.gd",
        "inputs": [{"polymorphic": True, "label": "输入数组"}],
        "outputs": [{"polymorphic": True, "label": "输出数组"}],
    },
    {
        "id": "card_holder.all_players",
        "folder": "CardHolder",
        "file": "all_players_node",
        "name": "所有玩家",
        "category": 2,
        "script": f"{SKILL}/nodes/CardHolder/all_players_node.gd",
        "outputs": [{"type": -5, "label": "玩家目标"}],
    },
    {
        "id": "card_holder.get_offset_player",
        "folder": "CardHolder",
        "file": "get_offset_player_node",
        "name": "获取相对位置玩家",
        "category": 2,
        "script": f"{SKILL}/nodes/CardHolder/get_offset_player_node.gd",
        "inputs": [
            {"type": -5, "label": "当前玩家"},
            {"type": 2, "label": "偏移数量", "widget": NUM(min=-5, max=5, step=1, value=1, rounded=True)},
            {"type": 2, "label": "玩家数量", "widget": NUM(min=0, max=5, step=1, value=1, rounded=True)},
            {"type": 3, "label": "按出牌历史", "widget": BOOL()},
        ],
        "outputs": [{"type": -5, "label": "玩家"}],
    },
    {
        "id": "card_holder.graveyard",
        "folder": "CardHolder",
        "file": "graveyard_node",
        "name": "墓地",
        "category": 2,
        "script": f"{SKILL}/nodes/CardHolder/graveyard_node.gd",
        "outputs": [{"type": 5, "label": "墓地目标"}],
    },
    {
        "id": "card_holder.random_player",
        "folder": "CardHolder",
        "file": "random_player_node",
        "name": "随机玩家",
        "category": 2,
        "script": f"{SKILL}/nodes/CardHolder/random_player_node.gd",
        "inputs": [
            {"type": 0},
            {"type": 2, "label": "随机数量", "widget": NUM(min=1, max=5, step=1, value=1, rounded=True)},
            {"type": 3, "label": "包含被冻结的玩家", "widget": BOOL()},
        ],
        "outputs": [{"type": -5, "label": "玩家"}],
    },
    {
        "id": "card_holder.deck",
        "folder": "CardHolder",
        "file": "deck_node",
        "name": "牌堆",
        "category": 2,
        "script": f"{SKILL}/nodes/CardHolder/deck_node.gd",
        "outputs": [{"type": 5, "label": "牌堆目标"}],
    },
    {
        "id": "card.transfer",
        "folder": "Card",
        "file": "transfer_card_node",
        "name": "转移卡牌",
        "category": 1,
        "script": f"{SKILL}/nodes/Card/transfer_card_node.gd",
        "inputs": [
            {"type": 1, "label": "事件"},
            {"type": -5, "label": "目标"},
            {"type": -6, "label": "卡牌"},
            {"type": 2, "label": "分配张数", "widget": NUM(min=1, max=5, step=1, value=1, rounded=True)},
            {"type": 3, "label": "标记隐藏", "widget": BOOL()},
            {"type": 3, "label": "无视被动", "widget": BOOL()},
        ],
        "outputs": [{"type": 1, "label": "事件"}],
    },
    {
        "id": "card.play",
        "folder": "Card",
        "file": "play_card_node",
        "name": "打出卡牌",
        "category": 1,
        "script": f"{SKILL}/nodes/Card/play_card_node.gd",
        "inputs": [
            {"type": 1, "label": "事件"},
            {"type": -6, "label": "卡牌"},
            {"type": -5, "label": "出牌目标"},
            {"type": 2, "label": "分配张数", "widget": NUM(min=1, max=5, step=1, value=1, rounded=True)},
            {"type": 3, "label": "无视被动", "widget": BOOL()},
        ],
        "outputs": [{"type": 1, "label": "事件"}],
    },
    {
        "id": "card.get_random",
        "folder": "Card",
        "file": "get_random_card_node",
        "name": "随机获取卡牌",
        "category": 1,
        "script": f"{SKILL}/nodes/Card/get_random_card_node.gd",
        "inputs": [
            {"type": 1, "label": "事件"},
            {"type": -5, "label": "目标"},
            {"type": 2, "label": "随机数量", "widget": NUM(min=1, max=10, step=1, value=1, rounded=True)},
        ],
        "outputs": [
            {"type": 1, "label": "事件"},
            {"type": -6, "label": "卡牌"},
        ],
    },
    {
        "id": "modifier.set_order",
        "folder": "Modifier",
        "file": "set_order_node",
        "name": "设置新顺序",
        "category": 3,
        "script": f"{SKILL}/nodes/Modifier/set_order_node.gd",
        "inputs": [
            {"type": 1, "label": "事件"},
            {"type": -5, "label": "玩家"},
            {"type": 3, "label": "无视被动", "widget": BOOL()},
        ],
        "outputs": [{"type": 1, "label": "事件"}],
    },
    {
        "id": "modifier.freeze",
        "folder": "Modifier",
        "file": "freeze_node",
        "name": "冻结目标",
        "category": 3,
        "script": f"{SKILL}/nodes/Modifier/freeze_node.gd",
        "inputs": [
            {"type": 1, "label": "事件"},
            {"type": -5, "label": "目标"},
            {"type": 2, "label": "冻结轮数", "widget": NUM(min=1, max=10, step=1, value=1, rounded=True)},
            {"type": 3, "label": "无法主动出牌", "widget": BOOL()},
            {"type": 3, "label": "无法无视场合出牌", "widget": BOOL()},
            {"type": 3, "label": "无视被动", "widget": BOOL()},
        ],
        "outputs": [{"type": 1, "label": "事件"}],
    },
    {
        "id": "modifier.move_player_position",
        "folder": "Modifier",
        "file": "move_player_position_node",
        "name": "偏移行动顺序",
        "category": 3,
        "script": f"{SKILL}/nodes/Modifier/move_player_position_node.gd",
        "inputs": [
            {"type": 1, "label": "事件"},
            {"type": -5, "label": "玩家"},
            {"type": 2, "label": "偏移量", "widget": NUM(min=-10, max=10, step=1, value=1, rounded=True)},
            {"type": 3, "label": "下一局", "widget": BOOL()},
            {"type": 3, "label": "无视被动", "widget": BOOL()},
        ],
        "outputs": [{"type": 1, "label": "事件"}],
    },
]


def main() -> None:
    for node in NODES:
        write_tres(node)


if __name__ == "__main__":
    main()
