"""Skin and eye texture painting for MakeHuman bodies.

The base colour is a *detail multiplier* around 0.8: the runtime material colour
is the skin tone, so one texture serves every tone and species.
"""
import os
import numpy as np
from PIL import Image

import texbake as tb
from sdf import fbm, value_noise

MASKS = os.environ.get('MPFB_TEX', '')


def load_mask(name, res):
    p = os.path.join(MASKS, f'mpfb_{name}.jpg')
    if not os.path.exists(p):
        return np.zeros((res, res), np.float32)
    im = Image.open(p).convert('L').resize((res, res), Image.BILINEAR)
    return np.asarray(im, np.float32) / 255.0


def gauss(pos, c, r):
    d2 = np.sum((pos - np.asarray(c, np.float32)) ** 2, axis=-1)
    return np.exp(-d2 / (r * r))


def paint_skin(pos, nrm, mask, J, res, ao=None, species='human', seed=0):
    """J: dict of joint positions (world, metres). Returns (albedo, rough, height)."""
    P = pos
    m = mask
    idx = np.nonzero(m)
    alb = np.ones((res, res, 3), np.float32) * 0.82
    red = np.zeros((res, res), np.float32)

    def f(fn):
        out = np.zeros(m.shape, np.float32)
        out[idx] = fn(P[idx])
        return out

    # large-scale mottling and blotches
    mott = f(lambda p: fbm(p, 9.0, 4, seed + 3))
    blot = f(lambda p: fbm(p, 22.0, 3, seed + 11))
    alb *= (1 + 0.05 * mott)[..., None]
    red += np.clip(blot, 0, 1) * 0.25
    # anatomical flush: cheeks, nose, ears, knuckles, elbows, knees, palms, soles, fingertips
    head = np.asarray(J['head'])
    eyeL, eyeR = np.asarray(J['eye_l']), np.asarray(J['eye_r'])
    face_fwd = np.array([0, -1, 0], np.float32)
    nose = (eyeL + eyeR) / 2 + face_fwd * 0.03 + np.array([0, 0, -0.035])
    for c, r, k in [
        (nose, 0.022, 0.8),
        (eyeL + np.array([0.012, -0.012, -0.032]), 0.026, 0.55),
        (eyeR + np.array([-0.012, -0.012, -0.032]), 0.026, 0.55),
        (J['elbow_l'], 0.05, 0.35), (J['elbow_r'], 0.05, 0.35),
        (J['knee_l'], 0.06, 0.35), (J['knee_r'], 0.06, 0.35),
    ]:
        red += gauss(P, c, r) * k * m
    for side in ('l', 'r'):
        hand = np.asarray(J['hand_' + side])
        red += gauss(P, hand, 0.09) * 0.35 * m
        red += gauss(P, np.asarray(J['finger_' + side]), 0.05) * 0.4 * m
        red += gauss(P, np.asarray(J['foot_' + side]) + np.array([0, -0.08, -0.05]), 0.08) * 0.3 * m
    ears = load_mask('ears', res)
    lips = load_mask('lips', res)
    lids = load_mask('eyelids', res)
    fnail = load_mask('fingernails', res)
    tnail = load_mask('toenails', res)
    mouth = load_mask('inside-mouth', res)
    areo = load_mask('aureolae', res)
    face = load_mask('face', res)
    red += ears * 0.5 + lids * 0.45
    red = np.clip(red, 0, 1.4)
    tint_red = np.array([1.0, 0.8, 0.78], np.float32)
    alb *= (1 - red[..., None] * (1 - tint_red) * 0.9)
    # lips, nails, mouth, areolae
    alb = alb * (1 - lips[..., None] * 0.35) + lips[..., None] * 0.35 * np.array([0.74, 0.52, 0.52])
    nails = np.clip(fnail + tnail, 0, 1)[..., None]
    alb = alb * (1 - nails) + nails * np.array([0.93, 0.82, 0.8])
    alb = alb * (1 - mouth[..., None]) + mouth[..., None] * np.array([0.45, 0.16, 0.17])
    alb *= (1 - areo[..., None] * np.array([0.1, 0.28, 0.3]))
    # veins (faint, inner forearms and temples)
    veins = f(lambda p: np.abs(fbm(p * np.array([1, 1, 0.3], np.float32), 38.0, 2, seed + 21)))
    vmask = np.zeros_like(red)
    for side in ('l', 'r'):
        a, b = np.asarray(J['elbow_' + side]), np.asarray(J['hand_' + side])
        for t in np.linspace(0.2, 0.9, 5):
            vmask += gauss(P, a + (b - a) * t, 0.045) * m
    vl = np.clip(1 - veins * 12, 0, 1) * np.clip(vmask, 0, 1) * 0.12
    alb *= (1 - vl[..., None] * np.array([0.2, 0.05, -0.1]))
    # ambient occlusion baked lightly (cavities only, real lighting does the rest)
    if ao is not None:
        a = np.clip(ao, 0, 1)
        alb *= (0.55 + 0.45 * a)[..., None]
    # micro detail: pores (height), fine creases
    pores = f(lambda p: value_noise(p, 900.0, seed + 5))
    pores2 = f(lambda p: value_noise(p, 420.0, seed + 6))
    crease = f(lambda p: np.abs(fbm(p, 60.0, 2, seed + 9)))
    height = -np.clip(pores, 0.25, 1) * 0.7 - np.clip(pores2, 0.4, 1) * 0.5 + np.clip(1 - crease * 10, 0, 1) * -0.4
    height *= (0.6 + 0.8 * face)
    alb *= (1 + 0.035 * f(lambda p: value_noise(p, 300.0, seed + 8)))[..., None]
    # roughness: oily T-zone and lips shinier
    rough = np.full((res, res), 0.58, np.float32)
    tzone = gauss(P, nose + np.array([0, 0, 0.02]), 0.03) + gauss(P, (eyeL + eyeR) / 2 + np.array([0, -0.01, 0.045]), 0.03)
    rough -= np.clip(tzone, 0, 1) * 0.18 * m
    rough -= lips * 0.2 + nails[..., 0] * 0.25
    rough += np.clip(pores, 0, 1) * 0.08
    rough = np.clip(rough, 0.25, 0.9)
    return np.clip(alb, 0, 1), rough, height


