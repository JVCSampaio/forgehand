"""Signed distance field modeller (numpy).

Characters are sculpted as smooth unions of anatomical primitives, then meshed
with marching cubes. Every node evaluates a batch of points (N, 3) and returns
(distance, material id). Children are only evaluated inside their bounds, which
keeps a whole body at 3-4 mm voxels fast enough to iterate on.

Coordinates are Blender's: Z up, the character faces -Y, its left is +X.
"""
import numpy as np

BIG = 1e3


def v3(x):
    return np.asarray(x, dtype=np.float32)


def rot_matrix(rx=0.0, ry=0.0, rz=0.0):
    """Rotation (degrees) applied X, then Y, then Z. Returns the matrix that maps
    local offsets to world offsets."""
    rx, ry, rz = np.radians([rx, ry, rz])
    cx, sx, cy, sy, cz, sz = np.cos(rx), np.sin(rx), np.cos(ry), np.sin(ry), np.cos(rz), np.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return (Rz @ Ry @ Rx).astype(np.float32)


def look_matrix(direction, up=(0, 0, 1)):
    """Matrix whose local Y axis points along `direction`."""
    y = v3(direction)
    y = y / (np.linalg.norm(y) + 1e-9)
    u = v3(up)
    if abs(float(np.dot(u, y))) > 0.95:
        u = v3((1, 0, 0))
    x = np.cross(y, u)
    x /= np.linalg.norm(x) + 1e-9
    z = np.cross(x, y)
    return np.stack([x, y, z], axis=1).astype(np.float32)


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


# ---------------------------------------------------------------- nodes
class Node:
    mat = 0
    lo = hi = None

    def eval(self, P):  # -> (d, mat)
        raise NotImplementedError

    def bounds(self):
        return self.lo, self.hi

    # sugar
    def __or__(self, other):
        return Union([self, other])

    def mat_(self, m):
        self.mat = m
        return self


class Prim(Node):
    def __init__(self, mat=0):
        self.mat = mat

    def eval(self, P):
        d = self.dist(P)
        return d, np.full(len(P), self.mat, dtype=np.int16)


class Sphere(Prim):
    def __init__(self, c, r, mat=0):
        super().__init__(mat)
        self.c, self.r = v3(c), float(r)
        self.lo, self.hi = self.c - self.r, self.c + self.r

    def dist(self, P):
        return np.linalg.norm(P - self.c, axis=1) - self.r


class Ellipsoid(Prim):
    def __init__(self, c, radii, rot=None, mat=0):
        super().__init__(mat)
        self.c, self.rad = v3(c), v3(radii)
        self.R = rot if rot is not None else np.eye(3, dtype=np.float32)
        m = float(self.rad.max())
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.R  # world -> local
        k0 = np.linalg.norm(q / self.rad, axis=1)
        k1 = np.linalg.norm(q / (self.rad * self.rad), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


class RoundCone(Prim):
    """Capsule between a and b with radius ra at a and rb at b (IQ)."""

    def __init__(self, a, b, ra, rb=None, mat=0):
        super().__init__(mat)
        self.a, self.b = v3(a), v3(b)
        self.ra = float(ra)
        self.rb = float(ra if rb is None else rb)
        m = max(self.ra, self.rb)
        self.lo = np.minimum(self.a, self.b) - m
        self.hi = np.maximum(self.a, self.b) + m

    def dist(self, P):
        a, b, r1, r2 = self.a, self.b, self.ra, self.rb
        ba = b - a
        l2 = float(ba @ ba)
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = P - a
        y = pa @ ba
        z = y - l2
        xv = pa * l2 - np.outer(y, ba)
        x2 = np.einsum('ij,ij->i', xv, xv)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        out = np.empty(len(P), dtype=np.float32)
        c1 = np.sign(z) * a2 * z2 > k
        c2 = (~c1) & (np.sign(y) * a2 * y2 < k)
        c3 = ~(c1 | c2)
        out[c1] = np.sqrt(x2[c1] + z2[c1]) * il2 - r2
        out[c2] = np.sqrt(x2[c2] + y2[c2]) * il2 - r1
        out[c3] = (np.sqrt(x2[c3] * a2 * il2) + y[c3] * rr) * il2 - r1
        return out


def Capsule(a, b, r, mat=0):
    return RoundCone(a, b, r, r, mat)


class RoundBox(Prim):
    def __init__(self, c, half, r=0.0, rot=None, mat=0):
        super().__init__(mat)
        self.c, self.h, self.r = v3(c), v3(half), float(r)
        self.R = rot if rot is not None else np.eye(3, dtype=np.float32)
        m = float(np.linalg.norm(self.h)) + self.r
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = np.abs((P - self.c) @ self.R) - (self.h - self.r)
        return np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(axis=1), 0) - self.r


