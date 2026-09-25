"""Anatomical SDF builders shared by every humanoid species.

Bodies are sculpted from the skeleton's joints, so a goblin or a kobold is the
same code with other joints and flesh parameters. Distances in metres.
"""
import numpy as np
from sdf import (Union, Subtract, Intersect, Sphere, Ellipsoid, RoundCone, Capsule, RoundBox, Plane,
                 Mirror, Displace, look_matrix, rot_matrix, blend, fbm, v3)

SKIN, EYE, NAIL, MOUTH, HORN, SCALE = 0, 1, 2, 3, 4, 5


def lerp(a, b, t):
    return v3(a) + (v3(b) - v3(a)) * t


def along(J, a, b, t, off=(0, 0, 0)):
    return lerp(J[a], J[b], t) + v3(off)


def limb_rot(J, a, b):
    return look_matrix(v3(J[b]) - v3(J[a]))


def muscle(J, a, b, t, radii, off=(0, 0, 0)):
    """Ellipsoid aligned with the bone a->b (radii: across X, along bone, across Z)."""
    R = limb_rot(J, a, b)
    return Ellipsoid(along(J, a, b, t, off), radii, rot=R)


def hand(J, side='L', scale=1.0, curl=0.35, claws=False, fingers=4, finger_r=0.0085, spread=1.0):
    """Relaxed hand, palm towards the thigh, thumb forward (-Y)."""
    sx = 1 if side == 'L' else -1
    w = v3(J['wrist_' + side])
    e = v3(J['hand_end_' + side])
    down = (e - w) / np.linalg.norm(e - w)
    L = np.linalg.norm(e - w) * scale
    palm_len = L * 0.52
    parts = []
    R = look_matrix(down, up=(0, -1, 0))  # local Y along the hand
    palm_c = w + down * palm_len * 0.55
    parts.append(RoundBox(palm_c, (0.011 * scale, palm_len * 0.55, 0.036 * scale), r=0.01 * scale, rot=R))
    parts.append(Ellipsoid(w + down * 0.012 * scale, (0.018 * scale, 0.02 * scale, 0.026 * scale)))
    knuck = w + down * palm_len
    inward = v3((-sx, 0, 0))
    offs = np.linspace(-0.027, 0.027, fingers) * scale * spread if fingers > 1 else [0.0]
    lens = [0.95, 1.0, 0.95, 0.8][:fingers] if fingers == 4 else [1.0] * fingers
    for i, oy in enumerate(offs):
        base = knuck + v3((0, oy, 0))
        fl = L * 0.48 * lens[i]
        d1 = down
        d2 = down * np.cos(curl) + inward * np.sin(curl)
        d3 = down * np.cos(curl * 2.2) + inward * np.sin(curl * 2.2)
        p1 = base + d1 * fl * 0.45
        p2 = p1 + d2 * fl * 0.32
        p3 = p2 + d3 * fl * 0.26
        r = finger_r * scale
        parts.append(RoundCone(base - down * 0.01, p1, r * 1.1, r))
        parts.append(RoundCone(p1, p2, r, r * 0.92))
        parts.append(RoundCone(p2, p3, r * 0.92, r * (0.55 if claws else 0.8)))
    # thumb: from the base of the palm, forward and down
    tb = w + down * palm_len * 0.28 + v3((-sx * 0.004, -0.024 * scale, 0))
    t1 = tb + (down * 0.45 + v3((-sx * 0.35, -0.75, 0))) * 0.03 * scale
    t2 = t1 + (down * 0.8 + v3((-sx * 0.45, -0.3, 0))) * 0.028 * scale
    parts.append(RoundCone(tb, t1, 0.012 * scale, 0.0095 * scale))
    parts.append(RoundCone(t1, t2, 0.0095 * scale, 0.008 * scale))
    return Union(parts, k=0.006 * scale)


def foot(J, side='L', scale=1.0, bare=True, claws=0):
    a = v3(J['ankle_' + side])
    b = v3(J['ball_' + side])
    t = v3(J['toe_' + side])
    parts = [
        Sphere(a, 0.034 * scale),
        Sphere((a[0], a[1] + 0.025 * scale, 0.038 * scale), 0.033 * scale),  # heel
        RoundCone((a[0], a[1] + 0.01, 0.045 * scale), (b[0], b[1], 0.03 * scale), 0.036 * scale, 0.028 * scale),
        RoundBox(lerp(a, b, 0.55) * v3((1, 1, 0)) + v3((0, 0, 0.028 * scale)), (0.036 * scale, 0.07 * scale, 0.022 * scale), r=0.018 * scale,
                 rot=look_matrix(b - a * v3((1, 1, 0)) - v3((0, 0, b[2])))),
    ]
    if bare:
        for i, dx in enumerate(np.linspace(-0.024, 0.026, 5) * scale):
            ln = [0.052, 0.046, 0.042, 0.037, 0.032][i] * scale
            base = v3((b[0] + dx * (1 if side == 'L' else -1), b[1] + 0.006, 0.02 * scale))
            r = (0.0115 if i == 0 else 0.0085) * scale
            parts.append(Capsule(base, base + v3((0, -ln, -0.004 * scale)), r))
    else:
        parts.append(RoundBox((b[0], (b[1] + t[1]) / 2, 0.022 * scale), (0.037 * scale, 0.045 * scale, 0.02 * scale), r=0.018 * scale))
    if claws:
        for i, dx in enumerate(np.linspace(-0.022, 0.022, claws) * scale):
            base = v3((b[0] + dx, b[1] - 0.03 * scale, 0.02 * scale))
            parts.append(RoundCone(base, base + v3((0, -0.05 * scale, -0.012 * scale)), 0.012 * scale, 0.003 * scale))
    f = Union(parts, k=0.02 * scale)
    return Subtract(f, Plane((0, 0, 0.0), (0, 0, 1)), k=0.004)


