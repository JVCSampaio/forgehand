"""Garment and hair builders on the MakeHuman fitting helpers.

A garment is a set of helper faces, pushed to a chosen distance from the skin,
subdivided, given folds and thickness, UV-unwrapped and baked with a material
recipe. Distances are measured to the real body, so layers stack cleanly:
underwear < shirt < trousers < boots < gambeson < mail < tabard < cloak.
"""
import numpy as np
from scipy.spatial import cKDTree

import kit
from sdf import fbm, value_noise

TORSO = {'pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'clavicle_l', 'clavicle_r'}
UPPER = {'upperarm_l', 'upperarm_r'}
LOWER = {'lowerarm_l', 'lowerarm_r'}
HAND = {'hand_l', 'hand_r'} | {f'{f}_0{i}_{s}' for f in ('index', 'middle', 'ring', 'pinky', 'thumb') for i in (1, 2, 3) for s in 'lr'}
THIGH = {'thigh_l', 'thigh_r'}
CALF = {'calf_l', 'calf_r'}
FOOT = {'foot_l', 'foot_r', 'ball_l', 'ball_r'}
HEAD = {'head'}


class Ctx:
    """Shared data for garment building: body surface for offsets."""

    def __init__(self, base):
        self.base = base
        ids = base.groups['body']
        self.body_ids = ids
        self.tree = cKDTree(base.V[ids])
        self.bodyN = base.N[ids]
        self.bodyV = base.V[ids]

    def select(self, group, bones, pred=None):
        b = self.base
        faces = b.group_faces(group)
        dom = b.dominant_bone(faces)
        C = b.face_centers(faces)
        out = []
        for f, d, c in zip(faces, dom, C):
            if d in bones and (pred is None or pred(c, d)):
                out.append(f)
        return out

    def push(self, obj, offset, min_only=False, blend_normal=0.5):
        """Place every vertex `offset` metres outside the skin."""
        V = kit.coords(obj)
        d, i = self.tree.query(V, k=4)
        w = 1.0 / np.maximum(d, 1e-4)
        w /= w.sum(1, keepdims=True)
        P = np.einsum('nk,nkd->nd', w, self.bodyV[i])
        N = np.einsum('nk,nkd->nd', w, self.bodyN[i])
        N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-9
        off = offset if np.ndim(offset) else np.full(len(V), offset, np.float32)
        target = P + N * off[:, None]
        if min_only:
            cur = np.einsum('nd,nd->n', V - P, N)
            move = cur < off
            V = np.where(move[:, None], target, V)
        else:
            V = target
        kit.set_coords(obj, V)
        return obj

    def folds(self, obj, amp, freq=14.0, stretch=(1.4, 1.4, 0.5), seed=0):
        V = kit.coords(obj)
        N = kit.normals(obj)
        n = fbm(V * np.array(stretch, np.float32), freq, 3, seed)
        kit.set_coords(obj, V + N * (n * amp)[:, None])
        return obj

    def smooth(self, obj, iters=2, factor=0.5):
        import bpy
        m = obj.modifiers.new('sm', 'SMOOTH')
        m.factor = factor
        m.iterations = iters
        return kit.apply_mods(obj)