class Torus(Prim):
    """Ring in the local XY plane (axis = local Z)."""

    def __init__(self, c, R, r, rot=None, mat=0):
        super().__init__(mat)
        self.c, self.Rr, self.r = v3(c), float(R), float(r)
        self.M = rot if rot is not None else np.eye(3, dtype=np.float32)
        m = self.Rr + self.r
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.M
        qx = np.linalg.norm(q[:, :2], axis=1) - self.Rr
        return np.sqrt(qx * qx + q[:, 2] ** 2) - self.r


class Cone(Prim):
    """Capped cone from base centre a (radius ra) to b (radius rb), sharp edges."""

    def __init__(self, a, b, ra, rb, mat=0):
        super().__init__(mat)
        self.a, self.b, self.ra, self.rb = v3(a), v3(b), float(ra), float(rb)
        m = max(ra, rb)
        self.lo = np.minimum(self.a, self.b) - m
        self.hi = np.maximum(self.a, self.b) + m

    def dist(self, P):
        a, b, ra, rb = self.a, self.b, self.ra, self.rb
        rba = rb - ra
        ba = b - a
        baba = float(ba @ ba)
        pa = P - a
        papa = np.einsum('ij,ij->i', pa, pa)
        paba = (pa @ ba) / baba
        x = np.sqrt(np.maximum(papa - paba * paba * baba, 0))
        cax = np.maximum(0.0, x - np.where(paba < 0.5, ra, rb))
        cay = np.abs(paba - 0.5) - 0.5
        k = rba * rba + baba
        f = np.clip((rba * (x - ra) + paba * baba) / k, 0.0, 1.0)
        cbx = x - ra - f * rba
        cby = paba - f
        s = np.where((cbx < 0) & (cay < 0), -1.0, 1.0)
        return s * np.sqrt(np.minimum(cax * cax + cay * cay * baba, cbx * cbx + cby * cby * baba))


class Plane(Prim):
    """Half-space below the plane through c with normal n (inside = behind n)."""

    def __init__(self, c, n, mat=0):
        super().__init__(mat)
        self.c = v3(c)
        self.n = v3(n) / np.linalg.norm(n)
        self.lo, self.hi = np.full(3, -BIG, np.float32), np.full(3, BIG, np.float32)

    def dist(self, P):
        return (P - self.c) @ self.n


class Func(Prim):
    """Arbitrary distance function with explicit bounds."""

    def __init__(self, fn, lo, hi, mat=0):
        super().__init__(mat)
        self.fn, self.lo, self.hi = fn, v3(lo), v3(hi)

    def dist(self, P):
        return self.fn(P)


def _mask(P, lo, hi, pad):
    return np.all((P >= lo - pad) & (P <= hi + pad), axis=1)