def human_head(J, p):
    """Human head sculpt. p: dict with sex (0..1), jaw, nose, brow, ears."""
    sex = p.get('sex', 0.0)
    h = v3(J['head'])
    top = v3(J['head_top'])
    s = (top[2] - h[2]) / 0.2  # head scale
    c = h + v3((0, 0.0, 0.1)) * s  # skull centre
    def P(x, y, z):
        return c + v3((x, y, z)) * s
    jaw = p.get('jaw', 1.0) * (1 - 0.25 * sex)
    parts = [
        Ellipsoid(P(0, 0.012, 0.012), (0.073, 0.093, 0.09)),                      # cranium
        blend(Ellipsoid(P(0, -0.026, -0.05), (0.056 * (0.9 + 0.1 * jaw), 0.05, 0.064)), 0.035),  # face mass
        blend(Sphere(P(0, -0.064, -0.104), 0.02 * (0.85 + 0.15 * jaw)), 0.03),   # chin
        blend(Mirror(Sphere(P(0.047 * jaw, -0.004, -0.078), 0.019)), 0.04),        # jaw angle
        blend(Mirror(Ellipsoid(P(0.046, -0.058, -0.028), (0.022, 0.02, 0.017))), 0.02),  # cheekbones
        blend(Capsule(P(-0.042, -0.08, 0.012), P(0.042, -0.08, 0.012), 0.012 * (1.1 - 0.4 * sex) * p.get('brow', 1.0)), 0.025),
        # nose
        blend(RoundCone(P(0, -0.087, 0.006), P(0, -0.104 * p.get('nose', 1.0), -0.038), 0.0085, 0.012), 0.012),
        blend(Mirror(Sphere(P(0.0125, -0.094, -0.042), 0.0095)), 0.008),
        # lips
        blend(Capsule(P(-0.019, -0.088, -0.059), P(0.019, -0.088, -0.059), 0.0068 + 0.001 * sex), 0.01),
        blend(Capsule(P(-0.016, -0.085, -0.071), P(0.016, -0.085, -0.071), 0.0078 + 0.0012 * sex), 0.01),
    ]
    ears = Mirror(Union([
        Ellipsoid(P(0.074, 0.006, -0.018), (0.011, 0.019, 0.031), rot=rot_matrix(0, 0, -12)),
    ]))
    parts.append(blend(ears, 0.01))
    head = Union(parts, k=0.02)
    cut = [
        Mirror(Sphere(P(0.032, -0.084, -0.002), 0.0145)),               # eye sockets
        Mirror(Sphere(P(0.083, 0.004, -0.02), 0.009)),                  # ear concha
        Capsule(P(-0.018, -0.1, -0.065), P(0.018, -0.1, -0.065), 0.0022),  # mouth line
    ]
    head = Subtract(head, cut, k=0.008)
    eyes = Mirror(Sphere(P(0.032, -0.071, -0.003), 0.0118, mat=EYE))
    return head, eyes, P


