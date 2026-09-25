"""Procedural texture baking in UV space.

Each texel is mapped back to its 3D surface point (position, normal), so
materials are painted with 3D noise and anatomical rules and never show UV
seams. Outputs are ordinary glTF maps: base colour (sRGB), normal (tangent
space, OpenGL/+Y), and metallic-roughness (G = roughness, B = metal).
"""
import numpy as np
from PIL import Image

from sdf import fbm, value_noise


def triangulate(polys, uvs):
    tris, tuv = [], []
    for p, uv in zip(polys, uvs):
        for k in range(1, len(p) - 1):
            tris.append((p[0], p[k], p[k + 1]))
            tuv.append((uv[0], uv[k], uv[k + 1]))
    return np.array(tris, np.int64), np.array(tuv, np.float32)


def rasterize(V, N, tris, tuv, res, extra=None):
    """Returns pos (R,R,3), nrm (R,R,3), mask (R,R) and optional per-vertex attributes."""
    R = res
    pos = np.zeros((R, R, 3), np.float32)
    nrm = np.zeros((R, R, 3), np.float32)
    ext = None if extra is None else np.zeros((R, R, extra.shape[1]), np.float32)
    mask = np.zeros((R, R), bool)
    # pixel coords: x = u*R, y = (1-v)*R (image rows go down)
    P = np.stack([tuv[..., 0] * R, (1 - tuv[..., 1]) * R], -1)
    for t in range(len(tris)):
        p = P[t]
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, R - 1), min(y1, R - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a, b, c = p
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-3) & (w1 >= -1e-3) & (w2 >= -1e-3)
        if not inside.any():
            continue
        iy, ix = np.nonzero(inside)
        W = np.stack([w0[inside], w1[inside], w2[inside]], 1)
        tri = tris[t]
        gy, gx = iy + y0, ix + x0
        pos[gy, gx] = W @ V[tri]
        nrm[gy, gx] = W @ N[tri]
        if ext is not None:
            ext[gy, gx] = W @ extra[tri]
        mask[gy, gx] = True
    n = np.linalg.norm(nrm, axis=-1, keepdims=True)
    nrm = np.where(n > 0, nrm / np.maximum(n, 1e-9), 0)
    return pos, nrm, mask, ext


def dilate(img, mask, iters=8):
    """Grow texel colours into the empty gutter so mips and filtering do not bleed black."""
    from scipy.ndimage import binary_dilation, uniform_filter
    img = img.copy()
    m = mask.copy()
    for _ in range(iters):
        grown = binary_dilation(m)
        new = grown & ~m
        if not new.any():
            break
        w = uniform_filter(m.astype(np.float32), 3)
        for c in range(img.shape[-1]):
            s = uniform_filter(np.where(m, img[..., c], 0).astype(np.float32), 3)
            img[..., c] = np.where(new, s / np.maximum(w, 1e-6), img[..., c])
        m = grown
    return img


def height_to_normal(h, strength, mask):
    gy, gx = np.gradient(h)
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], -1)  # image y is -v
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    n = np.where(mask[..., None], n, np.array([0, 0, 1], np.float32))
    return n


def eval_noise(pos, mask, fn):
    out = np.zeros(mask.shape, np.float32)
    idx = np.nonzero(mask)
    out[idx] = fn(pos[idx])
    return out


def save_rgb(path, rgb, mask=None, dil=True, size=None):
    if mask is not None and dil:
        rgb = dilate(rgb, mask)
    im = Image.fromarray(np.clip(rgb * 255 + 0.5, 0, 255).astype(np.uint8))
    if size:
        im = im.resize((size, size), Image.LANCZOS)
    im.save(path, optimize=True)
    return path


def save_normal(path, n, mask=None, size=None):
    rgb = n * 0.5 + 0.5
    if mask is not None:
        rgb = dilate(rgb, mask)
    return save_rgb(path, rgb, None, size=size)


def vertex_ao(V, N, tris, rays=24, dist=0.12, seed=1):
    """Hemisphere ambient occlusion per vertex (mathutils BVH)."""
    from mathutils.bvhtree import BVHTree
    from mathutils import Vector
    bvh = BVHTree.FromPolygons([tuple(v) for v in V.tolist()], [tuple(t) for t in tris.tolist()], epsilon=0.0)
    rng = np.random.default_rng(seed)
    dirs = rng.normal(size=(rays, 3))
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    ao = np.zeros(len(V), np.float32)
    for i in range(len(V)):
        n = N[i]
        p = V[i] + n * 0.002
        hit = 0.0
        cnt = 0
        for d in dirs:
            c = float(d @ n)
            if c <= 0:
                d = -d
                c = -c
            loc, _, _, dd = bvh.ray_cast(Vector(p), Vector(d), dist)
            cnt += 1
            if loc is not None:
                hit += (1 - dd / dist) * c
        ao[i] = 1 - min(1, 2.0 * hit / max(cnt, 1))
    return ao