class Union(Node):
    def __init__(self, children, k=0.0, mat=None):
        self.children = [c for c in children if c is not None]
        self.k = k
        if mat is not None:
            for c in self.children:
                c.mat = mat
        self.lo = np.min([c.bounds()[0] for c in self.children], axis=0)
        self.hi = np.max([c.bounds()[1] for c in self.children], axis=0)

    def eval(self, P, pad=0.02):
        d = np.full(len(P), BIG, dtype=np.float32)
        m = np.zeros(len(P), dtype=np.int16)
        for c in self.children:
            ck = getattr(c, 'blend', None)
            k = self.k if ck is None else ck
            lo, hi = c.bounds()
            idx = np.nonzero(_mask(P, lo, hi, k + pad))[0]
            if not len(idx):
                continue
            cd, cm = c.eval(P[idx])
            old = d[idx]
            m[idx] = np.where(cd < old, cm, m[idx])
            d[idx] = smin(old, cd, k)
        return d, m


class Subtract(Node):
    def __init__(self, base, cutters, k=0.0):
        self.base = base
        self.cutters = cutters if isinstance(cutters, (list, tuple)) else [cutters]
        self.k = k
        self.lo, self.hi = base.bounds()
        self.mat = base.mat

    def eval(self, P, pad=0.02):
        d, m = self.base.eval(P)
        for c in self.cutters:
            lo, hi = c.bounds()
            idx = np.nonzero(_mask(P, lo, hi, self.k + pad))[0]
            if not len(idx):
                continue
            cd, cm = c.eval(P[idx])
            d[idx] = smax(d[idx], -cd, self.k)
        return d, m


class Intersect(Node):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, k
        alo, ahi = a.bounds()
        blo, bhi = b.bounds()
        self.lo, self.hi = np.maximum(alo, blo), np.minimum(ahi, bhi)
        self.mat = a.mat

    def eval(self, P):
        d, m = self.a.eval(P)
        bd, _ = self.b.eval(P)
        return smax(d, bd, self.k), m


class Shell(Node):
    """Hollow surface of thickness t centred on offset `o` from the child's surface.
    Used for garments: shell(body, offset) clipped by a region."""

    def __init__(self, child, offset, thickness):
        self.child, self.o, self.t = child, offset, thickness
        lo, hi = child.bounds()
        self.lo, self.hi = lo - offset - thickness, hi + offset + thickness
        self.mat = child.mat

    def eval(self, P):
        d, m = self.child.eval(P)
        return np.abs(d - self.o) - self.t * 0.5, m


class Offset(Node):
    def __init__(self, child, amount):
        self.child, self.amount = child, amount
        lo, hi = child.bounds()
        self.lo, self.hi = lo - max(amount, 0), hi + max(amount, 0)
        self.mat = child.mat

    def eval(self, P):
        d, m = self.child.eval(P)
        return d - self.amount, m


class Displace(Node):
    """d + fn(P). fn must stay small (a few mm) to keep the field a distance."""

    def __init__(self, child, fn, amp):
        self.child, self.fn, self.amp = child, fn, amp
        lo, hi = child.bounds()
        self.lo, self.hi = lo - amp, hi + amp
        self.mat = child.mat

    def eval(self, P):
        d, m = self.child.eval(P)
        return d + self.fn(P), m


class Material(Node):
    def __init__(self, child, mat):
        self.child, self.mat = child, mat
        self.lo, self.hi = child.bounds()

    def eval(self, P):
        d, _ = self.child.eval(P)
        return d, np.full(len(P), self.mat, dtype=np.int16)


class Mirror(Node):
    """Mirror the child across X=0 (build the left side, get both)."""

    def __init__(self, child):
        self.child = child
        lo, hi = child.bounds()
        m = np.maximum(np.abs(lo[0]), np.abs(hi[0]))
        self.lo = v3([-m, lo[1], lo[2]])
        self.hi = v3([m, hi[1], hi[2]])
        self.mat = child.mat

    def eval(self, P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        return self.child.eval(Q)


def blend(node, k):
    """Give a child its own blend radius inside a Union."""
    node.blend = k
    return node


# ---------------------------------------------------------------- noise
def _hash3(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65535.0


def value_noise(P, freq=1.0, seed=0):
    Q = P * freq
    i = np.floor(Q).astype(np.int64)
    f = Q - i
    u = f * f * (3 - 2 * f)
    res = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2])
                res = res + w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return res * 2 - 1


