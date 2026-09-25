"""Procedural PBR material recipes baked in each part's own UV space.

All recipes evaluate their patterns on the 3D surface point of every texel, so
UV seams never show. Base colours are detail multipliers (~0.8) for dyeable
materials; fixed materials (iron, bone, brass) carry their own colour.
"""
import os
import numpy as np

import texbake as tb
from sdf import fbm, value_noise


def _f(pos, mask, fn):
    out = np.zeros(mask.shape, np.float32)
    idx = np.nonzero(mask)
    if len(idx[0]):
        out[idx] = fn(pos[idx])
    return out


def quilt_height(p, spacing=0.055):
    a = np.array([0.7071, 0.0, 0.7071], np.float32)
    b = np.array([-0.7071, 0.0, 0.7071], np.float32)
    ka = np.abs(np.sin(np.pi * (p @ a) / spacing))
    kb = np.abs(np.sin(np.pi * (p @ b) / spacing))
    return np.minimum(ka, kb) ** 0.5


def recipe(kind, pos, nrm, mask, res, ao=None, seed=0, params=None):
    """Returns albedo (R,R,3), roughness (R,R), metal (R,R), height (R,R), normal strength."""
    p = params or {}
    R = res
    m = mask
    alb = np.ones((R, R, 3), np.float32) * 0.8
    rough = np.full((R, R), 0.8, np.float32)
    metal = np.zeros((R, R), np.float32)
    height = np.zeros((R, R), np.float32)
    ns = 1.0
    z = pos[..., 2]
    low = np.clip((0.55 - z) / 0.5, 0, 1) * m          # grime rising from the floor
    mott = _f(pos, m, lambda q: fbm(q, 7.0, 4, seed + 1))
    if kind in ('cloth', 'wool', 'linen', 'quilted', 'fur', 'rope'):
        weave_f = p.get('weave', 700.0)
        w1 = _f(pos, m, lambda q: value_noise(q * np.array([1, 1, 0.25], np.float32), weave_f, seed + 2))
        w2 = _f(pos, m, lambda q: value_noise(q * np.array([0.25, 1, 1], np.float32), weave_f, seed + 3))
        fibres = _f(pos, m, lambda q: value_noise(q, 1800.0, seed + 4))
        height = 0.5 * w1 + 0.5 * w2 + 0.3 * fibres
        folds = _f(pos, m, lambda q: fbm(q * np.array([1.6, 1.6, 0.6], np.float32), 16.0, 3, seed + 5))
        height += folds * 2.0
        alb *= (1 + 0.07 * mott + 0.05 * (w1 - w2))[..., None]
        rough[:] = 0.88 + 0.06 * fibres
        ns = 0.9
        if kind == 'quilted':
            qh = _f(pos, m, lambda q: quilt_height(q, p.get('spacing', 0.06)))
            height += qh * 6.0
            alb *= (0.8 + 0.2 * qh)[..., None]
        if kind == 'wool':
            fuzz = _f(pos, m, lambda q: fbm(q, 400.0, 2, seed + 6))
            height += fuzz * 0.8
            rough[:] = 0.95
        if kind == 'fur':
            strands = _f(pos, m, lambda q: value_noise(q * np.array([3, 3, 0.35], np.float32), 260.0, seed + 7))
            clumps = _f(pos, m, lambda q: fbm(q * np.array([2, 2, 0.5], np.float32), 60.0, 3, seed + 8))
            height = strands * 3 + clumps * 3
            alb *= (0.7 + 0.35 * np.clip(strands * 0.5 + clumps * 0.5 + 0.5, 0, 1))[..., None]
            rough[:] = 0.92
            ns = 1.4
    elif kind == 'leather':
        grain = _f(pos, m, lambda q: fbm(q, 380.0, 3, seed + 2))
        cracks = _f(pos, m, lambda q: np.abs(fbm(q, 120.0, 3, seed + 3)))
        scuff = _f(pos, m, lambda q: fbm(q, 25.0, 4, seed + 4))
        height = grain * 0.6 - np.clip(0.06 - cracks, 0, 0.06) * 18
        alb *= (1 + 0.12 * mott + 0.06 * grain)[..., None]
        alb *= (1 + np.clip(scuff, 0, 1)[..., None] * np.array([0.25, 0.22, 0.18]))
        rough[:] = 0.55 + 0.2 * np.clip(scuff * 0.5 + 0.5, 0, 1)
        ns = 0.8
    elif kind in ('iron', 'steel', 'mail', 'brass', 'gold'):
        base = {'iron': (0.42, 0.42, 0.43), 'steel': (0.62, 0.63, 0.65), 'mail': (0.5, 0.5, 0.52),
                'brass': (0.72, 0.55, 0.28), 'gold': (0.9, 0.7, 0.3)}[kind]
        alb[:] = np.array(base, np.float32)
        metal[:] = 1.0
        hammer = _f(pos, m, lambda q: fbm(q, 45.0, 3, seed + 2))
        scratches = _f(pos, m, lambda q: value_noise(q * np.array([6, 1, 1], np.float32), 350.0, seed + 3))
        rust = np.clip(_f(pos, m, lambda q: fbm(q, 14.0, 5, seed + 4)) * 1.8 - 0.35 + low * 0.6, 0, 1) * p.get('rust', 0.5)
        height = hammer * 1.5 + np.clip(scratches - 0.75, 0, 1) * -3
        rough[:] = 0.36 + 0.18 * np.clip(hammer * 0.5 + 0.5, 0, 1) + np.clip(scratches - 0.6, 0, 1) * 0.3
        if kind == 'mail':
            ring = _f(pos, m, lambda q: _mail(q))
            height = ring * 5
            alb *= (0.55 + 0.6 * ring)[..., None]
            rough[:] = 0.5 - 0.15 * ring
            ns = 2.2
        rust_col = np.array([0.35, 0.17, 0.08], np.float32)
        alb = alb * (1 - rust[..., None]) + rust_col * rust[..., None]
        metal = metal * (1 - rust)
        rough = rough * (1 - rust) + 0.9 * rust
    elif kind == 'bone':
        alb[:] = np.array([0.82, 0.77, 0.64], np.float32)
        pores = _f(pos, m, lambda q: value_noise(q, 600.0, seed + 2))
        stain = np.clip(_f(pos, m, lambda q: fbm(q, 12.0, 4, seed + 3)) + 0.2, 0, 1)
        cracks = _f(pos, m, lambda q: np.abs(fbm(q, 60.0, 4, seed + 4)))
        alb *= (1 - stain[..., None] * np.array([0.25, 0.32, 0.45]))
        alb *= (1 - np.clip(0.04 - cracks, 0, 0.04)[..., None] * 12)
        height = pores * 0.4 - np.clip(0.04 - cracks, 0, 0.04) * 30
        rough[:] = 0.7
    elif kind == 'wood':
        grain = _f(pos, m, lambda q: value_noise(q * np.array([6, 6, 0.4], np.float32), 60.0, seed + 2))
        alb[:] = np.array([0.42, 0.28, 0.16], np.float32)
        alb *= (0.8 + 0.35 * grain)[..., None]
        height = grain * 1.5
        rough[:] = 0.75
    # universal grime and cavity darkening
    grime = float(p.get('grime', 0.35))
    alb *= (1 - low[..., None] * grime * np.array([0.35, 0.4, 0.45]))
    if ao is not None:
        alb *= (0.45 + 0.55 * np.clip(ao, 0, 1))[..., None]
    return np.clip(alb, 0, 1), np.clip(rough, 0.05, 1), np.clip(metal, 0, 1), height, ns


