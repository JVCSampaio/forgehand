"""Humanoid skeleton definitions and automatic skin weights.

Every humanoid (human, goblin, kobold, skeleton) uses the same bone names and
hierarchy, so the runtime can treat them alike and every animation clip is
authored once. Proportions change per species; bone directions do not.
"""
import numpy as np

HUMANOID_BONES = [
    # name, parent, head joint, tail joint
    ('root', None, 'root', 'root_tail'),
    ('hips', 'root', 'pelvis', 'spine'),
    ('spine', 'hips', 'spine', 'chest'),
    ('chest', 'spine', 'chest', 'neck'),
    ('neck', 'chest', 'neck', 'head'),
    ('head', 'neck', 'head', 'head_top'),
    ('clavicle_L', 'chest', 'clav_L', 'shoulder_L'),
    ('upperarm_L', 'clavicle_L', 'shoulder_L', 'elbow_L'),
    ('forearm_L', 'upperarm_L', 'elbow_L', 'wrist_L'),
    ('hand_L', 'forearm_L', 'wrist_L', 'hand_end_L'),
    ('thigh_L', 'hips', 'hip_L', 'knee_L'),
    ('shin_L', 'thigh_L', 'knee_L', 'ankle_L'),
    ('foot_L', 'shin_L', 'ankle_L', 'ball_L'),
    ('toe_L', 'foot_L', 'ball_L', 'toe_L'),
]
TAIL_BONES = [
    ('tail_1', 'hips', 'tail_0', 'tail_1'),
    ('tail_2', 'tail_1', 'tail_1', 'tail_2'),
    ('tail_3', 'tail_2', 'tail_2', 'tail_3'),
]


def mirrored(bones):
    out = []
    for b in bones:
        out.append(b)
        if b[0].endswith('_L'):
            out.append(tuple(x.replace('_L', '_R') if isinstance(x, str) else x for x in b))
    return out


def mirror_joints(J):
    J = dict(J)
    for k in list(J):
        if k.endswith('_L'):
            x, y, z = J[k]
            J[k[:-2] + '_R'] = (-x, y, z)
    return J


def human_joints(height=1.78, sex=0.0):
    """Joint positions in metres. sex: 0 masculine .. 1 feminine proportions."""
    s = height / 1.78
    sh = 0.185 - 0.022 * sex   # shoulder joint half-width
    hp = 0.092 + 0.008 * sex   # hip joint half-width
    J = {
        'root': (0, 0, 0), 'root_tail': (0, 0, 0.18),
        'pelvis': (0, 0.005, 0.965), 'spine': (0, 0.0, 1.07), 'chest': (0, 0.006, 1.25),
        'neck': (0, 0.014, 1.472), 'head': (0, 0.01, 1.585), 'head_top': (0, 0.004, 1.785),
        'clav_L': (0.02, -0.018, 1.44), 'shoulder_L': (sh, 0.012, 1.425),
        'elbow_L': (sh + 0.05, 0.032, 1.148), 'wrist_L': (sh + 0.083, 0.004, 0.905),
        'hand_end_L': (sh + 0.098, -0.006, 0.735),
        'hip_L': (hp, 0.0, 0.935), 'knee_L': (hp + 0.008, -0.014, 0.52),
        'ankle_L': (hp + 0.014, 0.03, 0.088), 'ball_L': (hp + 0.02, -0.088, 0.024),
        'toe_L': (hp + 0.023, -0.158, 0.02),
    }
    J = {k: tuple(np.array(v) * s) for k, v in J.items()}
    return mirror_joints(J)


# ------------------------------------------------------------ skin weights
def _seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0, 1)
    return np.linalg.norm(P - (a + np.outer(t, ab)), axis=1)


def auto_weights(P, J, bones, deform=None, power=5.0, max_inf=3, radius_fn=None, extra_segments=None):
    """Inverse-distance weights to bone segments, side-aware and capped to the
    strongest `max_inf` bones. Returns (names, W[N, B])."""
    names = [b[0] for b in bones if (deform is None or b[0] in deform) and b[0] != 'root']
    W = np.zeros((len(P), len(names)), dtype=np.float64)
    x = P[:, 0]
    for j, name in enumerate(names):
        b = next(bb for bb in bones if bb[0] == name)
        a, t = np.array(J[b[2]]), np.array(J[b[3]])
        d = _seg_dist(P, a, t)
        if extra_segments and name in extra_segments:
            for (ea, eb) in extra_segments[name]:
                d = np.minimum(d, _seg_dist(P, np.array(ea), np.array(eb)))
        d = np.maximum(d, 0.004)
        w = 1.0 / d ** power
        if name.endswith('_L'):
            w *= np.clip((x + 0.012) / 0.024, 0, 1)
        elif name.endswith('_R'):
            w *= np.clip((-x + 0.012) / 0.024, 0, 1)
        W[:, j] = w
    # keep strongest influences
    if max_inf < len(names):
        idx = np.argsort(-W, axis=1)[:, max_inf:]
        np.put_along_axis(W, idx, 0, axis=1)
    W /= W.sum(axis=1, keepdims=True) + 1e-12
    return names, W


def smooth_weights(W, faces, iterations=3, alpha=0.5):
    """Laplacian smoothing of weights over mesh edges."""
    n = len(W)
    e = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]])
    e = np.concatenate([e, e[:, ::-1]])
    import scipy.sparse as sp
    A = sp.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)).tocsr()
    A.data[:] = 1
    deg = np.asarray(A.sum(axis=1)).ravel()
    deg[deg == 0] = 1
    for _ in range(iterations):
        avg = (A @ W) / deg[:, None]
        W = W * (1 - alpha) + avg * alpha
    W /= W.sum(axis=1, keepdims=True) + 1e-12
    return W


def limit_influences(W, k=4):
    if W.shape[1] > k:
        idx = np.argsort(-W, axis=1)[:, k:]
        np.put_along_axis(W, idx, 0, axis=1)
    W[W < 0.01] = 0
    W /= W.sum(axis=1, keepdims=True) + 1e-12
    return W


def transfer_weights(P, bodyP, bodyW, k=6):
    """Garment weights copied from the nearest body vertices."""
    from scipy.spatial import cKDTree
    tree = cKDTree(bodyP)
    d, i = tree.query(P, k=k)
    w = 1.0 / np.maximum(d, 1e-4) ** 2
    w /= w.sum(axis=1, keepdims=True)
    W = np.einsum('nk,nkb->nb', w, bodyW[i])
    return W / (W.sum(axis=1, keepdims=True) + 1e-12)
