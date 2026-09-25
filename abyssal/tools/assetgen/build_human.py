"""Human base bodies (PZ-style layered characters): body, eyes, skin textures.

    MH_DATA=... MPFB_TEX=... python3 tools/assetgen/build_human.py male|female
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import bpy
import numpy as np

import bl
import mh
import skin
import texbake as tb

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TEX = os.path.join(ROOT, 'assets', 'textures')
OUT = os.path.join(ROOT, 'assets', 'models')

PRESETS = {
    'male': {'gender': 1.0, 'age': 0.45, 'muscle': 0.62, 'weight': 0.48, 'height': 0.62, 'proportions': 0.6,
             'race': {'caucasian': 0.6, 'african': 0.2, 'asian': 0.2}},
    'female': {'gender': 0.0, 'age': 0.42, 'muscle': 0.52, 'weight': 0.46, 'height': 0.6, 'proportions': 0.62,
               'cupsize': 0.5, 'firmness': 0.6, 'race': {'caucasian': 0.6, 'african': 0.2, 'asian': 0.2}},
}


def joints(arm):
    B = arm.data.bones
    W = arm.matrix_world
    h = lambda n: np.array((W @ B[n].head_local)[:], np.float32)
    t = lambda n: np.array((W @ B[n].tail_local)[:], np.float32)
    J = {'head': h('head'), 'neck': h('neck_01')}
    for s in ('l', 'r'):
        J['hand_' + s] = h('hand_' + s)
        J['finger_' + s] = t('middle_03_' + s)
        J['elbow_' + s] = h('lowerarm_' + s)
        J['knee_' + s] = h('calf_' + s)
        J['foot_' + s] = h('foot_' + s)
    return J


def main(kind):
    t0 = time.time()
    bl.reset()
    body, arm, eyes = mh.create(PRESETS[kind])
    M = mh.mpfb()
    M('services.targetservice').TargetService.bake_targets(body)
    bpy.context.view_layer.objects.active = body
    for m in list(body.modifiers):
        if m.type == 'MASK':
            bpy.ops.object.modifier_apply(modifier=m.name)
    body.name = 'body'
    arm.name = 'rig_' + kind
    eyes.name = 'eyes'
    J = joints(arm)
    ev, en, epolys, euvs = bl.obj_arrays(eyes)
    ev = ev @ np.array(eyes.matrix_world)[:3, :3].T + np.array(eyes.matrix_world)[:3, 3]
    xs = ev[:, 0]
    J['eye_l'] = ev[xs > 0].mean(0)
    J['eye_r'] = ev[xs < 0].mean(0)
    print('rigged', round(time.time() - t0, 1), 's; eyes at', J['eye_l'], J['eye_r'])

    # ---- skin texture
    v, n, polys, uvs = bl.obj_arrays(body)
    Mw = np.array(body.matrix_world)
    v = v @ Mw[:3, :3].T + Mw[:3, 3]
    tris, tuv = tb.triangulate(polys, uvs)
    ao = tb.vertex_ao(v, n, tris, rays=20, dist=0.1)
    print('ao', round(time.time() - t0, 1))
    R = 2048
    pos, nrm, mask, ext = tb.rasterize(v, n, tris, tuv, R, extra=ao[:, None])
    print('raster', round(time.time() - t0, 1), mask.mean())
    alb, rough, height = skin.paint_skin(pos, nrm, mask, J, R, ao=ext[..., 0])
    nmap = tb.height_to_normal(height, 1.2, mask)
    os.makedirs(TEX, exist_ok=True)
    base = tb.save_rgb(os.path.join(TEX, f'skin_{kind}_base.jpg'), alb, mask)
    nrmp = tb.save_normal(os.path.join(TEX, f'skin_{kind}_normal.jpg'), nmap, mask)
    mr = np.stack([np.zeros_like(rough), rough, np.zeros_like(rough)], -1)
    mrp = tb.save_rgb(os.path.join(TEX, f'skin_{kind}_mr.jpg'), mr, mask, size=1024)
    print('skin', round(time.time() - t0, 1))
    body.data.materials.clear()
    body.data.materials.append(bl.pbr_material('skin', base=base, normal=nrmp, mr=mrp, normal_strength=0.6))
    for p in body.data.polygons:
        p.use_smooth = True
        p.material_index = 0

    # ---- eyes: sclera + tintable iris
    etris, etuv = tb.triangulate(epolys, euvs)
    ER = 512
    epos, enrm, emask, _ = tb.rasterize(ev, en, etris, etuv, ER)
    scl, iris, in_iris = skin.paint_eye(epos, emask, ER, [J['eye_l'], J['eye_r']])
    sp = tb.save_rgb(os.path.join(TEX, 'eye_sclera.jpg'), scl, emask)
    ip = tb.save_rgb(os.path.join(TEX, 'eye_iris.jpg'), iris, emask)
    eyes.data.materials.clear()
    eyes.data.materials.append(bl.pbr_material('eye_sclera', base=sp, rough=0.15))
    eyes.data.materials.append(bl.pbr_material('eye_iris', base=ip, rough=0.12, color=(0.35, 0.45, 0.6)))
    fwd = np.array([0, -1, 0], np.float32)
    for i, p in enumerate(eyes.data.polygons):
        c = ev[list(p.vertices)].mean(0)
        e = J['eye_l'] if c[0] > 0 else J['eye_r']
        d = c - e
        ang = np.degrees(np.arccos(np.clip(d @ fwd / (np.linalg.norm(d) + 1e-9), -1, 1)))
        p.material_index = 1 if ang < 26 else 0
        p.use_smooth = True

    path = os.path.join(OUT, f'human_{kind}.glb')
    bl.export_glb(path)
    print('exported', path, round(time.time() - t0, 1), 's')


if __name__ == '__main__':
    main(sys.argv[-1])