def _mail(q, r=0.0065):
    # riveted mail: rings on a staggered lattice in a local 2D frame (xz + yz blend)
    u = (q[:, 0] + q[:, 1] * 0.7) / r
    v = q[:, 2] / (r * 0.8)
    row = np.floor(v)
    u = u + (row % 2) * 0.5
    fu = u - np.floor(u) - 0.5
    fv = v - row - 0.5
    d = np.sqrt(fu * fu + fv * fv)
    return np.clip(1 - np.abs(d - 0.33) / 0.14, 0, 1)


def bake(obj_arrays, out_prefix, kind, res=1024, ao=None, seed=0, params=None):
    """Bake a recipe for one part. Returns dict(base, normal, mr) paths."""
    V, N, polys, puv = obj_arrays
    tris, tuv = tb.triangulate(polys, puv)
    extra = None if ao is None else ao[:, None]
    pos, nrm, mask, ext = tb.rasterize(V, N, tris, tuv, res, extra=extra)
    alb, rough, metal, height, ns = recipe(kind, pos, nrm, mask, res, None if ext is None else ext[..., 0], seed, params)
    nmap = tb.height_to_normal(height, 0.9 * ns, mask)
    os.makedirs(os.path.dirname(out_prefix), exist_ok=True)
    base = tb.save_rgb(out_prefix + '_base.jpg', alb, mask)
    normal = tb.save_normal(out_prefix + '_normal.jpg', nmap, mask)
    mr = tb.save_rgb(out_prefix + '_mr.jpg', np.stack([np.zeros_like(rough), rough, metal], -1), mask, size=res // 2)
    return {'base': base, 'normal': normal, 'mr': mr}