def human_body(J, p):
    """Full human body (without head) from joints. p: sex, muscle, fat."""
    sex = p.get('sex', 0.0)
    mus = p.get('muscle', 0.5)
    fat = p.get('fat', 0.2)
    sc = (v3(J['head_top'])[2]) / 1.785
    def S(x):
        return x * sc
    pel, sp, ch, nk = (v3(J[k]) for k in ('pelvis', 'spine', 'chest', 'neck'))
    parts = []
    # --- torso
    parts += [
        Ellipsoid(ch + v3((0, 0.004, S(0.05))), (S(0.142 - 0.02 * sex + 0.01 * mus), S(0.1), S(0.17))),   # ribcage
        Ellipsoid(ch + v3((0, 0.056, S(0.07))), (S(0.12), S(0.055), S(0.14))),                            # upper back
        Ellipsoid(sp + v3((0, 0.002, S(0.03))), (S(0.122 - 0.015 * sex + 0.03 * fat), S(0.078 + 0.03 * fat), S(0.13))),  # abdomen
        Ellipsoid(pel + v3((0, 0.004, 0)), (S(0.15 + 0.022 * sex), S(0.102), S(0.1))),                  # pelvis
        Mirror(Ellipsoid(pel + v3((S(0.066 + 0.01 * sex), S(0.062 + 0.01 * sex), S(-0.04))), (S(0.07 + 0.012 * sex), S(0.06), S(0.078)))),  # glutes
        Mirror(Ellipsoid(ch + v3((S(0.105 - 0.01 * sex), S(0.045), S(0.06))), (S(0.05 + 0.02 * mus), S(0.055), S(0.12)))),  # lats
        Mirror(RoundCone(nk + v3((S(0.026), S(0.024), S(0.0))), v3(J['shoulder_L']) + v3((S(-0.04), S(0.02), S(0.018))), S(0.03 + 0.006 * mus), S(0.024))),  # traps
        Mirror(Capsule(v3(J['clav_L']) + v3((0, S(-0.026), S(0.012))), v3(J['shoulder_L']) + v3((S(-0.035), S(-0.018), S(0.024))), S(0.012))),  # clavicles
        RoundCone(nk + v3((0, S(0.006), S(-0.035))), v3(J['head']) + v3((0, S(0.004), S(0.02))), S(0.056 - 0.006 * sex), S(0.047 - 0.005 * sex)),  # neck
        Mirror(Capsule(v3(J['head']) + v3((S(0.042), S(0.012), S(-0.012))), nk + v3((S(0.018), S(-0.042), S(-0.03))), S(0.015))),  # SCM
    ]
    if sex < 0.5:
        parts.append(Mirror(Ellipsoid(ch + v3((S(0.066), S(-0.066), S(0.085))), (S(0.07), S(0.03 + 0.012 * mus), S(0.052)), rot=rot_matrix(0, 12, 0))))  # pecs
    else:
        parts.append(Mirror(Ellipsoid(ch + v3((S(0.068), S(-0.07), S(0.07))), (S(0.058), S(0.05), S(0.054)), rot=rot_matrix(-12, 10, 0))))  # breasts
    torso = Union(parts, k=S(0.045))
    # --- arm (left, mirrored)
    sh, el, wr = v3(J['shoulder_L']), v3(J['elbow_L']), v3(J['wrist_L'])
    arm = [
        Ellipsoid(sh + v3((S(0.008), S(0.0), S(-0.022))), (S(0.043 + 0.008 * mus), S(0.075), S(0.05)), rot=limb_rot(J, 'shoulder_L', 'elbow_L')),  # deltoid
        RoundCone(sh, el, S(0.045 - 0.005 * sex), S(0.034 - 0.004 * sex)),
        muscle(J, 'shoulder_L', 'elbow_L', 0.5, (S(0.03 + 0.012 * mus), S(0.085), S(0.034)), off=(0, S(-0.014), 0)),   # biceps
        muscle(J, 'shoulder_L', 'elbow_L', 0.42, (S(0.032 + 0.008 * mus), S(0.095), S(0.034)), off=(0, S(0.016), 0)),  # triceps
        Sphere(el, S(0.032)),
        RoundCone(el, wr, S(0.037 - 0.004 * sex), S(0.025 - 0.003 * sex)),
        muscle(J, 'elbow_L', 'wrist_L', 0.28, (S(0.038 + 0.006 * mus), S(0.08), S(0.034)), off=(S(0.004), S(-0.004), 0)),  # forearm
    ]
    armU = Union(arm, k=S(0.03))
    handL = hand(J, 'L', scale=sc * (1 - 0.1 * sex))
    # --- leg (left, mirrored)
    hp, kn, an = v3(J['hip_L']), v3(J['knee_L']), v3(J['ankle_L'])
    leg = [
        RoundCone(hp + v3((S(-0.01), 0, S(0.03))), kn, S(0.083 + 0.01 * sex + 0.01 * fat), S(0.05)),
        muscle(J, 'hip_L', 'knee_L', 0.45, (S(0.058 + 0.008 * mus), S(0.15), S(0.05)), off=(S(0.006), S(-0.022), 0)),  # quads
        muscle(J, 'hip_L', 'knee_L', 0.4, (S(0.052), S(0.14), S(0.05)), off=(0, S(0.024), 0)),                   # hamstrings
        muscle(J, 'hip_L', 'knee_L', 0.3, (S(0.04), S(0.12), S(0.045)), off=(S(-0.03), S(-0.004), 0)),           # adductors
        Sphere(kn + v3((0, S(-0.004), 0)), S(0.047)),
        Sphere(kn + v3((0, S(-0.04), S(0.006))), S(0.022)),                                                  # kneecap
        RoundCone(kn, an, S(0.048), S(0.028)),
        muscle(J, 'knee_L', 'ankle_L', 0.3, (S(0.042 + 0.006 * mus), S(0.11), S(0.042)), off=(S(-0.002), S(0.026), 0)),   # calf
        muscle(J, 'knee_L', 'ankle_L', 0.35, (S(0.026), S(0.13), S(0.022)), off=(S(0.004), S(-0.022), 0)),       # shin
    ]
    legU = Union(leg, k=S(0.035))
    footL = foot(J, 'L', scale=sc * (1 - 0.08 * sex))
    limbs = Mirror(Union([armU, blend(handL, S(0.012)), blend(legU, S(0.05)), blend(footL, S(0.025))], k=S(0.03)))
    return Union([torso, blend(limbs, S(0.035))], k=S(0.035))
