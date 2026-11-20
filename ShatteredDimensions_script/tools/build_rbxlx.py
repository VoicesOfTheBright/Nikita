#!/usr/bin/env python3
"""Собирает готовое место Roblox (.rbxlx) из Luau-исходников проекта.

Файлы с суффиксом .server.luau превращаются в Script,
с суффиксом .client.luau — в LocalScript, остальные — в ModuleScript.
"""

from __future__ import annotations

import html
import pathlib
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
OUTPUT = ROOT / "ShatteredDimensions.rbxlx"

_referent = 0


def next_referent() -> str:
    global _referent
    _referent += 1
    return f"RBX{_referent:06d}"


def indent(level: int) -> str:
    return "  " * level


def property_xml(name: str, value: str, level: int) -> str:
    pad = indent(level)
    escaped = html.escape(value, quote=False)
    return f'{pad}<string name="{name}">{escaped}</string>'


class Node:
    def __init__(self, class_name: str, name: str):
        self.class_name = class_name
        self.name = name
        self.properties: dict[str, object] = {}
        self.children: list[Node] = []

    def render(self, level: int = 1) -> str:
        pad = indent(level)
        lines = [
            f'{pad}<Item class="{self.class_name}" referent="{next_referent()}">',
            f"{pad}  <Properties>",
            property_xml("Name", self.name, level + 2),
        ]

        for prop_name, value in self.properties.items():
            if prop_name == "Source":
                lines.append(f'{pad}    <ProtectedString name="Source"><![CDATA[\n{value}\n]]></ProtectedString>')
            elif isinstance(value, bool):
                lines.append(f'{pad}    <bool name="{prop_name}">{"true" if value else "false"}</bool>')
            else:
                lines.append(property_xml(prop_name, str(value), level + 2))

        lines.append(f"{pad}  </Properties>")
        for child in self.children:
            lines.append(child.render(level + 1))
        lines.append(f"{pad}</Item>")
        return "\n".join(lines)


def folder_node(name: str) -> Node:
    return Node("Folder", name)


def script_node_from_file(path: pathlib.Path) -> Node:
    name = path.name
    if name.endswith(".server.luau"):
        class_name = "Script"
        clean_name = name[: -len(".server.luau")]
    elif name.endswith(".client.luau"):
        class_name = "LocalScript"
        clean_name = name[: -len(".client.luau")]
    elif name.endswith(".luau"):
        class_name = "ModuleScript"
        clean_name = name[: -len(".luau")]
    else:
        raise ValueError(f"Неизвестный файл Luau: {path}")

    node = Node(class_name, clean_name)
    node.properties["Source"] = path.read_text(encoding="utf-8").rstrip("\n")
    if class_name in ("Script", "LocalScript"):
        node.properties["Disabled"] = False
    return node


def folder_from_directory(path: pathlib.Path, name: str | None = None) -> Node:
    node = folder_node(name or path.name)
    for child in sorted(path.iterdir(), key=lambda p: (p.is_dir(), p.name)):
        if child.is_dir():
            node.children.append(folder_from_directory(child))
        elif child.suffix == ".luau":
            # Вложенные папки UI и Controllers имеют только ModuleScript'ы.
            node.children.append(script_node_from_file(child))
    return node


def string_value(name: str, value: str) -> Node:
    node = Node("StringValue", name)
    node.properties["Value"] = value.strip()
    return node


