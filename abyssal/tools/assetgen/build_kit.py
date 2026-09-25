"""Build a layered human character kit (Project Zomboid style) to one GLB.

    python3 tools/assetgen/build_kit.py male|female [--quick]

Contents: armature (game_engine rig, UE-mannequin bone names), body, eyes,
brows, lashes, hair styles, beards, garments for every class, sockets.
Every part is its own skinned mesh; the runtime shows the parts an outfit
uses and tints the dyeable materials.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import bpy
import numpy as np

import bl
import kit
import materials as mt
import mh
import skin
import texbake as tb
from sdf import value_noise, fbm

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TEX = os.path.join(ROOT, 'assets', 'textures')
OUT = os.path.join(ROOT, 'assets', 'models')
QUICK = '--quick' in sys.argv

PRESETS = {
    'male': {'gender': 1.0, 'age': 0.45, 'muscle': 0.62, 'weight': 0.48, 'height': 0.62, 'proportions': 0.6,
             'race': {'caucasian': 0.6, 'african': 0.2, 'asian': 0.2}},
    'female': {'gender': 0.0, 'age': 0.42, 'muscle': 0.52, 'weight': 0.46, 'height': 0.6, 'proportions': 0.62,
               'cupsize': 0.5, 'firmness': 0.6, 'race': {'caucasian': 0.6, 'african': 0.2, 'asian': 0.2}},
}

T0 = time.time()


def log(*a):
    print(f'[{time.time() - T0:6.1f}s]', *a, flush=True)


def tex_path(name):
    return os.path.join(TEX, name)


# ------------------------------------------------------------------ body
def build_body(base, kind):
    faces = base.group_faces('body')
    obj = kit.part(base, 'body', faces)
    V, N, polys, puv = kit.arrays(obj)
    tris, tuv = tb.triangulate(polys, puv)
    ao = tb.vertex_ao(V, N, tris, rays=20, dist=0.1)
    R = 1024 if QUICK else 2048
    pos, nrm, mask, ext = tb.rasterize(V, N, tris, tuv, R, extra=ao[:, None])
    J = {
        'head': base.J['head'], 'neck': base.J['neck_01'],
        'eye_l': base.eye_l, 'eye_r': base.eye_r,
    }
    for s in ('l', 'r'):
        J['hand_' + s] = base.J['hand_' + s]
        J['finger_' + s] = base.Jt['middle_03_' + s]
        J['elbow_' + s] = base.J['lowerarm_' + s]
        J['knee_' + s] = base.J['calf_' + s]
        J['foot_' + s] = base.J['foot_' + s]
    alb, rough, height = skin.paint_skin(pos, nrm, mask, J, R, ao=ext[..., 0])
    nmap = tb.height_to_normal(height, 0.8, mask)
    b = tb.save_rgb(tex_path(f'skin_{kind}_base.jpg'), alb, mask)
    n = tb.save_normal(tex_path(f'skin_{kind}_normal.jpg'), nmap, mask)
    mr = tb.save_rgb(tex_path(f'skin_{kind}_mr.jpg'), np.stack([np.zeros_like(rough), rough, np.zeros_like(rough)], -1), mask, size=R // 2)
    obj.data.materials.append(bl.pbr_material('skin', base=b, normal=n, mr=mr, normal_strength=0.5))
    return obj


def build_eyes(base):
    eyes = base.eyes
    eyes.name = 'eyes'
    V, N, polys, puv = bl.obj_arrays(eyes)
    Mw = np.array(eyes.matrix_world)
    V = V @ Mw[:3, :3].T + Mw[:3, 3]
    tris, tuv = tb.triangulate(polys, puv)
    pos, nrm, mask, _ = tb.rasterize(V, N, tris, tuv, 512)
    scl, iris, _ = skin.paint_eye(pos, mask, 512, [base.eye_l, base.eye_r])
    sp = tb.save_rgb(tex_path('eye_sclera.jpg'), scl, mask)
    ip = tb.save_rgb(tex_path('eye_iris.jpg'), iris, mask)
    eyes.data.materials.clear()
    eyes.data.materials.append(bl.pbr_material('eye_sclera', base=sp, rough=0.12))
    eyes.data.materials.append(bl.pbr_material('eye_iris', base=ip, rough=0.1, color=(0.36, 0.46, 0.62)))
    fwd = np.array([0, -1, 0], np.float32)
    for p in eyes.data.polygons:
        c = V[list(p.vertices)].mean(0)
        e = base.eye_l if c[0] > 0 else base.eye_r
        d = c - e
        ang = np.degrees(np.arccos(np.clip(d @ fwd / (np.linalg.norm(d) + 1e-9), -1, 1)))
        p.material_index = 1 if ang < 26 else 0
    # rigid on the head bone
    eyes.vertex_groups.clear()
    vg = eyes.vertex_groups.new(name='head')
    vg.add(list(range(len(eyes.data.vertices))), 1.0, 'REPLACE')
    eyes.modifiers.clear()
    eyes.parent = None
    bpy.context.view_layer.objects.active = eyes
    eyes.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    eyes.select_set(False)
    return eyes


def alpha_texture(obj, name, alpha_fn, res=512, color=(1, 1, 1)):
    """Bake an RGBA texture whose alpha comes from a 3D function of the surface."""
    kit.smart_uv(obj, angle=80)
    V, N, polys, puv = kit.arrays(obj)
    tris, tuv = tb.triangulate(polys, puv)
    pos, nrm, mask, _ = tb.rasterize(V, N, tris, tuv, res)
    a = np.zeros(mask.shape, np.float32)
    idx = np.nonzero(mask)
    a[idx] = alpha_fn(pos[idx])
    rgb = np.ones((res, res, 3), np.float32) * np.array(color, np.float32)
    rgb *= (0.75 + 0.25 * a)[..., None]
    rgba = np.concatenate([tb.dilate(rgb, mask), a[..., None]], -1)
    from PIL import Image
    path = tex_path(name + '.png')
    Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), 'RGBA').save(path, optimize=True)
    return path


def build_brows(base):
    out = []
    faces = base.group_faces('body')
    C = base.face_centers(faces)
    for side, E in (('l', base.eye_l), ('r', base.eye_r)):
        sx = 1 if side == 'l' else -1
        rel = C - E
        xo = rel[:, 0] * sx  # outward positive
        sel = (xo > -0.024) & (xo < 0.03) & (rel[:, 2] > 0.004) & (rel[:, 2] < 0.03) & (rel[:, 1] < 0.0)
        out += [f for f, s in zip(faces, sel) if s]
    obj = kit.part(base, 'brows', out)
    V = kit.coords(obj)
    ids = obj['base_ids']
    kit.set_coords(obj, V + base.N[ids] * 0.0012)

    def brow_alpha(p):
        a = np.zeros(len(p), np.float32)
        for E, sx in ((base.eye_l, 1), (base.eye_r, -1)):
            rel = p - E
            xo = rel[:, 0] * sx
            s = np.clip((xo + 0.02) / 0.047, 0, 1)            # 0 inner .. 1 outer
            centre = 0.0135 + 0.006 * np.sin(np.pi * np.clip(s * 1.1, 0, 1)) - 0.003 * s
            half = 0.0052 * (1.15 - 0.75 * s)
            t = np.abs(rel[:, 2] - centre) / half
            band = np.clip(1.2 - t, 0, 1) * np.clip(xo + 0.021, 0, 0.004) / 0.004 * np.clip(0.03 - xo, 0, 0.004) / 0.004
            q = p.copy()
            q[:, 0] = xo * np.cos(0.5 * s) - rel[:, 2] * np.sin(0.5 * s)
            strands = value_noise(q * np.array([1, 1, 6], np.float32), 600.0, 3) * 0.5 + 0.5
            a = np.maximum(a, np.clip(band * (0.55 + 0.9 * strands) - 0.25, 0, 1) * (rel[:, 0] * sx > -1))
        return a
    path = alpha_texture(obj, 'brows', brow_alpha, 512, color=(0.95, 0.95, 0.95))
    obj.data.materials.append(bl.pbr_material('hair_brows', base=path, rough=0.7, alpha_clip=0.35, color=(0.2, 0.14, 0.1)))
    return obj


def build_lashes(base):
    faces = []
    for g in ('helper-l-eyelashes-1', 'helper-l-eyelashes-2', 'helper-r-eyelashes-1', 'helper-r-eyelashes-2'):
        if g in base.groups:
            faces += base.group_faces(g)
    obj = kit.part(base, 'lashes', faces)

    def lash_alpha(p):
        a = np.zeros(len(p), np.float32)
        for E in (base.eye_l, base.eye_r):
            d = np.linalg.norm(p - E, axis=1)
            near = d < 0.03
            r = np.clip((d - 0.0125) / 0.006, 0, 1)
            strands = value_noise(p * np.array([4, 1, 1], np.float32), 2500.0, 5) * 0.5 + 0.5
            a = np.where(near, np.clip((1 - r) * 1.3 * (0.4 + strands) - 0.2, 0, 1), a)
        return a
    path = alpha_texture(obj, 'lashes', lash_alpha, 256, color=(0.2, 0.2, 0.2))
    obj.data.materials.append(bl.pbr_material('lashes', base=path, rough=0.6, alpha_clip=0.3, double_sided=True, color=(0.08, 0.07, 0.06)))
    return obj


# ------------------------------------------------------------------ main
def main(kind):
    bl.reset()
    base = kit.Base(PRESETS[kind])
    ev = kit.coords(base.eyes) @ np.array(base.eyes.matrix_world)[:3, :3].T + np.array(base.eyes.matrix_world)[:3, 3]
    base.eye_l = ev[ev[:, 0] > 0].mean(0)
    base.eye_r = ev[ev[:, 0] < 0].mean(0)
    arm = base.arm
    arm.name = 'rig'
    log('base ready', len(base.V), 'verts, bones', len(base.bones))
    parts = []
    parts.append(build_body(base, kind)); log('body')
    parts.append(build_eyes(base)); log('eyes')
    parts.append(build_brows(base)); log('brows')
    parts.append(build_lashes(base)); log('lashes')
    base.discard_source()
    for p in parts:
        kit.bind(p, arm)
    path = os.path.join(OUT, f'human_{kind}.glb')
    bl.export_glb(path)
    log('exported', path, os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    main([a for a in sys.argv[1:] if not a.startswith('--')][0])
