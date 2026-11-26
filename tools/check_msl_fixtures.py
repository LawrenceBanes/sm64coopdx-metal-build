#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(sys.argv[1])
expected = {
    "textureless.metal": ("fragment float4 coopdx_fragment", "return combined"),
    "alpha_texture_edge.metal": ("discard_fragment()", "texture2d<float> tex0"),
    "texture_tile1.metal": ("in.uv1", "coopdx_sample"),
    "two_cycle_fog_lightmap.metal": ("in.fog", "shaderFlags[6]", "combined=float4"),
    "dynos_custom_material_three_point.metal": ("filterMode==2", "coopdx_sample(tex1", "in.uv0"),
    "character_texture_replacement.metal": ("coopdx_sample(tex0", "in.uv0"),
    "hud_vertex_color_alpha.metal": ("in.input1.rgb", "in.input1.a"),
    "runtime_texture_rebind.metal": ("texture2d<float> tex0", "coopdx_sample"),
}
missing = []
for name, snippets in expected.items():
    path = root / name
    if not path.is_file():
        missing.append(f"{name}: missing")
        continue
    text = path.read_text()
    for snippet in snippets:
        if snippet not in text:
            missing.append(f"{name}: expected {snippet!r}")
if missing:
    raise SystemExit("MSL fixture coverage check failed:\n" + "\n".join(missing))
print(f"Validated {len(expected)} generated MSL coverage fixtures")