def build_content_folder() -> Node:
    content = folder_node("Content")
    content.children.append(string_value(
        "README",
        """
SHATTERED DIMENSIONS — CONTENT SDK
Maps — модели карт.
CharacterModels — костюмы персонажей.
Abilities — ModuleScript'ы способностей (см. _TemplateAbility).

Подробная инструкция — в README.md проекта и README внутри каждой папки.
""",
    ))

    maps = folder_node("Maps")
    maps.children.append(string_value(
        "README",
        """
КАК ДОБАВИТЬ 3D-КАРТУ
1. Поместите Model внутрь этой папки. Имя не должно начинаться с "_".
2. Модель должна быть собрана в любом месте; при старте раунда её pivot
   переместится в зону арены.
3. Добавьте части-маркеры спавна:
   • Part с атрибутом SpawnRole = "Killer" (или имя KillerSpawn / LostSoulSpawn)
   • один или несколько Part с SpawnRole = "Savior" (SurvivorSpawn / SaviorSpawn)
   Маркеры автоматически станут невидимыми и не будут сталкиваться.
   Необязательный атрибут SpawnOffset (Vector3) — смещение от маркера (по умолчанию 0,4,0).
4. Атрибуты модели (все необязательные):
   MapName (string), MapSubtitle (string), Weight (number), Enabled (bool),
   ClockTime, Brightness, FogStart, FogEnd (number),
   AmbientColor, OutdoorAmbientColor, FogColor (Color3).
5. Модели с именем, начинающимся с "_", и с Enabled = false игнорируются.

Если маркеров нет, система создаст резервные точки — но лучше расставить свои.
""",
    ))
    content.children.append(maps)

    characters = folder_node("CharacterModels")
    characters.children.append(string_value(
        "README",
        """
КАК ДОБАВИТЬ 3D-МОДЕЛЬ ПЕРСОНАЖА
1. Поместите Model внутрь этой папки.
2. Назовите её id персонажа (например, seeker) или id скина
   (например, seeker_nocturne). Можно вместо имени задать атрибут
   CharacterId или SkinId.
3. Модель — это костюм поверх аватара. Каждая BasePart крепится к части
   аватара по имени (Head, UpperTorso, RightHand и т.д.) или по атрибуту
   AvatarPart. Неизвестные части крепятся к торсу.
4. Соберите модель в стойке, примерно совпадающей с R15-аватаром.
   Управление и анимации остаются от аватара, поэтому кастомные
   Motor6D внутри модели не анимируются отдельно.
5. Имена, начинающиеся с "_", игнорируются.

Приоритет: скин → персонаж. Модели не нужны для работы игры:
без них используется обычный аватар.
""",
    ))
    content.children.append(characters)

    abilities = folder_from_directory(SRC / "content" / "abilities", "Abilities")
    content.children.append(abilities)
    return content


def build() -> str:
    workspace = Node("Workspace", "Workspace")
    players = Node("Players", "Players")
    players.properties["CharacterAutoLoads"] = False
    lighting = Node("Lighting", "Lighting")

    replicated = Node("ReplicatedStorage", "ReplicatedStorage")
    replicated.children.append(folder_from_directory(SRC / "shared", "Shared"))

    server_scripts = Node("ServerScriptService", "ServerScriptService")
    server_scripts.children.append(script_node_from_file(SRC / "server" / "Bootstrap.server.luau"))
    services = folder_from_directory(SRC / "server" / "Services", "Services")
    server_scripts.children.append(services)

    server_storage = Node("ServerStorage", "ServerStorage")
    content_root = folder_node("ShatteredDimensions")
    content_root.children.append(build_content_folder())
    server_storage.children.append(content_root)

    starter_player = Node("StarterPlayer", "StarterPlayer")
    starter_scripts = Node("StarterPlayerScripts", "StarterPlayerScripts")
    client_folder = folder_from_directory(SRC / "client", "Client")
    starter_scripts.children.append(client_folder)
    starter_player.children.append(starter_scripts)

    services_root = [workspace, players, lighting, replicated, server_scripts, server_storage, starter_player]

    chunks = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        "  <External>null</External>",
        "  <External>nil</External>",
        '  <Meta name="ExplicitAutoJoints">true</Meta>',
    ]
    for service in services_root:
        chunks.append(service.render(1))
    chunks.append("</roblox>")
    return "\n".join(chunks) + "\n"


def main() -> None:
    xml = build()
    OUTPUT.write_text(xml, encoding="utf-8")

    # Проверка, что XML как минимум корректно разбирается.
    ET.fromstring(xml)
    print(f"Готово: {OUTPUT}")
    print(f"Размер: {OUTPUT.stat().st_size / 1024:.1f} КБ")


if __name__ == "__main__":
    main()
