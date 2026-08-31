# DPN Neuralizer Blender/Sollumz helper
# Usage:
# 1. Open Blender with Sollumz installed.
# 2. Run this script from Blender's Python console or Text Editor.
# 3. Export the object as YDR named dpn_neuralizer_prop.ydr into this resource's stream/ folder.
# 4. In config.lua set Config.Prop.useCustomModel = true.

import bpy
from pathlib import Path

# Change this path if Blender is not opened from model_source/.
base = Path(__file__).resolve().parent if "__file__" in globals() else Path.cwd()
obj_path = base / "dpn_neuralizer_prop.obj"

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.wm.obj_import(filepath=str(obj_path))
obj = bpy.context.object
obj.name = "dpn_neuralizer_prop"

# GTA/FiveM props usually need sane scale and origin. Tweak if your hand placement needs adjustment.
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
obj.scale = (1.0, 1.0, 1.0)

# Add a tiny lens light for preview only; YDR export may require material/light tuning in Sollumz.
bpy.ops.object.light_add(type='POINT', location=(0, 0.18, 0))
light = bpy.context.object
light.name = "dpn_neuralizer_preview_lens_light"
light.data.color = (0.0, 0.85, 1.0)
light.data.energy = 60

# Save a Blender source file beside the OBJ.
bpy.ops.wm.save_as_mainfile(filepath=str(base / "dpn_neuralizer_prop.blend"))
print("DPN Neuralizer model imported. Export as dpn_neuralizer_prop.ydr to stream/ using Sollumz.")