def paint_eye(pos, mask, res, centers, fwd=(0, -1, 0), iris_deg=24.0, pupil_deg=9.0, seed=0):
    """Eyeball texture split in two: sclera (fixed) and iris (tinted at runtime)."""
    fwd = np.asarray(fwd, np.float32)
    sclera = np.ones((res, res, 3), np.float32) * np.array([0.93, 0.9, 0.87])
    iris = np.zeros((res, res, 3), np.float32)
    ang = np.full((res, res), np.pi, np.float32)
    for c in centers:
        d = pos - np.asarray(c, np.float32)
        n = np.linalg.norm(d, axis=-1)
        close = n < 0.02
        cosang = np.einsum('ijk,k->ij', d, fwd) / np.maximum(n, 1e-9)
        a = np.arccos(np.clip(cosang, -1, 1))
        ang = np.where(close & (a < ang), a, ang)
    deg = np.degrees(ang)
    idx = np.nonzero(mask)
    fib = np.zeros(mask.shape, np.float32)
    fib[idx] = fbm(pos[idx] * np.array([1, 1, 1], np.float32), 900.0, 3, seed)
    # sclera: faint vessels towards the corners, darker limbal ring
    ves = np.zeros(mask.shape, np.float32)
    ves[idx] = np.abs(fbm(pos[idx], 500.0, 3, seed + 3))
    corner = np.clip((deg - 35) / 40, 0, 1)
    sclera *= (1 - (np.clip(0.05 - ves, 0, 0.05) * 8 * corner)[..., None] * np.array([0.0, 0.5, 0.5]))
    limbal = np.clip(1 - np.abs(deg - iris_deg) / 4.0, 0, 1)
    sclera *= (1 - limbal * 0.55)[..., None]
    # iris: radial fibres, bright collarette, dark pupil
    r = np.clip(deg / iris_deg, 0, 1)
    val = 0.62 + 0.25 * fib - 0.25 * r + 0.25 * np.exp(-((r - 0.45) / 0.12) ** 2)
    iris = np.repeat(val[..., None], 3, -1)
    iris *= (1 - np.clip(1 - np.abs(r - 0.97) / 0.06, 0, 1) * 0.6)[..., None]
    pup = deg < pupil_deg
    iris[pup] = 0.03
    in_iris = deg < iris_deg
    return np.clip(sclera, 0, 1), np.clip(iris, 0, 1), in_iris
