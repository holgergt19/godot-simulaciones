#!/usr/bin/env python3
"""
build_kit.py — Sophie's Godot construction-kit generator.

Escanea assets/models/<pack>/*.glb, calcula la caja de colision real de
cada modelo (a partir de su geometria, no a ojo) y genera una escena
.tscn lista para arrastrar: StaticBody3D -> (modelo instanciado + colision).

Uso:
    pip install pygltflib --break-system-packages
    python3 tools/build_kit.py

Vuelve a ejecutarlo cada vez que agregues un pack nuevo en assets/models/.
Para un pack nuevo, agrega su carpeta a PACKS y sus reglas a CATEGORY_RULES.
"""
import re
from pathlib import Path
from pygltflib import GLTF2

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "assets" / "models"
OUT = ROOT / "scenes" / "kit"

# pack_folder_name -> lista de (categoria, [prefijos o palabras clave])
# Se evalua en orden; el primer match gana. "*" al final = todo lo demas.
CATEGORY_RULES = {
    "kenney_town": [
        ("muros", ["wall"]),
        ("techos", ["roof"]),
        ("escaleras", ["stairs"]),
        ("caminos", ["road"]),
        ("vallas_setos", ["fence", "hedge"]),
        ("decoracion", ["*"]),
    ],
    "kenney_furniture": [
        ("estructura", ["wall", "floor", "doorway", "stairs"]),
        ("dormitorio", ["bed", "cabinetbed"]),
        ("bano", ["bathroom", "toilet", "shower", "bathtub", "washer", "dryer"]),
        ("cocina", ["kitchen", "hood", "toaster"]),
        ("sala", ["lounge", "table", "chair", "bench", "bookcase", "television",
                  "computer", "laptop", "radio", "speaker", "coatrack", "rug",
                  "pillow", "lamp", "ceilingfan", "sidetable", "stool", "desk"]),
        ("decoracion", ["*"]),
    ],
    "kenney_nature": [
        ("arboles", ["tree"]),
        ("puentes", ["bridge"]),
        ("caminos_rios", ["ground_path", "ground_river", "path_", "platform"]),
        ("rocas", ["rock", "stone", "cliff"]),
        ("vegetacion", ["grass", "flower", "plant", "lily", "mushroom",
                         "hanging_moss", "crop", "cactus"]),
        ("vallas", ["fence"]),
        ("decoracion", ["*"]),
    ],
}


def snake(name: str) -> str:
    """wall-door / cameCase / Mixed_Case -> minusculas_con_guion_bajo
    (regla del proyecto: sin mayusculas, sin guiones sueltos)."""
    s = re.sub(r"(?<!^)(?=[A-Z])", "_", name)
    s = s.replace("-", "_")
    s = re.sub(r"_+", "_", s)
    return s.lower()


def categorize(pack: str, stem: str) -> str:
    """Solo coincidencia por PREFIJO (startswith). Se evita 'contains' a
    proposito: con contains, 'bridge_stone' terminaba en 'rocas' porque
    contiene la palabra 'stone', o 'platform_stone' idem. El orden de
    CATEGORY_RULES sigue importando para prefijos que se pisan entre si."""
    lower = stem.lower()
    for category, keys in CATEGORY_RULES[pack]:
        if keys == ["*"]:
            return category
        if any(lower.startswith(k) for k in keys):
            return category
    return "decoracion"


def get_aabb(path: Path):
    g = GLTF2().load(str(path))
    mins = [float("inf")] * 3
    maxs = [float("-inf")] * 3
    found = False
    for mesh in g.meshes:
        for prim in mesh.primitives:
            acc_idx = prim.attributes.POSITION
            if acc_idx is None:
                continue
            acc = g.accessors[acc_idx]
            if acc.min and acc.max:
                found = True
                for i in range(3):
                    mins[i] = min(mins[i], acc.min[i])
                    maxs[i] = max(maxs[i], acc.max[i])
    if not found:
        return None
    return mins, maxs


TSCN_TEMPLATE = """[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="{model_path}" id="1"]

[sub_resource type="BoxShape3D" id="Shape_1"]
size = Vector3({sx}, {sy}, {sz})

[node name="{node_name}" type="StaticBody3D"]

[node name="Model" parent="." instance=ExtResource("1")]

[node name="Collision" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cx}, {cy}, {cz})
shape = SubResource("Shape_1")
"""


def build_pack(pack: str):
    src_dir = MODELS / pack
    glbs = sorted(src_dir.glob("*.glb"))
    if not glbs:
        print(f"  (sin modelos en {src_dir}, se omite)")
        return 0
    count = 0
    for glb in glbs:
        stem = glb.stem
        aabb = get_aabb(glb)
        if aabb is None:
            print(f"  ! no se pudo leer geometria de {glb.name}, se omite")
            continue
        mins, maxs = aabb
        size = [max(maxs[i] - mins[i], 0.02) for i in range(3)]
        center = [(mins[i] + maxs[i]) / 2 for i in range(3)]

        category = categorize(pack, stem)
        out_dir = OUT / pack / category
        out_dir.mkdir(parents=True, exist_ok=True)

        name = snake(stem)
        model_path = f"res://assets/models/{pack}/{glb.name}"
        tscn = TSCN_TEMPLATE.format(
            model_path=model_path,
            node_name=name,
            sx=round(size[0], 4), sy=round(size[1], 4), sz=round(size[2], 4),
            cx=round(center[0], 4), cy=round(center[1], 4), cz=round(center[2], 4),
        )
        (out_dir / f"{name}.tscn").write_text(tscn, encoding="utf-8")
        count += 1
    print(f"  {pack}: {count} escenas generadas en scenes/kit/{pack}/")
    return count


def main():
    total = 0
    for pack in CATEGORY_RULES:
        print(f"Procesando {pack}...")
        total += build_pack(pack)
    print(f"\nListo. {total} piezas envueltas con colision en scenes/kit/")


if __name__ == "__main__":
    main()
