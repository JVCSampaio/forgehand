import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
import bpy
import bl, mh
bl.reset()
t = time.time()
body, arm, eyes = mh.create({'gender': float(sys.argv[-2]), 'age': 0.45, 'muscle': 0.6, 'weight': 0.5,
                             'race': {'caucasian': 0.7, 'african': 0.15, 'asian': 0.15}})
print('created', time.time() - t, body.name, arm.name if arm else None, eyes.name if eyes else None)
print([o.name + ':' + o.type for o in bpy.data.objects])
print('mods', [(m.name, m.type) for m in body.modifiers])
# bake shape keys + mask so the export is the final shape
M = mh.mpfb()
M('services.targetservice').TargetService.bake_targets(body)
bpy.context.view_layer.objects.active = body
for m in list(body.modifiers):
    if m.type == 'MASK':
        bpy.ops.object.modifier_apply(modifier=m.name)
print('verts', len(body.data.vertices), 'polys', len(body.data.polygons), 'dims', tuple(round(x, 3) for x in body.dimensions))
for o in bpy.data.objects:
    if o.type == 'MESH':
        for p in o.data.polygons: p.use_smooth = True
bl.export_glb(sys.argv[-1])