def fbm(P, freq=1.0, octaves=4, seed=0, gain=0.5):
    amp, tot, s = 1.0, 0.0, 0.0
    for o in range(octaves):
        s = s + amp * value_noise(P, freq * (2 ** o), seed + o * 17)
        tot += amp
        amp *= gain
    return s / tot


# ---------------------------------------------------------------- meshing
def _eval_grid(node, lo, voxel, n, stride=1):
    xs = lo[0] + np.arange(0, n[0], stride, dtype=np.float32) * voxel
    ys = lo[1] + np.arange(0, n[1], stride, dtype=np.float32) * voxel
    zs = lo[2] + np.arange(0, n[2], stride, dtype=np.float32) * voxel
    X, Y, Z = np.meshgrid(xs, ys, zs, indexing='ij')
    P = np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1)
    out = np.empty(len(P), dtype=np.float32)
    for s in range(0, len(P), 2_000_000):
        out[s:s + 2_000_000] = node.eval(P[s:s + 2_000_000])[0]
    return out.reshape(X.shape)


def mesh_sdf(node, voxel=0.004, pad=0.03, bounds=None, coarse=4):
    """Narrow-band marching cubes: a coarse pass finds the surface, the fine pass
    only evaluates voxels near it."""
    from skimage.measure import marching_cubes
    from scipy.ndimage import zoom

    lo, hi = bounds if bounds is not None else node.bounds()
    lo = v3(lo) - pad
    hi = v3(hi) + pad
    n = np.ceil((hi - lo) / voxel).astype(int) + 1
    n = ((n + coarse - 1) // coarse) * coarse + 1
    cv = _eval_grid(node, lo, voxel, n, coarse)
    vol = zoom(cv, [(n[i]) / cv.shape[i] for i in range(3)], order=1).astype(np.float32)
    vol = vol[:n[0], :n[1], :n[2]]
    band = np.nonzero(np.abs(vol) < voxel * coarse * 1.9)
    P = np.stack([lo[0] + band[0] * voxel, lo[1] + band[1] * voxel, lo[2] + band[2] * voxel], axis=1).astype(np.float32)
    out = np.empty(len(P), dtype=np.float32)
    for s in range(0, len(P), 2_000_000):
        out[s:s + 2_000_000] = node.eval(P[s:s + 2_000_000])[0]
    vol[band] = out
    verts, faces, normals, _ = marching_cubes(vol, level=0.0, spacing=(voxel, voxel, voxel))
    verts = verts.astype(np.float32) + lo
    # Orient faces outward (along the field gradient).
    tri = verts[faces]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    c = tri.mean(axis=1)
    g = sdf_normals(node, c[:2000])
    if np.mean(np.einsum('ij,ij->i', fn[:2000], g)) < 0:
        faces = faces[:, ::-1].copy()
    return verts, faces


def sdf_normals(node, P, eps=0.002):
    e = np.eye(3, dtype=np.float32) * eps
    g = np.stack([node.eval(P + e[i])[0] - node.eval(P - e[i])[0] for i in range(3)], axis=1)
    return g / (np.linalg.norm(g, axis=1, keepdims=True) + 1e-9)


def sdf_ao(node, P, N, steps=5, delta=0.012, strength=1.0):
    """Classic distance-field ambient occlusion (0 = occluded, 1 = open)."""
    occ = np.zeros(len(P), dtype=np.float32)
    w = 1.0
    for i in range(1, steps + 1):
        h = delta * i
        d, _ = node.eval(P + N * h)
        occ += w * np.maximum(h - d, 0)
        w *= 0.6
    return np.clip(1.0 - strength * occ / delta * 0.9, 0.0, 1.0)
