import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import bl
from sdf import mesh_sdf, Union, sdf_ao, blend
from anatomy import human_body, human_head
from rig import human_joints, HUMANOID_BONES, mirrored, auto_weights, smooth_weights, limit_influences

bl.reset()
J = human_joints()
body = human_body(J, {'sex': 0})
head, eyes, P = human_head(J, {})
full = Union([body, blend(head, 0.03)], k=0.03)
fullE = Union([full, eyes])
v, f = mesh_sdf(full, voxel=0.003)
v, f = bl.decimate(v, f, 22000)
from sdf import sdf_normals
n = sdf_normals(full, v)
ao = sdf_ao(full, v, n, steps=5, delta=0.01)
col = np.stack([ao, ao, ao], 1) * 0.5 + 0.5
bones = mirrored(HUMANOID_BONES)
names, W = auto_weights(v, J, bones)
W = limit_influences(smooth_weights(W, f, 4), 4)
arm = bl.build_armature('Human', J, bones)
obj = bl.build_mesh('body', v, f, [bl.material('skin', (0.8, 0.6, 0.48), 0.6)], colors=col, normals=n)
ev, ef = mesh_sdf(eyes, voxel=0.0015)
ev, ef = bl.decimate(ev, ef, 600)
eo = bl.build_mesh('eyes', ev, ef, [bl.material('eye', (0.9,0.9,0.88), 0.2)], normals=sdf_normals(eyes, ev))
bl.rigid(eo, arm, 'head')
bl.skin(obj, arm, names, W)
bl.make_action(arm, 'wave', [(1, {}), (15, {'upperarm_L': (-60, -40, 0), 'forearm_L': (-70, 0, 0), 'thigh_R': (-40, 0, 0), 'shin_R': (50, 0, 0), 'spine': (10, 0, 15)}), (30, {})], loop=True)
out = sys.argv[-1]
bl.export_glb(out)
print('tris', len(f), 'verts', len(v))
